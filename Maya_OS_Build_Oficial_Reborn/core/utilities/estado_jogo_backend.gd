class_name EstadoJogoBackend
extends RefCounted
## Contrato de arquivo entre o jogo (Godot) e o backend em C (§25/§26): `estado_jogo.json`.
##
## COMO O BACKEND É EXECUTADO: é uma FERRAMENTA AUXILIAR de linha de comando (backend/, compilada à parte com o Makefile), não um módulo, uma
## biblioteca nem uma extensão da Godot. O jogo NUNCA a executa (o projeto não executa programas externos: `make check-shell` confere). A integração é este
## ARQUIVO: a ferramenta (`maya_backend --choice <id>`) grava o estado e o jogo o lê e o valida; o jogo também grava o MESMO formato, e a
## ferramenta aceita o arquivo do jogo como ponto de partida. Os dois lados seguem as mesmas regras (backend/bk_estado.h).
##
## FORMATO (versão 1; todos os campos são obrigatórios na leitura, campos desconhecidos são ignorados):
##   { "schema_version": 1, "choice_id": "ok", "status": "ok",
##     "metrics": {"autonomia": 47, "conformidade": 52, "dependencia": 4},
##     "timestamp": "2026-11-17T21:00:00Z", "is_placeholder": false }
##   - choice_id: "" (nenhuma escolha aplicada) ou 1 a 48 caracteres, letra minúscula e depois [a-z0-9_].
##   - status: 1 a 32 caracteres [a-z_].   - metrics: números finitos de 0 a 100 (as mesmas métricas AUT/CON/DEP do jogo).
##   - timestamp: UTC, "YYYY-MM-DDTHH:MM:SSZ".   - is_placeholder: a escolha ainda usa texto/narrativa provisórios.
##
## FORMATO v2 (Roteiro v2.1, `schema_version` 2): o estado da campanha como o backend o enxerga: D (`dependencia_maya`), A (`autonomia_jogador`), as
## cinco permissões, `task_atual` numérico (1..9; 10 = AV), `final` (NENHUM ou um dos seis ids do C), `genero`, `rafael_investigacao_profunda` e as
## `flags` (booleanas, números e enumerações numéricas como `entrega_modo`). `criar_v21` lê tudo dos serviços do jogo (a investigação profunda e o final
## NÃO são recalculados aqui). Cada opção do roteiro com `id_backend` liga a escolha ao id canônico da matriz do C (`registrar_escolha_v21`). O formato
## v1 continua aceito na leitura (arquivos antigos).
##
## ONDE: `user://nexus_os/estado_jogo.json`, junto do salvamento e SEPARADO dele e das configurações (outro arquivo, outro esquema). Nunca em
## res:// (somente leitura numa build distribuída): gravar em res:// é recusado sempre. Caminhos absolutos fora de user:// só com
## `permitir_absoluto` (testes e ferramentas de desenvolvimento).
##
## GRAVAÇÃO: validada ANTES (nunca escreve um estado fora do esquema), em UTF-8, com .tmp conferido por releitura e depois renomeado por cima
## do destino; o arquivo anterior vira `.bak` durante a troca, então uma falha no meio (energia, disco cheio, o renomear por cima falha no
## Windows) deixa o último estado bom recuperável: `ler()` cai para o `.bak` quando o principal falta ou está inválido. O jogo não apaga
## arquivos: um .tmp de gravação que falhou fica até a próxima gravação o sobrescrever.
##
## PONTE OPCIONAL: `usar_backend_json` (Configurações, desligada por padrão) liga a gravação automática depois de cada escolha do Mensageiro
## (`registrar_escolha`). Aplicar o conteúdo do arquivo às métricas do jogo (`aplicar_ao_jogo`) é sempre uma chamada EXPLÍCITA: o arquivo
## nunca sobrescreve o progresso do jogador sozinho, e as métricas só mudam pelo GerenciadorEstado (a regra central, com os limites).

