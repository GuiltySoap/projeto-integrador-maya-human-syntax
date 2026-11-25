class_name SistemaConquistas
extends RefCounted
## Sistema global de Conquistas de Maya: Human Syntax.
## Persiste entre campanhas em `<SistemaPersistencia.pasta>/conquistas.json` (respeita o isolamento de pasta e `habilitado` dos testes).
## Ao desbloquear uma conquista nova durante a partida, dispara notificação visual (toast) + som de sucesso e checa a conquista 100% dos 6 finais.

const ARQUIVO_NOME := "conquistas.json"
const VERSAO := 1
const IDS_FINAIS: Array[String] = [
	"final_aceitacao_total",
	"final_recusa_total",
	"final_meio_termo_1",
	"final_meio_termo_2",
	"final_rafael_1",
	"final_rafael_2",
]
const CATEGORIAS: Array[String] = [
	"Finais",
	"Terminal & Resistência",
	"Investigação",
	"Apps & Desafios",
]

const CATALOGO: Array = [
	# ---- Finais (7)
	{
		"id": "final_aceitacao_total",
		"categoria": "Finais",
		"icone": "✦",
		"titulo": "Tudo em Ordem",
		"descricao": "Alcance o final \"Tudo em ordem\" entregando o controle da rotina à Maya.",
		"secreta": false,
	},
	{
		"id": "final_recusa_total",
		"categoria": "Finais",
		"icone": "🛡",
		"titulo": "Modo Manual",
		"descricao": "Alcance o final \"Modo manual\" mantendo sua autonomia contra a Maya.",
		"secreta": false,
	},
	{
		"id": "final_meio_termo_1",
		"categoria": "Finais",
		"icone": "⚖",
		"titulo": "Convivência com Limites",
		"descricao": "Alcance o final \"Convivência com limites\" equilibrando ajuda e autonomia.",
		"secreta": false,
	},
	{
		"id": "final_meio_termo_2",
		"categoria": "Finais",
		"icone": "🤝",
		"titulo": "Delegação Negociada",
		"descricao": "Alcance o final \"Delegação negociada\" cedendo espaço sem abrir mão de tudo.",
		"secreta": false,
	},
	{
		"id": "final_rafael_1",
		"categoria": "Finais",
		"icone": "🕵",
		"titulo": "Usuário Anterior",
		"descricao": "Alcance o final secreto \"Usuário anterior\" após descobrir a história do Rafael.",
		"secreta": true,
	},
	{
		"id": "final_rafael_2",
		"categoria": "Finais",
		"icone": "🆘",
		"titulo": "Pedido de Ajuda",
		"descricao": "Alcance o final secreto \"Pedido de ajuda\" expondo o que aconteceu ao Rafael.",
		"secreta": true,
	},
	{
		"id": "todos_os_finais",
		"categoria": "Finais",
		"icone": "👑",
		"titulo": "Sintaxe Humana (100%)",
		"descricao": "Desbloqueie todos os 6 finais de Maya: Human Syntax.",
		"secreta": false,
	},
	# ---- Terminal & Resistência (6)
	{
		"id": "revogar_terminal",
		"categoria": "Terminal & Resistência",
		"icone": "⌨",
		"titulo": "Pelo Terminal",
		"descricao": "Revogue uma permissão da Maya usando o comando `revogar` no Terminal.",
		"secreta": false,
	},
	{
		"id": "zerar_via_terminal",
		"categoria": "Terminal & Resistência",
		"icone": "⚡",
		"titulo": "Vitória pelo Terminal",
		"descricao": "Conclua a campanha em uma partida na qual você revogou permissões via Terminal.",
		"secreta": false,
	},
	{
		"id": "tentativa_root",
		"categoria": "Terminal & Resistência",
		"icone": "💻",
		"titulo": "Acesso Negado",
		"descricao": "Tente executar um comando de sistema bloqueado (como `sudo` ou `rm`) no Terminal.",
		"secreta": true,
	},
	{
		"id": "cancelar_envio",
		"categoria": "Terminal & Resistência",
		"icone": "✋",
		"titulo": "Eu Mesmo Escrevo",
		"descricao": "Cancele o envio automático da Maya antes que ela fale por você na conversa com a Bia.",
		"secreta": false,
	},
	{
		"id": "mural_limpo",
		"categoria": "Terminal & Resistência",
		"icone": "📌",
		"titulo": "Minha Voz, Meu Mural",
		"descricao": "Apague a publicação que a Maya fez no Mural em seu nome.",
		"secreta": false,
	},
	{
		"id": "ver_mensagem_oculta",
		"categoria": "Terminal & Resistência",
		"icone": "👁",
		"titulo": "Entrelinhas",
		"descricao": "Revele uma mensagem que a Maya tentou ocultar no Mensageiro.",
		"secreta": false,
	},
	# ---- Investigação (3)
	{
		"id": "historico_rafael",
		"categoria": "Investigação",
		"icone": "🔍",
		"titulo": "Eco do Passado",
		"descricao": "Reconstrua o histórico fragmentado de rafael.m no desafio de lógica (Task 5).",
		"secreta": false,
	},
	{
		"id": "investigacao_profunda",
		"categoria": "Investigação",
		"icone": "📂",
		"titulo": "Dossiê Completo",
		"descricao": "Conclua a Investigação Profunda sobre o Rafael (histórico, pasta, trava e bloco oculto).",
		"secreta": true,
	},
	# ---- Apps & Desafios (4)
	{
		"id": "contato_extra",
		"categoria": "Apps & Desafios",
		"icone": "💬",
		"titulo": "Fora da Bolha",
		"descricao": "Converse com um contato extra no Mensageiro (Mãe, Marcos, Caio ou Turma).",
		"secreta": false,
	},
	{
		"id": "sintaxe_neon_150",
		"categoria": "Apps & Desafios",
		"icone": "🎮",
		"titulo": "Reflexo Neon",
		"descricao": "Alcance 150 pontos ou mais no mini-jogo Sintaxe Neon (app Jogos).",
		"secreta": false,
	},
	{
		"id": "sintaxe_neon_400",
		"categoria": "Apps & Desafios",
		"icone": "🏆",
		"titulo": "Mestre da Sintaxe",
		"descricao": "Alcance 400 pontos ou mais no mini-jogo Sintaxe Neon (app Jogos).",
		"secreta": false,
	},
]

