/*
 * Backend em C (Maya Human Syntax): ferramenta auxiliar de linha de comando, FORA do jogo Godot (o jogo não a executa).
 *   - `--choice <id>`: aplica uma escolha do catálogo e grava `estado_jogo.json` (contrato lido pelo Godot);
 *   - sem argumentos: modo interativo de console, com o roteiro `dialogues.json` (formato days/turns).
 * Veja bk_args.h para todas as opções e bk_estado.h para o formato do arquivo.
 */
#include "bk_args.h"
#include "bk_comando.h"
#include "bk_maya_v21.h"
#include "game.h"
#include "json_loader.h"
#include "ui.h"

#include <stdio.h>
#include <string.h>

#define BK_VERSAO "2.1.0"
#define BK_ROTEIRO_PADRAO "dialogues.json"

static void mostrar_ajuda(void) {
    puts("Uso: maya_backend [opcoes]\n"
         "  --choice <id>          aplica a escolha <id> do catalogo legado (schema_version 1) e grava estado_jogo.json\n"
         "  --v21-choice <id>      aplica a escolha <id> do Roteiro v2.1 (schema_version 2) e grava estado_jogo.json\n"
         "  --nome <nome>          nome do jogador para inferencia de genero {o/a} no modo --v21-choice\n"
         "  --out <caminho>        arquivo de estado (padrao: $MAYA_USER_DIR/estado_jogo.json ou ./estado_jogo.json)\n"
         "  --catalog <caminho>    catalogo de escolhas (padrao: choices.json)\n"
         "  --timestamp <iso>      carimbo fixo YYYY-MM-DDTHH:MM:SSZ (testes)\n"
         "  --reset                ignora o estado gravado e parte dos valores iniciais\n"
         "  --dialogues <caminho>  roteiro do modo interativo (padrao: dialogues.json)\n"
         "  --help, -h             esta ajuda\n"
         "  --version              versao\n"
         "Sem --choice abre o modo interativo (console).\n"
         "Codigos de saida: 0 ok, 2 argumento, 3 formato do id, 4 id desconhecido, 5 E/S, 6 json, 7 memoria, 8 esquema, 9 limite.");
}

static bool arquivo_acessivel(const char *path) {
    if (path == NULL) return false;
    FILE *f = fopen(path, "rb");
    if (f != NULL) {
        fclose(f);
        return true;
    }
    return false;
}

static bk_status modo_interativo(const bk_args *args) {
    const char *roteiro = args->tem_dialogos ? args->dialogos :
        (arquivo_acessivel("maya_dialogue.json") ? "maya_dialogue.json" :
         (arquivo_acessivel("backend/maya_dialogue.json") ? "backend/maya_dialogue.json" : BK_ROTEIRO_PADRAO));
    char err[BK_ERR_MSG_MAX];
    for (;;) {
        limpar_tela();
        printf("==================================================\n");
        printf("         MAYA HUMAN SYNTAX - HUMAXOS v2.1         \n");
        printf("==================================================\n\n");
        printf("1. Iniciar Novo Jogo (Roteiro Final v2.1 - T1 a T9 + AV)\n");
        printf("2. Demonstracao por JSON (%s)\n", roteiro);
        printf("3. Sair\n");
        printf("\nEscolha uma opcao (1-3): ");
        (void)fflush(stdout);
        int opcao = 0;
        bk_status st = ui_ler_inteiro(1, 3, &opcao);
        if (st == BK_ERR_IO) {
            return BK_OK; /* entrada encerrada: sai sem erro */
        }
        if (st != BK_OK) {
            continue;
        }
        if (opcao == 3) {
            printf("\nEncerrando a sessao do HumaxOS... Ate logo!\n");
            return BK_OK;
        }
        if (opcao == 1) {
            char nome[BK_MAYA_NOME_MAX];
            printf("\nDigite seu nome: ");
            (void)fflush(stdout);
            if (!ui_ler_linha(nome, sizeof nome)) {
                return BK_OK;
            }
            bk_maya_estado v21;
            bk_maya_estado_inicial(&v21, nome);
            printf("Ativar tempo estendido de acessibilidade na barra da Task 6 (6.0s em vez de 3.0s)? (S/N): ");
            (void)fflush(stdout);
            char acc[8];
            if (ui_ler_linha(acc, sizeof acc) && (acc[0] == 'S' || acc[0] == 's')) {
                v21.tempo_estendido = true;
            }
            const char *saida_v21 = args->tem_saida ? args->saida : "estado_maya_v21.json";
            st = bk_maya_jogar_v21(&v21, saida_v21, err, sizeof err);
            if (st != BK_OK) {
                fprintf(stderr, "[ERRO] %s\n", err);
                return st;
            }
        } else {
            GameState jogo;
            memset(&jogo, 0, sizeof jogo);
            jogo.autonomia = 100;
            st = executar_jogo(roteiro, &jogo, err, sizeof err);
            if (st != BK_OK) {
                fprintf(stderr, "[ERRO] %s\n", err);
                return st;
            }
            limpar_tela();
            printf("==================================================\n");
            printf("            FIM DA DEMONSTRACAO DO JOGO           \n");
            printf("==================================================\n\n");
            printf("Autonomia Final do Utilizador: %d%%\n", jogo.autonomia);
            printf("Status do Perfil: %s\n\n", jogo.autonomia <= 40 ? "ALOCADO COMO ATIVO/PRODUTO" : "DESCONECTADO COM SUCESSO");
        }
        printf("\nDeseja jogar novamente? (S/N): ");
        (void)fflush(stdout);
        char resposta[8];
        if (!ui_ler_linha(resposta, sizeof resposta) || (resposta[0] != 'S' && resposta[0] != 's')) {
            printf("\nObrigado por jogar Maya Human Syntax!\n");
            return BK_OK;
        }
    }
}

int main(int argc, char **argv) {
    bk_cjson_instalar_hooks();
    bk_args args;
    char err[BK_ERR_MSG_MAX];
    bk_status st = bk_args_interpretar(argc, argv, &args, err, sizeof err);
    if (st != BK_OK) {
        fprintf(stderr, "[ERRO] %s\nUse --help para ver as opcoes.\n", err);
        return (int)st;
    }
    if (args.ajuda) {
        mostrar_ajuda();
        return 0;
    }
    if (args.versao) {
        puts("maya_backend " BK_VERSAO);
        return 0;
    }
    if (args.tem_escolha) {
        bk_estado estado;
        char usado[BK_PATH_MAX];
        st = bk_comando_escolha(&args, &estado, usado, sizeof usado, err, sizeof err);
        if (st != BK_OK) {
            fprintf(stderr, "[ERRO] %s (%s)\n", err, bk_status_str(st));
            return (int)st;
        }
        printf("ok: escolha '%s' aplicada; estado gravado em %s\n", estado.choice_id, usado);
        return 0;
    }
    if (args.tem_escolha_v21) {
        bk_maya_estado estado_v21;
        char usado[BK_PATH_MAX];
        st = bk_maya_executar_comando_v21(&args, &estado_v21, usado, sizeof usado, err, sizeof err);
        if (st != BK_OK) {
            fprintf(stderr, "[ERRO] %s (%s)\n", err, bk_status_str(st));
            return (int)st;
        }
        printf("ok: escolha v2.1 '%s' aplicada (D=%d, A=%d, final=%s); estado gravado em %s\n",
               estado_v21.choice_id, estado_v21.dependencia_maya, estado_v21.autonomia_jogador,
               bk_maya_final_id(estado_v21.final_obtido), usado);
        return 0;
    }
    st = modo_interativo(&args);
    return (int)st;
}
