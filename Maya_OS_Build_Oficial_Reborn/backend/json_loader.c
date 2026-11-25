#include "json_loader.h"
#include "cJSON.h"
#include "ui.h"

#include <limits.h>
#include <math.h>
#include <string.h>

static bk_status campo_texto(const cJSON *obj, const char *nome, char *dst, size_t cap, char *err, size_t errcap) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(obj, nome);
    if (!cJSON_IsString(item) || item->valuestring == NULL) {
        bk_err(err, errcap, "campo '%s' ausente ou nao textual", nome);
        return BK_ERR_ESQUEMA;
    }
    if (!bk_copiar(dst, cap, item->valuestring)) {
        bk_err(err, errcap, "campo '%s' tem %zu bytes (limite %zu)", nome, strlen(item->valuestring), cap - 1);
        return BK_ERR_LIMITE;
    }
    return BK_OK;
}

static bk_status campo_inteiro(const cJSON *obj, const char *nome, int *dst, char *err, size_t errcap) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(obj, nome);
    if (!cJSON_IsNumber(item) || !isfinite(item->valuedouble) || item->valuedouble != floor(item->valuedouble) ||
        item->valuedouble < (double)INT_MIN || item->valuedouble > (double)INT_MAX) {
        bk_err(err, errcap, "campo '%s' ausente ou nao e um inteiro", nome);
        return BK_ERR_ESQUEMA;
    }
    *dst = (int)item->valuedouble;
    return BK_OK;
}

/* "delegated" aparece como 0/1 em roteiros antigos e como true/false nos novos. */
static bk_status campo_booleano(const cJSON *obj, const char *nome, bool *dst, char *err, size_t errcap) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(obj, nome);
    if (cJSON_IsBool(item)) {
        *dst = cJSON_IsTrue(item);
        return BK_OK;
    }
    if (cJSON_IsNumber(item) && (item->valuedouble == 0.0 || item->valuedouble == 1.0)) {
        *dst = item->valuedouble == 1.0;
        return BK_OK;
    }
    bk_err(err, errcap, "campo '%s' ausente ou nao booleano", nome);
    return BK_ERR_ESQUEMA;
}

bk_status carregar_turno(const struct cJSON *turno_json, Turn *out, char *err, size_t cap) {
    if (turno_json == NULL || out == NULL) {
        bk_err(err, cap, "carregar_turno: ponteiro nulo");
        return BK_ERR_ARG;
    }
    memset(out, 0, sizeof *out);
    const cJSON *msgs = cJSON_GetObjectItemCaseSensitive(turno_json, "messages");
    if (!cJSON_IsArray(msgs)) {
        bk_err(err, cap, "turno sem lista 'messages'");
        return BK_ERR_ESQUEMA;
    }
    if (cJSON_GetArraySize(msgs) > MAX_MESSAGES) {
        bk_err(err, cap, "turno com %d mensagens (limite %d)", cJSON_GetArraySize(msgs), MAX_MESSAGES);
        return BK_ERR_LIMITE;
    }
    const cJSON *m_item = NULL;
    cJSON_ArrayForEach(m_item, msgs) {
        Message *m = &out->messages[out->message_count];
        bk_status st = campo_inteiro(m_item, "id", &m->id, err, cap);
        if (st == BK_OK) {
            st = campo_texto(m_item, "timestamp", m->timestamp, sizeof m->timestamp, err, cap);
        }
        if (st == BK_OK) {
            st = campo_texto(m_item, "sender", m->sender, sizeof m->sender, err, cap);
        }
        if (st == BK_OK) {
            st = campo_texto(m_item, "text", m->text, sizeof m->text, err, cap);
        }
        if (st != BK_OK) {
            return st;
        }
        out->message_count++;
    }
    const cJSON *choices = cJSON_GetObjectItemCaseSensitive(turno_json, "choices");
    if (!cJSON_IsArray(choices)) {
        bk_err(err, cap, "turno sem lista 'choices'");
        return BK_ERR_ESQUEMA;
    }
    if (cJSON_GetArraySize(choices) > MAX_CHOICES) {
        bk_err(err, cap, "turno com %d escolhas (limite %d)", cJSON_GetArraySize(choices), MAX_CHOICES);
        return BK_ERR_LIMITE;
    }
    const cJSON *c_item = NULL;
    cJSON_ArrayForEach(c_item, choices) {
        Choice *c = &out->choices[out->choice_count];
        bk_status st = campo_inteiro(c_item, "choice_id", &c->id, err, cap);
        if (st == BK_OK) {
            st = campo_texto(c_item, "text", c->text, sizeof c->text, err, cap);
        }
        if (st == BK_OK) {
            st = campo_inteiro(c_item, "autonomy_impact", &c->autonomy_impact, err, cap);
        }
        if (st == BK_OK) {
            st = campo_booleano(c_item, "delegated", &c->delegated, err, cap);
        }
        if (st == BK_OK) {
            st = campo_texto(c_item, "nexus_reply", c->nexus_reply, sizeof c->nexus_reply, err, cap);
        }
        if (st != BK_OK) {
            return st;
        }
        out->choice_count++;
    }
    return BK_OK;
}

