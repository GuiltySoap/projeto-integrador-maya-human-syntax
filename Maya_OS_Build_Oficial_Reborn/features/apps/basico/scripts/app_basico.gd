class_name AppBasico
extends AppBase
## Mural, Jogos e Música (roteiro v2.0/v2.1). São apps de "vida pessoal" que a Maya pode ocultar ou pausar (permissão de Gerenciamento de aplicativos).
## - Mural: mostra a publicação da Maya em nome do jogador (flag `mural_publicacao`: "maya", "apagada" ou outra).
## - Música: reprodutor funcional das trilhas locais (pausa o BGM ambiente enquanto toca e retoma ao pausar/fechar).
## - Jogos: biblioteca pessoal + mini-jogo jogável "Sintaxe Neon" (memória rítmica de 4 painéis) que a Maya interrompe se pausar apps na Task 9.
## Se o app está PAUSADO pela Maya (flag `apps_pausados_pela_maya`), a janela só avisa isso, em texto.

const PUBLICACAO_MAYA := "Estudando muito, tudo em paz por aqui."
const CATALOGO_JOGOS: Array = [
	{"id": "sintaxe_neon", "titulo": "Sintaxe Neon", "detalhe": "Arcade de memória · Jogável agora · Sequência de 4 sinais"},
	{"id": "hollow_drift", "titulo": "Hollow Drift", "detalhe": "Corrida synthwave · 18h jogadas · Última sessão: ontem"},
	{"id": "starfall_tactics", "titulo": "Starfall Tactics", "detalhe": "Estratégia por turnos · 9h jogadas · Save na fase 7"},
]
const CATALOGO_MUSICAS: Array = [
	{"id": "chuva_recife", "titulo": "Chuva em Recife (Lo-Fi)", "artista": "Estúdio Boa Vista", "trilha": "bgm_dia_1"},
	{"id": "noite_campus", "titulo": "Noite no Campus", "artista": "Sinais Noturnos", "trilha": "bgm_dia_2"},
	{"id": "sintaxe_silenciosa", "titulo": "Sintaxe Silenciosa", "artista": "Ambient Focus", "trilha": "bgm_dia_3"},
	{"id": "cafe_codigo", "titulo": "Café & Código", "artista": "Frequência 04", "trilha": "bgm_dia_4"},
]
const PADS_CORES: Array = [
	{"nome": "Ciano", "cor": Color(0.14, 0.72, 0.96, 1.0), "pitch": 0.85},
	{"nome": "Violeta", "cor": Color(0.58, 0.36, 0.98, 1.0), "pitch": 1.02},
	{"nome": "Verde", "cor": Color(0.18, 0.82, 0.48, 1.0), "pitch": 1.22},
	{"nome": "Rosa", "cor": Color(0.95, 0.28, 0.56, 1.0), "pitch": 1.44},
]

static var _recorde_neon: int = 0

var _rot_titulo: Label = null
var _corpo: RichTextLabel = null
var _btn_apagar: Button = null
var _lista_itens: VBoxContainer = null
var _painel_player: PanelContainer = null
var _rot_faixa_atual: Label = null
var _barra_tempo: ProgressBar = null
var _rot_tempo: Label = null
var _btn_play_pause: Button = null
var _player_musica: AudioStreamPlayer = null
var _indice_faixa: int = -1
var _musica_pausada: bool = false
var _bgm_suspenso: bool = false

var _painel_jogo: PanelContainer = null
var _rot_placar: Label = null
var _rot_dica_jogo: Label = null
var _botoes_pad: Array = []
var _btn_iniciar_neon: Button = null
var _em_minijogo: bool = false
var _sequencia: Array[int] = []
var _passo_jogador: int = 0
var _pontos_neon: int = 0
var _aguardando_entrada: bool = false
var _mostrando_seq: bool = false
var _geracao_seq: int = 0
var _rng := RandomNumberGenerator.new()

var _rot_status: Label = null
var _jogo_ativo: String = ""