const VERSAO_ESQUEMA := 1
const VERSAO_ESQUEMA_V21 := 2
const ROTEIRO_VERSAO_V21 := "2.1"
const NOME_ARQUIVO := "estado_jogo.json"
const CAMINHO := "user://nexus_os/estado_jogo.json"
const TAMANHO_MAX_BYTES := 1048576
const ID_MAX := 48
const STATUS_MAX := 32
const STATUS_INICIAL := "inicial"
const STATUS_OK := "ok"
const METRICA_MIN := 0.0
const METRICA_MAX := 100.0
const METRICAS: PackedStringArray = ["autonomia", "conformidade", "dependencia"]
const SUFIXO_TEMP := ".tmp"
const SUFIXO_BACKUP := ".bak"

## Onde o jogo lê e grava quando nenhum caminho é passado. Só os testes mudam isto (para não tocar no arquivo real do jogador); restaure depois.
static var caminho_ativo: String = CAMINHO


static func _caminho(caminho: String) -> String:
	return caminho_ativo if caminho == "" else caminho


# ------------------------------------------------------------------ validações pontuais (as mesmas regras do backend em C)
## 1 a 48 caracteres, letra minúscula e depois [a-z0-9_]. Texto vazio NÃO é um id válido (use "" só como "nenhuma escolha" no estado).
static func id_valido(id: Variant) -> bool:
	if typeof(id) != TYPE_STRING:
		return false
	var texto: String = id
	if texto.length() == 0 or texto.length() > ID_MAX:
		return false
	for i in texto.length():
		var c: int = texto.unicode_at(i)
		var minuscula: bool = c >= 97 and c <= 122
		var digito: bool = c >= 48 and c <= 57
		if i == 0 and not minuscula:
			return false
		if not (minuscula or digito or c == 95):
			return false
	return true


## 1 a 32 caracteres [a-z_].
static func status_valido(status: Variant) -> bool:
	if typeof(status) != TYPE_STRING:
		return false
	var texto: String = status
	if texto.length() == 0 or texto.length() > STATUS_MAX:
		return false
	for i in texto.length():
		var c: int = texto.unicode_at(i)
		if not ((c >= 97 and c <= 122) or c == 95):
			return false
	return true


## "YYYY-MM-DDTHH:MM:SSZ" com campos numericamente plausíveis (mesma regra do backend).
static func timestamp_valido(carimbo: Variant) -> bool:
	if typeof(carimbo) != TYPE_STRING:
		return false
	var t: String = carimbo
	if t.length() != 20:
		return false
	if t[4] != "-" or t[7] != "-" or t[10] != "T" or t[13] != ":" or t[16] != ":" or t[19] != "Z":
		return false
	for faixa in [[0, 4], [5, 2], [8, 2], [11, 2], [14, 2], [17, 2]]:
		var ini: int = faixa[0]
		for i in range(ini, ini + int(faixa[1])):
			var c: int = t.unicode_at(i)
			if c < 48 or c > 57:
				return false
	var mes: int = int(t.substr(5, 2))
	var dia: int = int(t.substr(8, 2))
	var hora: int = int(t.substr(11, 2))
	var minuto: int = int(t.substr(14, 2))
	var segundo: int = int(t.substr(17, 2))
	return mes >= 1 and mes <= 12 and dia >= 1 and dia <= 31 and hora <= 23 and minuto <= 59 and segundo <= 60


## Agora, em UTC, no formato do arquivo.
static func timestamp_agora() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func _numero_de_metrica(valor: Variant) -> bool:
	if typeof(valor) != TYPE_INT and typeof(valor) != TYPE_FLOAT:
		return false
	var v: float = float(valor)
	return not is_nan(v) and not is_inf(v) and v >= METRICA_MIN and v <= METRICA_MAX


# ------------------------------------------------------------------ montar, validar, serializar
## Monta um estado válido: métricas travadas em 0..100 (valor inválido vira o inicial da métrica), arredondadas a 2 casas como no backend.
## `metricas` pode trazer só algumas métricas; as que faltarem usam o valor inicial do jogo (Metricas.inicial).
static func criar(choice_id: String, status: String, metricas: Dictionary, is_placeholder: bool, carimbo: String = "") -> Dictionary:
	var saida_metricas: Dictionary = {}
	for nome in METRICAS:
		var bruto: Variant = metricas.get(nome, Metricas.inicial(nome))
		var valor: float = Metricas.inicial(nome)
		if typeof(bruto) == TYPE_INT or typeof(bruto) == TYPE_FLOAT:
			var f: float = float(bruto)
			if not is_nan(f) and not is_inf(f):
				valor = f
		saida_metricas[nome] = snappedf(clampf(valor, METRICA_MIN, METRICA_MAX), 0.01)
	return {
		"schema_version": VERSAO_ESQUEMA,
		"choice_id": choice_id,
		"status": status,
		"metrics": saida_metricas,
		"timestamp": carimbo if carimbo != "" else timestamp_agora(),
		"is_placeholder": is_placeholder,
	}