/* ------------------------------------------------------------------ formato "dialogue" (roteiro Maya v2: grafo de nós)
 * Esquema aceito (maya_dialogue.json):
 *   { "start_node": "<id>" (opcional; padrão: primeiro nó),
 *     "dialogue": [ { "id": "<id>", "task"|"stage": "<título>" (opcional), "speaker": "<quem>" (opcional, padrão SISTEMA),
 *                     "text": "<fala>", "next": "<id>|END" (obrigatório quando não há escolhas),
 *                     "choices": [ { "id": <int>, "text": "<opção>", "dependency_delta": <int -100..100> (opcional),
 *                                    "delegada": <bool> (opcional), "reply_text": "<resposta>" (opcional),
 *                                    "next": "<id>|END" } ] } ] }
 * Mesmo contrato de carregar_turno: o grafo inteiro é validado ANTES de jogar e um valor que não cabe no buffer, uma lista
 * maior que o máximo, um "next" que aponta para um nó inexistente ou um ciclo sem escolhas é RECUSADO com erro (nada de
 * truncar, descartar ou encerrar em silêncio). */
#define BK_NO_ID_MAX 64
#define BK_NO_FIM "END"
#define BK_DELTA_MAX 100
#define BK_DIALOGO_PASSOS_MAX 100000L /* trava de segurança: nenhum roteiro legítimo chega perto disso */

/* Reescreve `err` como "no '<id>': <mensagem anterior>". */
static void prefixar_no(char *err, size_t cap, const char *id) {
    if (err == NULL || cap == 0) {
        return;
    }
    char anterior[BK_ERR_MSG_MAX];
    (void)bk_copiar(anterior, sizeof anterior, err);
    bk_err(err, cap, "no '%s': %s", id != NULL ? id : "?", anterior);
}

static bk_status texto_opcional(const cJSON *obj, const char *nome, const char *padrao, char *dst, size_t dcap, char *err, size_t cap) {
    if (cJSON_GetObjectItemCaseSensitive(obj, nome) == NULL) {
        if (!bk_copiar(dst, dcap, padrao)) {
            bk_err(err, cap, "valor padrao de '%s' nao cabe", nome);
            return BK_ERR_LIMITE;
        }
        return BK_OK;
    }
    return campo_texto(obj, nome, dst, dcap, err, cap);
}

static const cJSON *no_por_id(const cJSON *dialogo, const char *id) {
    const cJSON *item = NULL;
    cJSON_ArrayForEach(item, dialogo) {
        const cJSON *nid = cJSON_GetObjectItemCaseSensitive(item, "id");
        if (cJSON_IsString(nid) && nid->valuestring != NULL && strcmp(nid->valuestring, id) == 0) {
            return item;
        }
    }
    return NULL;
}

static bool destino_valido(const cJSON *dialogo, const char *destino) {
    return strcmp(destino, BK_NO_FIM) == 0 || no_por_id(dialogo, destino) != NULL;
}

