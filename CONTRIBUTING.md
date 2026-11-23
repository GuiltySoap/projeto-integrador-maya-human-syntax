# Como Contribuir com o Maya: Human Syntax

Obrigado por contribuir com o projeto! Este guia explica como configurar o ambiente do zero, rodar o jogo e os testes, organizar branches e enviar Pull Requests para o `main`.

A regra central é simples: **mudanças pequenas, rastreáveis a uma issue/história, testadas e revisadas antes do merge.**

---

## 1. Configuração do Ambiente

### Pré-requisitos
* **Git** (2.30+)
* **Godot Engine 4.7** (para rodar, editar e testar o jogo principal)
* **GCC / MinGW** + **`make` (`mingw32-make` no Windows)** (para compilar e testar o backend em C)

### Passo a passo

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/GuiltySoap/projeto-integrador-maya-human-syntax.git
   cd projeto-integrador-maya-human-syntax
   ```

2. **Executar o jogo (Godot 4.7):**
   * Abra a Godot 4.7, clique em **Importar** e selecione o arquivo `project.godot`.
   * Aguarde a importação inicial de assets e classes (`class_name`).
   * Pressione **F5** para executar o jogo a partir da Splash Screen.

3. **Compilar e testar o Backend em C (v2.1):**
   * **Windows (PowerShell / CMD com MinGW):**
     ```powershell
     mingw32-make -B backend
     .\backend\output\maya_backend.exe --version
     .\backend\output\maya_backend.exe --v21-choice t1_4_maya --nome Erika --reset
     ```
   * **Linux / macOS / MSYS2:**
     ```bash
     make backend
     make test-c
     ```
   * **Rodar a suíte nativa de testes em C no Windows (1.461 verificações):**
     ```powershell
     gcc -std=c11 -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wcast-qual -Wformat=2 -Wnull-dereference -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wwrite-strings -Werror -g -O1 -DBK_TESTING backend/tests/test_backend.c backend/bk_common.c backend/bk_args.c backend/bk_estado.c backend/bk_catalogo.c backend/bk_comando.c backend/bk_maya_v21.c backend/json_loader.c backend/ui.c backend/output/cJSON.o -lm -o backend/output/test_backend.exe
     .\backend\output\test_backend.exe
     ```

4. **Rodar as suítes de teste no editor Godot:**
   * Abra cada cena de teste (`tests/sistemas_novos/sistemas_novos.tscn`, `tests/monitor_virtual/monitor_virtual.tscn`, `tests/splash/splash.tscn`) e pressione **F6**.
   * Todas as suítes devem finalizar com **0 falhas**.

---

## 2. Fluxo de Trabalho (GitHub Flow)

| Branch | Papel | Origem | Destino |
| :--- | :--- | :--- | :--- |
| `main` | Sempre estável, compilável e jogável. | — | — |
| `<tipo>/<area>-<descricao>` | Mudança isolada ligada a uma US ou issue. | `main` | `main` (via PR) |

### Regras
* **Sem push direto no `main`**: toda alteração entra via Pull Request revisado.
* **Uma branch por tarefa/US** (ex.: `feat/backend-roteiro-v21`, `fix/ui-quebra-linha-chat`, `docs/sprint3-rastreabilidade`).
* Sempre atualize sua branch antes de abrir PR: `git pull --rebase origin main`.
* Remova a branch após o merge.

---

## 3. Padrão de Commits e Rastreabilidade

Seguimos [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/) vinculando cada commit à US ou Issue:

```text
tipo(escopo): descrição curta no imperativo

Explicação breve do porquê da mudança (quando necessário).

Refs: #12 / US-15
```

| Tipo | Quando usar |
| :--- | :--- |
| `feat` | Nova funcionalidade ou história de usuário |
| `fix` | Correção de bug |
| `test` | Adição ou ajuste de testes automatizados |
| `refactor` | Reestruturação interna sem alterar comportamento |
| `docs` | Atualização de README, relatórios, diagramas ou guias |
| `build` | Alterações em `Makefile`, presets de exportação ou compilação |

---

## 4. Regras Técnicas Obrigatórias

* **Sem chamadas ao shell:** o código Godot **nunca** deve usar `OS.execute`, `OS.create_process`, `OS.shell_open` ou `OS.kill`. O código C **nunca** deve usar `system`, `popen` ou funções de cópia sem limite (`strcpy`, `strcat`, `sprintf`, `gets`, `scanf`).
* **Compilação limpa:** qualquer alteração em `backend/` precisa compilar com `0 erros` e `0 avisos` sob `-Werror` e passar na suíte `test_backend.exe`.
* **GDScript tipado:** todas as funções e variáveis novas em `.gd` devem declarar tipos estáticos e usar **tabs**.
