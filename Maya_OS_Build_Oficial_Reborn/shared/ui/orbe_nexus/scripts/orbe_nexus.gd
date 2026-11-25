class_name OrbeNexus
extends Control
## Avatar animado da Maya (componente ÚNICO: Novo Jogo/boot, Painel da Maya, Menu Iniciar e Menu Principal instanciam esta mesma cena).
## Desenhado em código (animação procedural): brilho, anéis concêntricos, pulso, rotação e a reação a eventos (`reagir`).
## O nó e o tamanho mínimo estão em orbe_nexus.tscn; cada tela ajusta o tamanho e os parâmetros abaixo na instância (nada de cópias).
##
## Núcleo: o disco central OU o "M" oficial (`usar_marca`, Marca.MAYA_MARCA, o mesmo arquivo do Menu Principal e da saudação do Novo Jogo).
##
## Cor (prioridade, da mais forte para a mais fraca):
##   1. Acessibilidade: "reduzir animações" congela o desenho; "alto contraste" troca o brilho por disco escuro + contorno branco.
##   2. Estado narrativo explícito da IA (`estado` diferente de "amigavel": controladora, revelada, isolando, colapso): a paleta do estado vence.
##   3. Dependência (`reagir_a_dependencia`): no estado "amigavel" o roxo vai ficando mais quente/avermelhado de forma GRADUAL, usando a mesma
##      curva de `FeedbackDependencia.peso_de_tinta` (sem nova fonte de verdade; o valor vem de `GerenciadorEstado.dependencia_maya()` e do
##      sinal `dependencia_alterada`). Abaixo de 25 não há tinta; em 100 o tom é vermelho-carmim. Reversível quando a Dependência cai.
##   4. Cor padrão: roxo (#8b5cf6) com acento azul, a paleta de `cores_de("amigavel")`.
## O estado nunca é só cor: o "M", os anéis e o texto do painel continuam dizendo o estado.

## Troca o núcleo (o disco central) pelo "M" oficial da Maya, mantendo o brilho, os anéis e todas as animações.
## Sem o arquivo da marca, desenha um "M" técnico no lugar (placeholder; ver shared/assets/branding/LEIA-ME.md).
@export var usar_marca: bool = false:
	set(valor):
		usar_marca = valor
		if is_node_ready():
			_carregar_marca()
			queue_redraw()
## A cor acompanha a Dependência da Maya (só no estado "amigavel"). Desligado no Menu Principal/boot, que têm paleta neutra.
@export var reagir_a_dependencia: bool = false:
	set(valor):
		reagir_a_dependencia = valor
		if is_node_ready():
			_ligar_dependencia()
## Intensidade do brilho (0 = sem brilho; 1 = padrão; até 2).
@export_range(0.0, 2.0, 0.05) var intensidade_glow: float = 1.0:
	set(valor):
		intensidade_glow = clampf(valor, 0.0, 2.0)
		queue_redraw()
## Intensidade (opacidade) dos anéis (0 = sem anéis; 1 = padrão).
@export_range(0.0, 2.0, 0.05) var intensidade_aneis: float = 1.0:
	set(valor):
		intensidade_aneis = clampf(valor, 0.0, 2.0)
		queue_redraw()
## Multiplicador da espessura dos anéis. A espessura-base já escala com o tamanho do avatar.
@export_range(0.25, 3.0, 0.05) var espessura_aneis: float = 1.0:
	set(valor):
		espessura_aneis = clampf(valor, 0.25, 3.0)
		queue_redraw()
## Fração do espaço do "M" reservada como margem interna (0 = ocupa todo o núcleo; 0,3 = 30% menor).
@export_range(0.0, 0.5, 0.01) var margem_logo: float = 0.0:
	set(valor):
		margem_logo = clampf(valor, 0.0, 0.5)
		queue_redraw()
## Velocidade da animação (1 = padrão).
@export_range(0.1, 3.0, 0.05) var velocidade: float = 1.0
## Alerta: pulso um pouco mais rápido e brilho mais forte (não troca a cor: quem manda nela é o estado/Dependência).
@export var alerta: bool = false:
	set(valor):
		alerta = valor
		queue_redraw()

## Peso máximo da tinta quente (cor-alvo carmim) e velocidade com que a cor persegue a Dependência (1/s). Interpolação suave, sem saltos.
const ALVO_QUENTE := Color("#e11d48")
const PESO_MAX_TINTA := 0.6
const VELOCIDADE_COR := 1.6
## Tinta aplicada na própria arte do "M" (só clareia/esquenta um pouco; o desenho original continua legível).
const FORCA_TINTA_LOGO := 0.45

var estado: String = "amigavel"
var energia: float = 0.0
var _fase: float = 0.0
var _marca: Texture2D = null
var _dependencia: int = 0
var _peso_atual: float = 0.0
var _peso_alvo: float = 0.0
var _alto_contraste: bool = false
var _sem_flashes: bool = false


func _ready() -> void:
	_carregar_marca()
	_ler_acessibilidade()
	if not GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.connect(_ao_configuracao)
	_ligar_dependencia()
	set_process(GerenciadorConfiguracoes.animacoes_permitidas())