/* Converte um nó em Turn (+ título), validando tipos e limites. */
static bk_status montar_turno_do_no(const cJSON *no, Turn *out, char *titulo, size_t titulo_cap,
                                    char *err, size_t cap) {
    memset(out, 0, sizeof *out);
    bk_status st = BK_OK;
    if (cJSON_GetObjectItemCaseSensitive(no, "task") != NULL) {
        st = campo_texto(no, "task", titulo, titulo_cap, err, cap);
    } else {
        st = texto_opcional(no, "stage", "", titulo, titulo_cap, err, cap);
    }
    Message *m = &out->messages[0];
    m->id = 1;
    (void)bk_copiar(m->timestamp, sizeof m->timestamp, "00:00");
    if (st == BK_OK) {
        st = texto_opcional(no, "speaker", "SISTEMA", m->sender, sizeof m->sender, err, cap);
    }
    if (st == BK_OK) {
        st = campo_texto(no, "text", m->text, sizeof m->text, err, cap);
    }
    if (st != BK_OK) {
        return st;
    }
    out->message_count = 1;

    const cJSON *choices = cJSON_GetObjectItemCaseSensitive(no, "choices");
    if (choices == NULL) {
        return BK_OK;
    }
    if (!cJSON_IsArray(choices)) {
        bk_err(err, cap, "'choices' nao e uma lista");
        return BK_ERR_ESQUEMA;
    }
    if (cJSON_GetArraySize(choices) > MAX_CHOICES) {
        bk_err(err, cap, "%d escolhas (limite %d)", cJSON_GetArraySize(choices), MAX_CHOICES);
        return BK_ERR_LIMITE;
    }
    const cJSON *c_item = NULL;
    cJSON_ArrayForEach(c_item, choices) {
        Choice *c = &out->choices[out->choice_count];
        int delta = 0;
        st = campo_inteiro(c_item, "id", &c->id, err, cap);
        if (st == BK_OK) {
            st = campo_texto(c_item, "text", c->text, sizeof c->text, err, cap);
        }
        if (st == BK_OK && cJSON_GetObjectItemCaseSensitive(c_item, "dependency_delta") != NULL) {
            st = campo_inteiro(c_item, "dependency_delta", &delta, err, cap);
            if (st == BK_OK && (delta < -BK_DELTA_MAX || delta > BK_DELTA_MAX)) {
                bk_err(err, cap, "dependency_delta %d fora de -%d..%d", delta, BK_DELTA_MAX, BK_DELTA_MAX);
                st = BK_ERR_ESQUEMA;
            }
        }
        if (st == BK_OK && cJSON_GetObjectItemCaseSensitive(c_item, "delegada") != NULL) {
            st = campo_booleano(c_item, "delegada", &c->delegated, err, cap);
        }
        if (st == BK_OK) {
            st = texto_opcional(c_item, "reply_text", "", c->nexus_reply, sizeof c->nexus_reply, err, cap);
        }
        if (st != BK_OK) {
            return st;
        }
        for (int k = 0; k < out->choice_count; k++) {
            if (out->choices[k].id == c->id) {
                bk_err(err, cap, "escolha com id %d repetido", c->id);
                return BK_ERR_ESQUEMA;
            }
        }
        /* Modo console legado: delegar à Maya reduz a autonomia exibida; dependency_delta +10 equivale a -10 de autonomia. */
        c->autonomy_impact = -delta;
        out->choice_count++;
    }
    return BK_OK;
}

/* "next" da escolha `escolha_id` (ou do próprio nó, quando ele não tem escolhas). NULL se ausente/não textual. */
static const char *proximo_do_no(const cJSON *no, int escolha_id, bool tem_escolhas) {
    const cJSON *alvo = no;
    if (tem_escolhas) {
        alvo = NULL;
        const cJSON *c_item = NULL;
        cJSON_ArrayForEach(c_item, cJSON_GetObjectItemCaseSensitive(no, "choices")) {
            const cJSON *cid = cJSON_GetObjectItemCaseSensitive(c_item, "id");
            if (cJSON_IsNumber(cid) && (int)cid->valuedouble == escolha_id) {
                alvo = c_item;
                break;
            }
        }
        if (alvo == NULL) {
            return NULL;
        }
    }
    const cJSON *next = cJSON_GetObjectItemCaseSensitive(alvo, "next");
    return (cJSON_IsString(next) && next->valuestring != NULL) ? next->valuestring : NULL;
}

