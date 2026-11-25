class_name PapelDeParede
extends Control
## Papel de parede. No modo "dia" (imagem do catálogo) mostra o wallpaper escolhido em Configurações > Personalização, resolvido pelo catálogo
## central (core/data/wallpapers.json, classe Wallpapers): um id fixo ou "Automático" (sorteado ao abrir o jogo e mantido na sessão: Task, Estágio
## e Dependência NÃO trocam a imagem). Com o slideshow ligado, um único Timer (filho deste nó) troca a imagem a cada 60 s, em ordem sequencial ou
## aleatória, com transição suave (sem flash branco). Sem o arquivo, ou com "Alto contraste" ligado, volta ao desenho procedural com a paleta do dia.
## Modos (Configurações): "dia" (imagem do dia + grade; no fallback procedural: gradiente + grade + círculos + marca "HumaxOS"),
## "grade" (gradiente + grade discreta, nunca a imagem) e "preto". A imagem traz a própria composição, então círculos e marca
## d'água só existem no fallback. A imagem cobre a área sem deformar (corte centralizado): o projeto usa stretch "expand",
## então a janela pode ter qualquer proporção.
## O desenho é procedural (a paleta muda a cada dia), por isso fica em _draw; o nó e o layout estão em papel_de_parede.tscn.

## Distância entre as linhas da grade, em pixels.
@export_range(16.0, 256.0, 1.0) var passo_grade: float = 64.0

var _gradiente: GradientTexture2D
var _textura: Texture2D = null
var _textura_anterior: Texture2D = null
var _mistura: float = 1.0
var _tween_troca: Tween = null
var _timer_slideshow: Timer = null
var _id_exibido: String = ""
## Gerador usado no slideshow aleatório e no "Automático": injetável nos testes.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
const DURACAO_TRANSICAO_S := 1.2


func _ready() -> void:
	rng.randomize()
	_timer_slideshow = Timer.new()
	_timer_slideshow.name = "TimerSlideshow"
	_timer_slideshow.one_shot = false
	_timer_slideshow.autostart = false
	_timer_slideshow.wait_time = Wallpapers.intervalo_slideshow()
	_timer_slideshow.timeout.connect(_ao_tempo_do_slideshow)
	add_child(_timer_slideshow)
	if not GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.connect(_ao_configuracao)
	atualizar()
	_sincronizar_slideshow()


func _exit_tree() -> void:
	if GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.disconnect(_ao_configuracao)


## Wallpaper que está na tela (id do catálogo; "" se nenhum arquivo é válido e o fundo procedural está em uso).
func id_exibido() -> String:
	return _id_exibido


func slideshow_ativo() -> bool:
	return bool(GerenciadorConfiguracoes.obter("wallpaper_slideshow")) and str(GerenciadorConfiguracoes.obter("papel_de_parede")) == "dia"


## O Timer único do slideshow (um só por área de trabalho; nunca é recriado).
func timer_slideshow() -> Timer:
	return _timer_slideshow


## Troca agora para o próximo do slideshow (o Timer chama isto a cada 60 s). Devolve o id novo.
func avancar_slideshow() -> String:
	var proximo: String
	if str(GerenciadorConfiguracoes.obter("wallpaper_ordem")) == "aleatorio":
		proximo = Wallpapers.proximo_aleatorio(_id_exibido, rng)
	else:
		proximo = Wallpapers.proximo_sequencial(_id_exibido)
	_exibir(proximo)
	_gravar_indice()
	return _id_exibido


func _ao_tempo_do_slideshow() -> void:
	if slideshow_ativo():
		avancar_slideshow()


func _sincronizar_slideshow() -> void:
	if _timer_slideshow == null:
		return
	if slideshow_ativo():
		if _timer_slideshow.is_stopped():
			_timer_slideshow.start(Wallpapers.intervalo_slideshow())
	elif not _timer_slideshow.is_stopped():
		_timer_slideshow.stop()


func _ao_configuracao(chave: String, valor: Variant) -> void:
	match chave:
		"wallpaper_id":
			_id_exibido = Wallpapers.resolver(str(valor), rng)   # a escolha manual manda; o slideshow (se ligado) continua dela
			atualizar()
			if slideshow_ativo():
				_gravar_indice()
				_timer_slideshow.start(Wallpapers.intervalo_slideshow())
		"papel_de_parede":
			atualizar()
			_sincronizar_slideshow()
		"wallpaper_slideshow":
			if bool(valor):
				_gravar_indice()
			else:
				atualizar()   # volta ao wallpaper escolhido nas Configurações
			_sincronizar_slideshow()
		"reduzir_animacoes", "modo_conforto":
			if _tween_troca != null and _tween_troca.is_valid() and not GerenciadorConfiguracoes.animacoes_permitidas():
				_tween_troca.kill()
				_concluir_troca()


func _gravar_indice() -> void:
	GerenciadorConfiguracoes.definir("wallpaper_indice", maxi(0, Wallpapers.indice_de(_id_exibido)))


## Wallpaper que deve aparecer quando nada o troca: o do slideshow em andamento (mantido) ou o escolhido/automático.
func _id_desejado() -> String:
	if slideshow_ativo():
		if _id_exibido == "" or not Wallpapers.valido(_id_exibido):
			return Wallpapers.por_indice(int(GerenciadorConfiguracoes.obter("wallpaper_indice")))
		return _id_exibido
	return Wallpapers.resolver(str(GerenciadorConfiguracoes.obter("wallpaper_id")), rng)


