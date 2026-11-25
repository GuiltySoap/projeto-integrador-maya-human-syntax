class_name Wallpapers
extends RefCounted
## Catálogo CENTRAL de papéis de parede (core/data/wallpapers.json) e as regras de escolha. Nenhum caminho de imagem mora fora do JSON.
## Cada item: id, nome, recurso (res://), ordem, disponivel_desde_inicio (todos são selecionáveis desde o início do jogo: nada se desbloqueia
## por Task, Estágio ou Dependência) e categoria opcional. Itens com id repetido ou recurso inexistente são ignorados na leitura (com aviso).
## Regras de escolha (puras, testáveis; o PapelDeParede só as aplica):
##   - "auto" = o jogo sorteia UM wallpaper ao abrir e o mantém até fechar o jogo. Task, Estágio, Dependência, Novo Jogo e carregar save NÃO sorteiam de novo.
##   - slideshow sequencial = segue a `ordem` do catálogo e volta ao início; aleatório = nunca repete o atual de imediato (com RNG injetável).
##   - id inválido (apagado do catálogo, arquivo ausente) cai no primeiro wallpaper válido.

const CAMINHO_CATALOGO := "res://core/data/wallpapers.json"
const AUTO := "auto"
const INTERVALO_PADRAO_S := 60.0

static var _cache: Array = []
static var _intervalo: float = INTERVALO_PADRAO_S
static var _carregado: bool = false
## Sorteio do modo "auto": fixo durante a sessão (um processo do jogo).
static var _auto_da_sessao: String = ""


static func recarregar() -> void:
	_carregado = false
	_cache = []
	_auto_da_sessao = ""


static func _carregar() -> void:
	if _carregado:
		return
	_carregado = true
	_cache = []
	_intervalo = INTERVALO_PADRAO_S
	if not FileAccess.file_exists(CAMINHO_CATALOGO):
		push_warning("Wallpapers: catálogo ausente (%s)." % CAMINHO_CATALOGO)
		return
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_CATALOGO))
	if not (dados is Dictionary):
		push_warning("Wallpapers: catálogo inválido (JSON).")
		return
	_intervalo = maxf(1.0, float((dados as Dictionary).get("intervalo_slideshow_s", INTERVALO_PADRAO_S)))
	var vistos: Dictionary = {}
	for item in (dados as Dictionary).get("wallpapers", []):
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var id_w := str(d.get("id", ""))
		var recurso := str(d.get("recurso", ""))
		if id_w == "" or id_w == AUTO or vistos.has(id_w):
			push_warning("Wallpapers: id inválido ou repetido ('%s') ignorado." % id_w)
			continue
		if recurso == "" or not ResourceLoader.exists(recurso):
			push_warning("Wallpapers: recurso ausente para '%s' (%s); item ignorado." % [id_w, recurso])
			continue
		vistos[id_w] = true
		_cache.append(d)
	_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("ordem", 0)) < int(b.get("ordem", 0)))


static func catalogo() -> Array:
	_carregar()
	return _cache


static func intervalo_slideshow() -> float:
	_carregar()
	return _intervalo


static func ids() -> PackedStringArray:
	var saida := PackedStringArray()
	for d in catalogo():
		saida.append(str((d as Dictionary)["id"]))
	return saida


## Wallpapers selecionáveis agora. Hoje todos (disponivel_desde_inicio), sem depender de progresso.
static func disponiveis() -> Array:
	var saida: Array = []
	for d in catalogo():
		if bool((d as Dictionary).get("disponivel_desde_inicio", true)):
			saida.append(d)
	return saida


static func valido(id_w: String) -> bool:
	for d in disponiveis():
		if str((d as Dictionary)["id"]) == id_w:
			return true
	return false


static func por_id(id_w: String) -> Dictionary:
	for d in catalogo():
		if str((d as Dictionary)["id"]) == id_w:
			return d
	return {}


static func indice_de(id_w: String) -> int:
	var lista: Array = disponiveis()
	for i in lista.size():
		if str((lista[i] as Dictionary)["id"]) == id_w:
			return i
	return -1


static func primeiro() -> String:
	var lista: Array = disponiveis()
	return str((lista[0] as Dictionary)["id"]) if not lista.is_empty() else ""


static func por_indice(indice: int) -> String:
	var lista: Array = disponiveis()
	if lista.is_empty():
		return ""
	return str((lista[clampi(indice, 0, lista.size() - 1)] as Dictionary)["id"])


## O wallpaper "auto" desta sessão: sorteia na primeira chamada e devolve sempre o mesmo depois.
static func auto_da_sessao(rng: RandomNumberGenerator = null) -> String:
	if _auto_da_sessao == "" or not valido(_auto_da_sessao):
		_auto_da_sessao = sortear(rng)
	return _auto_da_sessao


static func sortear(rng: RandomNumberGenerator = null) -> String:
	var lista: Array = disponiveis()
	if lista.is_empty():
		return ""
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	return str((lista[r.randi_range(0, lista.size() - 1)] as Dictionary)["id"])


## Define explicitamente o "auto" da sessão (testes; e o jogo, ao abrir).
static func definir_auto_da_sessao(id_w: String) -> void:
	_auto_da_sessao = id_w if valido(id_w) else ""


## Converte a escolha das Configurações ("auto" ou um id) no id concreto a exibir.
static func resolver(id_config: String, rng: RandomNumberGenerator = null) -> String:
	if id_config == AUTO or not valido(id_config):
		return auto_da_sessao(rng) if id_config == AUTO else primeiro()
	return id_config


static func proximo_sequencial(atual: String) -> String:
	var lista: Array = disponiveis()
	if lista.is_empty():
		return ""
	var i: int = indice_de(atual)
	return str((lista[(i + 1) % lista.size()] as Dictionary)["id"]) if i >= 0 else str((lista[0] as Dictionary)["id"])


## Aleatório sem repetir o atual de imediato (com um só wallpaper, devolve ele mesmo).
static func proximo_aleatorio(atual: String, rng: RandomNumberGenerator = null) -> String:
	var lista: Array = disponiveis()
	if lista.is_empty():
		return ""
	if lista.size() == 1:
		return str((lista[0] as Dictionary)["id"])
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var candidatos: Array = []
	for d in lista:
		if str((d as Dictionary)["id"]) != atual:
			candidatos.append(str((d as Dictionary)["id"]))
	return str(candidatos[r.randi_range(0, candidatos.size() - 1)])