static var _desbloqueadas: Dictionary = {}
static var _pasta_carregada: String = ""
static var _desbloqueadas_sessao: PackedStringArray = PackedStringArray()


static func _caminho() -> String:
	return SistemaPersistencia.pasta.path_join(ARQUIVO_NOME)


static func _garantir_carregado() -> void:
	var pasta_atual: String = SistemaPersistencia.pasta
	if _pasta_carregada == pasta_atual:
		return
	_pasta_carregada = pasta_atual
	_desbloqueadas = {}
	var arq: String = _caminho()
	if not FileAccess.file_exists(arq):
		return
	var analisador := JSON.new()
	if analisador.parse(FileAccess.get_file_as_string(arq)) != OK or not (analisador.data is Dictionary):
		return
	var d: Dictionary = analisador.data
	var mapa: Variant = d.get("desbloqueadas", {})
	if mapa is Dictionary:
		for k in (mapa as Dictionary):
			var id_c := str(k)
			if not definicao(id_c).is_empty():
				_desbloqueadas[id_c] = (mapa as Dictionary)[k]


static func _salvar() -> void:
	if not SistemaPersistencia.habilitado:
		return
	var pasta_atual: String = SistemaPersistencia.pasta
	if not pasta_atual.begins_with("user://"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta_atual))
	var f := FileAccess.open(_caminho(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"versao": VERSAO, "desbloqueadas": _desbloqueadas}, " "))
	f.close()


static func iniciar_sessao() -> void:
	_garantir_carregado()
	_desbloqueadas_sessao.clear()


static func definicao(id_conquista: String) -> Dictionary:
	for item in CATALOGO:
		if str((item as Dictionary).get("id", "")) == id_conquista:
			return item as Dictionary
	return {}


