extends ModuloDeTeste
## Módulo 7 (roteiro v2.1): o que mudou da v2.0 para a v2.1 e o que o jogo agora cumpre à risca.
##   - T9.6 vale D ±15 ([Não] com A +1); T3.5 vale D −5 / +5 (testado no módulo de minigames);
##   - Recusa total aceita no máximo UMA permissão ativa, desde que não seja a do Mensageiro;
##   - religar em Configurações uma permissão que o jogador revogou desfaz exatamente a revogação (D e A voltam; flags do canal também);
##   - a janela de investigação vai até T6.8: o histórico antigo (Task 5) abre pelo painel durante a conversa da Task 6 e volta ao mesmo nó;
##   - "Você leu o que eu disse?" (T6.3) é sempre da Bia; os 10 arquivos de apoio; rascunho_apresentacao completo; Lista 4 no final Modo manual;
##   - {o/a} no roteiro; Minigame #2 disponível até o fim de T9.5R;
##   - ponte com o backend em C: ids canônicos (`id_backend`), tipos de flag, final e task no formato do C, passando pelos serviços do jogo.

const APOIO: PackedStringArray = [
	"aula_01_variaveis.txt", "aula_02_condicionais.txt", "aula_03_lacos.txt", "aula_04_vetores.txt", "aula_05_funcoes.txt",
	"exercicios_lista_1.txt", "exercicios_lista_2.txt", "exercicios_lista_3.txt", "anotacoes_monitoria_marcos.txt", "rascunho_prova_p1.txt",
]


func executar(banca_do_executor: BancaDeTestes) -> void:
	banca = banca_do_executor
	_isolar_configuracoes()
	_testar_pesos_da_decisao_final()
	_testar_recusa_total_v21()
	_testar_reconceder_permissao()
	_testar_janela_de_investigacao_ate_t6_8()
	_testar_textos_e_arquivos()
	_testar_minigame_2_ate_t9_5r()
	await _testar_ponte_com_o_backend_em_c()
	_restaurar_configuracoes()
	await get_tree().process_frame


func _node(id_no: String) -> Dictionary:
	return FluxoRoteiro.no(id_no)


func _testar_pesos_da_decisao_final() -> void:
	_secao("T9.6: [Sim] D +15; [Não] D −15 e A +1; [Não] ignorado com Organização + Apps + Mensageiro")
	_novo_jogo()
	GerenciadorNarrativa.ir_para_no("T9.6")
	var d0 := _dep()
	_ok(GerenciadorNarrativa.escolher_opcao("sim"), "[Sim] é aceito")
	_igual(_dep() - d0, 15, "[Sim]: D +15")
	_novo_jogo()
	GerenciadorNarrativa.ir_para_no("T9.6")
	d0 = _dep()
	var a0 := _aut()
	_ok(GerenciadorNarrativa.escolher_opcao("nao"), "[Não] é aceito quando as três permissões não estão todas ativas")
	_igual(_dep() - d0, -15, "[Não]: D −15")
	_igual(_aut() - a0, 1, "[Não]: A +1")
	_novo_jogo()
	for id_perm in ["permissao_organizacao_desktop", "permissao_gerenciamento_apps", "permissao_gerenciamento_mensageiro"]:
		Permissoes.permitir(id_perm, 0)
	GerenciadorNarrativa.ir_para_no("T9.6")
	_ok(not GerenciadorNarrativa.escolher_opcao("nao"), "com as três permissões ativas o clique em [Não] é ignorado")
	_igual((GerenciadorNarrativa.opcoes_bloqueadas() as Array).size(), 1, "...mas o botão continua visível (opção bloqueada)")


func _testar_recusa_total_v21() -> void:
	_secao("Recusa total (v2.1): no máximo uma permissão ativa e nunca a do Mensageiro")
	for caso in [
		[[], "recusa_total", "nenhuma permissão"],
		[["permissao_dispositivos"], "recusa_total", "uma permissão (Dispositivos)"],
		[["permissao_gerenciamento_mensageiro"], "meio_termo_2", "só o Mensageiro ativo"],
		[["permissao_contatos", "permissao_dispositivos"], "meio_termo_1", "duas permissões"],
	]:
		_novo_jogo()
		GerenciadorEstado.definir_metrica("dependencia", 20)
		GerenciadorEstado.definir_metrica("autonomia", 5)
		for id_perm in Permissoes.ids():
			GerenciadorEstado.definir_permissao(str(id_perm), (caso[0] as Array).has(str(id_perm)))
		_igual(GerenciadorNarrativa.avaliar_final(), str(caso[1]), "D 20, A 5 e %s → %s" % [str(caso[2]), str(caso[1])])