## Valida um estado já interpretado. Devolve {ok, erros: Array[String], estado: Dictionary}; `estado` só tem os campos conhecidos,
## na ordem do arquivo, e só é preenchido quando ok. Cada erro diz o campo e o motivo.
static func validar(dados: Variant) -> Dictionary:
	var erros: Array = []
	if not (dados is Dictionary):
		return {"ok": false, "erros": ["a raiz do JSON deve ser um objeto"], "estado": {}}
	var d: Dictionary = dados
	var versao: Variant = d.get("schema_version")
	if (typeof(versao) == TYPE_INT or typeof(versao) == TYPE_FLOAT) and float(versao) == float(VERSAO_ESQUEMA_V21):
		return _validar_v21(d)
	if (typeof(versao) != TYPE_INT and typeof(versao) != TYPE_FLOAT) or float(versao) != float(VERSAO_ESQUEMA):
		erros.append("schema_version ausente ou diferente de %d/%d" % [VERSAO_ESQUEMA, VERSAO_ESQUEMA_V21])
	var escolha: Variant = d.get("choice_id")
	if typeof(escolha) != TYPE_STRING:
		erros.append("choice_id ausente ou não textual")
	elif String(escolha) != "" and not id_valido(escolha):
		erros.append("choice_id inválido (1 a %d caracteres: letra minúscula e depois [a-z0-9_])" % ID_MAX)
	var situacao: Variant = d.get("status")
	if not status_valido(situacao):
		erros.append("status ausente ou inválido (1 a %d caracteres [a-z_])" % STATUS_MAX)
	var metricas: Variant = d.get("metrics")
	if not (metricas is Dictionary):
		erros.append("metrics ausente ou não é um objeto")
	else:
		for nome in METRICAS:
			if not _numero_de_metrica((metricas as Dictionary).get(nome)):
				erros.append("metrics.%s ausente, não numérica ou fora de 0..100" % nome)
	var carimbo: Variant = d.get("timestamp")
	if typeof(carimbo) != TYPE_STRING:
		erros.append("timestamp ausente ou não textual")
	elif String(carimbo) != "" and not timestamp_valido(carimbo):
		erros.append("timestamp inválido (esperado YYYY-MM-DDTHH:MM:SSZ)")
	var provisorio: Variant = d.get("is_placeholder")
	if typeof(provisorio) != TYPE_BOOL:
		erros.append("is_placeholder ausente ou não booleano")
	if not erros.is_empty():
		return {"ok": false, "erros": erros, "estado": {}}
	var m: Dictionary = metricas
	var estado: Dictionary = {
		"schema_version": VERSAO_ESQUEMA,
		"choice_id": String(escolha),
		"status": String(situacao),
		"metrics": {"autonomia": float(m["autonomia"]), "conformidade": float(m["conformidade"]), "dependencia": float(m["dependencia"])},
		"timestamp": String(carimbo),
		"is_placeholder": bool(provisorio),
	}
	return {"ok": true, "erros": [], "estado": estado}


