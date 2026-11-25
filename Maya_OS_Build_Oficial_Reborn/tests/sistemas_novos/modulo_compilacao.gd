extends ModuloDeTeste
## Módulo 0: o jogo INTEIRO compila. Carrega cada script (.gd) e cada cena (.tscn) do projeto e confere que o compilador do Godot os aceitou.
## Existe porque um erro de parser (por exemplo, uma variável declarada duas vezes) só aparece quando o script é carregado pela primeira vez, e um
## app que o jogador só abre numa escolha tardia (como o Explorador, em "Abrir o histórico antigo") derruba a partida no meio da gameplay.
## Também confere que todo JSON de dados (core/data) é válido. Nada é instanciado nem alterado: só carregado.

const PASTAS_IGNORADAS: PackedStringArray = ["res://addons", "res://.godot", "res://tests/_saida", "res://.git"]


func executar(banca_do_executor: BancaDeTestes) -> void:
	banca = banca_do_executor
	await get_tree().process_frame
	_secao("Todos os scripts compilam")
	var scripts: PackedStringArray = []
	var cenas: PackedStringArray = []
	var jsons: PackedStringArray = []
	_listar("res://", scripts, cenas, jsons)
	scripts.sort()
	cenas.sort()
	jsons.sort()
	_ok(scripts.size() > 50, "o projeto tem scripts para verificar (%d encontrados)" % scripts.size())
	var quebrados: PackedStringArray = []
	for caminho in scripts:
		var recurso: Resource = ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_REUSE)
		var s: GDScript = recurso as GDScript
		if s == null or not (s.can_instantiate() or s.is_abstract()):
			quebrados.append(caminho)
	_ok(quebrados.is_empty(), "nenhum script com erro de compilação%s" % ("" if quebrados.is_empty() else ": " + ", ".join(quebrados)))
	for q in quebrados:
		_info("NÃO COMPILA: %s" % q)

	_secao("Todas as cenas carregam")
	var cenas_quebradas: PackedStringArray = []
	for caminho in cenas:
		var cena: PackedScene = ResourceLoader.load(caminho, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
		if cena == null or not cena.can_instantiate():
			cenas_quebradas.append(caminho)
	_ok(cenas.size() > 30, "o projeto tem cenas para verificar (%d encontradas)" % cenas.size())
	_ok(cenas_quebradas.is_empty(), "nenhuma cena com erro de carga%s" % ("" if cenas_quebradas.is_empty() else ": " + ", ".join(cenas_quebradas)))

	_secao("Todos os JSON de dados são válidos")
	var json_ruins: PackedStringArray = []
	for caminho in jsons:
		var texto: String = FileAccess.get_file_as_string(caminho)
		var json := JSON.new()
		if json.parse(texto) != OK:
			json_ruins.append("%s (linha %d)" % [caminho, json.get_error_line()])
	_ok(jsons.size() > 5, "o projeto tem JSON de dados (%d encontrados)" % jsons.size())
	_ok(json_ruins.is_empty(), "nenhum JSON inválido%s" % ("" if json_ruins.is_empty() else ": " + ", ".join(json_ruins)))


func _listar(pasta: String, scripts: PackedStringArray, cenas: PackedStringArray, jsons: PackedStringArray) -> void:
	var raiz: String = pasta.trim_suffix("/")
	if PASTAS_IGNORADAS.has(raiz):
		return
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nome: String = dir.get_next()
	while nome != "":
		var caminho: String = pasta.path_join(nome)
		if dir.current_is_dir():
			if not nome.begins_with("."):
				_listar(caminho, scripts, cenas, jsons)
		elif nome.ends_with(".gd"):
			scripts.append(caminho)
		elif nome.ends_with(".tscn"):
			cenas.append(caminho)
		elif nome.ends_with(".json") and caminho.begins_with("res://core/data"):
			jsons.append(caminho)
		nome = dir.get_next()
	dir.list_dir_end()