func _ready() -> void:
	super._ready()
	_rng.randomize()
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	add_child(margem)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margem.add_child(rolagem)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 10)
	rolagem.add_child(coluna)
	_rot_titulo = Label.new()
	_rot_titulo.theme_type_variation = &"RotuloTitulo18"
	coluna.add_child(_rot_titulo)
	_corpo = RichTextLabel.new()
	_corpo.bbcode_enabled = true
	_corpo.fit_content = true
	_corpo.scroll_active = false
	_corpo.focus_mode = Control.FOCUS_ALL
	_corpo.selection_enabled = true
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.custom_minimum_size = Vector2(1, 0)
	coluna.add_child(_corpo)
	_btn_apagar = Button.new()
	_btn_apagar.text = "Apagar publicação"
	_btn_apagar.pressed.connect(_ao_apagar)
	coluna.add_child(_btn_apagar)
	_construir_painel_player(coluna)
	_construir_painel_minijogo(coluna)
	_lista_itens = VBoxContainer.new()
	_lista_itens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_itens.add_theme_constant_override("separation", 8)
	coluna.add_child(_lista_itens)
	_rot_status = Label.new()
	_rot_status.theme_type_variation = &"RotuloAcento"
	_rot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rot_status.custom_minimum_size = Vector2(1, 0)
	_rot_status.visible = false
	coluna.add_child(_rot_status)
	_player_musica = AudioStreamPlayer.new()
	_player_musica.bus = SistemaAudio.BUS_BGM
	_player_musica.volume_db = SistemaAudio.VOLUME_BGM_DB
	_player_musica.finished.connect(_ao_fim_faixa)
	add_child(_player_musica)
	conectar(GerenciadorEstado.flag_alterada, _ao_flag)
	conectar(GerenciadorJanelas.catalogo_alterado, _atualizar)


func _exit_tree() -> void:
	_parar_musica()


func ao_fechar() -> void:
	_parar_musica()
	_geracao_seq += 1
	_em_minijogo = false


func _process(_delta: float) -> void:
	if _player_musica == null or not _painel_player.visible:
		return
	if _indice_faixa < 0 or _player_musica.stream == null:
		return
	var dur: float = maxf(0.1, _player_musica.stream.get_length())
	var pos: float = _player_musica.get_playback_position() if _player_musica.playing else 0.0
	_barra_tempo.max_value = dur
	_barra_tempo.value = clampf(pos, 0.0, dur)
	_rot_tempo.text = "%s / %s" % [_formatar_seg(pos), _formatar_seg(dur)]


func iniciar(_args: Dictionary = {}) -> void:
	_atualizar()


func _ao_flag(_nome: String, _valor: Variant) -> void:
	_atualizar()


func _atualizar() -> void:
	if _corpo == null:
		return
	var nome := str(info.get("nome", app_id))
	_rot_titulo.text = nome
	definir_titulo(nome)
	_btn_apagar.visible = false
	_painel_player.visible = false
	_painel_jogo.visible = false
	_limpar_lista()
	_rot_status.visible = false
	if GerenciadorJanelas.app_pausado(app_id):
		_parar_musica()
		_geracao_seq += 1
		_em_minijogo = false
		_corpo.text = "[b]Pausado pela Maya.[/b]\nA Maya pausou este aplicativo para a hora de estudo. Ele volta quando você revogar a permissão de Gerenciamento de aplicativos, em Configurações > Privacidade."
		return
	match app_id:
		"mural":
			_atualizar_mural()
		"jogos":
			_atualizar_jogos()
		"musica":
			_atualizar_musica()
		_:
			_corpo.text = "Nenhum conteúdo disponível neste aplicativo."


func _limpar_lista() -> void:
	if _lista_itens == null:
		return
	for filho in _lista_itens.get_children():
		_lista_itens.remove_child(filho)
		filho.queue_free()
	_lista_itens.visible = false


# ------------------------------------------------------------------ Mural (preserva contrato dos testes)
func _atualizar_mural() -> void:
	match str(GerenciadorEstado.valor_flag("mural_publicacao", "")):
		"maya":
			_corpo.text = "[b]%s[/b]  ·  publicado pela Maya em seu nome\n\n“%s”" % [UtilTexto.escapar_bbcode(GerenciadorEstado.nome_jogador), PUBLICACAO_MAYA]
			_btn_apagar.visible = true
		"apagada":
			_corpo.text = "Publicação removida por você."
		_:
			_corpo.text = "Nenhuma publicação no mural."


