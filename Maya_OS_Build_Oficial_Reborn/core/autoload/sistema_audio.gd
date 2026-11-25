extends Node
## Áudio do jogo. Se existir res://shared/assets/audio/<nome>.ogg|wav|mp3, o arquivo tem prioridade sobre o som procedural
## (o projeto traz os 9 efeitos principais em .wav e as trilhas bgm_dia_1..5.ogg em laço). Qualquer arquivo ausente ou
## inválido cai no som gerado em código (AudioStreamWAV), então o jogo também roda sem nenhum arquivo de áudio.
## Os barramentos BGM e SFX são criados em código quando não existem; falhas de áudio nunca interrompem o jogo.

const TAXA := 22050
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const PASTA_AUDIO := "res://shared/assets/audio/"
const TOTAL_PLAYERS_SFX := 6
const VOLUME_BGM_DB := -6.0
## As trilhas de arquivo não têm a versão "suave" do drone procedural: com "Reduzir ruído" ligado elas tocam mais baixo.
const VOLUME_BGM_SUAVE_DB := -12.0
## Cada segmento: f (Hz inicial), f2 (Hz final), d (s), v (0..1), tipo (seno|quadrada|serra|ruido)
const SONS := {
	"clique": [{"f": 880.0, "f2": 660.0, "d": 0.035, "v": 0.35, "tipo": "seno"}],
	"tecla": [{"f": 1400.0, "f2": 1100.0, "d": 0.02, "v": 0.2, "tipo": "seno"}],
	"abrir": [{"f": 420.0, "f2": 640.0, "d": 0.09, "v": 0.35, "tipo": "seno"}, {"f": 640.0, "f2": 880.0, "d": 0.08, "v": 0.3, "tipo": "seno"}],
	"fechar": [{"f": 640.0, "f2": 420.0, "d": 0.08, "v": 0.3, "tipo": "seno"}, {"f": 420.0, "f2": 260.0, "d": 0.08, "v": 0.25, "tipo": "seno"}],
	"minimizar": [{"f": 520.0, "f2": 300.0, "d": 0.08, "v": 0.25, "tipo": "seno"}],
	"notificacao": [{"f": 784.0, "f2": 784.0, "d": 0.09, "v": 0.35, "tipo": "seno"}, {"f": 1175.0, "f2": 1175.0, "d": 0.16, "v": 0.3, "tipo": "seno"}],
	"mensagem": [{"f": 988.0, "f2": 988.0, "d": 0.06, "v": 0.3, "tipo": "seno"}, {"f": 1319.0, "f2": 1319.0, "d": 0.1, "v": 0.28, "tipo": "seno"}],
	"erro": [{"f": 220.0, "f2": 180.0, "d": 0.14, "v": 0.35, "tipo": "quadrada"}, {"f": 180.0, "f2": 140.0, "d": 0.18, "v": 0.3, "tipo": "quadrada"}],
	"alerta": [{"f": 740.0, "f2": 740.0, "d": 0.12, "v": 0.3, "tipo": "serra"}, {"f": 554.0, "f2": 554.0, "d": 0.18, "v": 0.3, "tipo": "serra"}],
	"sucesso": [{"f": 523.0, "f2": 523.0, "d": 0.08, "v": 0.3, "tipo": "seno"}, {"f": 659.0, "f2": 659.0, "d": 0.08, "v": 0.3, "tipo": "seno"}, {"f": 784.0, "f2": 784.0, "d": 0.16, "v": 0.3, "tipo": "seno"}],
	"glitch": [{"f": 0.0, "f2": 0.0, "d": 0.07, "v": 0.3, "tipo": "ruido"}, {"f": 90.0, "f2": 60.0, "d": 0.09, "v": 0.3, "tipo": "quadrada"}],
	"boot": [{"f": 330.0, "f2": 330.0, "d": 0.18, "v": 0.3, "tipo": "seno"}, {"f": 494.0, "f2": 494.0, "d": 0.18, "v": 0.3, "tipo": "seno"}, {"f": 660.0, "f2": 660.0, "d": 0.34, "v": 0.3, "tipo": "seno"}],
	"final_bom": [{"f": 392.0, "f2": 392.0, "d": 0.2, "v": 0.3, "tipo": "seno"}, {"f": 523.0, "f2": 523.0, "d": 0.2, "v": 0.3, "tipo": "seno"}, {"f": 659.0, "f2": 659.0, "d": 0.2, "v": 0.3, "tipo": "seno"}, {"f": 784.0, "f2": 784.0, "d": 0.5, "v": 0.3, "tipo": "seno"}],
	"final_mau": [{"f": 220.0, "f2": 196.0, "d": 0.3, "v": 0.3, "tipo": "serra"}, {"f": 196.0, "f2": 147.0, "d": 0.5, "v": 0.3, "tipo": "serra"}],
	"voz_maya": [{"f": 620.0, "f2": 560.0, "d": 0.032, "v": 0.22, "tipo": "seno"}],
	"voz_bia": [{"f": 470.0, "f2": 510.0, "d": 0.030, "v": 0.22, "tipo": "seno"}],
	"voz_rafael": [{"f": 310.0, "f2": 270.0, "d": 0.034, "v": 0.20, "tipo": "seno"}],
	"voz_sistema": [{"f": 920.0, "f2": 720.0, "d": 0.020, "v": 0.16, "tipo": "seno"}],
}
## Drones de fundo por dia: frequências múltiplas de 0.25 Hz para o laço de 4 s ficar sem emenda.
const DRONES := {
	1: [110.0, 165.0, 220.0],
	2: [98.0, 147.0, 196.5],
	3: [87.5, 131.25, 88.0],
	4: [82.5, 123.75, 165.5],
	5: [73.5, 110.25, 74.0],
}