func _exit_tree() -> void:
	if GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao):
		GerenciadorConfiguracoes.configuracao_alterada.disconnect(_ao_configuracao)
	_desligar_dependencia()


## O núcleo mostra a marca oficial? (false = orbe procedural, ou placeholder quando faltar o arquivo)
func mostra_marca_oficial() -> bool:
	return usar_marca and _marca != null


func definir_estado(novo: String) -> void:
	estado = novo
	queue_redraw()


## Dá um "pulso" no orbe (mensagem recebida, evento, fala da IA). Com "sem flashes" o pulso é bem mais discreto.
func reagir(forca: float = 0.7) -> void:
	if not GerenciadorConfiguracoes.animacoes_permitidas():
		return
	energia = clampf(energia + forca * (0.4 if _sem_flashes else 1.0), 0.0, 1.0)
	set_process(true)


## Aplica um nível de Dependência (0 a 100) ao avatar. Normalmente vem do sinal; a chamada direta serve para testes e prévias.
## A cor caminha até o novo alvo aos poucos (ou muda direto quando as animações estão desligadas).
func definir_dependencia(valor: int) -> void:
	_dependencia = clampi(valor, 0, 100)
	_peso_alvo = _peso_para(_dependencia)
	if not GerenciadorConfiguracoes.animacoes_permitidas():
		_peso_atual = _peso_alvo
	else:
		set_process(true)
	queue_redraw()


## Nível de Dependência que o avatar está refletindo agora (0 a 100).
func dependencia_atual() -> int:
	return _dependencia


## Peso da tinta quente em uso agora (0 a 1; 0 = roxo puro). Usado pelos testes e pela prévia.
func peso_quente_atual() -> float:
	return _peso_atual


## Alto contraste ativo neste avatar?
func em_alto_contraste() -> bool:
	return _alto_contraste


## A cor principal que o avatar usa agora: a paleta do estado narrativo ou o roxo tingido pela Dependência.
func cor_principal_atual() -> Color:
	return _cores()[0]


## Um passo da interpolação da cor (separado de `_process` para os testes conferirem que a mudança é gradual).
func avancar_cor(delta: float) -> void:
	if is_equal_approx(_peso_atual, _peso_alvo):
		_peso_atual = _peso_alvo
		return
	_peso_atual = move_toward(_peso_atual, _peso_alvo, delta * VELOCIDADE_COR)


func _process(delta: float) -> void:
	_fase += delta * velocidade * (1.0 + energia * 3.0 + (0.6 if alerta else 0.0))
	energia = maxf(0.0, energia - delta * 1.2)
	avancar_cor(delta)
	queue_redraw()


func _carregar_marca() -> void:
	_marca = null
	if usar_marca:
		_marca = Marca.carregar(Marca.MAYA_MARCA)


func _ler_acessibilidade() -> void:
	_alto_contraste = bool(GerenciadorConfiguracoes.obter("alto_contraste"))
	_sem_flashes = bool(GerenciadorConfiguracoes.obter("sem_flashes"))


func _ao_configuracao(chave: String, _valor: Variant) -> void:
	if chave in ["alto_contraste", "sem_flashes", "reduzir_animacoes", "modo_conforto"]:
		_ler_acessibilidade()
		set_process(GerenciadorConfiguracoes.animacoes_permitidas())
		if not GerenciadorConfiguracoes.animacoes_permitidas():
			energia = 0.0
			_peso_atual = _peso_alvo
		queue_redraw()


## Liga (uma vez) o sinal da Dependência e já aplica o valor ATUAL, para o avatar nunca nascer ou voltar com um nível velho.
func _ligar_dependencia() -> void:
	if not reagir_a_dependencia:
		_desligar_dependencia()
		_dependencia = 0
		_peso_alvo = 0.0
		_peso_atual = 0.0
		queue_redraw()
		return
	if not GerenciadorEstado.dependencia_alterada.is_connected(_ao_dependencia_alterada):
		GerenciadorEstado.dependencia_alterada.connect(_ao_dependencia_alterada)
	_dependencia = GerenciadorEstado.dependencia_maya()
	_peso_alvo = _peso_para(_dependencia)
	_peso_atual = _peso_alvo   # entra na cena já na cor certa (sem "viajar" do roxo na abertura)
	queue_redraw()


func _desligar_dependencia() -> void:
	if GerenciadorEstado.dependencia_alterada.is_connected(_ao_dependencia_alterada):
		GerenciadorEstado.dependencia_alterada.disconnect(_ao_dependencia_alterada)


func _ao_dependencia_alterada(valor: int, _motivo: StringName) -> void:
	definir_dependencia(valor)


## Peso 0..1 da tinta quente para uma Dependência: a curva da interface inteira (FeedbackDependencia), normalizada pelo máximo dela.
static func _peso_para(dependencia: int) -> float:
	return clampf(FeedbackDependencia.peso_de_tinta(dependencia) / PESO_MAX_TINTA, 0.0, 1.0)