static func _validar_v21(d: Dictionary) -> Dictionary:
	var erros: Array = []
	var escolha: Variant = d.get("choice_id", "")
	if typeof(escolha) != TYPE_STRING:
		erros.append("choice_id não textual")
	elif String(escolha) != "" and not id_valido(escolha):
		erros.append("choice_id inválido")
	var situacao: Variant = d.get("status", STATUS_OK)
	if not status_valido(situacao):
		erros.append("status inválido")
	var carimbo: Variant = d.get("timestamp", "")
	if typeof(carimbo) != TYPE_STRING:
		erros.append("timestamp não textual")
	elif String(carimbo) != "" and not timestamp_valido(carimbo):
		erros.append("timestamp inválido")
	var dep: Variant = d.get("dependencia_maya")
	if not _numero_de_metrica(dep):
		erros.append("dependencia_maya ausente ou fora de 0..100")
	var aut: Variant = d.get("autonomia_jogador")
	if (typeof(aut) != TYPE_INT and typeof(aut) != TYPE_FLOAT) or float(aut) < 0.0 or is_nan(float(aut)) or is_inf(float(aut)):
		erros.append("autonomia_jogador ausente ou negativo")
	var perms_raw: Variant = d.get("permissoes")
	if not (perms_raw is Dictionary):
		erros.append("permissoes ausente ou não é um objeto")
	if not erros.is_empty():
		return {"ok": false, "erros": erros, "estado": {}}
	var perms_in: Dictionary = perms_raw
	var perms_out: Dictionary = {}
	var ativas: int = 0
	for p in GerenciadorEstado.PERMISSOES_V2:
		var v: bool = bool(perms_in.get(p, false))
		perms_out[p] = v
		if v:
			ativas += 1
	var flags_in: Dictionary = d.get("flags", {}) if d.get("flags") is Dictionary else {}
	var estado: Dictionary = {
		"schema_version": VERSAO_ESQUEMA_V21,
		"roteiro_versao": str(d.get("roteiro_versao", ROTEIRO_VERSAO_V21)),
		"choice_id": String(escolha),
		"status": String(situacao),
		"timestamp": String(carimbo),
		"nome_usuario": str(d.get("nome_usuario", "Usuario")),
		"genero": "feminino" if str(d.get("genero", "masculino")) == "feminino" else "masculino",
		"tempo_estendido": bool(d.get("tempo_estendido", false)),
		"dependencia_maya": int(clampi(int(dep), 0, 100)),
		"autonomia_jogador": maxi(0, int(aut)),
		"task_atual": maxi(1, int(d.get("task_atual", 1))),
		"permissoes_ativas": ativas,
		"rafael_investigacao_profunda": bool(d.get("rafael_investigacao_profunda", false)),
		"final": str(d.get("final", "NENHUM")),
		"permissoes": perms_out,
		"flags": flags_in.duplicate(true),
	}
	return {"ok": true, "erros": [], "estado": estado}


## O texto do arquivo: JSON com tabulações, UTF-8 (a Godot grava texto em UTF-8), quebra de linha final e números inteiros sem ".0".
static func serializar(estado: Dictionary) -> String:
	if int(estado.get("schema_version", VERSAO_ESQUEMA)) == VERSAO_ESQUEMA_V21:
		return JSON.stringify(estado, "\t", false) + "\n"
	var m: Dictionary = estado.get("metrics", {})
	var metricas: Dictionary = {}
	for nome in METRICAS:
		var v: float = float(m.get(nome, 0.0))
		if is_equal_approx(v, roundf(v)):
			metricas[nome] = int(v)
		else:
			metricas[nome] = v
	var ordenado: Dictionary = {
		"schema_version": int(estado.get("schema_version", VERSAO_ESQUEMA)),
		"choice_id": str(estado.get("choice_id", "")),
		"status": str(estado.get("status", STATUS_INICIAL)),
		"metrics": metricas,
		"timestamp": str(estado.get("timestamp", "")),
		"is_placeholder": bool(estado.get("is_placeholder", false)),
	}
	return JSON.stringify(ordenado, "\t", false) + "\n"   # sort_keys = false: a ordem do contrato (a mesma do backend em C), não a alfabética


## Interpreta o texto de um arquivo: tamanho, BOM, JSON e esquema. Devolve {ok, erro, estado}.
static func interpretar(texto: String) -> Dictionary:
	if texto.to_utf8_buffer().size() > TAMANHO_MAX_BYTES:
		return {"ok": false, "erro": "arquivo acima do limite de %d bytes" % TAMANHO_MAX_BYTES, "estado": {}}
	var limpo: String = texto.trim_prefix("﻿")
	var json := JSON.new()
	if json.parse(limpo) != OK:
		return {"ok": false, "erro": "json malformado (linha %d: %s)" % [json.get_error_line(), json.get_error_message()], "estado": {}}
	var r: Dictionary = validar(json.data)
	if not bool(r["ok"]):
		return {"ok": false, "erro": "; ".join(PackedStringArray(r["erros"])), "estado": {}}
	return {"ok": true, "erro": "", "estado": r["estado"]}