func _testar_reconceder_permissao() -> void:
	_secao("Religar em Configurações desfaz EXATAMENTE a revogação (D +5, A −1; canal restaurado)")
	_novo_jogo()
	GerenciadorEstado.task_atual = "task_3"
	_ok(not Permissoes.pode_reconceder("permissao_contatos"), "uma permissão que nunca foi revogada não é religada pelas Configurações")
	Permissoes.permitir("permissao_contatos", 0)
	GerenciadorEstado.set_flag("contatos_reordenados", true)
	var d0 := _dep()
	var a0 := _aut()
	Permissoes.revogar("permissao_contatos")
	_igual(_dep(), d0 - 5, "revogar: D −5")
	_igual(_aut(), a0 + 1, "revogar: A +1")
	_ok(not GerenciadorEstado.tem_flag("contatos_reordenados"), "revogar desliga o canal (contatos_reordenados = false)")
	_ok(Permissoes.pode_reconceder("permissao_contatos"), "depois de revogada, a permissão pode ser religada")
	var r: Dictionary = Permissoes.reconceder("permissao_contatos")
	_igual(str(r["resultado"]), "reconcedida", "religar funciona")
	_ok(Permissoes.valor("permissao_contatos"), "a permissão volta a true")
	_igual(_dep(), d0, "D volta ao valor de antes (+5)")
	_igual(_aut(), a0, "A volta ao valor de antes (−1: única exceção a 'A nunca diminui')")
	_ok(GerenciadorEstado.tem_flag("contatos_reordenados"), "a flag do canal volta ao que era")
	_ok(not Permissoes.pode_reconceder("permissao_contatos"), "o registro da revogação some depois de religar")
	# a Autonomia nunca diminui por outro caminho
	GerenciadorEstado.registrar_resistencia(&"teste_v21")
	var a1 := _aut()
	avisos_esperados += 1
	_ok(not GerenciadorEstado.definir_metrica("autonomia", a1 - 1, "teste"), "fora da reversão exata a Autonomia continua sem diminuir")
	_igual(_aut(), a1, "...e o valor não muda")
	# o Mensageiro: maya_controla_respostas volta
	_novo_jogo()
	GerenciadorEstado.task_atual = "task_6"
	Permissoes.permitir("permissao_gerenciamento_mensageiro", 0)
	GerenciadorEstado.set_flag("maya_controla_respostas", true)
	Permissoes.revogar("permissao_gerenciamento_mensageiro")
	_ok(not bool(GerenciadorEstado.valor_flag("maya_controla_respostas", false)), "revogar o Mensageiro desliga maya_controla_respostas")
	Permissoes.reconceder("permissao_gerenciamento_mensageiro")
	_ok(bool(GerenciadorEstado.valor_flag("maya_controla_respostas", false)), "religar devolve maya_controla_respostas = true")
	# apps: os apps ocultos pela revogação voltam a seguir o estado anterior
	_novo_jogo()
	GerenciadorEstado.task_atual = "task_4"
	Permissoes.permitir("permissao_gerenciamento_apps", 0)
	GerenciadorEstado.definir_flag_roteiro("app_oculto:mural", true)
	Permissoes.revogar("permissao_gerenciamento_apps")
	_ok(not GerenciadorEstado.tem_flag("app_oculto:mural"), "revogar Aplicativos devolve o Mural à área de trabalho")
	Permissoes.reconceder("permissao_gerenciamento_apps")
	_ok(GerenciadorEstado.tem_flag("app_oculto:mural"), "religar esconde o Mural de novo (estado anterior)")
	# o registro sobrevive a salvar e carregar
	_novo_jogo()
	GerenciadorEstado.task_atual = "task_3"
	Permissoes.permitir("permissao_dispositivos", 0)
	Permissoes.revogar("permissao_dispositivos")
	var salvo: Dictionary = JSON.parse_string(JSON.stringify(GerenciadorEstado.para_dicionario()))
	GerenciadorEstado.de_dicionario(salvo)
	_ok(Permissoes.pode_reconceder("permissao_dispositivos"), "o registro da revogação sobrevive a salvar e carregar")