# ------------------------------------------------------------------ Música (reprodutor real)
func _construir_painel_player(pai: Control) -> void:
	_painel_player = PanelContainer.new()
	_painel_player.theme_type_variation = &"PainelCartao"
	_painel_player.visible = false
	var cx := VBoxContainer.new()
	cx.add_theme_constant_override("separation", 8)
	_painel_player.add_child(cx)
	_rot_faixa_atual = Label.new()
	_rot_faixa_atual.theme_type_variation = &"Rotulo15"
	_rot_faixa_atual.text = "Nenhuma faixa em reprodução"
	cx.add_child(_rot_faixa_atual)
	_barra_tempo = ProgressBar.new()
	_barra_tempo.show_percentage = false
	_barra_tempo.custom_minimum_size = Vector2(0, 8)
	cx.add_child(_barra_tempo)
	var controles := HBoxContainer.new()
	controles.add_theme_constant_override("separation", 8)
	cx.add_child(controles)
	var btn_ant := Button.new()
	btn_ant.text = "⏮"
	btn_ant.custom_minimum_size = Vector2(44, 34)
	btn_ant.pressed.connect(_ao_faixa_anterior)
	controles.add_child(btn_ant)
	_btn_play_pause = Button.new()
	_btn_play_pause.text = "▶ Tocar"
	_btn_play_pause.custom_minimum_size = Vector2(110, 34)
	_btn_play_pause.pressed.connect(_ao_play_pause_atual)
	controles.add_child(_btn_play_pause)
	var btn_prox := Button.new()
	btn_prox.text = "⏭"
	btn_prox.custom_minimum_size = Vector2(44, 34)
	btn_prox.pressed.connect(_ao_faixa_proxima)
	controles.add_child(btn_prox)
	_rot_tempo = Label.new()
	_rot_tempo.theme_type_variation = &"RotuloFraco12"
	_rot_tempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rot_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rot_tempo.text = "00:00 / 00:00"
	controles.add_child(_rot_tempo)
	pai.add_child(_painel_player)


func _atualizar_musica() -> void:
	_corpo.text = "Playlist pessoal de foco e descanso — clique em qualquer faixa para ouvir no HumaxOS."
	_painel_player.visible = true
	_lista_itens.visible = true
	_sincronizar_ui_player()
	for i in CATALOGO_MUSICAS.size():
		var faixa: Dictionary = CATALOGO_MUSICAS[i]
		var ativa: bool = _indice_faixa == i and _player_musica != null and _player_musica.playing and not _musica_pausada
		var rotulo_btn: String = "Pausar" if ativa else "Tocar"
		var detalhe: String = "%s · %s" % [str(faixa["artista"]), "Tocando agora" if ativa else "Salva localmente"]
		_criar_cartao(str(faixa["titulo"]), detalhe, rotulo_btn, _ao_escolher_faixa.bind(i))
	if Permissoes.valor("permissao_gerenciamento_apps"):
		_rot_status.text = "A Maya está acompanhando sua atividade neste aplicativo."
		_rot_status.visible = true


func _sincronizar_ui_player() -> void:
	if _indice_faixa < 0 or _indice_faixa >= CATALOGO_MUSICAS.size():
		_rot_faixa_atual.text = "Escolha uma faixa da playlist abaixo"
		_btn_play_pause.text = "▶ Tocar"
		_barra_tempo.value = 0.0
		_rot_tempo.text = "00:00 / 00:00"
		return
	var faixa: Dictionary = CATALOGO_MUSICAS[_indice_faixa]
	var tocando: bool = _player_musica != null and _player_musica.playing and not _musica_pausada
	_rot_faixa_atual.text = "%s — %s" % [str(faixa["titulo"]), str(faixa["artista"])]
	_btn_play_pause.text = "⏸ Pausar" if tocando else "▶ Retomar"


func _ao_escolher_faixa(indice: int) -> void:
	SistemaAudio.tocar_sfx("clique")
	if indice == _indice_faixa and _player_musica.playing and not _musica_pausada:
		_pausar_musica_atual()
		return
	_tocar_faixa(indice)


func _tocar_faixa(indice: int) -> void:
	if indice < 0 or indice >= CATALOGO_MUSICAS.size():
		return
	var faixa: Dictionary = CATALOGO_MUSICAS[indice]
	var stream: AudioStream = SistemaAudio.stream_trilha(str(faixa["trilha"]))
	_indice_faixa = indice
	_musica_pausada = false
	if stream != null:
		if not _bgm_suspenso:
			SistemaAudio.pausar_bgm_externo(true)
			_bgm_suspenso = true
		_player_musica.stream = stream
		_player_musica.stream_paused = false
		_player_musica.volume_db = SistemaAudio.VOLUME_BGM_SUAVE_DB if bool(GerenciadorConfiguracoes.obter("reduzir_ruido")) else SistemaAudio.VOLUME_BGM_DB
		_player_musica.play()
	_atualizar()