const CAMINHO_FAIXAS := "res://core/data/audio_faixas.json"
const FADE_PADRAO_S := 1.6
const VOLUME_MUDO_DB := -80.0
const BUSES_VALIDOS: PackedStringArray = ["BGM"]

var _bgm: AudioStreamPlayer
## Segundo player FIXO da trilha (criado uma vez no _ready): durante um crossfade um sai e o outro entra; depois eles trocam de papel.
## Nunca há mais de dois players de trilha, nem players órfãos: reiniciar uma cena não cria players novos.
var _bgm_alt: AudioStreamPlayer
var _tween_fade: Tween = null
var _faixa_atual: StringName = &""
var _offset_faixa_db: float = 0.0
var _faixas: Dictionary = {}       # id -> item do catálogo (core/data/audio_faixas.json)
var _eventos: Dictionary = {}      # evento narrativo -> id de faixa
var _faixas_finais: Dictionary = {} # id do final -> id de faixa
var _faixa_padrao: StringName = &"default"
var _fade_padrao: float = FADE_PADRAO_S
var _sfx: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _proximo: int = 0
var _dia_bgm: int = 0
var _bgm_de_arquivo: bool = false
var _habilitado: bool = true
var _rng_voz: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng_voz.randomize()
	_garantir_barramentos()
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	add_child(_bgm)
	_bgm_alt = AudioStreamPlayer.new()
	_bgm_alt.bus = BUS_BGM
	add_child(_bgm_alt)
	carregar_catalogo()
	for i in TOTAL_PLAYERS_SFX:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		# Os efeitos (cliques dos menus, avisos) continuam tocando com a árvore pausada; só a trilha (_bgm) pausa junto com o jogo.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx.append(p)
	aplicar_volumes()
	GerenciadorConfiguracoes.configuracao_alterada.connect(_ao_configuracao_alterada)


func _exit_tree() -> void:
	if GerenciadorConfiguracoes.configuracao_alterada.is_connected(_ao_configuracao_alterada):
		GerenciadorConfiguracoes.configuracao_alterada.disconnect(_ao_configuracao_alterada)