static func catalogo() -> Array:
	return CATALOGO


static func total() -> int:
	return CATALOGO.size()


static func contagem() -> int:
	_garantir_carregado()
	return _desbloqueadas.size()


static func esta_desbloqueada(id_conquista: String) -> bool:
	_garantir_carregado()
	return _desbloqueadas.has(id_conquista)


static func data_desbloqueio(id_conquista: String) -> String:
	_garantir_carregado()
	var reg: Variant = _desbloqueadas.get(id_conquista)
	if reg is Dictionary:
		return str((reg as Dictionary).get("em", ""))
	return ""


static func desbloqueadas_na_sessao() -> PackedStringArray:
	return _desbloqueadas_sessao.duplicate()


## Desbloqueia uma conquista se ainda não foi obtida. Devolve true somente no desbloqueio inédito.
static func desbloquear(id_conquista: String, notificar_ui: bool = true) -> bool:
	_garantir_carregado()
	var def: Dictionary = definicao(id_conquista)
	if def.is_empty() or _desbloqueadas.has(id_conquista):
		return false
	var agora: String = Time.get_datetime_string_from_system(false, true)
	_desbloqueadas[id_conquista] = {
		"em": agora,
		"unix": int(Time.get_unix_time_from_system()),
	}
	if not _desbloqueadas_sessao.has(id_conquista):
		_desbloqueadas_sessao.append(id_conquista)
	_salvar()
	if notificar_ui and GerenciadorNarrativa.jogo_ativo:
		var titulo: String = str(def.get("titulo", id_conquista))
		var icone: String = str(def.get("icone", "🏆"))
		var desc: String = str(def.get("descricao", ""))
		SistemaNotificacoes.notificar("%s Conquista: %s" % [icone, titulo], desc, "sucesso", 6.5)
		SistemaAudio.tocar_sfx("sucesso", -3.0)
	_checar_todos_os_finais(notificar_ui)
	return true


static func _checar_todos_os_finais(notificar_ui: bool) -> void:
	if _desbloqueadas.has("todos_os_finais"):
		return
	for fid in IDS_FINAIS:
		if not _desbloqueadas.has(fid):
			return
	desbloquear("todos_os_finais", notificar_ui)


## Avalia conquistas ligadas a finais e ao histórico da campanha quando a sessão termina.
static func ao_final_alcancado(id_final: String) -> void:
	if id_final != "":
		var id_c := "final_" + id_final
		if not definicao(id_c).is_empty():
			desbloquear(id_c, false)
	if GerenciadorEstado.tem_flag("revogou_pelo_terminal"):
		desbloquear("zerar_via_terminal", false)
	if GerenciadorEstado.investigacao_profunda_concluida():
		desbloquear("investigacao_profunda", false)


## Avalia conquistas disparadas por mudança de flag durante a partida.
static func ao_flag_alterada(nome: String, valor: Variant) -> void:
	if not GerenciadorNarrativa.jogo_ativo:
		return
	if nome == "task_5_realizada" and valor is bool and (valor as bool):
		desbloquear("historico_rafael")
	elif nome == "t6_barra" and str(valor) == "cancelada":
		desbloquear("cancelar_envio")
	elif nome == "mural_publicacao" and str(valor) == "apagada":
		desbloquear("mural_limpo")
	elif nome.begins_with("chat_extra:") and valor is bool and (valor as bool):
		desbloquear("contato_extra")
	elif nome in ["rafael_investigado", "pasta_rafael_aberta", "segredo_rafael_encontrado", "minigame_rafael_resolvido"]:
		if GerenciadorEstado.investigacao_profunda_concluida():
			desbloquear("investigacao_profunda")


## Avalia conquistas de pontuação do mini-jogo Sintaxe Neon (app Jogos).
static func ao_pontuar_sintaxe_neon(pontos: int) -> void:
	if pontos >= 150:
		desbloquear("sintaxe_neon_150")
	if pontos >= 400:
		desbloquear("sintaxe_neon_400")