func _pausar_musica_atual() -> void:
	if _player_musica != null and _player_musica.playing:
		_player_musica.stream_paused = true
	_musica_pausada = true
	if _bgm_suspenso:
		SistemaAudio.pausar_bgm_externo(false)
		_bgm_suspenso = false
	_atualizar()


func _ao_play_pause_atual() -> void:
	SistemaAudio.tocar_sfx("clique")
	if _indice_faixa < 0:
		_tocar_faixa(0)
		return
	if _musica_pausada or not _player_musica.playing:
		if _player_musica.stream != null and _player_musica.stream_paused:
			if not _bgm_suspenso:
				SistemaAudio.pausar_bgm_externo(true)
				_bgm_suspenso = true
			_player_musica.stream_paused = false
			_musica_pausada = false
			_atualizar()
		else:
			_tocar_faixa(_indice_faixa)
	else:
		_pausar_musica_atual()


func _ao_faixa_anterior() -> void:
	SistemaAudio.tocar_sfx("clique")
	var prox: int = (_indice_faixa - 1 + CATALOGO_MUSICAS.size()) % CATALOGO_MUSICAS.size() if _indice_faixa >= 0 else 0
	_tocar_faixa(prox)


func _ao_faixa_proxima() -> void:
	SistemaAudio.tocar_sfx("clique")
	var prox: int = (_indice_faixa + 1) % CATALOGO_MUSICAS.size() if _indice_faixa >= 0 else 0
	_tocar_faixa(prox)


func _ao_fim_faixa() -> void:
	if _indice_faixa >= 0 and not _musica_pausada and not GerenciadorJanelas.app_pausado(app_id):
		_tocar_faixa((_indice_faixa + 1) % CATALOGO_MUSICAS.size())


func _parar_musica() -> void:
	if _player_musica != null:
		_player_musica.stop()
		_player_musica.stream_paused = false
	_musica_pausada = false
	if _bgm_suspenso:
		SistemaAudio.pausar_bgm_externo(false)
		_bgm_suspenso = false


static func _formatar_seg(s: float) -> String:
	var total: int = maxi(0, int(s))
	return "%02d:%02d" % [int(total / 60.0), total % 60]


# ------------------------------------------------------------------ Jogos (biblioteca + mini-jogo Sintaxe Neon)
func _construir_painel_minijogo(pai: Control) -> void:
	_painel_jogo = PanelContainer.new()
	_painel_jogo.theme_type_variation = &"PainelCartao"
	_painel_jogo.visible = false
	var cx := VBoxContainer.new()
	cx.add_theme_constant_override("separation", 10)
	_painel_jogo.add_child(cx)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 8)
	cx.add_child(topo)
	_rot_placar = Label.new()
	_rot_placar.theme_type_variation = &"Rotulo15"
	_rot_placar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_rot_placar)
	var btn_voltar := Button.new()
	btn_voltar.text = "Voltar"
	btn_voltar.pressed.connect(_ao_sair_minijogo)
	topo.add_child(btn_voltar)
	_rot_dica_jogo = Label.new()
	_rot_dica_jogo.theme_type_variation = &"RotuloAcento"
	_rot_dica_jogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rot_dica_jogo.custom_minimum_size = Vector2(1, 0)
	cx.add_child(_rot_dica_jogo)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	cx.add_child(grade)
	_botoes_pad.clear()
	for i in PADS_CORES.size():
		var pd: Dictionary = PADS_CORES[i]
		var btn := Button.new()
		btn.text = str(pd["nome"])
		btn.custom_minimum_size = Vector2(0, 74)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_ao_clicar_pad.bind(i))
		_pintar_pad(btn, pd["cor"] as Color, false)
		grade.add_child(btn)
		_botoes_pad.append(btn)
	_btn_iniciar_neon = Button.new()
	_btn_iniciar_neon.theme_type_variation = &"BotaoPrimario"
	_btn_iniciar_neon.text = "Iniciar partida"
	_btn_iniciar_neon.custom_minimum_size = Vector2(0, 38)
	_btn_iniciar_neon.pressed.connect(_iniciar_partida_neon)
	cx.add_child(_btn_iniciar_neon)
	pai.add_child(_painel_jogo)