/* Valida o grafo inteiro e devolve o nó inicial em `inicio`. */
static bk_status validar_dialogo(const cJSON *root, const cJSON *dialogo, char *inicio, size_t inicio_cap, char *err, size_t cap) {
    int total = cJSON_GetArraySize(dialogo);
    if (total <= 0) {
        bk_err(err, cap, "'dialogue' esta vazio");
        return BK_ERR_ESQUEMA;
    }
    /* 1) ids, campos e limites de cada nó */
    const cJSON *no = NULL;
    int indice = 0;
    cJSON_ArrayForEach(no, dialogo) {
        char id[BK_NO_ID_MAX];
        bk_status st = campo_texto(no, "id", id, sizeof id, err, cap);
        if (st != BK_OK) {
            char anterior[BK_ERR_MSG_MAX];
            (void)bk_copiar(anterior, sizeof anterior, err != NULL ? err : "");
            bk_err(err, cap, "dialogue[%d]: %s", indice, anterior);
            return st;
        }
        if (id[0] == '\0' || strcmp(id, BK_NO_FIM) == 0) {
            bk_err(err, cap, "dialogue[%d]: id '%s' e reservado ou vazio", indice, id);
            return BK_ERR_ESQUEMA;
        }
        if (no_por_id(dialogo, id) != no) {
            bk_err(err, cap, "id de no '%s' repetido", id);
            return BK_ERR_ESQUEMA;
        }
        Turn turno;
        char titulo[128];
        st = montar_turno_do_no(no, &turno, titulo, sizeof titulo, err, cap);
        if (st != BK_OK) {
            prefixar_no(err, cap, id);
            return st;
        }
        /* 2) todo "next" aponta para um nó existente ou para END */
        if (turno.choice_count == 0) {
            const char *prox = proximo_do_no(no, 0, false);
            if (prox == NULL) {
                bk_err(err, cap, "no '%s' sem escolhas precisa de \"next\"", id);
                return BK_ERR_ESQUEMA;
            }
            if (!destino_valido(dialogo, prox)) {
                bk_err(err, cap, "no '%s': next '%s' nao existe", id, prox);
                return BK_ERR_ESQUEMA;
            }
        } else {
            for (int i = 0; i < turno.choice_count; i++) {
                const char *prox = proximo_do_no(no, turno.choices[i].id, true);
                if (prox == NULL) {
                    bk_err(err, cap, "no '%s': escolha %d sem \"next\"", id, turno.choices[i].id);
                    return BK_ERR_ESQUEMA;
                }
                if (!destino_valido(dialogo, prox)) {
                    bk_err(err, cap, "no '%s': escolha %d aponta para '%s', que nao existe", id, turno.choices[i].id, prox);
                    return BK_ERR_ESQUEMA;
                }
            }
        }
        indice++;
    }
    /* 3) nenhum ciclo formado só por nós sem escolhas (o jogador ficaria preso apertando ENTER) */
    cJSON_ArrayForEach(no, dialogo) {
        const cJSON *atual = no;
        for (int passos = 0; ; passos++) {
            const cJSON *ch = cJSON_GetObjectItemCaseSensitive(atual, "choices");
            if (cJSON_IsArray(ch) && cJSON_GetArraySize(ch) > 0) {
                break;
            }
            const char *prox = proximo_do_no(atual, 0, false);
            if (strcmp(prox, BK_NO_FIM) == 0) {
                break;
            }
            if (passos > total) {
                const cJSON *nid = cJSON_GetObjectItemCaseSensitive(no, "id");
                bk_err(err, cap, "ciclo sem escolhas a partir do no '%s'", nid->valuestring);
                return BK_ERR_ESQUEMA;
            }
            atual = no_por_id(dialogo, prox);
        }
    }
    /* 4) nó inicial */
    const cJSON *start = cJSON_GetObjectItemCaseSensitive(root, "start_node");
    if (start != NULL) {
        if (!cJSON_IsString(start) || start->valuestring == NULL || !bk_copiar(inicio, inicio_cap, start->valuestring)) {
            bk_err(err, cap, "'start_node' invalido");
            return BK_ERR_ESQUEMA;
        }
        if (no_por_id(dialogo, inicio) == NULL) {
            bk_err(err, cap, "start_node '%s' nao existe", inicio);
            return BK_ERR_ESQUEMA;
        }
    } else {
        const cJSON *nid = cJSON_GetObjectItemCaseSensitive(cJSON_GetArrayItem(dialogo, 0), "id");
        (void)bk_copiar(inicio, inicio_cap, nid->valuestring);
    }
    return BK_OK;
}

static bk_status executar_grafo_dialogo(const cJSON *root, const cJSON *dialogo, GameState *jogo, char *err, size_t cap) {
    char atual[BK_NO_ID_MAX];
    bk_status st = validar_dialogo(root, dialogo, atual, sizeof atual, err, cap);
    if (st != BK_OK) {
        return st;
    }
    long passos = 0;
    while (strcmp(atual, BK_NO_FIM) != 0) {
        if (++passos > BK_DIALOGO_PASSOS_MAX) {
            bk_err(err, cap, "roteiro passou de %ld passos (laco?)", BK_DIALOGO_PASSOS_MAX);
            return BK_ERR_LIMITE;
        }
        const cJSON *no = no_por_id(dialogo, atual); /* existe: validado acima */
        Turn turno;
        char titulo[sizeof jogo->scene_title];
        st = montar_turno_do_no(no, &turno, titulo, sizeof titulo, err, cap);
        if (st != BK_OK) {
            prefixar_no(err, cap, atual);
            return st;
        }
        if (titulo[0] != '\0' && strcmp(titulo, jogo->scene_title) != 0) {
            (void)bk_copiar(jogo->scene_title, sizeof jogo->scene_title, titulo);
            exibir_cabecalho_dia(jogo->scene_title, jogo->autonomia);
        }
        int escolha = 0;
        st = executar_turno_com_escolha(jogo, &turno, &escolha);
        if (st != BK_OK) {
            bk_err(err, cap, "a entrada terminou no meio do jogo");
            return st;
        }
        const char *prox = proximo_do_no(no, escolha, turno.choice_count > 0); /* existe: validado acima */
        if (prox == NULL || !bk_copiar(atual, sizeof atual, prox)) {
            bk_err(err, cap, "no '%s': destino invalido", atual);
            return BK_ERR_ESQUEMA;
        }
        limpar_tela();
    }
    return BK_OK;
}


