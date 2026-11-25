# Trilhas dinâmicas (clímax e epílogos)

O catálogo vive em `core/data/audio_faixas.json`. Coloque os arquivos **nesta pasta** com estes nomes (extensão `.ogg` recomendada; `.wav` e `.mp3` também funcionam):

| Faixa (id)         | Arquivo                 | Quando toca                                   |
|--------------------|-------------------------|-----------------------------------------------|
| `climax`           | `bgm_climax`            | Início da Task 9 (evento `task_9_started`)    |
| `final_acceptance` | `bgm_final_aceitacao`   | Final Aceitação total                          |
| `final_autonomy`   | `bgm_final_autonomia`   | Final Recusa total                             |
| `final_middle_01`  | `bgm_final_meio_01`     | Final Meio-termo 1                             |
| `final_middle_02`  | `bgm_final_meio_02`     | Final Meio-termo 2                             |
| `final_rafael_01`  | `bgm_final_rafael_01`   | Final Rafael 1                                 |
| `final_rafael_02`  | `bgm_final_rafael_02`   | Final Rafael 2                                 |

Enquanto um arquivo não existir, a faixa cai no `fallback` do catálogo (`default` = `bgm_dia_5`), então o jogo funciona sem nenhum deles.
Antes de adicionar uma música, confirme a licença na página oficial do autor/site e guarde a atribuição (veja `docs/19_trilha_sonora_dinamica.md`).