func _testar_janela_de_investigacao_ate_t6_8() -> void:
	_secao("Janela de investigação: o histórico antigo continua acessível durante a conversa da Task 6 (até T6.8)")
	_novo_jogo()
	GerenciadorEstado.set_flag("sincronizacao_concluida", true)
	GerenciadorNarrativa.ir_para_no("T6.3")
	_igual(_no(), "T6.3", "a conversa está em T6.3 (escolha)")
	_ok(GerenciadorNarrativa.historico_antigo_extra_disponivel(), "o histórico antigo está disponível durante a conversa")
	_ok(GerenciadorNarrativa.abrir_historico_antigo(), "abrir o histórico antigo pelo painel funciona")
	_igual(_no(), "T5.1", "...e leva à confirmação da Task 5 (T5.1)")
	_ok(GerenciadorNarrativa.escolher_opcao("deixa_pra_la"), "[Deixa pra lá] fecha o histórico")
	_igual(_no(), "T6.3", "...e volta ao MESMO nó da conversa (não ao T4.F)")
	_ok(not GerenciadorEstado.tem_flag("rafael_investigado"), "[Deixa pra lá] não marca investigação")
	GerenciadorNarrativa.abrir_historico_antigo()
	_ok(GerenciadorNarrativa.escolher_opcao("abrir"), "[Abrir] confirma")
	_ok(GerenciadorEstado.tem_flag("rafael_investigado"), "[Abrir] marca rafael_investigado (v2.1: o clique confirmado já conta)")
	GerenciadorNarrativa.concluir_minigame("historico_fragmentado", "sair")
	_igual(_no(), "T6.3", "fechar o minigame sem resolver também volta à conversa")
	_ok(GerenciadorNarrativa.historico_antigo_extra_disponivel() and not GerenciadorEstado.tem_flag("task_5_realizada"), "...e o histórico continua acessível (task_5_realizada ainda false)")
	# o encerramento fecha a janela definitivamente (T6.8)
	_novo_jogo()
	GerenciadorEstado.set_flag("sincronizacao_concluida", true)
	GerenciadorNarrativa.ir_para_no("T6.8")
	_ok(GerenciadorEstado.tem_flag("rafael_arquivada"), "T6.8: quem não investigou tem a pasta e o histórico arquivados")
	_ok(not GerenciadorNarrativa.historico_antigo_extra_disponivel(), "...e depois de T6.8 o histórico antigo não abre mais")
	_novo_jogo()
	GerenciadorEstado.set_flag("sincronizacao_concluida", true)
	GerenciadorEstado.set_flag("rafael_investigado", true)
	GerenciadorNarrativa.ir_para_no("T6.8")
	_ok(not GerenciadorEstado.tem_flag("rafael_arquivada") and GerenciadorEstado.tem_flag("task_7_desbloqueada"), "T6.8 com investigação: a Task 7 é liberada e nada é arquivado")
	_ok(FluxoRoteiro.validar().is_empty(), "o roteiro continua consistente com o destino especial de retorno: %s" % str(FluxoRoteiro.validar()))


