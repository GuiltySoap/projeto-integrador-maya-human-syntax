class_name EstadoPainel
extends RefCounted
## Máquina de estados do painel ancorado da Maya (e de qualquer janela marcada com `painel_ancorado` no catálogo de apps):
##   FECHADO -> ABRINDO -> ABERTO -> FECHANDO -> FECHADO.
## Proteção contra clique duplo: pedir abrir/fechar fora do estado certo é RECUSADO (devolve false) e nada muda, então um segundo clique
## durante a animação não reabre, não fecha duas vezes e não cria uma segunda instância. Sem animação (reduzir animações) as transições
## "concluir_*" são chamadas na hora pelo dono. Classe pura: não depende de cena nem de autoload (testável sem a árvore).

enum Estado { FECHADO, ABRINDO, ABERTO, FECHANDO }

var estado: Estado = Estado.FECHADO


func pedir_abrir() -> bool:
	if estado != Estado.FECHADO:
		return false
	estado = Estado.ABRINDO
	return true


func concluir_abertura() -> void:
	if estado == Estado.ABRINDO:
		estado = Estado.ABERTO


func pedir_fechar() -> bool:
	if estado != Estado.ABERTO:
		return false
	estado = Estado.FECHANDO
	return true


func concluir_fechamento() -> void:
	if estado == Estado.FECHANDO:
		estado = Estado.FECHADO


func em_transicao() -> bool:
	return estado == Estado.ABRINDO or estado == Estado.FECHANDO


func aberto() -> bool:
	return estado == Estado.ABERTO


func nome() -> String:
	return Estado.keys()[estado]
