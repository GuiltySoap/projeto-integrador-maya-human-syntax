#ifndef BK_MAYA_V21_H
#define BK_MAYA_V21_H
/*
 * Motor completo do Roteiro Revisado v2.1 (Maya: Human Syntax).
 * Implementa:
 *   - Eixos D (dependencia_maya: 0..100, inicial 50) e A (autonomia_jogador: >= 0, inicial 0);
 *   - 5 permissoes com reversao exata de delta em Configuracoes (T2..T8) e revogacao em 2 tentativas na Task 9;
 *   - Genero dinamico inferido a partir do nome_usuario (substituicao de tokens {o/a}, [NOME], {bia_ocultadas_count});
 *   - Todas as flags narrativas, janela de investigacao T4.F estendida ate T6.8, limite do Minigame #2 em T9.5R;
 *   - Regra de acessibilidade (barra T6.5: 3.0s padrao / 6.0s estendido) e trava do botao [Nao] em T9.6;
 *   - Maquina de avaliacao de finais (no AV) na ordem estrita de prioridade (1o ao 6o);
 *   - Persistencia JSON v2.1 com escrita atomica e modo interativo completo no console.
 */
#include "bk_args.h"
#include "bk_common.h"

#define BK_MAYA_V21_SCHEMA 2
#define BK_MAYA_NOME_MAX 64
#define BK_MAYA_DEP_INICIAL 50
#define BK_MAYA_AUT_INICIAL 0

typedef enum {
    BK_PERM_DISPOSITIVOS = 0,
    BK_PERM_ORG_DESKTOP = 1,
    BK_PERM_CONTATOS = 2,
    BK_PERM_APPS = 3,
    BK_PERM_MENSAGEIRO = 4,
    BK_PERM_TOTAL = 5
} bk_maya_permissao;

typedef enum {
    BK_T1_ORG_NENHUMA = 0,
    BK_T1_ORG_MAYA = 1,
    BK_T1_ORG_JOGADOR = 2
} bk_t1_org;

typedef enum {
    BK_T3_NONE = 0,
    BK_T3_COMO_SABE = 1,
    BK_T3_POR_QUE_ACESSOU = 2,
    BK_T3_VALEU = 3
} bk_t3_resp;

typedef enum {
    BK_ENTREGA_NENHUMA = 0,
    BK_ENTREGA_MAYA = 1,
    BK_ENTREGA_JOGADOR = 2,
    BK_ENTREGA_REVISAO = 3
} bk_entrega_modo;

typedef enum {
    BK_T8_NONE = 0,
    BK_T8_PARAR = 1,
    BK_T8_ACEITAR = 2,
    BK_T8_PENSAR = 3
} bk_t8_postura;

typedef enum {
    BK_MURAL_NENHUMA = 0,
    BK_MURAL_MAYA = 1,
    BK_MURAL_APAGADA = 2
} bk_mural_pub;

typedef enum {
    BK_FINAL_NENHUM = 0,
    BK_FINAL_RAFAEL_2 = 1,        /* Pedido de ajuda */
    BK_FINAL_RAFAEL_1 = 2,        /* Usuario anterior */
    BK_FINAL_ACEITACAO_TOTAL = 3, /* Tudo em ordem */
    BK_FINAL_RECUSA_TOTAL = 4,    /* Modo manual */
    BK_FINAL_MEIO_TERMO_1 = 5,    /* Convivencia com limites */
    BK_FINAL_MEIO_TERMO_2 = 6     /* Delegacao negociada */
} bk_maya_final;

typedef enum {
    BK_REVOG_JA_INATIVA = 0,
    BK_REVOG_ADIADA = 1,     /* 1a tentativa na Task 9 */
    BK_REVOG_CONCLUIDA = 2   /* 2a tentativa na Task 9 (ou toggle em Configuracoes) */
} bk_revog_resultado;

typedef struct {
    char choice_id[BK_ID_MAX + 1];
    char status[BK_STATUS_MAX + 1];
    char timestamp[BK_TIMESTAMP_MAX];

    char nome_usuario[BK_MAYA_NOME_MAX];
    bool genero_feminino;
    bool tempo_estendido; /* T6.5: false = 3.0s, true = 6.0s */

    int dependencia_maya;   /* D: 0..100, inicial 50 */
    int autonomia_jogador;  /* A: >= 0, inicial 0 */

    bool permissoes[BK_PERM_TOTAL];
    bool revogada_em_config[BK_PERM_TOTAL];
    int tentativas_revogacao_t9[BK_PERM_TOTAL];

    bool maya_interferiu_mensagem;
    bool maya_controla_respostas;
    bool bia_censurada;
    int bia_ocultadas_count;
    bool pediu_limite;
    bool pista_anotacao_lida;

    bk_t1_org t1_organizacao;
    bk_t3_resp t3_resposta;
    bool rotina_por_maya;
    bk_entrega_modo entrega_modo;
    bool conhecimento_logico_adquirido;
    bool sincronizacao_concluida;

    bool janela_t4f_aberta;
    bool rafael_investigado;
    bool task_5_realizada;
    bool pasta_rafael_aberta;
    bool rafael_diario_lido;
    bool rafael_fotos_vistas;
    bool segredo_rafael_encontrado;
    bool minigame_rafael_resolvido;
    bool minigame_2_bloqueado;
    bool task_7_desbloqueada;
    bool rafael_confronto;
    bool rafael_evidencia_enviada;

    bk_t8_postura t8_postura;
    bool bia_alertada;
    bool bia_convidada;
    bk_mural_pub mural_publicacao;

    bool t2_primeira_recusa_exibida;
    bool t91_todos_negados_bonus;

    int task_atual; /* 1..9, 10 = AV */
    bool final_avaliado;
    bk_maya_final final_obtido;
} bk_maya_estado;