func _cores() -> Array:
	var cores: Array = cores_de(estado)
	if estado != "amigavel" or not reagir_a_dependencia or _peso_atual <= 0.0:
		return cores
	var principal: Color = cores[0]
	var secundaria: Color = cores[1]
	# o carmim entra pela metade na cor secundária: o brilho esquenta junto sem o azul sumir de repente
	return [principal.lerp(ALVO_QUENTE, _peso_atual * 0.9), secundaria.lerp(ALVO_QUENTE, _peso_atual * 0.45)]


## Par de cores [principal, secundária] de um estado da IA (também usado pelo WidgetMaya, que não desenha mais um orbe).
static func cores_de(estado_ia: String) -> Array:
	match estado_ia:
		"controladora":
			return [Color.html("#38bdf8"), Color.html("#818cf8")]
		"revelada":
			return [Color.html("#e11d48"), Color.html("#a855f7")]
		"isolando":
			return [Color.html("#ef4444"), Color.html("#f97316")]
		"colapso":
			return [Color.html("#22c55e"), Color.html("#ef4444")]
		_:
			return [Color.html("#8b5cf6"), Color.html("#38bdf8")]


func _draw() -> void:
	var c := size / 2.0
	var base := minf(size.x, size.y) * 0.5
	if base <= 1.0:
		return
	var pulso := 0.5 + 0.5 * sin(_fase * 2.0)
	var r := base * (0.50 + 0.04 * pulso + 0.10 * energia)
	var cores := _cores()
	var principal: Color = cores[0]
	var secundaria: Color = cores[1]
	# brilho: mais fraco em alto contraste (não pode reduzir a leitura do "M"); o alerta o reforça um pouco
	var glow: float = intensidade_glow * (0.25 if _alto_contraste else 1.0) * (1.25 if alerta else 1.0)
	draw_circle(c, base * 0.98, Color(principal.r, principal.g, principal.b, clampf((0.06 + 0.06 * energia) * glow, 0.0, 1.0)))
	draw_circle(c, base * 0.78, Color(principal.r, principal.g, principal.b, clampf(0.12 * glow, 0.0, 1.0)))
	if _alto_contraste:
		# alto contraste: disco escuro sólido atrás do núcleo + contorno branco, o "M" nunca depende do que está atrás
		draw_circle(c, r * 1.12, Color(0, 0, 0, 0.92))
		draw_arc(c, r * 1.12, 0.0, TAU, 48, Color(1, 1, 1, 1), maxf(1.5, base * 0.03), true)
	if usar_marca:
		_desenhar_marca(c, r, principal)
	else:
		draw_circle(c, r, Color(principal.r, principal.g, principal.b, 0.88))
		draw_circle(c - Vector2(r * 0.25, r * 0.30), r * 0.55, Color(secundaria.r, secundaria.g, secundaria.b, 0.55))
	# anéis: espessura proporcional ao tamanho (mesmos 2 px e 1,5 px de antes num avatar de 150 px; mais finos no compacto)
	var fino: float = clampf(base * 0.027, 1.0, 2.6) * espessura_aneis
	var a: float = intensidade_aneis
	draw_arc(c, r * 1.28, _fase, _fase + PI * 1.2, 48, Color(secundaria.r, secundaria.g, secundaria.b, clampf(0.9 * a, 0.0, 1.0)), fino, true)
	draw_arc(c, r * 1.42, -_fase * 0.7, -_fase * 0.7 + PI * 0.6, 32, Color(principal.r, principal.g, principal.b, clampf(0.6 * a, 0.0, 1.0)), fino * 0.75, true)
	if estado == "colapso" or estado == "isolando":
		var passo := floorf(_fase * 6.0)
		for i in 3:
			var y := c.y + (fmod(passo * 17.0 + float(i) * 41.0, base * 1.6) - base * 0.8)
			draw_rect(Rect2(c.x - base * 0.7, y, base * 1.4, 2.0), Color(secundaria.r, secundaria.g, secundaria.b, 0.35 * intensidade_aneis))


func _desenhar_marca(c: Vector2, r: float, cor: Color) -> void:
	var lado: float = r * 2.1 * (1.0 - margem_logo)
	if _marca != null:
		var t: Vector2 = _marca.get_size()
		var tam: Vector2 = t * (lado / maxf(t.x, t.y))
		# a arte oficial entra pura (branco = cores originais) e só esquenta um pouco junto com a Dependência
		var tinta: Color = Color.WHITE
		if not _alto_contraste and _peso_atual > 0.0:
			tinta = Color.WHITE.lerp(cor.lightened(0.35), _peso_atual * FORCA_TINTA_LOGO)
		draw_texture_rect(_marca, Rect2(c - tam / 2.0, tam), false, tinta)
		return
	var fonte: Font = get_theme_default_font()
	if fonte == null:
		return
	var tf: int = int(lado * 0.9)
	var larg: float = fonte.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
	draw_string(fonte, Vector2(c.x - larg / 2.0, c.y + tf * 0.33), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, tf, Color.WHITE if _alto_contraste else cor)
