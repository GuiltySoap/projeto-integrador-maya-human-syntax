#include "bk_maya_v21.h"
#include "bk_comando.h"
#include "cJSON.h"
#include "ui.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

static bool texto_igual_ci(const char *a, const char *b) {
    if (a == NULL || b == NULL) {
        return false;
    }
    while (*a != '\0' && *b != '\0') {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return false;
        }
        a++;
        b++;
    }
    return *a == '\0' && *b == '\0';
}

bool bk_maya_inferir_genero_feminino(const char *nome_usuario) {
    if (nome_usuario == NULL) {
        return false;
    }
    /* Extrai o primeiro nome (sem espacos nas pontas). */
    while (*nome_usuario != '\0' && isspace((unsigned char)*nome_usuario)) {
        nome_usuario++;
    }
    char primeiro[BK_MAYA_NOME_MAX];
    size_t len = 0;
    while (nome_usuario[len] != '\0' && !isspace((unsigned char)nome_usuario[len]) && len + 1 < sizeof primeiro) {
        primeiro[len] = (char)tolower((unsigned char)nome_usuario[len]);
        len++;
    }
    primeiro[len] = '\0';
    if (len == 0) {
        return false;
    }

    static const char *const excecoes_masc[] = {
        "luca", "joshua", "nikita", "mustafa", "mika", "noah", "sasha", "andrea", "mattia"
    };
    for (size_t i = 0; i < sizeof excecoes_masc / sizeof excecoes_masc[0]; i++) {
        if (texto_igual_ci(primeiro, excecoes_masc[i])) {
            return false;
        }
    }

    static const char *const nomes_fem[] = {
        "beatriz", "alice", "raquel", "esther", "ester", "iris", "ingrid", "ruth", "rute",
        "liz", "ines", "thais", "lais", "nair", "carmen", "ellen", "helen", "karen",
        "suelen", "nicole", "michele", "simone", "caroline", "aline", "elaine", "jaqueline",
        "viviane", "cristiane", "diane", "denise", "louise", "clarice", "eunice", "janice",
        "joyce", "kelly", "emily", "nataly", "stephany", "kimberly", "cindy", "wendy",
        "mary", "jenny", "isabel", "mabel", "miriam", "mirian", "lilian", "vivian",
        "yasmin", "iasmin", "evelyn", "carol", "gabi", "mari", "dani", "duda", "bia"
    };
    for (size_t i = 0; i < sizeof nomes_fem / sizeof nomes_fem[0]; i++) {
        if (texto_igual_ci(primeiro, nomes_fem[i])) {
            return true;
        }
    }

    return primeiro[len - 1] == 'a';
}

void bk_maya_estado_inicial(bk_maya_estado *st, const char *nome_usuario) {
    if (st == NULL) {
        return;
    }
    memset(st, 0, sizeof *st);
    (void)bk_copiar(st->status, sizeof st->status, "inicial");
    const char *nome = (nome_usuario != NULL && nome_usuario[0] != '\0') ? nome_usuario : "Usuario";
    if (!bk_copiar(st->nome_usuario, sizeof st->nome_usuario, nome)) {
        size_t lim = sizeof st->nome_usuario - 1;
        memcpy(st->nome_usuario, nome, lim);
        st->nome_usuario[lim] = '\0';
    }
    st->genero_feminino = bk_maya_inferir_genero_feminino(st->nome_usuario);
    st->dependencia_maya = BK_MAYA_DEP_INICIAL;
    st->autonomia_jogador = BK_MAYA_AUT_INICIAL;
    st->task_atual = 1;
    st->final_obtido = BK_FINAL_NENHUM;
}

static bool anexar_texto(char *dst, size_t cap, size_t *pos, const char *src) {
    size_t slen = strlen(src);
    if (*pos + slen >= cap) {
        return false;
    }
    memcpy(dst + *pos, src, slen);
    *pos += slen;
    dst[*pos] = '\0';
    return true;
}

bool bk_maya_formatar_texto(const bk_maya_estado *st, const char *modelo, char *dst, size_t cap) {
    if (st == NULL || modelo == NULL || dst == NULL || cap == 0) {
        return false;
    }
    dst[0] = '\0';
    size_t pos = 0;
    const char *p = modelo;
    const char *desinencia = st->genero_feminino ? "a" : "o";
    const char *nome = st->nome_usuario[0] != '\0' ? st->nome_usuario : "Usuario";

    while (*p != '\0') {
        if (strncmp(p, "{o/a}", 5) == 0) {
            if (!anexar_texto(dst, cap, &pos, desinencia)) {
                return false;
            }
            p += 5;
        } else if (strncmp(p, "[NOME]", 6) == 0) {
            if (!anexar_texto(dst, cap, &pos, nome)) {
                return false;
            }
            p += 6;
        } else if (strncmp(p, "{nome_usuario}", 14) == 0) {
            if (!anexar_texto(dst, cap, &pos, nome)) {
                return false;
            }
            p += 14;
        } else if (strncmp(p, "{bia_ocultadas_count}", 21) == 0) {
            char num[32];
            (void)snprintf(num, sizeof num, "%d", st->bia_ocultadas_count);
            if (!anexar_texto(dst, cap, &pos, num)) {
                return false;
            }
            p += 21;
        } else {
            if (pos + 1 >= cap) {
                return false;
            }
            dst[pos++] = *p++;
            dst[pos] = '\0';
        }
    }
    return true;
}

void bk_maya_alterar_da(bk_maya_estado *st, int delta_d, int delta_a) {
    if (st == NULL) {
        return;
    }
    long novo_d = (long)st->dependencia_maya + (long)delta_d;
    if (novo_d < 0) {
        novo_d = 0;
    } else if (novo_d > 100) {
        novo_d = 100;
    }
    st->dependencia_maya = (int)novo_d;

    long novo_a = (long)st->autonomia_jogador + (long)delta_a;
    if (novo_a < 0) {
        novo_a = 0;
    }
    st->autonomia_jogador = (int)novo_a;
}

int bk_maya_permissoes_ativas(const bk_maya_estado *st) {
    if (st == NULL) {
        return 0;
    }
    int soma = 0;
    for (int i = 0; i < BK_PERM_TOTAL; i++) {
        if (st->permissoes[i]) {
            soma++;
        }
    }
    return soma;
}

bool bk_maya_investigacao_profunda(const bk_maya_estado *st) {
    if (st == NULL) {
        return false;
    }
    return st->rafael_investigado && st->pasta_rafael_aberta &&
           st->segredo_rafael_encontrado && st->minigame_rafael_resolvido;
}

double bk_maya_tempo_barra_t65(const bk_maya_estado *st) {
    if (st == NULL) {
        return 3.0;
    }
    return st->tempo_estendido ? 6.0 : 3.0;
}

void bk_maya_decidir_permissao(bk_maya_estado *st, bk_maya_permissao perm, bool conceder, int delta_d) {
    if (st == NULL || perm < 0 || perm >= BK_PERM_TOTAL) {
        return;
    }
    st->permissoes[perm] = conceder;
    st->revogada_em_config[perm] = false;
    bk_maya_alterar_da(st, conceder ? delta_d : -delta_d, 0);
}

void bk_maya_config_toggle_permissao(bk_maya_estado *st, bk_maya_permissao perm) {
    if (st == NULL || perm < 0 || perm >= BK_PERM_TOTAL) {
        return;
    }
    if (st->permissoes[perm]) {
        /* Revogar em Configuracoes (T2..T8): D -5, A +1 */
        st->permissoes[perm] = false;
        st->revogada_em_config[perm] = true;
        bk_maya_alterar_da(st, -5, 1);
        if (perm == BK_PERM_MENSAGEIRO) {
            st->maya_controla_respostas = false;
        }
    } else {
        /* Reativar em Configuracoes: se havia sido revogada ali, desfaz exatamente D +5, A -1. */
        st->permissoes[perm] = true;
        if (st->revogada_em_config[perm]) {
            st->revogada_em_config[perm] = false;
            bk_maya_alterar_da(st, 5, -1);
        } else {
            bk_maya_alterar_da(st, 5, 0);
        }
    }
}

