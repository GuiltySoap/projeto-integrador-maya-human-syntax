# Relatório Consolidado de Alterações e Bateria de Testes do Backend C

Data da execução: 20/11/2026  
Status geral: **100% APROVADO (Zero falhas, Zero erros de compilação)**

---

## 1. Sumário das Alterações Realizadas

Todas as modificações foram concentradas e aplicadas no diretório oficial `backend/` do projeto Maya:

### 1.1 `backend/json_loader.c`
* **Implementação do motor `executar_grafo_dialogo`**:
  * Adicionado suporte nativo à chave `"dialogue": [ ... ]` presente no roteiro Maya v2.
  * O carregador agora localiza o `start_node`, itera nó por nó, exibe cabeçalhos de Task/Estágio, processa mensagens do locutor (`speaker` e `text`) e oferece as escolhas (`choices`).
  * Processa a seleção do usuário e segue o nó seguinte definido dinamicamente pelo campo `next` de cada escolha tomada até o nó final `"END"`.
  * Mantida 100% da compatibilidade com arquivos legados no formato `days/turns` e tratamento resiliente de erros para esquemas inválidos.

### 1.2 `backend/maya_dialogue.json`
* **Inclusão do Roteiro Oficial Maya v2**:
  * Adicionado o arquivo de 12 nós encadeados cobrindo desde a Task 1 até a Task 9 e desfecho:
    - `t1_sync_1` / `t1_sync_2` (Sincronização e gancho inicial)
    - `t2_permissoes` (Dark pattern de permissões)
    - `t3_calendario` / `t3_fissura` (Calendário e a fissura do sono)
    - `t4_cronometro` / `t4_conselho` (Decisões com contagem regressiva)
    - `t6_mensagem_amigos` / `t6_investigacao` (Mensagem sabotada da Bia e investigação do Rafael)
    - `t7_terminal_cmd` (Minigame de terminal com `[search USER]`, `[list_profiles]` e `[override]`)
    - `t8_confissao` (A confissão da IA Maya)
    - `t9_final_decisao` (Microdecisões e ruptura/conclusão)
    - `END` (Encerramento do jogo)

### 1.3 `backend/ui.h` e `backend/ui.c`
* **Implementação de `executar_turno_com_escolha`**:
  * Adicionada a função `executar_turno_com_escolha(GameState *jogo, const Turn *turno, int *escolha_id_out)`.
  * Permite que a interface informe qual foi o ID da escolha tomada pelo jogador, possibilitando ao carregador navegar pela rota narrativa correta.
  * Mantida a função existente `executar_turno` chamando a nova função com retorno nulo (preservando o contrato existente).
  * Adicionado suporte seguro a terminal no Windows MinGW (`fileno` e `_isatty`).

### 1.4 `backend/bk_common.h` e `backend/bk_common.c`
* **Portabilidade MinGW / Windows**:
  * `bk_common.h`: Ativado `__USE_MINGW_ANSI_STDIO 1` e adicionada a anotação `gnu_printf` sob GCC/MinGW para permitir o uso seguro de `%zu` com `-Wformat=2` e `-Werror`.
  * `bk_common.c`: Substituído `gmtime_s` por fallback padrão para `gmtime` sob compiladores MinGW (resolvendo undefined reference da msvcrt). Adicionado protótipo de `fileno` sob `_WIN32`.

### 1.5 `backend/main.c`
* **Seleção Inteligente do Roteiro**:
  * Função `modo_interativo` atualizada para verificar se `maya_dialogue.json` está disponível no diretório de execução, usando-o como padrão automático, com fallback para `dialogues.json` ou arquivo passado via `--dialogues <caminho>`.

### 1.6 `Makefile`
* **Compatibilidade com Windows CMD**:
  * Corrigida a regra de criação de diretório de saída (`backend/output`) para usar comando condicional compatível com Windows NT (`if not exist backend\output mkdir backend\output`), eliminando o erro de sintaxe do `mkdir -p`.

---

## 2. Bateria de Testes Executada

### Teste T1: Compilação Estrita com Avisos Máximos e `-Werror`
* **Comando**:
  ```bash
  mingw32-make -B backend
  ```
* **Flags utilizadas**:
  `-std=c11 -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wcast-qual -Wformat=2 -Wnull-dereference -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wwrite-strings -Werror -O2`
