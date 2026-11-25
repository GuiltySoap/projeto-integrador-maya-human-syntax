class_name IconeAreaDeTrabalho
extends Button
## Atalho de aplicativo na área de trabalho. Mouse: duplo clique. Teclado: Enter/Espaço com o ícone focado.
## A estrutura (ícone + legenda) está em icone_area_de_trabalho.tscn; aqui entram só os dados do app e a entrada.

signal abrir_pedido(app_id: String)

var app_id: String = ""
var _info: Dictionary = {}
var _veio_do_mouse: bool = false
var _badge_texto: String = ""
var _badge_cor: Color = Color(0.92, 0.22, 0.34, 1.0)

@onready var _icone: IconeApp = %Icone
@onready var _rotulo: Label = %Rotulo


func _ready() -> void:
	if not UiKit.refs_ok(self, {"Icone": _icone, "Rotulo": _rotulo}):
		return
	_aplicar()


## Pode ser chamada antes ou depois de a cena entrar na árvore.
func configurar(info: Dictionary) -> void:
	_info = info
	app_id = str(info.get("id", ""))
	if is_node_ready():
		_aplicar()


## Selo de notificação ou ação pendente no canto superior direito do ícone. Texto vazio esconde o selo.
func definir_badge(texto: String, cor: Color = Color(0.92, 0.22, 0.34, 1.0)) -> void:
	if _badge_texto == texto and _badge_cor == cor:
		return
	_badge_texto = texto
	_badge_cor = cor
	_atualizar_dica()
	queue_redraw()


func _aplicar() -> void:
	if _info.is_empty():
		return
	var nome: String = str(_info.get("nome", app_id))
	_icone.configurar(_info)
	_rotulo.text = nome
	_atualizar_dica()


func _atualizar_dica() -> void:
	if _info.is_empty():
		return
	var nome: String = str(_info.get("nome", app_id))
	if _badge_texto != "":
		tooltip_text = "%s — novidade pendente (duplo clique ou Enter para abrir)" % nome
	else:
		tooltip_text = "%s (duplo clique ou Enter para abrir)" % nome


func _draw() -> void:
	if _badge_texto == "":
		return
	var raio: float = 11.0
	var centro := Vector2(size.x - 24.0, 18.0)
	draw_circle(centro, raio + 2.0, Color(0.05, 0.07, 0.12, 0.95))
	draw_circle(centro, raio, _badge_cor)
	if bool(GerenciadorConfiguracoes.obter("alto_contraste")):
		draw_arc(centro, raio + 1.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	var fonte: Font = get_theme_default_font()
	var tam: int = 12
	var larg: float = fonte.get_string_size(_badge_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(fonte, Vector2(centro.x - larg * 0.5, centro.y + float(tam) * 0.36), _badge_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color.WHITE)


# Conectado na cena: gui_input
func _ao_entrada(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
		_veio_do_mouse = true
		if evento.double_click:
			abrir_pedido.emit(app_id)


# Conectado na cena: pressed
func _ao_pressionado() -> void:
	if _veio_do_mouse:
		_veio_do_mouse = false
		return
	abrir_pedido.emit(app_id)