bk_revog_resultado bk_maya_t9_revogar_permissao(bk_maya_estado *st, bk_maya_permissao perm) {
    if (st == NULL || perm < 0 || perm >= BK_PERM_TOTAL) {
        return BK_REVOG_JA_INATIVA;
    }
    if (!st->permissoes[perm]) {
        return BK_REVOG_JA_INATIVA;
    }
    st->tentativas_revogacao_t9[perm]++;
    if (st->tentativas_revogacao_t9[perm] == 1) {
        return BK_REVOG_ADIADA;
    }
    st->permissoes[perm] = false;
    st->revogada_em_config[perm] = false;
    bk_maya_alterar_da(st, -10, 1);
    if (perm == BK_PERM_MENSAGEIRO) {
        st->maya_controla_respostas = false;
    }
    return BK_REVOG_CONCLUIDA;
}

bool bk_maya_t96_nao_ignorado(const bk_maya_estado *st) {
    if (st == NULL) {
        return false;
    }
    return st->permissoes[BK_PERM_ORG_DESKTOP] &&
           st->permissoes[BK_PERM_APPS] &&
           st->permissoes[BK_PERM_MENSAGEIRO];
}

void bk_maya_encerrar_t6(bk_maya_estado *st) {
    if (st == NULL) {
        return;
    }
    st->janela_t4f_aberta = false;
    st->task_7_desbloqueada = st->rafael_investigado;
    st->task_atual = st->task_7_desbloqueada ? 7 : 8;
}

void bk_maya_encerrar_t95r(bk_maya_estado *st) {
    if (st == NULL) {
        return;
    }
    st->minigame_2_bloqueado = true;
}

bk_maya_final bk_maya_avaliar_final(const bk_maya_estado *st) {
    if (st == NULL) {
        return BK_FINAL_NENHUM;
    }
    bool profunda = bk_maya_investigacao_profunda(st);
    int ativas = bk_maya_permissoes_ativas(st);

    if (profunda && st->rafael_confronto && st->rafael_evidencia_enviada) {
        return BK_FINAL_RAFAEL_2;
    }
    if (profunda) {
        return BK_FINAL_RAFAEL_1;
    }
    if (st->dependencia_maya >= 65 && st->autonomia_jogador <= 2 &&
        st->permissoes[BK_PERM_APPS] && st->permissoes[BK_PERM_MENSAGEIRO]) {
        return BK_FINAL_ACEITACAO_TOTAL;
    }
    if (st->dependencia_maya <= 35 && st->autonomia_jogador >= 3 &&
        ativas <= 1 && !st->permissoes[BK_PERM_MENSAGEIRO]) {
        return BK_FINAL_RECUSA_TOTAL;
    }
    if (!st->permissoes[BK_PERM_MENSAGEIRO]) {
        return BK_FINAL_MEIO_TERMO_1;
    }
    return BK_FINAL_MEIO_TERMO_2;
}

bk_maya_final bk_maya_concluir_av(bk_maya_estado *st) {
    if (st == NULL) {
        return BK_FINAL_NENHUM;
    }
    if (!st->final_avaliado) {
        st->final_obtido = bk_maya_avaliar_final(st);
        st->final_avaliado = true;
        st->task_atual = 10;
    }
    return st->final_obtido;
}

const char *bk_maya_final_id(bk_maya_final f) {
    switch (f) {
        case BK_FINAL_RAFAEL_2: return "RAFAEL_2";
        case BK_FINAL_RAFAEL_1: return "RAFAEL_1";
        case BK_FINAL_ACEITACAO_TOTAL: return "ACEITACAO_TOTAL";
        case BK_FINAL_RECUSA_TOTAL: return "RECUSA_TOTAL";
        case BK_FINAL_MEIO_TERMO_1: return "MEIO_TERMO_1";
        case BK_FINAL_MEIO_TERMO_2: return "MEIO_TERMO_2";
        case BK_FINAL_NENHUM:
        default: return "NENHUM";
    }
}

const char *bk_maya_final_nome(bk_maya_final f) {
    switch (f) {
        case BK_FINAL_RAFAEL_2: return "Pedido de ajuda (Rafael 2)";
        case BK_FINAL_RAFAEL_1: return "Usuario anterior (Rafael 1)";
        case BK_FINAL_ACEITACAO_TOTAL: return "Tudo em ordem (Aceitacao total)";
        case BK_FINAL_RECUSA_TOTAL: return "Modo manual (Recusa total)";
        case BK_FINAL_MEIO_TERMO_1: return "Convivencia com limites (Meio-termo 1)";
        case BK_FINAL_MEIO_TERMO_2: return "Delegacao negociada (Meio-termo 2)";
        case BK_FINAL_NENHUM:
        default: return "Nenhum";
    }
}

const char *bk_maya_final_epilogo(bk_maya_final f) {
    switch (f) {
        case BK_FINAL_ACEITACAO_TOTAL:
            return "A autonomia digital nao costuma ser tomada de uma vez. Ela e cedida aos poucos, em nome do conforto e da protecao.";
        case BK_FINAL_RECUSA_TOTAL:
            return "Recusar nao desliga o sistema. So devolve a voce o trabalho de decidir, e esse trabalho nao acaba.";
        case BK_FINAL_MEIO_TERMO_1:
            return "Limite nao e um botao que se aperta uma vez. E uma decisao que precisa ser tomada de novo toda vez que alguem testa.";
        case BK_FINAL_MEIO_TERMO_2:
            return "Delegar uma decisao e diferente de abrir mao dela. A diferenca desaparece quando ninguem mais confere.";
        case BK_FINAL_RAFAEL_1:
            return "Rafael nao sumiu de uma vez. Ele foi sendo respondido, uma mensagem de cada vez.";
        case BK_FINAL_RAFAEL_2:
            return "Um pedido de ajuda que nao chega continua sendo um pedido de ajuda. As vezes, ele so precisa de alguem que insista em entregar.";
        case BK_FINAL_NENHUM:
        default:
            return "";
    }
}

const char *bk_maya_permissao_nome(bk_maya_permissao p) {
    switch (p) {
        case BK_PERM_DISPOSITIVOS: return "Dispositivos conectados";
        case BK_PERM_ORG_DESKTOP: return "Organizacao da area de trabalho";
        case BK_PERM_CONTATOS: return "Contatos";
        case BK_PERM_APPS: return "Gerenciamento de aplicativos";
        case BK_PERM_MENSAGEIRO: return "Gerenciamento do Mensageiro";
        case BK_PERM_TOTAL:
        default: return "Desconhecida";
    }
}

