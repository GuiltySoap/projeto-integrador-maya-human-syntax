class_name EfeitoGlitch
extends Control
## Camada de efeitos de glitch e interferência visual da Maya sobre o HumaxOS. Acessibilidade:
## - "Reduzir glitch" / "Modo conforto" desligam completamente o efeito visual e os pulsos periódicos;
## - "Sem flashes" congela a animação (sem barras piscantes nem pulsos periódicos);
## - "Reduzir tremor" desliga o balanço das janelas.
##
## Escalada psicológica contínua:
##   Tasks 1–4: ambiente limpo (0.0);
##   Tasks 5–6: raros micro-glitches ocasionais quando surgem as primeiras inconsistências;
##   Tasks 7–8: interferência sutil de fundo + pulsos periódicos;
##   Task 9:    tensão alta com base contínua e pulsos mais frequentes enquanto a Maya resiste.

var _material: ShaderMaterial
var _alvo_tremor: Control = null
var _base: float = 0.0
var _extra: float = 0.0
var _pico: float = 0.0
var _duracao: float = 0.0
var _restante: float = 0.0
var _timer_ambiente: float = -1.0
var _tween_tremor: Tween
var _rng := RandomNumberGenerator.new()

@onready var _retangulo: ColorRect = %Retangulo


func _ready() -> void:
	_rng.randomize()
	if not UiKit.refs_ok(self, {"Retangulo": _retangulo}):
		return
	_material = _retangulo.material as ShaderMaterial
	if _material == null:
		push_error("EfeitoGlitch: o Retangulo precisa de um ShaderMaterial (veja efeito_glitch.tscn).")
		return
	set_process(false)
	atualizar_base()


func definir_alvo_tremor(alvo: Control) -> void:
	_alvo_tremor = alvo


## Efeito pontual (evento da narrativa, troca de fase ou interferência da Maya).
func disparar(intensidade: float, duracao: float, silencioso: bool = false) -> void:
	if not GerenciadorConfiguracoes.glitch_permitido():
		return
	var forca := clampf(intensidade, 0.0, 1.0)
	if bool(GerenciadorConfiguracoes.obter("sem_flashes")):
		forca = minf(forca, 0.25)
	_pico = maxf(forca, _extra)
	_extra = _pico
	_duracao = maxf(duracao, 0.2)
	_restante = maxf(_restante, _duracao)
	_aplicar()
	set_process(true)
	if silencioso:
		SistemaAudio.tocar_sfx("glitch", -12.0, _rng.randf_range(0.92, 1.12))
	else:
		SistemaAudio.tocar_sfx("glitch", -4.5, _rng.randf_range(0.95, 1.08))
		GerenciadorJanelas.glitch_nas_janelas(_duracao)
		_tremer(forca)


## Atualiza a interferência ambiente e o ritmo de micro-glitches conforme a Task atual (1..9).
func atualizar_base() -> void:
	if _material == null:
		return
	if not GerenciadorConfiguracoes.glitch_permitido():
		_base = 0.0
		_extra = 0.0
		_restante = 0.0
		_timer_ambiente = -1.0
		_aplicar()
		set_process(false)
		return
	var etapa: int = GerenciadorEstado.etapa_atual
	var sem_flashes: bool = bool(GerenciadorConfiguracoes.obter("sem_flashes"))
	if etapa >= 9:
		_base = 0.08 if sem_flashes else 0.14
	elif etapa >= 7:
		_base = 0.05 if sem_flashes else 0.07
	else:
		_base = 0.0
	# Dependência alta: interferência ambiente MUITO baixa (zero abaixo de 75), escalada pela intensidade das Configurações; sem flashes = metade.
	_base += FeedbackDependencia.interferencia_ambiente(GerenciadorEstado.dependencia_maya(), float(GerenciadorConfiguracoes.obter("intensidade_glitch"))) * (0.5 if sem_flashes else 1.0)
	if sem_flashes or etapa < 5:
		_timer_ambiente = -1.0
	else:
		_agendar_proximo_micro_glitch(etapa)
	_aplicar()
	set_process(_restante > 0.0 or _timer_ambiente >= 0.0)


func _agendar_proximo_micro_glitch(etapa: int) -> void:
	if etapa >= 9:
		_timer_ambiente = _rng.randf_range(5.5, 10.5)
	elif etapa >= 7:
		_timer_ambiente = _rng.randf_range(9.5, 16.0)
	elif etapa >= 5:
		_timer_ambiente = _rng.randf_range(14.0, 22.0)
	else:
		_timer_ambiente = -1.0


func _process(delta: float) -> void:
	if not GerenciadorConfiguracoes.glitch_permitido():
		atualizar_base()
		return
	if _restante > 0.0:
		_restante -= delta
		if _restante <= 0.0:
			_restante = 0.0
			_extra = 0.0
		else:
			_extra = _pico * clampf(_restante / _duracao, 0.0, 1.0)
	if _timer_ambiente >= 0.0 and GerenciadorNarrativa.jogo_ativo and not bool(GerenciadorConfiguracoes.obter("sem_flashes")):
		_timer_ambiente -= delta
		if _timer_ambiente <= 0.0:
			var etapa: int = GerenciadorEstado.etapa_atual
			if etapa >= 9:
				disparar(_rng.randf_range(0.42, 0.62), _rng.randf_range(0.28, 0.44), true)
			elif etapa >= 7:
				disparar(_rng.randf_range(0.30, 0.46), _rng.randf_range(0.22, 0.34), true)
			elif etapa >= 5:
				disparar(_rng.randf_range(0.22, 0.32), _rng.randf_range(0.18, 0.26), true)
			_agendar_proximo_micro_glitch(etapa)
	_aplicar()
	if _restante <= 0.0 and _timer_ambiente < 0.0:
		set_process(false)


func _aplicar() -> void:
	if _material == null:
		return
	var total := clampf(_base + _extra, 0.0, 1.0)
	_material.set_shader_parameter("intensidade", total)
	_material.set_shader_parameter("animar", 0.0 if bool(GerenciadorConfiguracoes.obter("sem_flashes")) else 1.0)
	_retangulo.visible = total > 0.001


func _tremer(forca: float) -> void:
	if _alvo_tremor == null or not GerenciadorConfiguracoes.tremor_permitido():
		return
	if _tween_tremor != null and _tween_tremor.is_valid():
		_tween_tremor.kill()
	var origem := _alvo_tremor.position
	var amplitude := 6.0 * forca
	_tween_tremor = create_tween()
	for dx in [1.0, -1.0, 0.6, -0.6, 0.0]:
		_tween_tremor.tween_property(_alvo_tremor, "position:x", origem.x + amplitude * float(dx), 0.045)