bk_status executar_jogo(const char *json_filename, GameState *jogo, char *err, size_t cap) {
    if (json_filename == NULL || jogo == NULL) {
        bk_err(err, cap, "executar_jogo: ponteiro nulo");
        return BK_ERR_ARG;
    }
    char *json_data = NULL;
    size_t tamanho = 0;
    bk_status st = bk_ler_arquivo(json_filename, &json_data, &tamanho, err, cap);
    if (st != BK_OK) {
        return st;
    }
    cJSON *root = cJSON_Parse(json_data);
    bk_free(json_data);
    if (root == NULL) {
        bk_err(err, cap, "sintaxe invalida em '%s' (ou sem memoria)", json_filename);
        return BK_ERR_JSON;
    }

    const cJSON *dialogue_arr = cJSON_GetObjectItemCaseSensitive(root, "dialogue");
    if (cJSON_IsArray(dialogue_arr)) {
        st = executar_grafo_dialogo(root, dialogue_arr, jogo, err, cap);
        goto fim;
    }

    const cJSON *days = cJSON_GetObjectItemCaseSensitive(root, "days");
    if (!cJSON_IsArray(days)) {
        if (cJSON_GetObjectItemCaseSensitive(root, "acts") != NULL) {
            bk_err(err, cap, "'%s' esta no formato acts/nodes (roteiro v4), que o modo interativo nao le; ele espera days/turns", json_filename);
        } else {
            bk_err(err, cap, "'%s' nao tem a lista 'days' nem 'dialogue'", json_filename);
        }
        st = BK_ERR_ESQUEMA;
        goto fim;
    }
    const cJSON *day_item = NULL;
    cJSON_ArrayForEach(day_item, days) {
        int day_num = 0;
        int act_num = 0;
        char act_title[sizeof jogo->act_title];
        char scene_title[sizeof jogo->scene_title];
        st = campo_inteiro(day_item, "day_number", &day_num, err, cap);
        if (st == BK_OK) {
            st = campo_inteiro(day_item, "act", &act_num, err, cap);
        }
        if (st == BK_OK) {
            st = campo_texto(day_item, "act_title", act_title, sizeof act_title, err, cap);
        }
        if (st == BK_OK) {
            st = campo_texto(day_item, "scene_title", scene_title, sizeof scene_title, err, cap);
        }
        if (st != BK_OK) {
            goto fim;
        }
        if (act_num != jogo->current_act) {
            jogo->current_act = act_num;
            (void)bk_copiar(jogo->act_title, sizeof jogo->act_title, act_title);
            exibir_cabecalho_ato(jogo->act_title);
        }
        jogo->current_day = day_num;
        (void)bk_copiar(jogo->scene_title, sizeof jogo->scene_title, scene_title);
        exibir_cabecalho_dia(jogo->scene_title, jogo->autonomia);
        const cJSON *turns = cJSON_GetObjectItemCaseSensitive(day_item, "turns");
        if (!cJSON_IsArray(turns)) {
            bk_err(err, cap, "dia %d sem lista 'turns'", day_num);
            st = BK_ERR_ESQUEMA;
            goto fim;
        }
        const cJSON *turn_item = NULL;
        cJSON_ArrayForEach(turn_item, turns) {
            Turn turno;
            st = carregar_turno(turn_item, &turno, err, cap);
            if (st != BK_OK) {
                goto fim;
            }
            st = executar_turno(jogo, &turno);
            if (st != BK_OK) {
                bk_err(err, cap, "a entrada terminou no meio do jogo");
                goto fim;
            }
            limpar_tela();
        }
    }
fim:
    cJSON_Delete(root);
    return st;
}