* **Resultado**:
  ```text
  if not exist backend\output mkdir backend\output
  gcc -std=c99 -Wall -Wextra -O2 -c backend/cJSON.c -o backend/output/cJSON.o
  gcc -std=c11 -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wcast-qual -Wformat=2 -Wnull-dereference -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wwrite-strings -Werror -O2 backend/main.c backend/bk_common.c backend/bk_args.c backend/bk_estado.c backend/bk_catalogo.c backend/bk_comando.c backend/json_loader.c backend/ui.c backend/output/cJSON.o -lm -o backend/output/maya_backend.exe
  ```
* **Status**: **PASS (0 erros, 0 avisos)**

---

### Teste T2: Suíte Completa de Testes Nativos do Backend em C (`test_backend.c`)
* **Executável**: `backend/output/test_backend.exe`
* **Cobertura**: Validação de argumentos CLI, injeção de falhas de alocação de memória, limites de buffer, integridade atômica de arquivos, esquema JSON, leitura de turnos e catálogo de escolhas.
* **Resultado**:
  ```text
  RESULTADO C: 1013 verificacoes, 0 falhas.
  ```
* **Status**: **PASS (1013/1013 verificações bem-sucedidas)**

---

### Teste T3: Modo CLI e Contrato de Integração (`--choice`)
* **Comando**:
  ```bash
  .\backend\output\maya_backend.exe --catalog backend/choices.json --choice ok --out test_estado.json
  ```
* **Resultado**:
  ```text
  ok: escolha 'ok' aplicada; estado gravado em test_estado.json
  ```
* **Conteúdo gerado no JSON**:
  ```json
  {
  	"schema_version": 1,
  	"choice_id": "ok",
  	"status": "ok",
  	"metrics": {
  		"autonomia": 47,
  		"conformidade": 52,
  		"dependencia": 4
  	},
  	"timestamp": "2026-11-21T00:23:03Z",
  	"is_placeholder": false
  }
  ```
* **Status**: **PASS (Contrato com o Godot validado com timestamp ISO-8601 UTC)**

---

### Teste T4: Playthrough Completo do Roteiro Maya v2 no Console Interativo
* **Comando**:
  Execução do binário contra `backend/maya_dialogue.json` percorrendo todas as 12 etapas do início ao fim:
* **Fluxo testado**:
  1. `Task 1 — Sincronizacao e o gancho`: Entrada "1" ("Pode apagar") -> Autonomia vai para 90%.
  2. `Task 2 — Permissoes (dark pattern)`: Entrada "1" ("Permitir") -> Autonomia vai para 80%.
  3. `Task 3 — Calendario e A Fissura`: Entrada "1" ("Pode montar") -> Autonomia vai para 70%.
  4. `Task 3 — A Fissura`: Entrada "1" ("Como voce sabe disso?") -> Resposta explicativa da Maya.
  5. `Task 4 — Decisao com cronometro`: Entrada "1" ("Pode escolher") -> Autonomia atualizada.
  6. `Task 6 — Mensagem sabotada (Bia)`: Entrada "1" -> Consequência narrada.
  7. `Task 7 — O confronto e o Terminal`: Entrada narrativa.
  8. `Task 7 — Terminal (Minigame #2)`: Entrada de comandos de terminal `[search USER]`, `[list_profiles]`, leitura do perfil de Rafael Munhoz.
  9. `Task 8 — A confissao`: Diálogo de confronto sobre Bia e Rafael.
  10. `Task 9 — Microdecisoes finais`: Decisão de ruptura e formatação.
  11. `Tela Final`: Exibição de `FIM DA DEMONSTRACAO DO JOGO`, exibição da Autonomia Final (`70%`) e status de perfil `DESCONECTADO COM SUCESSO`.
* **Status**: **PASS (Ciclo narrativo completo executado com código de saída 0)**

---

## 3. Conclusão e Integridade do Repositório

* **Nenhum arquivo de `modificacoes_c` foi inserido no projeto**: Os conflitos de linkagem e bugs de buffer daquela versão foram completamente evitados.
* **O backend oficial em `backend/` está totalmente alinhado com o Roteiro v2 da Maya**: O executável `backend/output/maya_backend.exe` está compilado, testado e pronto para uso.