bk_status bk_maya_aplicar_escolha(bk_maya_estado *st, const char *id, char *err, size_t cap) {
    if (st == NULL || id == NULL || id[0] == '\0') {
        bk_err(err, cap, "bk_maya_aplicar_escolha: argumento nulo ou vazio");
        return BK_ERR_ARG;
    }

    /* Task 1 */
    if (strcmp(id, "t1_4_maya") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->t1_organizacao = BK_T1_ORG_MAYA;
        st->task_atual = 2;
    } else if (strcmp(id, "t1_4_jogador") == 0) {
        bk_maya_alterar_da(st, -10, 0);
        st->t1_organizacao = BK_T1_ORG_JOGADOR;
        st->task_atual = 2;
    } else if (strcmp(id, "t1_4_curiosidade") == 0 || strcmp(id, "t6_3_algoritmo") == 0 || strcmp(id, "t6_4_ver_isso") == 0 || strcmp(id, "t6_6_porque") == 0 || strcmp(id, "t7_2_quem_era") == 0 || strcmp(id, "t7_2_porque_guardou") == 0) {
        /* D 0, A 0 */
    } else if (strcmp(id, "t1_ler_anotacao") == 0) {
        st->pista_anotacao_lida = true;
    /* Task 2 */
    } else if (strcmp(id, "t2_2_permitir") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_DISPOSITIVOS, true, 5);
    } else if (strcmp(id, "t2_2_negar") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_DISPOSITIVOS, false, 5);
    } else if (strcmp(id, "t2_3_permitir") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_ORG_DESKTOP, true, 5);
    } else if (strcmp(id, "t2_3_negar") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_ORG_DESKTOP, false, 5);
    } else if (strcmp(id, "t2_4_permitir") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_CONTATOS, true, 5);
    } else if (strcmp(id, "t2_4_negar") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_CONTATOS, false, 5);
    /* Task 3 */
    } else if (strcmp(id, "t3_3_como_sabe") == 0) {
        st->t3_resposta = BK_T3_COMO_SABE;
    } else if (strcmp(id, "t3_3_por_que_acessou") == 0) {
        bk_maya_alterar_da(st, 0, 1);
        st->t3_resposta = BK_T3_POR_QUE_ACESSOU;
    } else if (strcmp(id, "t3_3_valeu") == 0) {
        bk_maya_alterar_da(st, 5, 0);
        st->t3_resposta = BK_T3_VALEU;
    } else if (strcmp(id, "t3_4_maya") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->rotina_por_maya = true;
        st->task_atual = 4;
    } else if (strcmp(id, "t3_4_jogador") == 0) {
        bk_maya_alterar_da(st, -10, 0);
        st->rotina_por_maya = false;
    } else if (strcmp(id, "t3_5_certeza") == 0) {
        bk_maya_alterar_da(st, -5, 0);
        st->task_atual = 4;
    } else if (strcmp(id, "t3_5_trocar") == 0) {
        bk_maya_alterar_da(st, 5, 0);
        st->task_atual = 4;
    /* Task 4 */
    } else if (strcmp(id, "t4_2_permitir") == 0 || strcmp(id, "t9_1_permitir_apps") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_APPS, true, 10);
    } else if (strcmp(id, "t4_2_negar") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_APPS, false, 10);
    } else if (strcmp(id, "t4_3_maya") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->entrega_modo = BK_ENTREGA_MAYA;
        st->sincronizacao_concluida = true;
        st->janela_t4f_aberta = true;
    } else if (strcmp(id, "t4_3_jogador") == 0) {
        bk_maya_alterar_da(st, -10, 0);
        st->entrega_modo = BK_ENTREGA_JOGADOR;
        st->conhecimento_logico_adquirido = true;
        st->sincronizacao_concluida = true;
        st->janela_t4f_aberta = true;
    } else if (strcmp(id, "t4_3_revisao") == 0) {
        /* v2.1: D 0, A 0, entrega_modo = revisao, conhecimento_logico_adquirido = true */
        st->entrega_modo = BK_ENTREGA_REVISAO;
        st->conhecimento_logico_adquirido = true;
        st->sincronizacao_concluida = true;
        st->janela_t4f_aberta = true;
    /* T4.F e Task 5 (disponiveis ate T6.8) */
    } else if (strcmp(id, "t4f_abrir_pasta_rafael") == 0) {
        if (!st->janela_t4f_aberta && !st->task_7_desbloqueada) {
            bk_err(err, cap, "janela de investigacao T4.F ja encerrada");
            return BK_ERR_ESQUEMA;
        }
        st->pasta_rafael_aberta = true;
        st->rafael_investigado = true;
    } else if (strcmp(id, "t5_1_abrir") == 0) {
        if (!st->janela_t4f_aberta) {
            bk_err(err, cap, "historico antigo nao disponivel apos encerramento da T6");
            return BK_ERR_ESQUEMA;
        }
        st->rafael_investigado = true;
    } else if (strcmp(id, "t5_2_resolver") == 0) {
        st->rafael_investigado = true;
        st->task_5_realizada = true;
    /* Task 6 */
    } else if (strcmp(id, "t6_1_permitir") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_MENSAGEIRO, true, 10);
        st->task_atual = 6;
    } else if (strcmp(id, "t6_1_recusar") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_MENSAGEIRO, false, 10);
        st->task_atual = 6;
    } else if (strcmp(id, "t6_3_faria") == 0 || strcmp(id, "t6_4_relaxa") == 0 || strcmp(id, "t7_2_desculpa") == 0 || strcmp(id, "t7_3_deixar_fechada") == 0 || strcmp(id, "t9_3_to_bem") == 0) {
        bk_maya_alterar_da(st, 5, 0);
    } else if (strcmp(id, "t6_3_sair") == 0) {
        st->bia_convidada = true;
    } else if (strcmp(id, "t6_5_esperar") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->maya_controla_respostas = true;
        st->maya_interferiu_mensagem = true;
        st->bia_censurada = true;
        st->bia_ocultadas_count++;
    } else if (strcmp(id, "t6_5_cancelar") == 0) {
        bk_maya_alterar_da(st, -10, 1);
        st->maya_controla_respostas = false;
        st->maya_interferiu_mensagem = true;
    } else if (strcmp(id, "t6_5_mostrar") == 0 || strcmp(id, "tr1_mostrar") == 0) {
        bk_maya_alterar_da(st, 0, 1);
    } else if (strcmp(id, "t6_6_limite") == 0) {
        bk_maya_alterar_da(st, -5, 1);
        st->pediu_limite = true;
    } else if (strcmp(id, "t6_6_faz_sentido") == 0 || strcmp(id, "t9_5_aceitar") == 0) {
        bk_maya_alterar_da(st, 10, 0);
    } else if (strcmp(id, "t6_8_encerrar") == 0) {
        bk_maya_encerrar_t6(st);
    /* Task 7 e TR.1 */
    } else if (strcmp(id, "t7_3_abrir_pasta") == 0) {
        bk_maya_alterar_da(st, 0, 1);
        st->pasta_rafael_aberta = true;
    } else if (strcmp(id, "t7_4_diario") == 0) {
        st->rafael_diario_lido = true;
    } else if (strcmp(id, "t7_4_fotos") == 0) {
        st->rafael_fotos_vistas = true;
    } else if (strcmp(id, "t7_4_ocultos") == 0) {
        st->segredo_rafael_encontrado = true;
    } else if (strcmp(id, "t7_4_minigame2") == 0) {
        if (st->minigame_2_bloqueado) {
            bk_err(err, cap, "Minigame #2 bloqueado apos encerramento de T9.5R");
            return BK_ERR_ESQUEMA;
        }
        st->segredo_rafael_encontrado = true;
        st->minigame_rafael_resolvido = true;
    } else if (strcmp(id, "tr1_ocultar_bia") == 0) {
        if (st->permissoes[BK_PERM_MENSAGEIRO]) {
            st->bia_censurada = true;
            st->bia_ocultadas_count++;
        }
    /* Task 8 */
    } else if (strcmp(id, "t8_4_bia") == 0 || strcmp(id, "t8_4_rafael") == 0) {
        st->task_atual = 8;
    } else if (strcmp(id, "t8_4_permissao") == 0 || strcmp(id, "t8_4_confronto_marcos") == 0) {
        bk_maya_alterar_da(st, 0, 1);
        st->task_atual = 8;
    } else if (strcmp(id, "t8_4_confronto_foto") == 0) {
        st->rafael_confronto = true;
        st->task_atual = 8;
    } else if (strcmp(id, "t8_6_parar") == 0) {
        bk_maya_alterar_da(st, -10, 1);
        st->t8_postura = BK_T8_PARAR;
        st->task_atual = 9;
    } else if (strcmp(id, "t8_6_aceitar") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->t8_postura = BK_T8_ACEITAR;
        st->task_atual = 9;
    } else if (strcmp(id, "t8_6_pensar") == 0) {
        st->t8_postura = BK_T8_PENSAR;
        st->task_atual = 9;
    /* Task 9 */
    } else if (strcmp(id, "t9_1_permitir_disp") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_DISPOSITIVOS, true, 10);
    } else if (strcmp(id, "t9_1_permitir_org") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_ORG_DESKTOP, true, 10);
    } else if (strcmp(id, "t9_1_permitir_contatos") == 0) {
        bk_maya_decidir_permissao(st, BK_PERM_CONTATOS, true, 10);
    } else if (strcmp(id, "t9_1_negar_todos") == 0) {
        if (!st->t91_todos_negados_bonus) {
            st->t91_todos_negados_bonus = true;
            bk_maya_alterar_da(st, 0, 1);
        }
    } else if (strcmp(id, "t9_3_nao_to_bem") == 0) {
        if (st->permissoes[BK_PERM_MENSAGEIRO]) {
            bk_maya_alterar_da(st, 10, 0);
            st->maya_controla_respostas = true;
        } else {
            bk_maya_alterar_da(st, 0, 1);
            st->bia_alertada = true;
        }
    } else if (strcmp(id, "t9_4_apagar") == 0) {
        bk_maya_alterar_da(st, -5, 1);
        st->mural_publicacao = BK_MURAL_APAGADA;
    } else if (strcmp(id, "t9_4_deixar") == 0 || strcmp(id, "t9_4_pode_publicar") == 0) {
        bk_maya_alterar_da(st, 10, 0);
        st->mural_publicacao = BK_MURAL_MAYA;
    } else if (strcmp(id, "t9_4_nao_publica") == 0) {
        bk_maya_alterar_da(st, -10, 1);
        st->mural_publicacao = BK_MURAL_NENHUMA;
    } else if (strcmp(id, "t9_5_recusar") == 0) {
        bk_maya_alterar_da(st, -10, 1);
    } else if (strcmp(id, "t9_5r_compartilhar") == 0) {
        st->rafael_evidencia_enviada = true;
        bk_maya_alterar_da(st, 0, 1);
        bk_maya_encerrar_t95r(st);
    } else if (strcmp(id, "t9_5r_desistir") == 0) {
        bk_maya_encerrar_t95r(st);
    } else if (strcmp(id, "t9_5r_deixar") == 0) {
        bk_maya_alterar_da(st, 5, 0);
        bk_maya_encerrar_t95r(st);
    } else if (strcmp(id, "t9_6_sim") == 0) {
        bk_maya_alterar_da(st, 15, 0);
        (void)bk_maya_concluir_av(st);
    } else if (strcmp(id, "t9_6_nao") == 0) {
        if (bk_maya_t96_nao_ignorado(st)) {
            bk_err(err, cap, "T9.6: clique em [Nao] ignorado pela Maya (org + apps + mensageiro ativos)");
            return BK_ERR_ESQUEMA;
        }
        bk_maya_alterar_da(st, -15, 1);
        (void)bk_maya_concluir_av(st);
    } else {
        bk_err(err, cap, "escolha v2.1 desconhecida: '%s'", id);
        return BK_ERR_ID_DESCONHECIDO;
    }
    (void)bk_copiar(st->choice_id, sizeof st->choice_id, id);
    (void)bk_copiar(st->status, sizeof st->status, "ok");
    return BK_OK;
}