func _testar_textos_e_arquivos() -> void:
	_secao("Textos e arquivos da v2.1")
	var bora: Dictionary = {}
	for o in _node("T6.3")["opcoes"]:
		if str((o as Dictionary)["id"]) == "bora_sair":
			bora = o
	var achou := false
	var da_bia := true
	for f in bora.get("resposta", []):
		if str((f as Dictionary).get("texto", "")) == "Você leu o que eu disse?":
			achou = true
			da_bia = da_bia and str((f as Dictionary).get("quem", "")) == "bia" and not (f as Dictionary).has("se")
	_ok(achou and da_bia, "'Você leu o que eu disse?' é sempre da Bia (sem variante da Maya)")
	_novo_jogo()
	var pasta := "/home/usuario/Lógica de Programação/"
	for nome in APOIO:
		_ok(SistemaArquivosVirtual.eh_arquivo(pasta + nome), "arquivo de apoio %s existe" % nome)
	_ok(SistemaArquivosVirtual.ler_texto(pasta + "aula_03_lacos.txt").contains("i += 2"), "aula_03_lacos.txt tem o exercício do laço")
	_ok(SistemaArquivosVirtual.ler_texto(pasta + "anotacoes_monitoria_marcos.txt").contains("casos de borda"), "anotacoes_monitoria_marcos.txt traz a dica do Marcos")
	var visiveis: Array = SistemaArquivosVirtual.listar(pasta)
	var nomes: Array = []
	for no in visiveis:
		nomes.append(str((no as Dictionary).get("nome", SistemaArquivosVirtual.nome_do_caminho(str((no as Dictionary).get("caminho", ""))))))
	_ok(not nomes.has("lista_03.txt"), "a lista 3 só aparece depois que a Maya a abre (T4.1)")
	GerenciadorEstado.set_flag("lista_3_aberta", true)
	nomes.clear()
	for no in SistemaArquivosVirtual.listar(pasta):
		nomes.append(str((no as Dictionary).get("nome", SistemaArquivosVirtual.nome_do_caminho(str((no as Dictionary).get("caminho", ""))))))
	_ok(nomes.has("lista_03.txt"), "...e aparece depois de lista_3_aberta")
	var rascunho: String = SistemaArquivosVirtual.ler_texto("/home/usuario/Rafael/outros_arquivos/rascunho_apresentacao.txt")
	_ok(rascunho.contains("Slide 1 - Introdução ao Projeto de Monitoria") and rascunho.contains("filtrando o que eu falo"), "rascunho_apresentacao.txt tem o conteúdo completo")
	var recusa: String = JSON.stringify(FluxoRoteiro.final_def("recusa_total"))
	_ok(recusa.contains("Lista_4_Logica_Resolvida.txt") and recusa.contains("permitir_cancelamento = true") and recusa.contains("mas fui eu quem fiz"), "o final Modo manual traz a Lista 4 e a nota de rodapé")
	_ok(recusa.contains("no máximo 1 permissão"), "...e as respostas obrigatórias dizem 'no máximo 1 permissão'")
	var texto_t11: String = JSON.stringify(_node("T1.1"))
	_ok(texto_t11.contains("Bem-vind{o/a}"), "T1.1 usa {o/a}")
	_igual(FluxoRoteiro.texto("cansad{o/a}"), "cansado", "{o/a} sem pronome (nome padrão) vira 'o'")
	_novo_jogo("Erika")
	_igual(FluxoRoteiro.texto("cansad{o/a}"), "cansada", "{o/a} com nome claramente feminino vira 'a'")


func _testar_minigame_2_ate_t9_5r() -> void:
	_secao("Minigame #2: disponível durante T9.5R; bloqueado pela Maya a partir de T9.6")
	_novo_jogo()
	GerenciadorEstado.set_flag("segredo_rafael_encontrado", true)
	var caminho := "/home/usuario/Rafael/bloco_de_notas_oculto.txt"
	var no_bloco: Dictionary = SistemaArquivosVirtual.obter_no(caminho)
	_ok(not no_bloco.is_empty() and str(no_bloco.get("abre_minigame", "")) == "trava_rafael", "o bloco oculto abre o Minigame #2")
	GerenciadorEstado.definir_task("task_9")
	GerenciadorEstado.definir_no_roteiro("T9.5R")
	_igual(str(SistemaArquivosVirtual.ao_abrir(caminho).get("minigame", "")), "trava_rafael", "em T9.5R o Minigame #2 ainda abre")
	GerenciadorEstado.definir_no_roteiro("T9.6")
	_igual(str(SistemaArquivosVirtual.ao_abrir(caminho).get("minigame", "")), "", "em T9.6 a Maya bloqueia o Minigame #2")