# ------------------------------------------------------------------ arquivo
## Lê e valida. Se o arquivo principal faltar ou estiver inválido e houver um `.bak` válido, usa o `.bak` (`origem: "backup"`).
## Devolve {ok, erro, estado, origem ("arquivo" | "backup" | "")}.
static func ler(caminho: String = "") -> Dictionary:
	var alvo: String = _caminho(caminho)
	var principal: Dictionary = _ler_um(alvo)
	if bool(principal["ok"]):
		principal["origem"] = "arquivo"
		return principal
	var reserva: Dictionary = _ler_um(alvo + SUFIXO_BACKUP)
	if bool(reserva["ok"]):
		reserva["origem"] = "backup"
		return reserva
	principal["origem"] = ""
	return principal


static func _ler_um(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {"ok": false, "erro": "arquivo não encontrado: %s" % caminho, "estado": {}}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {"ok": false, "erro": "não foi possível abrir %s (erro %d)" % [caminho, FileAccess.get_open_error()], "estado": {}}
	if arquivo.get_length() > TAMANHO_MAX_BYTES:
		arquivo.close()
		return {"ok": false, "erro": "arquivo acima do limite de %d bytes" % TAMANHO_MAX_BYTES, "estado": {}}
	var texto: String = arquivo.get_as_text()
	arquivo.close()
	return interpretar(texto)


## O caminho pode receber o estado? Nunca res://; user:// sempre; outros caminhos absolutos só com `permitir_absoluto`.
static func caminho_gravavel(caminho: String, permitir_absoluto: bool = false) -> bool:
	if caminho.strip_edges() == "" or caminho.begins_with("res://"):
		return false
	if caminho.get_file() == "" or caminho.contains(".."):
		return false
	if caminho.begins_with("user://"):
		return true
	return permitir_absoluto and caminho.is_absolute_path()


## Grava de forma validada, em UTF-8 e resistente a falha parcial (ver o cabeçalho). Devolve {ok, erro}.
static func gravar(estado: Dictionary, destino: String = "", permitir_absoluto: bool = false) -> Dictionary:
	var caminho: String = _caminho(destino)
	if not caminho_gravavel(caminho, permitir_absoluto):
		return {"ok": false, "erro": "caminho recusado (res:// nunca; fora de user:// só em desenvolvimento): %s" % caminho}
	var r: Dictionary = validar(estado)
	if not bool(r["ok"]):
		return {"ok": false, "erro": "estado inválido: " + "; ".join(PackedStringArray(r["erros"]))}
	var texto: String = serializar(r["estado"])
	var pasta: String = caminho.get_base_dir()
	if not DirAccess.dir_exists_absolute(pasta):
		var criada: Error = DirAccess.make_dir_recursive_absolute(pasta)
		if criada != OK:
			return {"ok": false, "erro": "não foi possível criar a pasta %s (erro %d)" % [pasta, criada]}
	var temporario: String = caminho + SUFIXO_TEMP
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return {"ok": false, "erro": "não foi possível criar %s (erro %d)" % [temporario, FileAccess.get_open_error()]}
	arquivo.store_string(texto)
	arquivo.flush()
	var erro_escrita: Error = arquivo.get_error()
	arquivo.close()
	if erro_escrita != OK or not _conferir_temporario(temporario, texto):
		return {"ok": false, "erro": "a escrita de %s não foi conferida; o arquivo anterior foi mantido" % temporario}
	# O jogo não apaga arquivos (regra do projeto): o .bak anterior é sobrescrito pelo renomear e o .tmp de uma gravação que falhou fica no
	# disco até a próxima gravação o sobrescrever (ninguém lê o .tmp).
	var reserva: String = caminho + SUFIXO_BACKUP
	var havia_anterior: bool = FileAccess.file_exists(caminho)
	if havia_anterior and DirAccess.rename_absolute(caminho, reserva) != OK:
		return {"ok": false, "erro": "não foi possível guardar o arquivo anterior em %s; nada foi alterado" % reserva}
	if DirAccess.rename_absolute(temporario, caminho) != OK:
		if havia_anterior:
			DirAccess.rename_absolute(reserva, caminho)
		return {"ok": false, "erro": "não foi possível colocar o novo estado em %s; o arquivo anterior foi restaurado" % caminho}
	return {"ok": true, "erro": ""}


static func _conferir_temporario(caminho: String, esperado: String) -> bool:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return false
	var lido: String = arquivo.get_as_text()
	arquivo.close()
	return lido == esperado


# ------------------------------------------------------------------ ponte com o jogo
## A ponte opcional está ligada? (Configurações: usar_backend_json; padrão desligada.)
static func ativo() -> bool:
	return bool(GerenciadorConfiguracoes.obter("usar_backend_json"))


## Estado do jogo agora, no formato do arquivo (métricas lidas do GerenciadorEstado, a única fonte delas).
static func estado_atual(choice_id: String, is_placeholder: bool, status: String = STATUS_OK) -> Dictionary:
	return criar(choice_id, status, GerenciadorEstado.copia_das_metricas(), is_placeholder)


## Chamado depois de cada escolha do Mensageiro. Com a ponte desligada não faz nada ({ok: false, motivo: "ponte_desligada"}); com ela ligada
## grava `estado_jogo.json`. Escolha de id fora do formato (não deve acontecer) não é gravada. Nunca derruba o jogo: devolve o resultado.
static func registrar_escolha(id_escolha: String, is_placeholder: bool, caminho: String = "") -> Dictionary:
	if not ativo():
		return {"ok": false, "erro": "", "motivo": "ponte_desligada"}
	if not id_valido(id_escolha):
		return {"ok": false, "erro": "id de escolha fora do formato: %s" % id_escolha, "motivo": "id_invalido"}
	var r: Dictionary = gravar(estado_atual(id_escolha, is_placeholder), caminho)
	if not bool(r["ok"]):
		push_warning("EstadoJogoBackend: %s" % str(r["erro"]))
	r["motivo"] = "gravado" if bool(r["ok"]) else "falha_ao_gravar"
	return r


# ------------------------------------------------------------------ contrato v2.1 (schema_version: 2)
## Flags que o backend em C conhece (backend/bk_maya_v21.c). Booleanas: o mesmo nome nos dois lados. Enumeradas: o jogo guarda TEXTO e o C guarda
## NÚMERO, por isso a tradução abaixo (nos dois sentidos). Qualquer outra flag do jogo (contadores, `arquivo_aberto:*`, `chat_extra:*`...) não vai ao arquivo.
const FLAGS_BOOL_V21: PackedStringArray = [
	"maya_interferiu_mensagem", "maya_controla_respostas", "bia_censurada", "pediu_limite", "pista_anotacao_lida", "rotina_por_maya",
	"conhecimento_logico_adquirido", "sincronizacao_concluida", "rafael_investigado", "task_5_realizada", "pasta_rafael_aberta", "rafael_diario_lido",
	"rafael_fotos_vistas", "segredo_rafael_encontrado", "minigame_rafael_resolvido", "task_7_desbloqueada", "rafael_confronto",
	"rafael_evidencia_enviada", "bia_alertada", "bia_convidada",
]
const FLAGS_ENUM_V21: Dictionary = {
	"t1_organizacao": ["", "maya", "jogador"],
	"t3_resposta": ["", "como_sabe", "por_que_acessou", "valeu"],
	"entrega_modo": ["", "maya", "jogador", "revisao"],
	"t8_postura": ["", "parar", "aceitar", "pensar"],
	"mural_publicacao": ["nenhuma", "maya", "apagada"],
}
## Ids de final do jogo -> ids do backend (bk_maya_final_id). O jogo guarda `final_id` no GerenciadorEstado.
const FINAIS_V21: Dictionary = {
	"": "NENHUM", "rafael_2": "RAFAEL_2", "rafael_1": "RAFAEL_1", "aceitacao_total": "ACEITACAO_TOTAL", "recusa_total": "RECUSA_TOTAL",
	"meio_termo_1": "MEIO_TERMO_1", "meio_termo_2": "MEIO_TERMO_2",
}


## Task atual como número (1..9; 10 = AV), o formato do backend. "tr_1" conta como 6 (a transição ainda é a conversa com a Bia).
static func task_numerica() -> int:
	var t: String = GerenciadorEstado.task_atual
	if t == "av":
		return 10
	if t == "tr_1":
		return 6
	if t.begins_with("task_"):
		return clampi(int(t.substr(5)), 1, 9)
	return 1


## As flags do jogo que o backend entende, já no formato dele (booleanas, números e enumerações numéricas).
static func flags_para_v21() -> Dictionary:
	var saida: Dictionary = {}
	for nome in FLAGS_BOOL_V21:
		saida[nome] = GerenciadorEstado.tem_flag(nome)
	for nome in FLAGS_ENUM_V21:
		var valores: Array = FLAGS_ENUM_V21[nome]
		var indice: int = valores.find(str(GerenciadorEstado.valor_flag(nome, "")))
		saida[nome] = maxi(0, indice)
	saida["bia_ocultadas_count"] = AppRelatorio.contar_ocultas()
	saida["minigame_2_bloqueado"] = GerenciadorEstado.tem_flag("rafael_fechada_pela_maya") or GerenciadorEstado.no_roteiro in ["T9.6", "AV"]
	return saida


## Estado atual do jogo no contrato v2.1, compatível com `maya_backend --v21-choice`. Tudo vem das fontes únicas do jogo (GerenciadorEstado,
## Permissoes): a investigação profunda e o final NÃO são recalculados aqui.
static func criar_v21(choice_id: String, status: String = STATUS_OK, carimbo: String = "") -> Dictionary:
	var perms: Dictionary = {}
	for p in GerenciadorEstado.PERMISSOES_V2:
		perms[p] = Permissoes.valor(str(p))
	var genero: String = "feminino" if GerenciadorEstado.pronome_jogador == "ela" else "masculino"
	return {
		"schema_version": VERSAO_ESQUEMA_V21,
		"roteiro_versao": ROTEIRO_VERSAO_V21,
		"choice_id": choice_id,
		"status": status,
		"timestamp": carimbo if carimbo != "" else timestamp_agora(),
		"nome_usuario": GerenciadorEstado.nome_jogador,
		"genero": genero,
		"tempo_estendido": bool(GerenciadorConfiguracoes.obter("tempo_estendido")),
		"dependencia_maya": GerenciadorEstado.dependencia_maya(),
		"autonomia_jogador": GerenciadorEstado.autonomia_jogador(),
		"task_atual": task_numerica(),
		"permissoes_ativas": GerenciadorEstado.permissoes_ativas(),
		"rafael_investigacao_profunda": GerenciadorEstado.investigacao_profunda_concluida(),
		"final": str(FINAIS_V21.get(GerenciadorEstado.final_id, "NENHUM")),
		"permissoes": perms,
		"flags": flags_para_v21(),
	}


## Grava o estado v2.1 em `estado_jogo.json` quando a ponte opcional `usar_backend_json` estiver ligada. `id_backend` é o id canônico da matriz do
## backend (campo `id_backend` da opção no roteiro). Opção sem id canônico não é gravada ({motivo: "sem_id_backend"}).
static func registrar_escolha_v21(id_backend: String, caminho: String = "") -> Dictionary:
	if not ativo():
		return {"ok": false, "erro": "", "motivo": "ponte_desligada"}
	if id_backend == "":
		return {"ok": false, "erro": "", "motivo": "sem_id_backend"}
	if not id_valido(id_backend):
		return {"ok": false, "erro": "id de escolha fora do formato: %s" % id_backend, "motivo": "id_invalido"}
	var r: Dictionary = gravar(criar_v21(id_backend), caminho)
	if not bool(r["ok"]):
		push_warning("EstadoJogoBackend: %s" % str(r["erro"]))
	r["motivo"] = "gravado" if bool(r["ok"]) else "falha_ao_gravar"
	return r


## Aplica as métricas de um estado VÁLIDO às métricas do jogo, pela regra central (GerenciadorEstado.definir_metrica: limites e validação).
## Suporta schema_version 1 (métricas legadas) e schema_version 2 (Roteiro v2.1: D, A, 5 permissões e flags).
## No v2.1: as permissões passam por `Permissoes.definir` e as flags por `definir_flag_roteiro` (flags de descoberta nunca voltam a false);
## a Autonomia nunca diminui (valor menor que o atual é ignorado); `task_atual` e `final` NÃO são aplicados (o progresso é do jogo).
## É uma ação explícita: nada chama isto sozinho. Devolve {ok, erro, aplicadas: {nome: valor}}.
static func aplicar_ao_jogo(estado: Dictionary) -> Dictionary:
	var r: Dictionary = validar(estado)
	if not bool(r["ok"]):
		return {"ok": false, "erro": "estado inválido: " + "; ".join(PackedStringArray(r["erros"])), "aplicadas": {}}
	var validado: Dictionary = r["estado"]
	var aplicadas: Dictionary = {}
	if int(validado.get("schema_version", VERSAO_ESQUEMA)) == VERSAO_ESQUEMA_V21:
		if GerenciadorEstado.definir_metrica(Metricas.DEPENDENCIA, float(validado["dependencia_maya"]), "backend_c"):
			aplicadas[Metricas.DEPENDENCIA] = GerenciadorEstado.obter_metrica(Metricas.DEPENDENCIA)
		var nova_autonomia: float = maxf(float(validado["autonomia_jogador"]), float(GerenciadorEstado.autonomia_jogador()))
		if GerenciadorEstado.definir_metrica(Metricas.AUTONOMIA, nova_autonomia, "backend_c"):
			aplicadas[Metricas.AUTONOMIA] = GerenciadorEstado.obter_metrica(Metricas.AUTONOMIA)
		var perms: Dictionary = validado.get("permissoes", {})
		for p in GerenciadorEstado.PERMISSOES_V2:
			if perms.has(p):
				Permissoes.definir(str(p), bool(perms[p]))
		_aplicar_flags_v21(validado.get("flags", {}))
		return {"ok": aplicadas.size() == 2, "erro": "", "aplicadas": aplicadas}
	var metricas: Dictionary = validado["metrics"]
	for nome in METRICAS:
		if GerenciadorEstado.definir_metrica(nome, metricas[nome], "backend_c"):
			aplicadas[nome] = GerenciadorEstado.obter_metrica(nome)
	return {"ok": aplicadas.size() == METRICAS.size(), "erro": "", "aplicadas": aplicadas}


## Flags do arquivo v2.1 para o jogo: só as conhecidas, com a tradução das enumerações de número para texto.
static func _aplicar_flags_v21(flags_arquivo: Variant) -> void:
	if not (flags_arquivo is Dictionary):
		return
	var f: Dictionary = flags_arquivo
	for nome in FLAGS_BOOL_V21:
		if f.has(nome) and typeof(f[nome]) == TYPE_BOOL:
			GerenciadorEstado.definir_flag_roteiro(str(nome), bool(f[nome]))
	for nome in FLAGS_ENUM_V21:
		if f.has(nome) and (typeof(f[nome]) == TYPE_INT or typeof(f[nome]) == TYPE_FLOAT):
			var valores: Array = FLAGS_ENUM_V21[nome]
			var indice: int = int(f[nome])
			if indice > 0 and indice < valores.size():
				GerenciadorEstado.definir_flag_roteiro(str(nome), valores[indice])


## Lê o arquivo, valida e aplica às métricas do jogo. Devolve {ok, erro, origem, estado, aplicadas}. Ação explícita (ver o cabeçalho).
static func sincronizar_do_arquivo(caminho: String = "") -> Dictionary:
	var lido: Dictionary = ler(caminho)
	if not bool(lido["ok"]):
		return {"ok": false, "erro": lido["erro"], "origem": lido.get("origem", ""), "estado": {}, "aplicadas": {}}
	var aplicado: Dictionary = aplicar_ao_jogo(lido["estado"])
	return {"ok": bool(aplicado["ok"]), "erro": aplicado["erro"], "origem": lido["origem"], "estado": lido["estado"], "aplicadas": aplicado["aplicadas"]}
