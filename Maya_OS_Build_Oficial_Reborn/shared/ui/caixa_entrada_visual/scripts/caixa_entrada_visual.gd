class_name CaixaEntradaVisual
extends PanelContainer
## Caixa de entrada VISUAL (Mensageiro e Painel da Maya). Não é um campo de texto: é um painel com um rótulo "Escreva uma mensagem...", sem cursor,
## sem colar, sem teclado virtual e sem digitação livre. Serve só de gatilho: clicar (ou Enter/Espaço/botão de confirmação do controle) REVELA as
## respostas do nó atual do roteiro, mas apenas quando o contexto tem opções. Sem opções nada acontece: nada é revelado, nenhuma flag, escolha ou
## Dependência muda e nenhum painel vazio aparece.
## Regras:
##   - `sincronizar(tem_opcoes, contexto)` é chamado pelo dono toda vez que as opções (ou a conversa) mudam. Um contexto novo (outro nó, outro
##     contato) fecha as respostas de novo: as opções são reveladas UMA vez por nó e consumidas quando o jogador escolhe;
##   - `revelada()` diz ao dono se a área de respostas pode aparecer; `consumir()` a fecha (depois de uma escolha);
##   - não guarda nada fora da memória: a revelação nunca vai para save, flag ou Dependência.
## Acessibilidade: foco por teclado/controle, dica de ferramenta com o estado, alto contraste = moldura branca, nunca só cor.

signal ativada

const TEXTO_PADRAO := "Escreva uma mensagem..."
const TEXTO_REVELADA := "Escolha uma resposta abaixo"
const DICA_SEM_OPCOES := "Não há nada para responder agora."
const DICA_COM_OPCOES := "Clique para ver as respostas disponíveis."
const DICA_REVELADA := "As respostas estão abaixo."

@export var placeholder: String = TEXTO_PADRAO

var _tem_opcoes: bool = false
var _revelada: bool = false
var _contexto: String = ""
var _rotulo: Label = null


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0, UiKit.escalar(34))
	_rotulo = get_node_or_null("Rotulo") as Label
	if _rotulo == null:
		_rotulo = Label.new()
		_rotulo.name = "Rotulo"
		add_child(_rotulo)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo.clip_text = true
	_rotulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.connect(_ao_configuracao)
	_atualizar_visual()


func _exit_tree() -> void:
	if GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.disconnect(_ao_configuracao)


## Informa o que existe para responder. Contexto diferente do anterior (outro nó/contato) fecha as respostas; sem opções também.
func sincronizar(com_opcoes: bool, id_contexto: String = "") -> void:
	if id_contexto != _contexto or not com_opcoes:
		_revelada = false
	_contexto = id_contexto
	_tem_opcoes = com_opcoes
	_atualizar_visual()


func tem_opcoes() -> bool:
	return _tem_opcoes


func revelada() -> bool:
	return _revelada


func contexto() -> String:
	return _contexto


## Mostra as respostas. Devolve false (e não faz nada) sem opções ou se elas já estão à mostra: nunca duplica nem reabre sozinho.
func ativar() -> bool:
	if not _tem_opcoes or _revelada:
		return false
	_revelada = true
	_atualizar_visual()
	ativada.emit()
	return true


## Fecha as respostas (o jogador escolheu: as opções foram consumidas).
func consumir() -> void:
	_revelada = false
	_atualizar_visual()


## A caixa nunca aceita texto: este método existe só para os testes comprovarem que não há entrada livre.
func aceita_texto() -> bool:
	return false


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ativar()
			accept_event()
	elif evento is InputEventKey:
		var k := evento as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE):
			ativar()
			accept_event()
	elif evento.is_action_pressed("ui_accept"):
		ativar()
		accept_event()


func _ao_configuracao(chave: String, _valor: Variant) -> void:
	if chave == "alto_contraste" or chave == "tema" or chave == "tamanho_texto":
		_atualizar_visual()


func texto_exibido() -> String:
	return TEXTO_REVELADA if _revelada else placeholder


func _atualizar_visual() -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto_exibido()
	_rotulo.modulate = Color(1, 1, 1, 1.0 if _tem_opcoes else 0.55)
	tooltip_text = DICA_REVELADA if _revelada else (DICA_COM_OPCOES if _tem_opcoes else DICA_SEM_OPCOES)
	var contraste: bool = bool(GerenciadorConfiguracoes.obter("alto_contraste"))
	var caixa := StyleBoxFlat.new()
	caixa.set_corner_radius_all(8)
	caixa.content_margin_left = 12
	caixa.content_margin_right = 12
	caixa.content_margin_top = 6
	caixa.content_margin_bottom = 6
	caixa.set_border_width_all(2 if (contraste or _revelada) else 1)
	var acento: Color = TemaNexus.cor("acento")
	if contraste:
		caixa.bg_color = Color.BLACK
		caixa.border_color = Color.WHITE
	else:
		caixa.bg_color = Color(0.07, 0.07, 0.12, 0.92)
		caixa.border_color = Color(acento.r, acento.g, acento.b, 0.95 if _revelada else (0.6 if _tem_opcoes else 0.25))
	add_theme_stylebox_override("panel", caixa)