func _testar_ponte_com_o_backend_em_c() -> void:
	_secao("Ponte Godot ↔ C (schema_version 2): ids canônicos, tipos de flag, final e task no formato do C")
	var ligados: int = 0
	var ids_c: Dictionary = {}
	var arquivo := FileAccess.open("res://backend/bk_maya_v21.c", FileAccess.READ)
	if arquivo != null:
		var fonte: String = arquivo.get_as_text()
		arquivo.close()
		var re := RegEx.new()
		re.compile("strcmp\\(id, \"([a-z0-9_]+)\"\\)")
		for m in re.search_all(fonte):
			ids_c[m.get_string(1)] = true
	var todos_existem := true
	var raiz: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/narrativa/roteiro_v2.json"))
	for id_no in (raiz["nos"] as Dictionary):
		for o in (raiz["nos"][id_no] as Dictionary).get("opcoes", []):
			if (o as Dictionary).has("id_backend"):
				ligados += 1
				todos_existem = todos_existem and ids_c.has(str((o as Dictionary)["id_backend"]))
	_ok(ligados >= 40, "o roteiro liga %d opções a ids do backend" % ligados)
	if not ids_c.is_empty():
		_ok(todos_existem, "todo `id_backend` do roteiro existe na matriz do backend (bk_maya_v21.c)")
	_novo_jogo("Erika", "ela")
	GerenciadorEstado.definir_task("task_6")
	GerenciadorEstado.set_flag("entrega_modo", "revisao")
	GerenciadorEstado.set_flag("t3_resposta", "por_que_acessou")
	GerenciadorEstado.set_flag("mural_publicacao", "apagada")
	GerenciadorEstado.set_flag("maya_pedidos:permissao_contatos", 3)   # flag que o backend não conhece: não vai ao arquivo
	Permissoes.permitir("permissao_contatos", 0)
	var estado: Dictionary = EstadoJogoBackend.criar_v21("t4_3_revisao")
	var v: Dictionary = EstadoJogoBackend.validar(estado)
	_ok(bool(v["ok"]), "o estado v2.1 do jogo passa na validação: %s" % str(v["erros"]))
	var fl: Dictionary = estado["flags"]
	_igual(int(estado["task_atual"]), 6, "task_atual é numérico (task_6 → 6)")
	_igual(int(fl["entrega_modo"]), 3, "entrega_modo 'revisao' vira o número 3 do C")
	_igual(int(fl["t3_resposta"]), 2, "t3_resposta 'por_que_acessou' vira 2")
	_igual(int(fl["mural_publicacao"]), 2, "mural_publicacao 'apagada' vira 2")
	_ok(not fl.has("maya_pedidos:permissao_contatos"), "flags desconhecidas pelo backend não vão ao arquivo")
	_igual(str(estado["final"]), "NENHUM", "sem final, o campo final é NENHUM")
	_igual(str(estado["genero"]), "feminino", "o gênero vem do pronome do jogo")
	_igual(int(estado["permissoes_ativas"]), 1, "permissoes_ativas vem do serviço central")
	_igual(bool(estado["rafael_investigacao_profunda"]), false, "a investigação profunda vem do serviço central (não é recalculada)")
	for nome in GerenciadorEstado.FLAGS_RAFAEL:
		GerenciadorEstado.definir_flag_roteiro(nome, true)
	_ok(bool(EstadoJogoBackend.criar_v21("t7_3_abrir_pasta")["rafael_investigacao_profunda"]), "com as quatro flags a investigação profunda é verdadeira")
	GerenciadorEstado.final_id = "recusa_total"
	_igual(str(EstadoJogoBackend.criar_v21("t9_6_nao")["final"]), "RECUSA_TOTAL", "o final vem de final_id e usa o id do backend")
	GerenciadorEstado.final_id = ""
	# ida e volta pelo arquivo: grava, lê e aplica pelos serviços do jogo
	var antes_caminho: String = EstadoJogoBackend.caminho_ativo
	var pasta: String = _pasta_de_teste("ponte_v21")
	var destino: String = pasta + "/estado_jogo.json"
	GerenciadorConfiguracoes.definir("usar_backend_json", true, false)
	var gravou: Dictionary = EstadoJogoBackend.registrar_escolha_v21("t4_3_revisao", destino)
	_ok(bool(gravou["ok"]), "com a ponte ligada o estado v2.1 é gravado (%s)" % str(gravou.get("erro", "")))
	_igual(str(EstadoJogoBackend.registrar_escolha_v21("", destino)["motivo"]), "sem_id_backend", "opção sem id canônico não grava nada")
	GerenciadorConfiguracoes.definir("usar_backend_json", false, false)
	_igual(str(EstadoJogoBackend.registrar_escolha_v21("t4_3_revisao", destino)["motivo"]), "ponte_desligada", "com a ponte desligada nada é gravado")
	var lido: Dictionary = EstadoJogoBackend.ler(destino)
	_ok(bool(lido["ok"]) and int(lido["estado"]["schema_version"]) == 2, "o arquivo gravado é lido e validado como schema 2")
	_novo_jogo()
	GerenciadorEstado.definir_task("task_6")
	var ap: Dictionary = EstadoJogoBackend.aplicar_ao_jogo(lido["estado"])
	_ok(bool(ap["ok"]), "aplicar_ao_jogo aceita o estado do arquivo")
	_ok(Permissoes.valor("permissao_contatos"), "a permissão vem pelo serviço Permissoes")
	_igual(str(GerenciadorEstado.valor_flag("entrega_modo", "")), "revisao", "a enumeração volta como texto do jogo (revisao)")
	_igual(str(GerenciadorEstado.valor_flag("mural_publicacao", "")), "apagada", "mural_publicacao volta como 'apagada'")
	_igual(GerenciadorEstado.task_atual, "task_6", "task_atual do jogo NÃO é sobrescrita pelo arquivo")
	EstadoJogoBackend.caminho_ativo = antes_caminho
	await get_tree().process_frame