func _carregar_textura(id_w: String) -> Texture2D:
	var item: Dictionary = Wallpapers.por_id(id_w)
	if item.is_empty():
		return null
	var caminho := str(item.get("recurso", ""))
	if not ResourceLoader.exists(caminho):
		return null
	var t: Resource = load(caminho)
	return t as Texture2D


## Exibe um wallpaper do catálogo; arquivo inválido -> tenta os seguintes; nenhum válido -> fundo procedural.
func _exibir(id_w: String) -> void:
	var tentativa: String = id_w
	var nova: Texture2D = null
	for _i in maxi(1, Wallpapers.disponiveis().size()):
		nova = _carregar_textura(tentativa)
		if nova != null:
			break
		tentativa = Wallpapers.proximo_sequencial(tentativa)
	_id_exibido = tentativa if nova != null else ""
	_trocar_textura(nova)


func atualizar() -> void:
	var p := TemaNexus.paleta()
	var topo: Color = p["fundo"]
	var meio: Color = p["painel"]
	var acento: Color = p["acento"]
	var g := Gradient.new()
	g.colors = PackedColorArray([topo, meio.lerp(acento, 0.16), topo])
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	_gradiente = GradientTexture2D.new()
	_gradiente.gradient = g
	_gradiente.fill = GradientTexture2D.FILL_LINEAR
	_gradiente.fill_from = Vector2(0.15, 0.0)
	_gradiente.fill_to = Vector2(0.85, 1.0)
	_gradiente.width = 256
	_gradiente.height = 256
	_exibir(_id_desejado())


## Troca a imagem com fusão suave (a anterior continua desenhada por baixo: nunca há quadro branco/preto no meio da troca).
func _trocar_textura(nova: Texture2D) -> void:
	var antiga: Texture2D = _textura
	_textura = nova
	if _tween_troca != null and _tween_troca.is_valid():
		_tween_troca.kill()
	if antiga != null and nova != null and antiga != nova and is_inside_tree() and GerenciadorConfiguracoes.animacoes_permitidas():
		_textura_anterior = antiga
		_mistura = 0.0
		_tween_troca = create_tween()
		_tween_troca.tween_method(_definir_mistura, 0.0, 1.0, DURACAO_TRANSICAO_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_troca.tween_callback(_concluir_troca)
	else:
		_textura_anterior = null
		_mistura = 1.0
	queue_redraw()


func _definir_mistura(valor: float) -> void:
	_mistura = clampf(valor, 0.0, 1.0)
	queue_redraw()


func _concluir_troca() -> void:
	_textura_anterior = null
	_mistura = 1.0
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## A imagem do dia só aparece no modo "dia" e sem alto contraste (que exige fundo liso para os ícones e legendas).
func _usa_imagem(modo: String) -> bool:
	return _textura != null and modo == "dia" and not bool(GerenciadorConfiguracoes.obter("alto_contraste"))


## Parte da imagem que cobre a área inteira sem deformar: corta o excedente, centralizado.
static func recorte_de_cobertura(tamanho_imagem: Vector2, tamanho_area: Vector2) -> Rect2:
	if tamanho_imagem.x <= 0.0 or tamanho_imagem.y <= 0.0 or tamanho_area.x <= 0.0 or tamanho_area.y <= 0.0:
		return Rect2(Vector2.ZERO, tamanho_imagem)
	var escala := maxf(tamanho_area.x / tamanho_imagem.x, tamanho_area.y / tamanho_imagem.y)
	var visivel := tamanho_area / escala
	return Rect2((tamanho_imagem - visivel) * 0.5, visivel)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var modo := str(GerenciadorConfiguracoes.obter("papel_de_parede"))
	if modo == "preto":
		draw_rect(area, Color.BLACK)
		return
	var p := TemaNexus.paleta()
	var acento: Color = p["acento"]
	var acento2: Color = p["acento2"]
	var com_imagem := _usa_imagem(modo)
	if com_imagem:
		if _textura_anterior != null and _mistura < 1.0:
			draw_texture_rect_region(_textura_anterior, area, recorte_de_cobertura(_textura_anterior.get_size(), size))
			draw_texture_rect_region(_textura, area, recorte_de_cobertura(_textura.get_size(), size), Color(1.0, 1.0, 1.0, _mistura))
		else:
			draw_texture_rect_region(_textura, area, recorte_de_cobertura(_textura.get_size(), size))
	elif _gradiente != null:
		draw_texture_rect(_gradiente, area, false)
	var passo: float = passo_grade
	var cor_grade := Color(acento.r, acento.g, acento.b, 0.06)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), cor_grade, 1.0)
		x += passo
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), cor_grade, 1.0)
		y += passo
	if modo == "grade" or com_imagem:
		return
	draw_circle(Vector2(size.x * 0.78, size.y * 0.32), size.y * 0.30, Color(acento.r, acento.g, acento.b, 0.07))
	draw_circle(Vector2(size.x * 0.22, size.y * 0.78), size.y * 0.24, Color(acento2.r, acento2.g, acento2.b, 0.06))
	var fonte := ThemeDB.fallback_font
	if fonte != null:
		var tamanho := int(size.y * 0.14)
		draw_string(fonte, Vector2(0, size.y * 0.58), "HumaxOS", HORIZONTAL_ALIGNMENT_CENTER, size.x, tamanho, Color(acento.r, acento.g, acento.b, 0.07))