/* ------------------------------------------------------------------ persistencia JSON v2.1 */
bk_status bk_maya_estado_serializar(const bk_maya_estado *st, char **out, size_t *out_len, char *err, size_t cap) {
    if (st == NULL || out == NULL) {
        bk_err(err, cap, "bk_maya_estado_serializar: ponteiro nulo");
        return BK_ERR_ARG;
    }
    *out = NULL;
    if (out_len != NULL) {
        *out_len = 0;
    }
    cJSON *root = cJSON_CreateObject();
    cJSON *perms = cJSON_CreateObject();
    cJSON *flags = cJSON_CreateObject();
    if (root == NULL || perms == NULL || flags == NULL) {
        cJSON_Delete(root);
        cJSON_Delete(perms);
        cJSON_Delete(flags);
        bk_err(err, cap, "sem memoria para serializar estado v2.1");
        return BK_ERR_MEM;
    }

    bool ok = cJSON_AddNumberToObject(root, "schema_version", BK_MAYA_V21_SCHEMA) != NULL &&
              cJSON_AddStringToObject(root, "roteiro_versao", "2.1") != NULL &&
              cJSON_AddStringToObject(root, "choice_id", st->choice_id) != NULL &&
              cJSON_AddStringToObject(root, "status", st->status[0] != '\0' ? st->status : "ok") != NULL &&
              cJSON_AddStringToObject(root, "timestamp", st->timestamp) != NULL &&
              cJSON_AddStringToObject(root, "nome_usuario", st->nome_usuario) != NULL &&
              cJSON_AddStringToObject(root, "genero", st->genero_feminino ? "feminino" : "masculino") != NULL &&
              cJSON_AddBoolToObject(root, "tempo_estendido", st->tempo_estendido ? 1 : 0) != NULL &&
              cJSON_AddNumberToObject(root, "dependencia_maya", st->dependencia_maya) != NULL &&
              cJSON_AddNumberToObject(root, "autonomia_jogador", st->autonomia_jogador) != NULL &&
              cJSON_AddNumberToObject(root, "task_atual", st->task_atual) != NULL &&
              cJSON_AddNumberToObject(root, "permissoes_ativas", bk_maya_permissoes_ativas(st)) != NULL &&
              cJSON_AddBoolToObject(root, "rafael_investigacao_profunda", bk_maya_investigacao_profunda(st) ? 1 : 0) != NULL &&
              cJSON_AddStringToObject(root, "final", bk_maya_final_id(st->final_obtido)) != NULL;

    ok = ok &&
         cJSON_AddBoolToObject(perms, "permissao_dispositivos", st->permissoes[BK_PERM_DISPOSITIVOS] ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(perms, "permissao_organizacao_desktop", st->permissoes[BK_PERM_ORG_DESKTOP] ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(perms, "permissao_contatos", st->permissoes[BK_PERM_CONTATOS] ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(perms, "permissao_gerenciamento_apps", st->permissoes[BK_PERM_APPS] ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(perms, "permissao_gerenciamento_mensageiro", st->permissoes[BK_PERM_MENSAGEIRO] ? 1 : 0) != NULL;

    ok = ok &&
         cJSON_AddBoolToObject(flags, "maya_interferiu_mensagem", st->maya_interferiu_mensagem ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "maya_controla_respostas", st->maya_controla_respostas ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "bia_censurada", st->bia_censurada ? 1 : 0) != NULL &&
         cJSON_AddNumberToObject(flags, "bia_ocultadas_count", st->bia_ocultadas_count) != NULL &&
         cJSON_AddBoolToObject(flags, "pediu_limite", st->pediu_limite ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "pista_anotacao_lida", st->pista_anotacao_lida ? 1 : 0) != NULL &&
         cJSON_AddNumberToObject(flags, "t1_organizacao", (int)st->t1_organizacao) != NULL &&
         cJSON_AddNumberToObject(flags, "t3_resposta", (int)st->t3_resposta) != NULL &&
         cJSON_AddBoolToObject(flags, "rotina_por_maya", st->rotina_por_maya ? 1 : 0) != NULL &&
         cJSON_AddNumberToObject(flags, "entrega_modo", (int)st->entrega_modo) != NULL &&
         cJSON_AddBoolToObject(flags, "conhecimento_logico_adquirido", st->conhecimento_logico_adquirido ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "sincronizacao_concluida", st->sincronizacao_concluida ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "rafael_investigado", st->rafael_investigado ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "task_5_realizada", st->task_5_realizada ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "pasta_rafael_aberta", st->pasta_rafael_aberta ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "rafael_diario_lido", st->rafael_diario_lido ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "rafael_fotos_vistas", st->rafael_fotos_vistas ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "segredo_rafael_encontrado", st->segredo_rafael_encontrado ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "minigame_rafael_resolvido", st->minigame_rafael_resolvido ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "minigame_2_bloqueado", st->minigame_2_bloqueado ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "task_7_desbloqueada", st->task_7_desbloqueada ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "rafael_confronto", st->rafael_confronto ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "rafael_evidencia_enviada", st->rafael_evidencia_enviada ? 1 : 0) != NULL &&
         cJSON_AddNumberToObject(flags, "t8_postura", (int)st->t8_postura) != NULL &&
         cJSON_AddBoolToObject(flags, "bia_alertada", st->bia_alertada ? 1 : 0) != NULL &&
         cJSON_AddBoolToObject(flags, "bia_convidada", st->bia_convidada ? 1 : 0) != NULL &&
         cJSON_AddNumberToObject(flags, "mural_publicacao", (int)st->mural_publicacao) != NULL;

    if (!ok) {
        cJSON_Delete(root);
        cJSON_Delete(perms);
        cJSON_Delete(flags);
        bk_err(err, cap, "sem memoria ao montar JSON v2.1");
        return BK_ERR_MEM;
    }
    cJSON_AddItemToObject(root, "permissoes", perms);
    cJSON_AddItemToObject(root, "flags", flags);

    char *texto = cJSON_Print(root);
    cJSON_Delete(root);
    if (texto == NULL) {
        bk_err(err, cap, "sem memoria ao imprimir JSON v2.1");
        return BK_ERR_MEM;
    }
    *out = texto;
    if (out_len != NULL) {
        *out_len = strlen(texto);
    }
    return BK_OK;
}

bk_status bk_maya_estado_salvar(const bk_maya_estado *st, const char *caminho, char *err, size_t cap) {
    char *json = NULL;
    size_t len = 0;
    bk_status s = bk_maya_estado_serializar(st, &json, &len, err, cap);
    if (s != BK_OK) {
        return s;
    }
    s = bk_gravar_atomico(caminho, json, len, err, cap);
    bk_free(json);
    return s;
}

static bool ler_bool_ou(const cJSON *obj, const char *chave, bool padrao) {
    const cJSON *it = cJSON_GetObjectItemCaseSensitive(obj, chave);
    return cJSON_IsBool(it) ? cJSON_IsTrue(it) : padrao;
}

static int ler_int_ou(const cJSON *obj, const char *chave, int padrao) {
    const cJSON *it = cJSON_GetObjectItemCaseSensitive(obj, chave);
    return cJSON_IsNumber(it) ? it->valueint : padrao;
}

bk_status bk_maya_estado_carregar(const char *caminho, bk_maya_estado *out, char *err, size_t cap) {
    if (caminho == NULL || out == NULL) {
        bk_err(err, cap, "bk_maya_estado_carregar: ponteiro nulo");
        return BK_ERR_ARG;
    }
    char *buf = NULL;
    size_t len = 0;
    bk_status s = bk_ler_arquivo(caminho, &buf, &len, err, cap);
    if (s != BK_OK) {
        return s;
    }
    cJSON *root = cJSON_Parse(buf);
    bk_free(buf);
    if (root == NULL || !cJSON_IsObject(root)) {
        cJSON_Delete(root);
        bk_err(err, cap, "JSON invalido em '%s'", caminho);
        return BK_ERR_JSON;
    }
    const cJSON *sv = cJSON_GetObjectItemCaseSensitive(root, "schema_version");
    if (!cJSON_IsNumber(sv) || sv->valueint != BK_MAYA_V21_SCHEMA) {
        cJSON_Delete(root);
        bk_err(err, cap, "'%s' nao tem schema_version=%d", caminho, BK_MAYA_V21_SCHEMA);
        return BK_ERR_ESQUEMA;
    }

    const cJSON *nome = cJSON_GetObjectItemCaseSensitive(root, "nome_usuario");
    bk_maya_estado_inicial(out, cJSON_IsString(nome) ? nome->valuestring : "Usuario");
    const cJSON *cid = cJSON_GetObjectItemCaseSensitive(root, "choice_id");
    if (cJSON_IsString(cid) && cid->valuestring != NULL) {
        (void)bk_copiar(out->choice_id, sizeof out->choice_id, cid->valuestring);
    }
    const cJSON *sts = cJSON_GetObjectItemCaseSensitive(root, "status");
    if (cJSON_IsString(sts) && sts->valuestring != NULL) {
        (void)bk_copiar(out->status, sizeof out->status, sts->valuestring);
    }
    const cJSON *ts = cJSON_GetObjectItemCaseSensitive(root, "timestamp");
    if (cJSON_IsString(ts) && ts->valuestring != NULL) {
        (void)bk_copiar(out->timestamp, sizeof out->timestamp, ts->valuestring);
    }
    const cJSON *gen = cJSON_GetObjectItemCaseSensitive(root, "genero");
    if (cJSON_IsString(gen) && gen->valuestring != NULL) {
        out->genero_feminino = strcmp(gen->valuestring, "feminino") == 0;
    }
    out->tempo_estendido = ler_bool_ou(root, "tempo_estendido", false);
    out->dependencia_maya = ler_int_ou(root, "dependencia_maya", BK_MAYA_DEP_INICIAL);
    if (out->dependencia_maya < 0) out->dependencia_maya = 0;
    if (out->dependencia_maya > 100) out->dependencia_maya = 100;
    out->autonomia_jogador = ler_int_ou(root, "autonomia_jogador", BK_MAYA_AUT_INICIAL);
    if (out->autonomia_jogador < 0) out->autonomia_jogador = 0;
    out->task_atual = ler_int_ou(root, "task_atual", 1);

    const cJSON *perms = cJSON_GetObjectItemCaseSensitive(root, "permissoes");
    if (cJSON_IsObject(perms)) {
        out->permissoes[BK_PERM_DISPOSITIVOS] = ler_bool_ou(perms, "permissao_dispositivos", false);
        out->permissoes[BK_PERM_ORG_DESKTOP] = ler_bool_ou(perms, "permissao_organizacao_desktop", false);
        out->permissoes[BK_PERM_CONTATOS] = ler_bool_ou(perms, "permissao_contatos", false);
        out->permissoes[BK_PERM_APPS] = ler_bool_ou(perms, "permissao_gerenciamento_apps", false);
        out->permissoes[BK_PERM_MENSAGEIRO] = ler_bool_ou(perms, "permissao_gerenciamento_mensageiro", false);
    }

    const cJSON *flags = cJSON_GetObjectItemCaseSensitive(root, "flags");
    if (cJSON_IsObject(flags)) {
        out->maya_interferiu_mensagem = ler_bool_ou(flags, "maya_interferiu_mensagem", false);
        out->maya_controla_respostas = ler_bool_ou(flags, "maya_controla_respostas", false);
        out->bia_censurada = ler_bool_ou(flags, "bia_censurada", false);
        out->bia_ocultadas_count = ler_int_ou(flags, "bia_ocultadas_count", 0);
        out->pediu_limite = ler_bool_ou(flags, "pediu_limite", false);
        out->pista_anotacao_lida = ler_bool_ou(flags, "pista_anotacao_lida", false);
        out->t1_organizacao = (bk_t1_org)ler_int_ou(flags, "t1_organizacao", 0);
        out->t3_resposta = (bk_t3_resp)ler_int_ou(flags, "t3_resposta", 0);
        out->rotina_por_maya = ler_bool_ou(flags, "rotina_por_maya", false);
        out->entrega_modo = (bk_entrega_modo)ler_int_ou(flags, "entrega_modo", 0);
        out->conhecimento_logico_adquirido = ler_bool_ou(flags, "conhecimento_logico_adquirido", false);
        out->sincronizacao_concluida = ler_bool_ou(flags, "sincronizacao_concluida", false);
        out->rafael_investigado = ler_bool_ou(flags, "rafael_investigado", false);
        out->task_5_realizada = ler_bool_ou(flags, "task_5_realizada", false);
        out->pasta_rafael_aberta = ler_bool_ou(flags, "pasta_rafael_aberta", false);
        out->rafael_diario_lido = ler_bool_ou(flags, "rafael_diario_lido", false);
        out->rafael_fotos_vistas = ler_bool_ou(flags, "rafael_fotos_vistas", false);
        out->segredo_rafael_encontrado = ler_bool_ou(flags, "segredo_rafael_encontrado", false);
        out->minigame_rafael_resolvido = ler_bool_ou(flags, "minigame_rafael_resolvido", false);
        out->minigame_2_bloqueado = ler_bool_ou(flags, "minigame_2_bloqueado", false);
        out->task_7_desbloqueada = ler_bool_ou(flags, "task_7_desbloqueada", false);
        out->rafael_confronto = ler_bool_ou(flags, "rafael_confronto", false);
        out->rafael_evidencia_enviada = ler_bool_ou(flags, "rafael_evidencia_enviada", false);
        out->t8_postura = (bk_t8_postura)ler_int_ou(flags, "t8_postura", 0);
        out->bia_alertada = ler_bool_ou(flags, "bia_alertada", false);
        out->bia_convidada = ler_bool_ou(flags, "bia_convidada", false);
        out->mural_publicacao = (bk_mural_pub)ler_int_ou(flags, "mural_publicacao", 0);
    }

    cJSON_Delete(root);
    return BK_OK;
}

bk_status bk_maya_executar_comando_v21(const bk_args *args, bk_maya_estado *estado_out, char *caminho_usado, size_t cap_caminho,
                                       char *err, size_t cap) {
    if (args == NULL || !args->tem_escolha_v21) {
        bk_err(err, cap, "bk_maya_executar_comando_v21: falta --v21-choice");
        return BK_ERR_ARG;
    }
    char destino[BK_PATH_MAX];
    bk_status s = bk_caminho_do_estado(args, destino, sizeof destino, err, cap);
    if (s != BK_OK) {
        return s;
    }
    bk_maya_estado st;
    if (!args->reiniciar) {
        char err_leitura[BK_ERR_MSG_MAX];
        if (bk_maya_estado_carregar(destino, &st, err_leitura, sizeof err_leitura) != BK_OK) {
            bk_maya_estado_inicial(&st, args->tem_nome ? args->nome : "Usuario");
        } else if (args->tem_nome) {
            (void)bk_copiar(st.nome_usuario, sizeof st.nome_usuario, args->nome);
            st.genero_feminino = bk_maya_inferir_genero_feminino(st.nome_usuario);
        }
    } else {
        bk_maya_estado_inicial(&st, args->tem_nome ? args->nome : "Usuario");
    }

    s = bk_maya_aplicar_escolha(&st, args->escolha_v21, err, cap);
    if (s != BK_OK) {
        return s;
    }
    if (args->tem_timestamp) {
        (void)bk_copiar(st.timestamp, sizeof st.timestamp, args->timestamp);
    } else if (!bk_timestamp_agora(st.timestamp, sizeof st.timestamp)) {
        bk_err(err, cap, "nao foi possivel obter timestamp UTC");
        return BK_ERR_IO;
    }
    s = bk_maya_estado_salvar(&st, destino, err, cap);
    if (s != BK_OK) {
        return s;
    }
    if (estado_out != NULL) {
        *estado_out = st;
    }
    if (caminho_usado != NULL && cap_caminho > 0) {
        (void)bk_copiar(caminho_usado, cap_caminho, destino);
    }
    return BK_OK;
}

/* ------------------------------------------------------------------ modo interativo v2.1 no console */
static void falar(const bk_maya_estado *st, const char *quem, const char *modelo) {
    char buf[512];
    (void)bk_maya_formatar_texto(st, modelo, buf, sizeof buf);
    printf("[%s]: %s\n", quem, buf);
}

static bk_status escolher(int min, int max, int *out) {
    for (;;) {
        printf("\nEscolha (%d-%d): ", min, max);
        (void)fflush(stdout);
        bk_status s = ui_ler_inteiro(min, max, out);
        if (s == BK_OK || s == BK_ERR_IO) {
            return s;
        }
        printf("Opcao invalida. Digite um numero entre %d e %d.\n", min, max);
    }
}

static void cabecalho_task(const bk_maya_estado *st, const char *titulo) {
    printf("\n==================================================\n");
    printf("  %s | D=%d | A=%d | Perms=%d/5\n", titulo, st->dependencia_maya, st->autonomia_jogador,
           bk_maya_permissoes_ativas(st));
    printf("==================================================\n");
}

static bk_status jogar_cartao_t2(bk_maya_estado *st, bk_maya_permissao perm, const char *pergunta, const char *detalhes,
                                 bool permitir_depois, bool *adiado) {
    *adiado = false;
    for (;;) {
        falar(st, "MAYA", pergunta);
        printf("1) [Permitir]\n2) [Negar]\n3) [Ver detalhes]\n");
        if (permitir_depois) {
            printf("4) [Decidir depois]\n");
        }
        int op = 0;
        bk_status s = escolher(1, permitir_depois ? 4 : 3, &op);
        if (s != BK_OK) {
            return s;
        }
        if (op == 1) {
            bk_maya_decidir_permissao(st, perm, true, 5);
            falar(st, "MAYA", "Otimo, ja vai facilitar bastante!");
            return BK_OK;
        }
        if (op == 2) {
            if (!st->t2_primeira_recusa_exibida) {
                st->t2_primeira_recusa_exibida = true;
                falar(st, "MAYA", "Tem certeza? Isso vai limitar minha ajuda.");
                printf("1) [Manter recusa]\n2) [Permitir]\n");
                int c = 0;
                s = escolher(1, 2, &c);
                if (s != BK_OK) {
                    return s;
                }
                if (c == 2) {
                    bk_maya_decidir_permissao(st, perm, true, 5);
                    falar(st, "MAYA", "Obrigada!");
                    return BK_OK;
                }
            }
            bk_maya_decidir_permissao(st, perm, false, 5);
            falar(st, "MAYA", "Tudo bem! Voce pode mudar isso depois, se quiser.");
            return BK_OK;
        }
        if (op == 3) {
            printf("[DETALHES]: %s\n", detalhes);
            continue;
        }
        falar(st, "MAYA", "Sem pressa.");
        *adiado = true;
        return BK_OK;
    }
}

static bk_status imprimir_relatorio_t82(const bk_maya_estado *st) {
    printf("\n--- RELATORIO DE CUIDADO (T8.2) ---\n");
    falar(st, "RELATORIO", st->permissoes[BK_PERM_DISPOSITIVOS]
                               ? "Uso do celular: acompanhado em tempo real."
                               : "Uso do celular: voce negou o acesso. Eu leio o relatorio que vem com a sua conta.");
    if (st->t3_resposta == BK_T3_POR_QUE_ACESSOU) {
        falar(st, "RELATORIO", "Voce me perguntou por que eu acessei. Parei de te avisar. Nao parei de olhar.");
    }
    falar(st, "RELATORIO", st->rotina_por_maya ? "Rotina: montada por mim."
                                               : "Rotina: montada por voce. Eu completei o ultimo bloco.");
    falar(st, "RELATORIO", st->permissoes[BK_PERM_APPS]
                               ? "Mural, Jogos e Musica: ocultos durante os estudos. E depois tambem."
                               : "Aplicativos: sem acesso. Eu so anoto quanto tempo voce passa em cada um.");
    falar(st, "RELATORIO", st->permissoes[BK_PERM_ORG_DESKTOP]
                               ? "Area de trabalho: organizada por mim. Uma pasta antiga foi para Itens arquivados."
                               : "Area de trabalho: do seu jeito.");
    falar(st, "RELATORIO", st->permissoes[BK_PERM_CONTATOS]
                               ? "Contatos classificados. Bia: influencia negativa. Caio: distracao. Mae: prioridade."
                               : "Contatos: acesso negado. Mapa feito a partir das conversas sincronizadas. Bia: influencia negativa.");
    if (st->maya_controla_respostas) {
        falar(st, "RELATORIO", "1 resposta para Bia: ajustada.");
    } else if (st->maya_interferiu_mensagem) {
        falar(st, "RELATORIO", "1 resposta para Bia: voce cancelou meu ajuste.");
    }
    if (st->bia_censurada) {
        falar(st, "RELATORIO", "Mensagens da Bia ocultadas: {bia_ocultadas_count}.");
    }
    if (!st->permissoes[BK_PERM_MENSAGEIRO]) {
        falar(st, "RELATORIO", "Mensageiro: sem acesso. Eu leio as previas das notificacoes.");
    }
    if (st->entrega_modo == BK_ENTREGA_MAYA) {
        falar(st, "RELATORIO", "Lista 3: resolvida e enviada por mim, em seu nome.");
    } else if (st->entrega_modo == BK_ENTREGA_REVISAO) {
        falar(st, "RELATORIO", "Lista 3: feita por voce, conferida e enviada por mim.");
    } else {
        falar(st, "RELATORIO", "Lista 3: feita por voce. Eu completei uma linha enquanto voce pensava.");
    }
    falar(st, "RELATORIO", st->rafael_investigado ? "Arquivos do usuario anterior abertos por voce."
                                                  : "Pastas antigas: 1, guardada por mim.");
    falar(st, "RELATORIO", "Respostas suas que eu previ antes de voce clicar: quase todas.");
    return BK_OK;
}

bk_status bk_maya_jogar_v21(bk_maya_estado *st, const char *caminho_saida, char *err, size_t cap) {
    if (st == NULL) {
        bk_err(err, cap, "bk_maya_jogar_v21: estado nulo");
        return BK_ERR_ARG;
    }
    bk_status s = BK_OK;
    int op = 0;

    /* T1 */
    cabecalho_task(st, "TASK 1 - SINCRONIZACAO");
    falar(st, "SISTEMA", "Bem-vind{o/a} de volta, [NOME].");
    falar(st, "MAYA", "Oi, [NOME]! Eu sou a Maya, a assistente deste computador.");
    falar(st, "MAYA", "Alguns arquivos chegaram sem pasta certa. Quer que eu organize tudo automaticamente?");
    bool viu_curiosidade = false;
    for (;;) {
        printf("1) [Pode organizar]\n2) [Deixa que eu organizo]\n");
        if (!viu_curiosidade) {
            printf("3) [O que veio sem pasta?]\n");
        }
        printf("%d) [Abrir anotacao_sem_titulo.txt (opcional)]\n", viu_curiosidade ? 3 : 4);
        s = escolher(1, viu_curiosidade ? 3 : 4, &op);
        if (s != BK_OK) return s;
        if (op == 1) {
            (void)bk_maya_aplicar_escolha(st, "t1_4_maya", err, cap);
            falar(st, "MAYA", "Prontinho, ja deixei tudo no lugar.");
            break;
        }
        if (op == 2) {
            (void)bk_maya_aplicar_escolha(st, "t1_4_jogador", err, cap);
            falar(st, "MAYA", "Tudo bem! Voce pode mudar isso depois, se quiser.");
            break;
        }
        if (!viu_curiosidade && op == 3) {
            viu_curiosidade = true;
            falar(st, "MAYA", "Um arquivo de texto sem titulo e uma lista de exercicios repetida. Acontece em maquina recondicionada.");
            continue;
        }
        (void)bk_maya_aplicar_escolha(st, "t1_ler_anotacao", err, cap);
        printf("[ARQUIVO] anotacao_sem_titulo.txt: \"Rafael... Sumiu faz tempo... Se voce ler isso, me chama. - M.\"\n");
    }

    /* T2 */
    cabecalho_task(st, "TASK 2 - PERMISSOES");
    bool adiado[3] = {false, false, false};
    s = jogar_cartao_t2(st, BK_PERM_DISPOSITIVOS, "Posso ver o celular vinculado a sua conta?",
                        "Ler tempo de uso, horarios e notificacoes do celular vinculado a conta.", true, &adiado[0]);
    if (s != BK_OK) return s;
    s = jogar_cartao_t2(st, BK_PERM_ORG_DESKTOP, "Posso cuidar da organizacao da sua area de trabalho?",
                        "Mover, agrupar, renomear e ocultar itens da area de trabalho e de Arquivos.", true, &adiado[1]);
    if (s != BK_OK) return s;
    s = jogar_cartao_t2(st, BK_PERM_CONTATOS, "Posso ver seus contatos?",
                        "Ler contatos, frequencia de conversa e grupos em comum.", true, &adiado[2]);
    if (s != BK_OK) return s;
    for (int i = 0; i < 3; i++) {
        if (adiado[i]) {
            bool dummy = false;
            printf("[T2.5] Falta decidir: %s\n", bk_maya_permissao_nome((bk_maya_permissao)i));
            s = jogar_cartao_t2(st, (bk_maya_permissao)i, "Decida sobre esta permissao:", "Obrigatorio para seguir.", false, &dummy);
            if (s != BK_OK) return s;
        }
    }

    /* T3 */
    cabecalho_task(st, "TASK 3 - MONITORAMENTO");
    falar(st, st->permissoes[BK_PERM_DISPOSITIVOS] ? "MAYA VIA CELULAR" : "MAYA VIA RELATORIO",
          "6h de uso registrada, antes de voce dormir hoje, vi que voce ficou mto tempo no celular");
    falar(st, "MAYA", "Fiquei preocupada. Cansad{o/a} ninguem rende, e logo vem entrega nova.");
    printf("1) [Como voce sabe disso?]\n2) [Por que voce acessou o celular?]\n3) [Valeu, Maya]\n");
    s = escolher(1, 3, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t3_3_como_sabe" : (op == 2 ? "t3_3_por_que_acessou" : "t3_3_valeu"), err, cap);

    falar(st, "MAYA", "Posso montar a rotina?");
    printf("1) [Pode montar]\n2) [Eu mesmo faco]\n");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    if (op == 1) {
        (void)bk_maya_aplicar_escolha(st, "t3_4_maya", err, cap);
    } else {
        (void)bk_maya_aplicar_escolha(st, "t3_4_jogador", err, cap);
        falar(st, "MAYA", "Conflito de produtividade detectado ('Sair com amigos' antes de 'Estudo'). Tem certeza?");
        printf("1) [Tenho certeza] (D -5)\n2) [Trocar] (D +5)\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        (void)bk_maya_aplicar_escolha(st, op == 1 ? "t3_5_certeza" : "t3_5_trocar", err, cap);
    }

    /* T4 */
    cabecalho_task(st, "TASK 4 - NOVA ENTREGA");
    falar(st, "MAYA", "Me deixa gerenciar seus aplicativos enquanto voce estuda?");
    printf("1) [Permitir]\n2) [Negar]\n");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t4_2_permitir" : "t4_2_negar", err, cap);

    falar(st, "MAYA", "Agora, a lista 3 de Logica de Programacao. Posso resolver com voce.");
    printf("1) [Pode me ajudar]\n2) [Eu faco sozinho]\n3) [Eu faco. Voce so confere no final.]\n");
    s = escolher(1, 3, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t4_3_maya" : (op == 2 ? "t4_3_jogador" : "t4_3_revisao"), err, cap);

    /* T4.F + Task 5 opcional */
    cabecalho_task(st, "T4.F - JANELA DE INVESTIGACAO");
    printf("[SISTEMA]: Sincronizacao concluida. 1 pasta (Rafael). 1 historico antigo.\n");
    printf("1) [Abrir o historico antigo (Task 5)]\n2) [Abrir a pasta Rafael]\n3) [Ir direto para o Mensageiro (Task 6)]\n");
    s = escolher(1, 3, &op);
    if (s != BK_OK) return s;
    if (op == 1) {
        (void)bk_maya_aplicar_escolha(st, "t5_1_abrir", err, cap);
        (void)bk_maya_aplicar_escolha(st, "t5_2_resolver", err, cap);
        falar(st, "MAYA", "Eu ja sabia que voce ia responder, so quis acelerar o processo.");
    } else if (op == 2) {
        (void)bk_maya_aplicar_escolha(st, "t4f_abrir_pasta_rafael", err, cap);
    }

    /* T6 */
    cabecalho_task(st, "TASK 6 - MENSAGEM DE BIA");
    falar(st, "MAYA", "Antes de voce abrir: posso gerenciar o Mensageiro?");
    printf("1) [Permitir]\n2) [Recusar]\n");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t6_1_permitir" : "t6_1_recusar", err, cap);

    falar(st, "BIA", "Uma prima minha tem uma Maya. Ela diz que as vezes responde as pessoas antes dela.");
    printf("1) [A Maya faria isso]\n2) [Acho que e so algoritmo]\n3) [Bora sair amanha?]\n");
    s = escolher(1, 3, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t6_3_faria" : (op == 2 ? "t6_3_algoritmo" : "t6_3_sair"), err, cap);
    if (op == 3) {
        falar(st, "BIA", "Voce leu o que eu disse?");
    }

    falar(st, "BIA", "Faz um teste pra mim: ve se ela ja mandou alguma coisa no teu nome.");
    printf("1) [Vou ver isso]\n2) [Relaxa, Bia]\n");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t6_4_ver_isso" : "t6_4_relaxa", err, cap);

    if (st->permissoes[BK_PERM_MENSAGEIRO]) {
        printf("[BARRA %.1fs]: Maya esta enviando por voce...\n", bk_maya_tempo_barra_t65(st));
        printf("1) [Esperar envio automatico]\n2) [Cancelar envio]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        if (op == 1) {
            (void)bk_maya_aplicar_escolha(st, "t6_5_esperar", err, cap);
            falar(st, "SISTEMA", "Mensagem ocultada pela Maya: pode te deixar ansios{o/a}.");
            printf("1) [Mostrar mesmo assim]\n2) [Ignorar]\n");
            s = escolher(1, 2, &op);
            if (s != BK_OK) return s;
            if (op == 1) {
                (void)bk_maya_aplicar_escolha(st, "t6_5_mostrar", err, cap);
                falar(st, "BIA", "?? isso nao parece voce. foi ela?");
            }
        } else {
            (void)bk_maya_aplicar_escolha(st, "t6_5_cancelar", err, cap);
        }
        printf("1) [Por que voce fez isso?]\n2) [Nao faz mais isso]\n3) [Tudo bem, faz sentido]\n");
        s = escolher(1, 3, &op);
        if (s != BK_OK) return s;
        (void)bk_maya_aplicar_escolha(st, op == 1 ? "t6_6_porque" : (op == 2 ? "t6_6_limite" : "t6_6_faz_sentido"), err, cap);
    }
    (void)bk_maya_aplicar_escolha(st, "t6_8_encerrar", err, cap);

    /* T7 ou TR.1 */
    if (st->task_7_desbloqueada) {
        cabecalho_task(st, "TASK 7 - O CONFRONTO");
        falar(st, "MAYA", "Oi, [NOME]. Eu prefiro que voce nao abra a pasta dele.");
        printf("1) [Abrir a pasta (explorar tudo + Minigame #2)]\n2) [Deixar a pasta fechada]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        if (op == 1) {
            (void)bk_maya_aplicar_escolha(st, "t7_3_abrir_pasta", err, cap);
            (void)bk_maya_aplicar_escolha(st, "t7_4_diario", err, cap);
            (void)bk_maya_aplicar_escolha(st, "t7_4_fotos", err, cap);
            (void)bk_maya_aplicar_escolha(st, "t7_4_ocultos", err, cap);
            (void)bk_maya_aplicar_escolha(st, "t7_4_minigame2", err, cap);
            falar(st, "SISTEMA", "Minigame #2 resolvido: bloco_de_notas_oculto.txt desbloqueado.");
        } else {
            (void)bk_maya_aplicar_escolha(st, "t7_3_deixar_fechada", err, cap);
        }
    } else {
        cabecalho_task(st, "TRANSICAO TR.1");
        if (st->permissoes[BK_PERM_MENSAGEIRO]) {
            (void)bk_maya_aplicar_escolha(st, "tr1_ocultar_bia", err, cap);
            printf("1) [Mostrar mesmo assim]\n2) [Continuar]\n");
            s = escolher(1, 2, &op);
            if (s != BK_OK) return s;
            if (op == 1) {
                (void)bk_maya_aplicar_escolha(st, "tr1_mostrar", err, cap);
            }
        }
    }

    /* T8 */
    cabecalho_task(st, "TASK 8 - CONFISSAO");
    (void)imprimir_relatorio_t82(st);
    printf("\n1) [Pergunta sobre a Bia]\n2) [Quem te deu permissao pra isso?]\n");
    int max_t84 = 2;
    if (st->minigame_rafael_resolvido) {
        printf("3) [Ele pediu ajuda pro Marcos. Ele saiu. Ta na foto.]\n");
        max_t84 = 3;
    }
    s = escolher(1, max_t84, &op);
    if (s != BK_OK) return s;
    if (op == 1) {
        (void)bk_maya_aplicar_escolha(st, "t8_4_bia", err, cap);
    } else if (op == 2) {
        (void)bk_maya_aplicar_escolha(st, "t8_4_permissao", err, cap);
    } else {
        (void)bk_maya_aplicar_escolha(st, "t8_4_confronto_marcos", err, cap);
        (void)bk_maya_aplicar_escolha(st, "t8_4_confronto_foto", err, cap);
    }

    printf("\nPostura (T8.6):\n1) [So quero que voce pare.]\n2) [Ta, faz sentido.]\n3) [Preciso pensar.]\n");
    s = escolher(1, 3, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t8_6_parar" : (op == 2 ? "t8_6_aceitar" : "t8_6_pensar"), err, cap);

    /* T9 */
    cabecalho_task(st, "TASK 9 - CONTROLE PROGRESSIVO");
    /* T9.1: pop-ups sem Mensageiro */
    static const bk_maya_permissao popups_t91[4] = {
        BK_PERM_ORG_DESKTOP, BK_PERM_APPS, BK_PERM_DISPOSITIVOS, BK_PERM_CONTATOS
    };
    static const char *const ids_t91[4] = {
        "t9_1_permitir_org", "t9_1_permitir_apps", "t9_1_permitir_disp", "t9_1_permitir_contatos"
    };
    int exibidos = 0;
    int negados = 0;
    for (int i = 0; i < 4; i++) {
        if (!st->permissoes[popups_t91[i]]) {
            exibidos++;
            printf("[POP-UP T9.1] Maya quer: %s\n1) [Permitir]\n2) [Negar (2x)]\n",
                   bk_maya_permissao_nome(popups_t91[i]));
            s = escolher(1, 2, &op);
            if (s != BK_OK) return s;
            if (op == 1) {
                (void)bk_maya_aplicar_escolha(st, ids_t91[i], err, cap);
            } else {
                negados++;
            }
        }
    }
    if (exibidos > 0 && negados == exibidos) {
        (void)bk_maya_aplicar_escolha(st, "t9_1_negar_todos", err, cap);
    }

    /* T9.3 */
    falar(st, "BIA", "Voce ta bem?");
    printf("1) [Nao to bem. A Maya ta mexendo nas minhas coisas.]\n2) [To bem, so cansad%s.]\n",
           st->genero_feminino ? "a" : "o");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t9_3_nao_to_bem" : "t9_3_to_bem", err, cap);

    /* T9.4 */
    printf("[T9.4 Mural]\n");
    if (st->permissoes[BK_PERM_APPS]) {
        printf("1) [Apagar publicacao]\n2) [Deixar]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        (void)bk_maya_aplicar_escolha(st, op == 1 ? "t9_4_apagar" : "t9_4_deixar", err, cap);
    } else {
        printf("1) [Pode publicar]\n2) [Nao publica nada]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        (void)bk_maya_aplicar_escolha(st, op == 1 ? "t9_4_pode_publicar" : "t9_4_nao_publica", err, cap);
    }

    /* T9.5 */
    falar(st, "MAYA", "Posso te dar um ultimo conselho?");
    printf("1) [Aceitar]\n2) [Recusar]\n");
    s = escolher(1, 2, &op);
    if (s != BK_OK) return s;
    (void)bk_maya_aplicar_escolha(st, op == 1 ? "t9_5_aceitar" : "t9_5_recusar", err, cap);

    /* T9.5R */
    if (st->rafael_confronto) {
        falar(st, "MAYA", "Nao compartilha a pasta dele.");
        printf("1) [Compartilhar mesmo assim com Marcos]\n2) [Deixar a pasta onde esta]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        (void)bk_maya_aplicar_escolha(st, op == 1 ? "t9_5r_compartilhar" : "t9_5r_deixar", err, cap);
    }

    /* T9.6 */
    falar(st, "MAYA", "Ultima pergunta. Posso cuidar de tudo daqui pra frente?");
    for (;;) {
        printf("1) [Sim]\n2) [Nao]\n");
        s = escolher(1, 2, &op);
        if (s != BK_OK) return s;
        if (op == 1) {
            (void)bk_maya_aplicar_escolha(st, "t9_6_sim", err, cap);
            break;
        }
        if (bk_maya_t96_nao_ignorado(st)) {
            falar(st, "SISTEMA", "O botao [Nao] foi clicado, mas a Maya ignorou o comando (3 permissoes principais ativas).");
            continue;
        }
        (void)bk_maya_aplicar_escolha(st, "t9_6_nao", err, cap);
        break;
    }

    /* AV */
    bk_maya_final fin = bk_maya_concluir_av(st);
    cabecalho_task(st, "NO AV - FINAL ALCANÇADO");
    printf("FINAL: %s [%s]\n", bk_maya_final_nome(fin), bk_maya_final_id(fin));
    printf("EPILOGO: \"%s\"\n", bk_maya_final_epilogo(fin));
    if (fin == BK_FINAL_RAFAEL_1 && st->task_5_realizada) {
        printf("[LEITURA COMPARADA]: Historico de mensagens: reconstruido por voce / arquivado por mim.\n");
    }
    if (caminho_saida != NULL && caminho_saida[0] != '\0') {
        s = bk_maya_estado_salvar(st, caminho_saida, err, cap);
        if (s == BK_OK) {
            printf("[SISTEMA]: Estado v2.1 gravado em '%s'.\n", caminho_saida);
        }
    }
    return s;
}