func tocar_sfx(nome: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _habilitado or _sfx.is_empty():
		return
	if (nome == "glitch") and bool(GerenciadorConfiguracoes.obter("reduzir_ruido")):
		return
	var stream := _obter_stream(nome)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx[_proximo]
	_proximo = (_proximo + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()


## Som curto e suave de diálogo/digitação diferenciado por personagem (respeita "reduzir ruído").
func tocar_voz(quem: String) -> void:
	if not _habilitado or _sfx.is_empty():
		return
	var som := "voz_maya"
	var base_db := -10.5
	var variacao := 0.06
	match quem:
		"bia", "ana":
			som = "voz_bia"
			base_db = -10.0
			variacao = 0.08
		"mae":
			som = "voz_bia"
			base_db = -10.5
			variacao = 0.05
		"marcos", "caio":
			som = "voz_rafael"
			base_db = -10.5
			variacao = 0.07
		"rafael", "rafael.m", "other":
			som = "voz_rafael"
			base_db = -11.0
			variacao = 0.05
		"sistema", "jogador":
			som = "voz_sistema"
			base_db = -13.5
			variacao = 0.04
	if bool(GerenciadorConfiguracoes.obter("reduzir_ruido")):
		base_db -= 6.0
	var pitch := 1.0 + _rng_voz.randf_range(-variacao, variacao)
	tocar_sfx(som, base_db, pitch)


func tocar_bgm(dia: int) -> void:
	if not _habilitado or _bgm == null:
		return
	var d := clampi(dia, 1, 5)
	var id_faixa := StringName("dia_%d" % d)
	if id_faixa == _faixa_atual and _bgm.playing:
		return
	_dia_bgm = d
	var stream: AudioStream = _carregar_arquivo("bgm_dia_%d" % d)
	_bgm_de_arquivo = stream != null
	if stream == null:
		stream = _drone(d)
	else:
		_definir_laco(stream, true)
	_offset_faixa_db = 0.0
	_trocar_faixa(stream, id_faixa, _volume_bgm_db(), 0.0 if _faixa_atual == &"" else FADE_PADRAO_S)


func parar_bgm() -> void:
	_dia_bgm = 0
	_faixa_atual = &""
	_offset_faixa_db = 0.0
	if _tween_fade != null and _tween_fade.is_valid():
		_tween_fade.kill()
	if _bgm != null:
		_bgm.stop()
	if _bgm_alt != null:
		_bgm_alt.stop()


# ------------------------------------------------------------------ trilhas dinâmicas (clímax e epílogos)
## Lê core/data/audio_faixas.json. Catálogo inválido não derruba o jogo: fica vazio (e as trilhas por Task continuam funcionando).
func carregar_catalogo(caminho: String = CAMINHO_FAIXAS) -> PackedStringArray:
	_faixas = {}
	_eventos = {}
	_faixas_finais = {}
	if not FileAccess.file_exists(caminho):
		return PackedStringArray(["catálogo de trilhas ausente: %s" % caminho])
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not (dados is Dictionary):
		return PackedStringArray(["catálogo de trilhas: JSON inválido"])
	var erros: PackedStringArray = validar_catalogo(dados as Dictionary)
	for e in erros:
		push_warning("SistemaAudio: " + e)
	var d: Dictionary = dados
	_faixa_padrao = StringName(str(d.get("faixa_padrao", "default")))
	_fade_padrao = maxf(0.0, float(d.get("fade_padrao_s", FADE_PADRAO_S)))
	for item in d.get("faixas", []):
		if item is Dictionary and str((item as Dictionary).get("id", "")) != "" and not _faixas.has(str((item as Dictionary)["id"])):
			_faixas[str((item as Dictionary)["id"])] = item
	for chave in (d.get("eventos", {}) as Dictionary):
		if _faixas.has(str((d["eventos"] as Dictionary)[chave])):
			_eventos[str(chave)] = str((d["eventos"] as Dictionary)[chave])
	for chave in (d.get("finais", {}) as Dictionary):
		if _faixas.has(str((d["finais"] as Dictionary)[chave])):
			_faixas_finais[str(chave)] = str((d["finais"] as Dictionary)[chave])
	return erros


## Valida o catálogo (função pura): ids únicos, volume, loop, barramento, fallbacks existentes e sem ciclo, eventos e finais apontando para faixas
## que existem. Arquivo de áudio ausente NÃO é erro (o fallback cobre); veja `arquivos_ausentes()`.
static func validar_catalogo(dados: Dictionary) -> PackedStringArray:
	var erros := PackedStringArray()
	var faixas: Variant = dados.get("faixas", [])
	if not (faixas is Array) or (faixas as Array).is_empty():
		erros.append("catálogo de trilhas sem 'faixas'")
		return erros
	var ids: Dictionary = {}
	for item in faixas:
		if not (item is Dictionary):
			erros.append("faixa inválida (não é objeto)")
			continue
		var f: Dictionary = item
		var id_f := str(f.get("id", ""))
		if id_f == "":
			erros.append("faixa sem id")
			continue
		if ids.has(id_f):
			erros.append("id de faixa repetido: %s" % id_f)
		ids[id_f] = f
		if str(f.get("arquivo", "")) == "":
			erros.append("faixa '%s' sem 'arquivo'" % id_f)
		var vol: float = float(f.get("volume_db", 0.0))
		if vol < -40.0 or vol > 6.0:
			erros.append("faixa '%s': volume_db fora de -40..6 (%s)" % [id_f, str(vol)])
		if f.has("loop") and typeof(f["loop"]) != TYPE_BOOL:
			erros.append("faixa '%s': 'loop' deve ser verdadeiro/falso" % id_f)
		if not (str(f.get("bus", "BGM")) in BUSES_VALIDOS):
			erros.append("faixa '%s': barramento desconhecido (%s)" % [id_f, str(f.get("bus"))])
	for id_f in ids:
		var atual: String = str(id_f)
		var visitados: Dictionary = {}
		while atual != "":
			if visitados.has(atual):
				erros.append("faixa '%s': fallback em ciclo" % id_f)
				break
			visitados[atual] = true
			var fb := str((ids[atual] as Dictionary).get("fallback", ""))
			if fb != "" and not ids.has(fb):
				erros.append("faixa '%s': fallback inexistente (%s)" % [atual, fb])
				break
			atual = fb
	for mapa in ["eventos", "finais"]:
		var m: Variant = dados.get(mapa, {})
		if m is Dictionary:
			for chave in (m as Dictionary):
				if not ids.has(str((m as Dictionary)[chave])):
					erros.append("%s: '%s' aponta para faixa inexistente (%s)" % [mapa, str(chave), str((m as Dictionary)[chave])])
	return erros


func faixas_catalogadas() -> PackedStringArray:
	return PackedStringArray(_faixas.keys())


func faixa_do_final(id_final: String) -> String:
	return str(_faixas_finais.get(id_final, ""))


func faixa_do_evento(evento: String) -> String:
	return str(_eventos.get(evento, ""))


## Ids de faixa cujo arquivo não existe em shared/assets/audio (cobertos pelo fallback; útil para avisar o desenvolvedor).
func arquivos_ausentes() -> PackedStringArray:
	var ausentes := PackedStringArray()
	for id_f in _faixas:
		if _carregar_arquivo(str((_faixas[id_f] as Dictionary).get("arquivo", ""))) == null:
			ausentes.append(str(id_f))
	return ausentes


## Segue a cadeia de fallback até achar um arquivo existente. Devolve {id, stream, item, fallback_usado} ou {} se nada existe.
func resolver_faixa(id_faixa: String) -> Dictionary:
	var atual: String = id_faixa
	var visitados: Dictionary = {}
	while atual != "" and _faixas.has(atual) and not visitados.has(atual):
		visitados[atual] = true
		var item: Dictionary = _faixas[atual]
		var stream: AudioStream = _carregar_arquivo(str(item.get("arquivo", "")))
		if stream != null:
			return {"id": atual, "stream": stream, "item": item, "fallback_usado": atual != id_faixa}
		atual = str(item.get("fallback", ""))
	return {}


## Toca uma faixa do catálogo com crossfade. Já tocando a mesma faixa = nada acontece (não reinicia). Devolve false se nem o fallback existe
## (a trilha atual continua).
func tocar_faixa(id_faixa: StringName, fade_s: float = -1.0) -> bool:
	if not _habilitado or _bgm == null:
		return false
	var r: Dictionary = resolver_faixa(str(id_faixa))
	if r.is_empty():
		return false
	var efetiva := StringName(str(r["id"]))
	if efetiva == _faixa_atual and (_bgm.playing or _bgm.stream_paused):
		return true
	var item: Dictionary = r["item"]
	var stream: AudioStream = r["stream"]
	_definir_laco(stream, bool(item.get("loop", true)))
	_dia_bgm = 0
	_bgm_de_arquivo = true
	_offset_faixa_db = float(item.get("volume_db", 0.0))
	var duracao: float = fade_s if fade_s >= 0.0 else float(item.get("fade_s", _fade_padrao))
	_trocar_faixa(stream, efetiva, _volume_bgm_db(), duracao if _faixa_atual != &"" else 0.0)
	return true


## Evento narrativo explícito (ex.: "climax_started", "task_9_started", "maya_control_escalated") -> faixa do catálogo.
func evento_narrativo(evento: StringName) -> bool:
	var id_faixa: String = faixa_do_evento(str(evento))
	return id_faixa != "" and tocar_faixa(StringName(id_faixa))


## Música do epílogo escolhida pelo resultado de `GerenciadorNarrativa.avaliar_final()`.
func tocar_musica_do_final(id_final: String) -> bool:
	var id_faixa: String = faixa_do_final(id_final)
	return id_faixa != "" and tocar_faixa(StringName(id_faixa))


func faixa_atual() -> StringName:
	return _faixa_atual


func crossfade_ativo() -> bool:
	return _tween_fade != null and _tween_fade.is_valid() and _tween_fade.is_running()


## Quantos players de trilha existem (sempre 2: o ativo e o reserva do crossfade).
func total_players_bgm() -> int:
	var n: int = 0
	for filho in get_children():
		if filho is AudioStreamPlayer and (filho as AudioStreamPlayer).bus == BUS_BGM:
			n += 1
	return n


## Quantos players de trilha estão tocando agora (0 ou 1 fora de um crossfade; 2 só durante a troca).
func players_bgm_tocando() -> int:
	var n: int = 0
	for filho in get_children():
		if filho is AudioStreamPlayer and (filho as AudioStreamPlayer).bus == BUS_BGM and (filho as AudioStreamPlayer).playing:
			n += 1
	return n


func volume_alvo_db() -> float:
	return _volume_bgm_db()


## Troca a trilha: o player reserva entra (fade-in) enquanto o ativo sai (fade-out) e para; depois trocam de papel. Sem sobreposição prolongada.
func _trocar_faixa(stream: AudioStream, id_faixa: StringName, volume_alvo: float, fade_s: float) -> void:
	if _tween_fade != null and _tween_fade.is_valid():
		_tween_fade.kill()
		_bgm_alt.stop()   # um crossfade anterior interrompido: o que estava saindo é descartado
	var saida: AudioStreamPlayer = _bgm
	var entrada: AudioStreamPlayer = _bgm_alt
	entrada.stream = stream
	entrada.stream_paused = saida.stream_paused
	var com_fade: bool = fade_s > 0.0 and saida.playing
	entrada.volume_db = VOLUME_MUDO_DB if com_fade else volume_alvo
	entrada.play()
	_bgm = entrada
	_bgm_alt = saida
	_faixa_atual = id_faixa
	if com_fade:
		_tween_fade = create_tween().set_parallel(true)
		_tween_fade.tween_property(entrada, "volume_db", volume_alvo, fade_s)
		_tween_fade.tween_property(saida, "volume_db", VOLUME_MUDO_DB, fade_s)
		_tween_fade.chain().tween_callback(saida.stop)
	else:
		saida.stop()


static func _definir_laco(stream: AudioStream, ligado: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = ligado
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = ligado
	elif stream is AudioStreamWAV and ligado:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED and wav.format == AudioStreamWAV.FORMAT_16_BITS:
			var quadros := int(float(wav.data.size()) / (4.0 if wav.stereo else 2.0))
			wav.loop_begin = 0
			wav.loop_end = quadros
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamWAV and not ligado:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


## Pausa temporariamente a trilha ambiente (ex.: quando o jogador ouve uma faixa no app Música).
func pausar_bgm_externo(pausar: bool) -> void:
	if _bgm == null:
		return
	_bgm.stream_paused = pausar


## Carrega uma trilha de áudio do projeto (ex.: "bgm_dia_1") para reprodução no app Música.
func stream_trilha(nome: String) -> AudioStream:
	return _carregar_arquivo(nome)


func _volume_bgm_db() -> float:
	if _bgm_de_arquivo and bool(GerenciadorConfiguracoes.obter("reduzir_ruido")):
		return VOLUME_BGM_SUAVE_DB + _offset_faixa_db
	return VOLUME_BGM_DB + _offset_faixa_db


## Garante o laço de uma trilha vinda de arquivo mesmo que a importação não tenha "Loop" marcado (.ogg/.mp3/.wav de 16 bits).
func _com_laco(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED and wav.format == AudioStreamWAV.FORMAT_16_BITS:
			var quadros := int(float(wav.data.size()) / (4.0 if wav.stereo else 2.0))
			wav.loop_begin = 0
			wav.loop_end = quadros
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


## Stream usado por apps (ex.: Galeria toca "gravacao_01"). Retorna null quando o id é desconhecido.
func stream_gravacao(id_audio: String) -> AudioStream:
	var arquivo := _carregar_arquivo(id_audio)
	if arquivo != null:
		return arquivo
	var chave := "rec_" + id_audio
	if _cache.has(chave):
		return _cache[chave]
	if id_audio != "gravacao_01":
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := int(3.0 * TAXA)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var passa_baixa := 0.0
	for i in n:
		var t := float(i) / float(TAXA)
		var ruido := rng.randf_range(-1.0, 1.0)
		passa_baixa = passa_baixa * 0.92 + ruido * 0.08
		var respiracao := 0.5 + 0.5 * sin(TAU * 0.6 * t)
		var tom := sin(TAU * 61.0 * t) * 0.25
		var v := (passa_baixa * 2.4 * respiracao + tom * 0.5) * 0.55
		dados.encode_s16(i * 2, clampi(int(v * 32767.0), -32768, 32767))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = TAXA
	st.stereo = false
	st.data = dados
	_cache[chave] = st
	return st


func aplicar_volumes() -> void:
	_definir_volume(BUS_MASTER, float(GerenciadorConfiguracoes.obter("volume_master")))
	_definir_volume(BUS_BGM, float(GerenciadorConfiguracoes.obter("volume_bgm")))
	_definir_volume(BUS_SFX, float(GerenciadorConfiguracoes.obter("volume_sfx")))


func _ao_configuracao_alterada(chave: String, _valor: Variant) -> void:
	if chave.begins_with("volume_"):
		aplicar_volumes()
	elif chave == "reduzir_ruido":
		_reaplicar_bgm()


## Aplica o ajuste "reduzir ruído" à trilha em andamento. Com o jogo pausado (o Menu de Pausa abre as Opções) a trilha está pausada, e um
## AudioStreamPlayer pausado deixa de contar como `playing`: sem esta checagem o ajuste só valeria na próxima troca de trilha.
func _reaplicar_bgm() -> void:
	if _bgm == null:
		return
	var pausada: bool = _bgm.stream_paused and _bgm.stream != null and _faixa_atual != &""
	if not _bgm.playing and not pausada:
		_dia_bgm = 0
		return
	if _bgm_de_arquivo:
		if not crossfade_ativo():
			_bgm.volume_db = _volume_bgm_db()
		return
	_dia_bgm = 0
	_faixa_atual = &""   # força a recriação do drone procedural com o ajuste novo
	tocar_bgm(clampi(ceili(GerenciadorEstado.etapa_atual / 2.0), 1, 5))
	if pausada:
		# A trilha nova nasce tocando. O jogo continua pausado: ela volta a ficar pausada até o jogo seguir (sem som durante a pausa).
		_bgm.stream_paused = false
		_bgm.stream_paused = true


func _definir_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _garantir_barramentos() -> void:
	for nome in [BUS_BGM, BUS_SFX]:
		if AudioServer.get_bus_index(nome) >= 0:
			continue
		AudioServer.add_bus(AudioServer.bus_count)
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, nome)
		AudioServer.set_bus_send(idx, BUS_MASTER)


func _obter_stream(nome: String) -> AudioStream:
	if _cache.has(nome):
		return _cache[nome]
	var stream: AudioStream = _carregar_arquivo(nome)
	if stream == null and SONS.has(nome):
		stream = _stream_de_segmentos(SONS[nome])
	if stream != null:
		_cache[nome] = stream
	return stream


func _carregar_arquivo(nome: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var caminho := "%s%s.%s" % [PASTA_AUDIO, nome, ext]
		if ResourceLoader.exists(caminho):
			var recurso: Resource = load(caminho)
			if recurso is AudioStream:
				return recurso
	return null


func _stream_de_segmentos(segmentos: Array) -> AudioStreamWAV:
	var total := 0
	for s in segmentos:
		total += int(float(s["d"]) * TAXA)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pos := 0
	var fase := 0.0
	for s in segmentos:
		var n := int(float(s["d"]) * TAXA)
		var f0 := float(s["f"])
		var f1 := float(s["f2"])
		var vol := float(s["v"])
		var tipo := str(s["tipo"])
		for i in n:
			var t := float(i) / float(maxi(n - 1, 1))
			fase += TAU * lerpf(f0, f1, t) / float(TAXA)
			var v := 0.0
			match tipo:
				"quadrada":
					v = 1.0 if sin(fase) >= 0.0 else -1.0
				"serra":
					v = fmod(fase / TAU, 1.0) * 2.0 - 1.0
				"ruido":
					v = rng.randf_range(-1.0, 1.0)
				_:
					v = sin(fase)
			var ataque := minf(1.0, float(i) / (0.004 * float(TAXA)))
			var envelope := ataque * (1.0 - t * 0.85)
			dados.encode_s16((pos + i) * 2, clampi(int(v * envelope * vol * 32767.0), -32768, 32767))
		pos += n
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = TAXA
	st.stereo = false
	st.data = dados
	return st


func _drone(dia: int) -> AudioStreamWAV:
	var chave := "drone_%d_%s" % [dia, str(bool(GerenciadorConfiguracoes.obter("reduzir_ruido")))]
	if _cache.has(chave):
		return _cache[chave]
	var freqs: Array = DRONES.get(dia, DRONES[1])
	var duracao := 4
	var n := duracao * TAXA
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var suave := bool(GerenciadorConfiguracoes.obter("reduzir_ruido"))
	var peso := 1.0 / float(freqs.size())
	for i in n:
		var t := float(i) / float(TAXA)
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t) * peso
		# Pulso lento (2 ciclos em 4 s) deixa o drone "respirando" sem emenda no laço.
		var lfo := 0.75 + 0.25 * sin(TAU * 0.5 * t)
		var rugosidade := 0.0
		if dia >= 4 and not suave:
			rugosidade = sin(TAU * 7.0 * t) * 0.12 * float(dia - 3)
		v = (v * lfo + rugosidade) * 0.35
		dados.encode_s16(i * 2, clampi(int(v * 32767.0), -32768, 32767))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = TAXA
	st.stereo = false
	st.data = dados
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	_cache[chave] = st
	return st
