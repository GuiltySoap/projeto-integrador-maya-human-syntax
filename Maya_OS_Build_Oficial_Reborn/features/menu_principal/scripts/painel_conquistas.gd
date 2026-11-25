class_name PainelConquistas
extends Control
## Painel de Conquistas do Menu Principal: exibe progresso global (X/18), barra de progresso, categorias e cartões de conquistas
## desbloqueadas, bloqueadas e secretas. Fecha com "Voltar" ou Esc e rola por mouse, setas, PageUp/PageDown, Home e End.

signal fechado

const PASSO_ROLAGEM := 72

var _aberto: bool = false
var _foco_anterior: Control = null

@onready var _rot_resumo: Label = %RotuloResumo
@onready var _barra_progresso: ProgressBar = %BarraProgresso
@onready var _rolagem: ScrollContainer = %Rolagem
@onready var _conteudo: VBoxContainer = %Conteudo
@onready var _botao_voltar: Button = %BotaoVoltar


func _ready() -> void:
	visible = false
	UiKit.refs_ok(self, {
		"RotuloResumo": _rot_resumo, "BarraProgresso": _barra_progresso,
		"Rolagem": _rolagem, "Conteudo": _conteudo, "BotaoVoltar": _botao_voltar,
	})


func esta_aberto() -> bool:
	return _aberto


func abrir() -> void:
	if _aberto or _rolagem == null:
		return
	_foco_anterior = get_viewport().gui_get_focus_owner()
	_aberto = true
	visible = true
	_preencher()
	_rolagem.scroll_vertical = 0
	_botao_voltar.call_deferred("grab_focus")


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	visible = false
	if _foco_anterior != null and is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree() and _foco_anterior.focus_mode != Control.FOCUS_NONE:
		_foco_anterior.grab_focus()
	_foco_anterior = null
	fechado.emit()


func _preencher() -> void:
	UiKit.limpar_filhos(_conteudo)
	var feitas: int = SistemaConquistas.contagem()
	var tot: int = maxi(1, SistemaConquistas.total())
	var pct: int = int(round(float(feitas) * 100.0 / float(tot)))
	_rot_resumo.text = "%d de %d desbloqueadas (%d%%)" % [feitas, tot, pct]
	_barra_progresso.max_value = float(tot)
	_barra_progresso.value = float(feitas)

	for categoria in SistemaConquistas.CATEGORIAS:
		var rot_cat := Label.new()
		rot_cat.theme_type_variation = &"RotuloAcento13Mono"
		rot_cat.text = categoria.to_upper()
		_conteudo.add_child(rot_cat)
		for item in SistemaConquistas.catalogo():
			var d: Dictionary = item
			if str(d.get("categoria", "")) != categoria:
				continue
			_conteudo.add_child(_criar_cartao(d))


func _criar_cartao(d: Dictionary) -> PanelContainer:
	var id_c: String = str(d.get("id", ""))
	var desbl: bool = SistemaConquistas.esta_desbloqueada(id_c)
	var secreta: bool = bool(d.get("secreta", false))
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contraste: bool = bool(GerenciadorConfiguracoes.obter("alto_contraste"))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_width_left = 4 if desbl else 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	if contraste:
		sb.bg_color = Color(0.05, 0.05, 0.05, 1.0)
		sb.border_color = Color(1.0, 0.85, 0.0, 1.0) if desbl else Color(0.65, 0.65, 0.65, 1.0)
	elif desbl:
		sb.bg_color = Color(0.14, 0.12, 0.24, 0.92)
		sb.border_color = Color(0.98, 0.75, 0.14, 0.85)
	else:
		sb.bg_color = Color(0.08, 0.08, 0.14, 0.65)
		sb.border_color = Color(1.0, 1.0, 1.0, 0.10)
	painel.add_theme_stylebox_override("panel", sb)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)

	var ico := Label.new()
	ico.text = str(d.get("icone", "🏆")) if desbl else "🔒"
	ico.theme_type_variation = &"RotuloTitulo22"
	ico.custom_minimum_size = Vector2(36, 0)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not desbl:
		ico.modulate = Color(1, 1, 1, 0.45)
	linha.add_child(ico)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	linha.add_child(col)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 8)
	col.add_child(topo)

	var titulo := Label.new()
	titulo.theme_type_variation = &"Rotulo15"
	titulo.text = str(d.get("titulo", "")) if (desbl or not secreta) else "Conquista secreta"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if desbl and not contraste:
		titulo.add_theme_color_override("font_color", Color(0.99, 0.92, 0.56, 1.0))
	elif not desbl:
		titulo.modulate = Color(1, 1, 1, 0.68)
	topo.add_child(titulo)

	var selo := Label.new()
	selo.theme_type_variation = &"RotuloFraco11Mono"
	if desbl:
		var dt := SistemaConquistas.data_desbloqueio(id_c)
		selo.text = ("✓ " + dt.left(16)) if dt != "" else "✓ Desbloqueada"
		if not contraste:
			selo.add_theme_color_override("font_color", Color(0.30, 0.87, 0.50, 1.0))
	else:
		selo.text = "Bloqueada"
	topo.add_child(selo)

	var desc := Label.new()
	desc.theme_type_variation = &"RotuloFraco13"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(1, 0)
	desc.text = str(d.get("descricao", "")) if (desbl or not secreta) else "Continue explorando o HumaxOS para revelar esta conquista."
	col.add_child(desc)
	return painel


func _input(evento: InputEvent) -> void:
	if not _aberto:
		return
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
	elif evento.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_rolar(PASSO_ROLAGEM)
	elif evento.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_rolar(-PASSO_ROLAGEM)
	elif evento.is_action_pressed("ui_page_down", true):
		get_viewport().set_input_as_handled()
		_rolar(int(_rolagem.size.y * 0.9))
	elif evento.is_action_pressed("ui_page_up", true):
		get_viewport().set_input_as_handled()
		_rolar(-int(_rolagem.size.y * 0.9))
	elif evento.is_action_pressed("ui_home"):
		get_viewport().set_input_as_handled()
		_rolagem.scroll_vertical = 0
	elif evento.is_action_pressed("ui_end"):
		get_viewport().set_input_as_handled()
		_rolagem.scroll_vertical = int(_conteudo.size.y)


func _rolar(pixels: int) -> void:
	_rolagem.scroll_vertical = maxi(0, _rolagem.scroll_vertical + pixels)


func _ao_voltar() -> void:
	fechar()