/* Inicializa o estado com os valores padrao da v2.1 (D=50, A=0, flags=false). */
void bk_maya_estado_inicial(bk_maya_estado *st, const char *nome_usuario);

/* Infere genero feminino a partir do nome inserido (ex.: Erika -> true, Antonio -> false). */
bool bk_maya_inferir_genero_feminino(const char *nome_usuario);

/* Formata string substituindo {o/a}, [NOME], {nome_usuario} e {bia_ocultadas_count}. */
bool bk_maya_formatar_texto(const bk_maya_estado *st, const char *modelo, char *dst, size_t cap);

/* Altera D (limitado a 0..100) e A (limitado a >= 0). */
void bk_maya_alterar_da(bk_maya_estado *st, int delta_d, int delta_a);

/* Quantidade de permissoes ativas (0..5) e derivacao de investigacao profunda. */
int bk_maya_permissoes_ativas(const bk_maya_estado *st);
bool bk_maya_investigacao_profunda(const bk_maya_estado *st);

/* Tempo da barra de cancelamento em T6.5 (3.0s padrao, 6.0s estendido). */
double bk_maya_tempo_barra_t65(const bk_maya_estado *st);

/* Concede ou nega uma permissao em cartao/pop-up (T2, T4.2, T6.1, T9.1). */
void bk_maya_decidir_permissao(bk_maya_estado *st, bk_maya_permissao perm, bool conceder, int delta_d);

/* Toggle em Configuracoes > Privacidade (T2 a T8): revogar aplica D -5, A +1; reativar desfaz exatamente D +5, A -1. */
void bk_maya_config_toggle_permissao(bk_maya_estado *st, bk_maya_permissao perm);

/* Revogacao na Task 9 (T9.2): exige 2 tentativas. Na 2a aplica D -10, A +1 (e zera maya_controla_respostas se Mensageiro). */
bk_revog_resultado bk_maya_t9_revogar_permissao(bk_maya_estado *st, bk_maya_permissao perm);

/* Regra v2.1 de T9.6: se org + apps + mensageiro == true, o botao [Nao] fica visivel mas o clique e ignorado. */
bool bk_maya_t96_nao_ignorado(const bk_maya_estado *st);

/* Encerramento de T6.8 (fecha janela T4.F e define task_7_desbloqueada = rafael_investigado). */
void bk_maya_encerrar_t6(bk_maya_estado *st);

/* Encerramento de T9.5R (bloqueia definitivamente o Minigame #2). */
void bk_maya_encerrar_t95r(bk_maya_estado *st);

/* Aplica uma acao/escolha da matriz v2.1 por ID canonico (ex.: "t1_4_maya", "t3_5_certeza", "t9_6_sim"). */
bk_status bk_maya_aplicar_escolha(bk_maya_estado *st, const char *id_escolha, char *err, size_t cap);

/* Maquina de avaliacao de finais (no AV): pura, deterministica, ordem estrita 1o..6o. */
bk_maya_final bk_maya_avaliar_final(const bk_maya_estado *st);

/* Executa o no AV uma unica vez, gravando final_obtido. */
bk_maya_final bk_maya_concluir_av(bk_maya_estado *st);

/* Metadados oficiais dos finais (nome, id e mini-epilogo). */
const char *bk_maya_final_id(bk_maya_final f);
const char *bk_maya_final_nome(bk_maya_final f);
const char *bk_maya_final_epilogo(bk_maya_final f);
const char *bk_maya_permissao_nome(bk_maya_permissao p);

/* Persistencia JSON v2.1 (escrita atomica e leitura validada). */
bk_status bk_maya_estado_serializar(const bk_maya_estado *st, char **out, size_t *out_len, char *err, size_t cap);
bk_status bk_maya_estado_salvar(const bk_maya_estado *st, const char *caminho, char *err, size_t cap);
bk_status bk_maya_estado_carregar(const char *caminho, bk_maya_estado *out, char *err, size_t cap);

/* Executa --v21-choice <id>: le estado_jogo.json (schema_version 2) se existir, aplica a escolha e grava atomicamente. */
bk_status bk_maya_executar_comando_v21(const bk_args *args, bk_maya_estado *estado_out, char *caminho_usado, size_t cap_caminho,
                                       char *err, size_t cap);

/* Modo interativo completo no console seguindo o Roteiro Revisado v2.1 (T1..T9 + AV). */
bk_status bk_maya_jogar_v21(bk_maya_estado *st, const char *caminho_saida, char *err, size_t cap);

#endif