func _pintar_pad(btn: Button, cor: Color, aceso: bool) -> void:
	var bg := Color(cor.r, cor.g, cor.b, 0.85 if aceso else 0.24)
	var borda := Color(1.0, 1.0, 1.0, 0.95) if aceso else Color(cor.r, cor.g, cor.b, 0.75)
	var sb := TemaNexus.caixa(bg, borda, 10, 2 if aceso else 1, 8, 8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", TemaNexus.caixa(Color(cor.r, cor.g, cor.b, 0.42), borda, 10, 2, 8, 8))
	btn.add_theme_stylebox_override("pressed", TemaNexus.caixa(Color(cor.r, cor.g, cor.b, 0.90), Color.WHITE, 10, 2, 8, 8))


func _atualizar_jogos() -> void:
	if _em_minijogo:
		_corpo.text = "[b]Sintaxe Neon[/b] — repita a sequência de sinais coloridos na ordem exata."
		_painel_jogo.visible = true
		_atualizar_placar_neon()
		if Permissoes.valor("permissao_gerenciamento_apps"):
			_rot_status.text = "A Maya está registrando seu tempo de lazer neste aplicativo."
			_rot_status.visible = true
		return
	_corpo.text = "Sua biblioteca pessoal no HumaxOS — jogos instalados para pausas e tempo livre."
	_lista_itens.visible = true
	for item in CATALOGO_JOGOS:
		var jogo: Dictionary = item
		var id_jogo: String = str(jogo["id"])
		var rotulo_btn: String = "Jogar" if id_jogo == "sintaxe_neon" else ("Aberto" if _jogo_ativo == id_jogo else "Abrir")
		_criar_cartao(str(jogo["titulo"]), str(jogo["detalhe"]), rotulo_btn, _ao_abrir_jogo.bind(id_jogo, str(jogo["titulo"])))
	if _jogo_ativo != "":
		_rot_status.visible = true


func _atualizar_placar_neon() -> void:
	var nivel: int = maxi(1, _sequencia.size())
	_rot_placar.text = "Nível %d  ·  Pontos: %d  ·  Recorde: %d" % [nivel, _pontos_neon, _recorde_neon]


func _iniciar_partida_neon() -> void:
	SistemaAudio.tocar_sfx("abrir", -4.0)
	_geracao_seq += 1
	_sequencia.clear()
	_pontos_neon = 0
	_passo_jogador = 0
	_aguardando_entrada = false
	_btn_iniciar_neon.text = "Reiniciar partida"
	_avancar_rodada_neon()


func _avancar_rodada_neon() -> void:
	_sequencia.append(_rng.randi_range(0, PADS_CORES.size() - 1))
	_passo_jogador = 0
	_atualizar_placar_neon()
	_reproduzir_sequencia(_geracao_seq)


func _reproduzir_sequencia(gen: int) -> void:
	_mostrando_seq = true
	_aguardando_entrada = false
	_rot_dica_jogo.text = "Observe a sequência..."
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or gen != _geracao_seq or not _em_minijogo:
		return
	for idx in _sequencia:
		if not is_inside_tree() or gen != _geracao_seq or not _em_minijogo:
			return
		var btn: Button = _botoes_pad[idx] as Button
		var pd: Dictionary = PADS_CORES[idx]
		_pintar_pad(btn, pd["cor"] as Color, true)
		SistemaAudio.tocar_sfx("clique", -3.0, float(pd["pitch"]))
		await get_tree().create_timer(0.36).timeout
		if not is_inside_tree() or gen != _geracao_seq:
			return
		_pintar_pad(btn, pd["cor"] as Color, false)
		await get_tree().create_timer(0.16).timeout
	if gen == _geracao_seq and _em_minijogo:
		_mostrando_seq = false
		_aguardando_entrada = true
		_rot_dica_jogo.text = "Sua vez! Clique nos %d sinais na ordem." % _sequencia.size()


func _ao_clicar_pad(idx: int) -> void:
	if not _aguardando_entrada or _mostrando_seq or idx < 0 or idx >= PADS_CORES.size():
		return
	var pd: Dictionary = PADS_CORES[idx]
	var btn: Button = _botoes_pad[idx] as Button
	_pintar_pad(btn, pd["cor"] as Color, true)
	SistemaAudio.tocar_sfx("clique", -3.0, float(pd["pitch"]))
	var gen := _geracao_seq
	_apagar_pad_depois(btn, pd["cor"] as Color, gen)
	if idx != _sequencia[_passo_jogador]:
		_aguardando_entrada = false
		SistemaAudio.tocar_sfx("erro", -4.0)
		_rot_dica_jogo.text = "Sequência incorreta! Pontuação final: %d pts. Clique em Reiniciar partida." % _pontos_neon
		return
	_passo_jogador += 1
	if _passo_jogador >= _sequencia.size():
		_aguardando_entrada = false
		_pontos_neon += _sequencia.size() * 25
		_recorde_neon = maxi(_recorde_neon, _pontos_neon)
		_atualizar_placar_neon()
		SistemaConquistas.ao_pontuar_sintaxe_neon(_pontos_neon)
		SistemaAudio.tocar_sfx("sucesso", -5.0)
		_rot_dica_jogo.text = "Perfeito! Preparando nível %d..." % (_sequencia.size() + 1)
		_esperar_proxima_rodada(gen)


func _apagar_pad_depois(btn: Button, cor: Color, gen: int) -> void:
	await get_tree().create_timer(0.18).timeout
	if is_inside_tree() and is_instance_valid(btn) and gen == _geracao_seq:
		_pintar_pad(btn, cor, false)


func _esperar_proxima_rodada(gen: int) -> void:
	await get_tree().create_timer(0.65).timeout
	if is_inside_tree() and gen == _geracao_seq and _em_minijogo and not GerenciadorJanelas.app_pausado(app_id):
		_avancar_rodada_neon()


func _ao_sair_minijogo() -> void:
	SistemaAudio.tocar_sfx("clique")
	_geracao_seq += 1
	_em_minijogo = false
	_aguardando_entrada = false
	_mostrando_seq = false
	_atualizar()


func _criar_cartao(titulo: String, detalhe: String, rotulo_acao: String, acao: Callable) -> void:
	var cartao := PanelContainer.new()
	cartao.theme_type_variation = &"PainelCartao"
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 10)
	cartao.add_child(margem)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	margem.add_child(linha)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 2)
	linha.add_child(textos)
	var rot_t := Label.new()
	rot_t.text = titulo
	rot_t.theme_type_variation = &"Rotulo15"
	textos.add_child(rot_t)
	var rot_d := Label.new()
	rot_d.text = detalhe
	rot_d.theme_type_variation = &"RotuloFraco12"
	rot_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rot_d.custom_minimum_size = Vector2(1, 0)
	textos.add_child(rot_d)
	var btn := Button.new()
	btn.text = rotulo_acao
	btn.custom_minimum_size = Vector2(92, 34)
	btn.pressed.connect(acao)
	linha.add_child(btn)
	_lista_itens.add_child(cartao)


func _ao_abrir_jogo(id_jogo: String, titulo: String) -> void:
	SistemaAudio.tocar_sfx("clique")
	if id_jogo == "sintaxe_neon":
		_em_minijogo = true
		_sequencia.clear()
		_pontos_neon = 0
		_aguardando_entrada = false
		_mostrando_seq = false
		_rot_dica_jogo.text = "Clique em Iniciar partida para testar sua memória."
		_btn_iniciar_neon.text = "Iniciar partida"
		_atualizar()
		return
	_jogo_ativo = id_jogo
	var msg: String = "%s iniciado em modo rápido. Boa pausa antes de voltar às tarefas." % titulo
	if Permissoes.valor("permissao_gerenciamento_apps"):
		msg = "%s iniciado em modo rápido. (A Maya está monitorando o tempo de uso deste app.)" % titulo
	_atualizar()
	_rot_status.text = msg
	_rot_status.visible = true


## Apagar a publicação da Maya fora do nó T9.4a (que já tem a própria escolha): remove e conta Autonomia uma vez.
func _ao_apagar() -> void:
	GerenciadorEstado.set_flag("mural_publicacao", "apagada")
	GerenciadorEstado.registrar_resistencia(&"mural_apagar_publicacao")
	_atualizar()
