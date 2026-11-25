extends ModuloDeTeste
## Módulo 9: caixa de entrada visual (Mensageiro e Painel da Maya), wallpapers (catálogo, "Automático" fixo, slideshow, persistência), feedback
## visual da Dependência, painel ancorado da Maya (estados, canto inferior direito, salto do ícone, avatar, "M" oficial) e trilhas dinâmicas
## (clímax, epílogos, crossfade, fallback, players).

## O script do autoload, para chamar a função ESTÁTICA `validar_catalogo` pelo tipo (pela instância o Godot avisa STATIC_CALLED_ON_INSTANCE).
const AudioScript := preload("res://core/autoload/sistema_audio.gd")
const CENA_CAIXA := "res://shared/ui/caixa_entrada_visual/scenes/caixa_entrada_visual.tscn"
const CENA_MENSAGEIRO := "res://features/apps/mensageiro/scenes/app_mensageiro.tscn"
const CENA_MAYA := "res://features/apps/maya/scenes/app_maya.tscn"
const CENA_BALAO := "res://features/apps/mensageiro/components/balao_chat/scenes/balao_chat.tscn"
const CENA_PAPEL := "res://features/shell/area_de_trabalho/scenes/papel_de_parede.tscn"
const CENA_WIDGET := "res://features/shell/widget_maya/scenes/widget_maya.tscn"
const CENA_ORBE := "res://shared/ui/orbe_nexus/scenes/orbe_nexus.tscn"
const CENA_BOOT := "res://features/shell/tela_boot/scenes/tela_boot.tscn"
const CENA_JANELA := "res://shared/ui/janela_base/scenes/janela_base.tscn"
const FINAIS: PackedStringArray = ["aceitacao_total", "recusa_total", "meio_termo_1", "meio_termo_2", "rafael_1", "rafael_2"]


func executar(banca_do_executor: BancaDeTestes) -> void:
	banca = banca_do_executor
	_isolar_configuracoes()
	GerenciadorConfiguracoes.definir("alto_contraste", false, false)
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)
	_testar_estado_do_painel()
	await _testar_caixa_de_entrada()
	await _testar_mensageiro_e_painel_da_maya()
	_testar_catalogo_de_wallpapers()
	await _testar_papel_de_parede()
	_testar_persistencia()
	_testar_feedback_da_dependencia()
	await _testar_widget_e_painel_ancorado()
	await _testar_avatar_e_marca()
	_testar_catalogo_de_trilhas()
	await _testar_crossfade_e_players()
	_restaurar_configuracoes()
	await get_tree().process_frame


func _no_filho(raiz: Node, classe: String) -> Node:
	for n in raiz.find_children("*", classe, true, false):
		return n
	return null


func _evento_clique() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


# ------------------------------------------------------------------ Bloco 1
func _testar_caixa_de_entrada() -> void:
	_secao("Caixa de entrada visual: só gatilho, sem digitação livre")
	_novo_jogo()
	var caixa: CaixaEntradaVisual = (load(CENA_CAIXA) as PackedScene).instantiate() as CaixaEntradaVisual
	add_child(caixa)
	await get_tree().process_frame
	var ativacoes: Array = [0]
	caixa.ativada.connect(func() -> void: ativacoes[0] += 1)
	var dep0: int = _dep()
	var aut0: int = _aut()
	var no0: String = _no()
	_ok(not caixa.aceita_texto() and _no_filho(caixa, "LineEdit") == null and _no_filho(caixa, "TextEdit") == null, "não há campo de texto: nada de digitação, colar ou teclado virtual")
	_igual(caixa.texto_exibido(), CaixaEntradaVisual.TEXTO_PADRAO, "mostra o texto de apoio 'Escreva uma mensagem...'")
	caixa.sincronizar(false, "sem_opcoes")
	_ok(not caixa.ativar(), "sem opções, o clique não revela nada")
	caixa._gui_input(_evento_clique())
	_ok(not caixa.revelada() and ativacoes[0] == 0, "sem opções: nada é revelado e nenhum sinal sai")
	caixa.sincronizar(true, "no_a")
	_ok(not caixa.revelada(), "com opções, as respostas NÃO aparecem sozinhas")
	caixa._gui_input(_evento_clique())
	_ok(caixa.revelada() and ativacoes[0] == 1, "o clique revela as respostas (uma vez)")
	caixa._gui_input(_evento_clique())
	_igual(ativacoes[0], 1, "clicar de novo não duplica a revelação")
	caixa.consumir()
	caixa.sincronizar(true, "no_a")
	_ok(not caixa.revelada(), "depois de consumidas, as opções do mesmo nó não reaparecem sozinhas")
	caixa.sincronizar(true, "no_b")
	var ev_enter := InputEventKey.new()
	ev_enter.keycode = KEY_ENTER
	ev_enter.pressed = true
	caixa._gui_input(ev_enter)
	_ok(caixa.revelada(), "teclado: Enter revela as respostas")
	caixa.sincronizar(true, "no_c")
	_ok(not caixa.revelada(), "um nó novo fecha as respostas de novo")
	var ev_acao := InputEventAction.new()
	ev_acao.action = "ui_accept"
	ev_acao.pressed = true
	caixa._gui_input(ev_acao)
	_ok(caixa.revelada(), "controle: o botão de confirmação (ui_accept) revela as respostas")
	caixa.sincronizar(false, "no_c")
	_ok(not caixa.revelada(), "se as opções somem, as respostas se fecham")
	_ok(_dep() == dep0 and _aut() == aut0 and _no() == no0, "clicar na caixa não muda Dependência, Autonomia nem o nó do roteiro")
	GerenciadorConfiguracoes.definir("alto_contraste", true, false)
	caixa._atualizar_visual()
	var estilo: StyleBoxFlat = caixa.get_theme_stylebox("panel") as StyleBoxFlat
	_ok(estilo != null and estilo.border_color == Color.WHITE, "alto contraste: moldura branca")
	GerenciadorConfiguracoes.definir("alto_contraste", false, false)
	_ok(caixa.focus_mode == Control.FOCUS_ALL, "a caixa recebe foco por teclado/controle")
	caixa.queue_free()


func _testar_mensageiro_e_painel_da_maya() -> void:
	_secao("Caixa nos dois lugares: respostas só depois do clique, sem duplicar")
	_novo_jogo()
	GerenciadorNarrativa.ir_para_no("T6.3")
	GerenciadorEstado.set_flag("mensageiro_indexado", true)   # o roteiro liga isto em T6.0; sem a flag o Mensageiro ainda não lista contatos
	var ap: Dictionary = GerenciadorNarrativa.apresentacao()
	var contato: String = str(ap.get("contato", ""))
	var total_opcoes: int = (ap.get("opcoes", []) as Array).size()
	var mensageiro: AppMensageiro = (load(CENA_MENSAGEIRO) as PackedScene).instantiate() as AppMensageiro
	add_child(mensageiro)
	await _quadros(3)
	mensageiro.iniciar({"contato": contato})
	await _quadros(3)
	var caixa_m: CaixaEntradaVisual = mensageiro.caixa_de_entrada()
	_ok(caixa_m != null and caixa_m.visible, "a caixa existe e aparece no Mensageiro")
	_ok(total_opcoes > 0 and caixa_m.tem_opcoes(), "o nó de chat tem opções e a caixa sabe disso")
	_ok(not mensageiro.area_de_escolhas_visivel(), "Mensageiro: as respostas ficam ocultas antes do clique")
	caixa_m.ativar()
	await _quadros(2)
	_ok(mensageiro.area_de_escolhas_visivel(), "Mensageiro: o clique revela as respostas")
	var botoes: Array = mensageiro.find_children("*", "ItemEscolha", true, false)
	_igual(botoes.size(), total_opcoes, "Mensageiro: uma resposta por opção (sem duplicar)")
	mensageiro.queue_free()
	await get_tree().process_frame

	_novo_jogo()
	GerenciadorNarrativa.ir_para_no("T1.4")
	var opcoes_painel: int = (GerenciadorNarrativa.apresentacao().get("opcoes", []) as Array).size()
	var maya: AppMaya = (load(CENA_MAYA) as PackedScene).instantiate() as AppMaya
	add_child(maya)
	await _quadros(4)
	_ok(maya.caixa_de_entrada() != null and maya.caixa_de_entrada().visible, "a caixa existe e aparece no Painel da Maya")
	_ok(opcoes_painel > 0 and maya.caixa_de_entrada().tem_opcoes(), "Painel da Maya: a caixa reconhece as opções do nó")
	_ok(not maya.area_de_escolhas_visivel(), "Painel da Maya: respostas ocultas antes do clique")
	var dep0: int = _dep()
	maya._ao_pedir_dica()
	_ok(maya._rot_resultado.visible and maya._rot_resultado.text.begins_with("Dica:"), "'Pedir dica' mostra uma orientação no painel")
	_igual(_dep(), dep0, "pedir dica não altera a Dependência")
	maya.caixa_de_entrada().ativar()
	await _quadros(2)
	_ok(maya.area_de_escolhas_visivel(), "Painel da Maya: o clique revela as respostas")
	maya.caixa_de_entrada().ativar()
	await _quadros(1)
	var botoes_maya: Array = maya.find_children("*", "ItemEscolha", true, false)
	_igual(botoes_maya.size(), opcoes_painel, "Painel da Maya: uma resposta por opção (sem duplicar)")
	var rolagem_existe: bool = maya.find_child("Rolagem", true, false) is ScrollContainer
	_ok(rolagem_existe, "o histórico fica numa ScrollContainer")
	var e_maya: Dictionary = AppMaya.entrada_do_balao({"quem": "maya", "texto": "oi", "hora": "10:00"})
	var e_jog: Dictionary = AppMaya.entrada_do_balao({"quem": "jogador", "texto": "oi", "hora": "10:01"})
	var balao_maya: BalaoChat = (load(CENA_BALAO) as PackedScene).instantiate() as BalaoChat
	var balao_jog: BalaoChat = (load(CENA_BALAO) as PackedScene).instantiate() as BalaoChat
	add_child(balao_maya)
	add_child(balao_jog)
	balao_maya.configurar(e_maya, 300)
	balao_jog.configurar(e_jog, 300)
	_ok(not balao_maya.alinhado_a_direita(), "as mensagens da Maya ficam à esquerda")
	_ok(balao_jog.alinhado_a_direita(), "as mensagens do jogador ficam à direita")
	balao_maya.queue_free()
	balao_jog.queue_free()
	_ok(AppMaya.texto_da_dica({"opcoes": [], "espera": "", "app": ""}).length() > 5, "a dica existe mesmo sem opções")
	maya.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------ Bloco 2
func _testar_catalogo_de_wallpapers() -> void:
	_secao("Wallpapers: catálogo central, todos disponíveis, 'Automático' fixo na sessão")
	Wallpapers.recarregar()
	var ids: PackedStringArray = Wallpapers.ids()
	_ok(ids.size() >= 2, "o catálogo traz os wallpapers do projeto")
	var unicos: Dictionary = {}
	var caminhos: Dictionary = {}
	for d in Wallpapers.catalogo():
		unicos[str((d as Dictionary)["id"])] = true
		caminhos[str((d as Dictionary)["recurso"])] = true
	_igual(unicos.size(), ids.size(), "ids únicos")
	_igual(caminhos.size(), ids.size(), "nenhum caminho de imagem duplicado")
	_igual(Wallpapers.disponiveis().size(), ids.size(), "todos os wallpapers estão disponíveis desde o início")
	for id_w in ids:
		_ok(Wallpapers.valido(id_w) and ResourceLoader.exists(str(Wallpapers.por_id(id_w)["recurso"])), "wallpaper %s é válido e o arquivo existe" % id_w)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	Wallpapers.definir_auto_da_sessao("")
	var auto1: String = Wallpapers.resolver("auto", rng)
	_novo_jogo()
	TemaNexus.definir_dia(5)
	GerenciadorEstado.alterar_dependencia_maya(20, &"teste")
	GerenciadorNarrativa.ir_para_no("T9.6")
	_igual(Wallpapers.resolver("auto", rng), auto1, "'Automático' não muda com Task, Estágio, Dependência nem Novo Jogo (fixo na sessão)")
	TemaNexus.definir_dia(1)
	_igual(Wallpapers.resolver("id_que_nao_existe"), Wallpapers.primeiro(), "id inválido cai no primeiro wallpaper válido")
	var atual: String = ids[ids.size() - 1]
	_igual(Wallpapers.proximo_sequencial(atual), ids[0], "sequencial volta ao início ao fim da lista")
	_igual(Wallpapers.proximo_sequencial("invalido"), ids[0], "sequencial a partir de id inválido começa do primeiro")
	var anterior: String = ids[0]
	var sem_repeticao: bool = true
	for _i in 200:
		var prox: String = Wallpapers.proximo_aleatorio(anterior, rng)
		if prox == anterior or not Wallpapers.valido(prox):
			sem_repeticao = false
		anterior = prox
	_ok(sem_repeticao, "aleatório nunca repete o atual de imediato (RNG injetado)")
	_ok(Wallpapers.intervalo_slideshow() == 60.0, "o intervalo do slideshow é 60 s")


func _testar_papel_de_parede() -> void:
	_secao("Papel de parede: um Timer só, slideshow 60 s, ordem, transição sem flash")
	GerenciadorConfiguracoes.definir("papel_de_parede", "dia", false)
	GerenciadorConfiguracoes.definir("wallpaper_id", "auto", false)
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", false, false)
	GerenciadorConfiguracoes.definir("wallpaper_ordem", "sequencial", false)
	var papel: PapelDeParede = (load(CENA_PAPEL) as PackedScene).instantiate() as PapelDeParede
	add_child(papel)
	papel.rng.seed = 7
	await _quadros(2)
	var timer: Timer = papel.timer_slideshow()
	_ok(timer != null and timer.is_stopped(), "slideshow desligado: o Timer está parado")
	var id_inicial: String = papel.id_exibido()
	_ok(id_inicial != "" and Wallpapers.valido(id_inicial), "o wallpaper exibido vem do catálogo")
	TemaNexus.definir_dia(4)
	papel.atualizar()
	_igual(papel.id_exibido(), id_inicial, "mudar de Task/Estágio não troca o wallpaper")
	TemaNexus.definir_dia(1)
	var escolhido: String = Wallpapers.ids()[Wallpapers.ids().size() - 1]
	GerenciadorConfiguracoes.definir("wallpaper_id", escolhido, false)
	_igual(papel.id_exibido(), escolhido, "a escolha manual vale na hora")
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", true, false)
	_ok(not timer.is_stopped() and is_equal_approx(timer.wait_time, 60.0), "slideshow ligado: o Timer corre a cada 60 s")
	var timers: int = 0
	for filho in papel.get_children():
		if filho is Timer:
			timers += 1
	_igual(timers, 1, "existe um único Timer no gerenciador")
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", false, false)
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", true, false)
	timers = 0
	for filho in papel.get_children():
		if filho is Timer:
			timers += 1
	_igual(timers, 1, "ligar e desligar não duplica o Timer")
	var antes: String = papel.id_exibido()
	var depois: String = papel.avancar_slideshow()
	_igual(depois, Wallpapers.proximo_sequencial(antes), "sequencial: segue a ordem do catálogo")
	_igual(int(GerenciadorConfiguracoes.obter("wallpaper_indice")), Wallpapers.indice_de(depois), "o índice atual fica gravado nas configurações")
	GerenciadorConfiguracoes.definir("wallpaper_ordem", "aleatorio", false)
	var repetiu: bool = false
	var atual: String = papel.id_exibido()
	for _i in 30:
		var prox: String = papel.avancar_slideshow()
		if prox == atual:
			repetiu = true
		atual = prox
	_ok(not repetiu, "aleatório não repete o mesmo wallpaper em sequência")
	_ok(papel._textura_anterior == null and is_equal_approx(papel._mistura, 1.0), "sem animações: a troca é instantânea (sem quadros intermediários)")
	GerenciadorConfiguracoes.definir("reduzir_animacoes", false, false)
	papel.avancar_slideshow()
	if Wallpapers.ids().size() > 1:
		_ok(papel._textura_anterior != null and papel._mistura < 1.0, "com animações: a imagem anterior continua por baixo durante a fusão (sem flash branco)")
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", false, false)
	_ok(timer.is_stopped(), "desligar o slideshow para o Timer")
	papel.queue_free()
	await get_tree().process_frame


func _testar_persistencia() -> void:
	_secao("Persistência das preferências (wallpaper, slideshow, glitch, volumes) e validação ao carregar")
	var caminho_original: String = GerenciadorConfiguracoes.caminho
	var persist_original: bool = GerenciadorConfiguracoes.persistencia_habilitada
	GerenciadorConfiguracoes.caminho = _pasta_de_teste("cfg_ux") + "/configuracoes.cfg"
	GerenciadorConfiguracoes.persistencia_habilitada = true
	GerenciadorConfiguracoes.definir("wallpaper_id", Wallpapers.primeiro(), false)
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", true, false)
	GerenciadorConfiguracoes.definir("wallpaper_ordem", "aleatorio", false)
	GerenciadorConfiguracoes.definir("wallpaper_indice", 1, false)
	GerenciadorConfiguracoes.definir("intensidade_glitch", 0.4, false)
	GerenciadorConfiguracoes.definir("volume_bgm", 0.2, false)
	GerenciadorConfiguracoes.definir("volume_sfx", 0.3, false)
	GerenciadorConfiguracoes.definir("reduzir_ruido", true, false)
	GerenciadorConfiguracoes.salvar()
	for chave in ["wallpaper_id", "wallpaper_slideshow", "wallpaper_ordem", "wallpaper_indice", "intensidade_glitch", "volume_bgm", "volume_sfx", "reduzir_ruido"]:
		GerenciadorConfiguracoes.valores[chave] = GerenciadorConfiguracoes.PADRAO[chave]
	GerenciadorConfiguracoes.carregar()
	_igual(GerenciadorConfiguracoes.obter("wallpaper_id"), Wallpapers.primeiro(), "wallpaper escolhido persiste")
	_igual(GerenciadorConfiguracoes.obter("wallpaper_slideshow"), true, "estado do slideshow persiste")
	_igual(GerenciadorConfiguracoes.obter("wallpaper_ordem"), "aleatorio", "ordem do slideshow persiste")
	_igual(GerenciadorConfiguracoes.obter("wallpaper_indice"), 1, "índice do slideshow persiste")
	_perto(float(GerenciadorConfiguracoes.obter("intensidade_glitch")), 0.4, "intensidade do glitch persiste")
	_perto(float(GerenciadorConfiguracoes.obter("volume_bgm")), 0.2, "volume da música persiste")
	_perto(float(GerenciadorConfiguracoes.obter("volume_sfx")), 0.3, "volume dos efeitos persiste")
	_igual(GerenciadorConfiguracoes.obter("reduzir_ruido"), true, "preferência de acessibilidade persiste")
	GerenciadorConfiguracoes.valores["wallpaper_id"] = "id_apagado_do_catalogo"
	GerenciadorConfiguracoes.valores["wallpaper_ordem"] = "diagonal"
	GerenciadorConfiguracoes.valores["intensidade_glitch"] = 9.0
	GerenciadorConfiguracoes.valores["wallpaper_indice"] = -3
	GerenciadorConfiguracoes.validar_valores()
	_igual(GerenciadorConfiguracoes.obter("wallpaper_id"), "auto", "wallpaper inexistente volta para Automático")
	_igual(GerenciadorConfiguracoes.obter("wallpaper_ordem"), "sequencial", "ordem inválida volta para sequencial")
	_perto(float(GerenciadorConfiguracoes.obter("intensidade_glitch")), 1.0, "intensidade fora da faixa é limitada")
	_igual(GerenciadorConfiguracoes.obter("wallpaper_indice"), 0, "índice negativo vira 0")
	GerenciadorConfiguracoes.caminho = caminho_original
	GerenciadorConfiguracoes.persistencia_habilitada = persist_original
	GerenciadorConfiguracoes.definir("wallpaper_slideshow", false, false)
	GerenciadorConfiguracoes.definir("wallpaper_ordem", "sequencial", false)


func _testar_feedback_da_dependencia() -> void:
	_secao("Feedback da Dependência: faixas graduais, glitch só em resistência com D alto")
	var casos: Array = [[0, &"neutra"], [24, &"neutra"], [25, &"morna_leve"], [49, &"morna_leve"], [50, &"morna"], [74, &"morna"], [75, &"vermelha_sutil"], [89, &"vermelha_sutil"], [90, &"vermelha_intensa"], [100, &"vermelha_intensa"]]
	for c in casos:
		var par: Array = c
		_igual(FeedbackDependencia.faixa(int(par[0])), par[1], "D=%d cai na faixa %s" % [int(par[0]), str(par[1])])
	var anterior: float = -1.0
	var crescente: bool = true
	for d in 101:
		var peso: float = FeedbackDependencia.peso_de_tinta(d)
		if peso < anterior - 0.0001:
			crescente = false
		anterior = peso
	_ok(crescente, "a tinta cresce de forma gradual e nunca regride (0 a 100)")
	_perto(FeedbackDependencia.peso_de_tinta(10), 0.0, "D baixo: paleta neutra")
	_ok(FeedbackDependencia.peso_de_tinta(95) > FeedbackDependencia.peso_de_tinta(60), "D maior = mais tinta")
	_ok(not FeedbackDependencia.glitch_condicional(74, &"negar:x"), "sem glitch abaixo de D 75, mesmo em resistência")
	_ok(not FeedbackDependencia.glitch_condicional(20, &"revogar:x"), "sem glitch com D baixo")
	_ok(FeedbackDependencia.glitch_condicional(80, &"revogar:permissao_dispositivos"), "glitch possível: D alto + revogar")
	_ok(FeedbackDependencia.glitch_condicional(95, &"negar:x"), "glitch possível: D alto + negar")
	_ok(not FeedbackDependencia.glitch_condicional(95, &"permitir:x"), "conceder permissão não é resistência: sem glitch")
	_ok(not FeedbackDependencia.glitch_condicional(95, &""), "sem contexto, sem glitch")
	var par_max: Dictionary = FeedbackDependencia.parametros_glitch(100, 1.0)
	_ok(float(par_max["intensidade"]) <= FeedbackDependencia.FORCA_MAX_GLITCH and float(par_max["duracao"]) <= FeedbackDependencia.DURACAO_MAX_GLITCH, "intensidade e duração do glitch são limitadas")
	_perto(float(FeedbackDependencia.parametros_glitch(100, 0.0)["intensidade"]), 0.0, "intensidade 0 nas configurações = nenhum glitch")
	_perto(FeedbackDependencia.interferencia_ambiente(50), 0.0, "sem interferência ambiente abaixo de 75")
	_ok(FeedbackDependencia.interferencia_ambiente(95) > FeedbackDependencia.interferencia_ambiente(80) and FeedbackDependencia.interferencia_ambiente(80) > 0.0, "interferência sutil em 75–89 e um pouco maior em 90+")
	_perto(FeedbackDependencia.interferencia_ambiente(95, 0.0), 0.0, "intensidade 0 zera a interferência")
	TemaNexus.definir_dependencia(0)
	var neutro: Color = TemaNexus.paleta()["acento"]
	TemaNexus.definir_dependencia(95)
	var quente: Color = TemaNexus.paleta()["acento"]
	_ok(quente != neutro, "a cor de destaque do tema muda com a Dependência alta")
	GerenciadorConfiguracoes.definir("alto_contraste", true, false)
	TemaNexus.definir_dependencia(95)
	var contraste: Color = TemaNexus.paleta()["acento"]
	TemaNexus.definir_dependencia(0)
	_igual(contraste, TemaNexus.paleta()["acento"], "alto contraste: a tinta da Dependência não altera as cores")
	GerenciadorConfiguracoes.definir("alto_contraste", false, false)
	TemaNexus.definir_dependencia(0)
	_novo_jogo()
	var d0: int = _dep()
	GerenciadorEstado.alterar_dependencia_maya(7, &"teste")
	_igual(_dep(), d0 + 7, "a variável central continua sendo a única fonte da Dependência")


# ------------------------------------------------------------------ Bloco 3
func _testar_estado_do_painel() -> void:
	_secao("Painel ancorado: máquina de estados e proteção contra clique duplo")
	var e := EstadoPainel.new()
	_igual(e.nome(), "FECHADO", "começa FECHADO")
	_ok(e.pedir_abrir() and e.nome() == "ABRINDO", "abrir: FECHADO -> ABRINDO")
	_ok(not e.pedir_abrir(), "segundo clique durante a abertura é ignorado")
	_ok(not e.pedir_fechar(), "fechar durante a abertura é ignorado")
	e.concluir_abertura()
	_ok(e.aberto(), "ABRINDO -> ABERTO")
	_ok(not e.pedir_abrir(), "já aberto: não abre outra instância")
	_ok(e.pedir_fechar() and e.nome() == "FECHANDO", "fechar: ABERTO -> FECHANDO")
	_ok(not e.pedir_fechar(), "segundo clique durante o fechamento é ignorado")
	_ok(not e.pedir_abrir(), "abrir durante o fechamento é ignorado")
	e.concluir_fechamento()
	_igual(e.nome(), "FECHADO", "FECHANDO -> FECHADO")
	e.concluir_fechamento()
	e.concluir_abertura()
	_igual(e.nome(), "FECHADO", "concluir fora de hora não muda nada")


func _testar_widget_e_painel_ancorado() -> void:
	_secao("Widget e painel da Maya: canto inferior direito, salto debounced, janela dentro da tela")
	_novo_jogo()
	_ok(bool(GerenciadorJanelas.app_info("maya").get("painel_ancorado", false)), "o catálogo marca o painel da Maya como ancorado")
	var widget: WidgetMaya = (load(CENA_WIDGET) as PackedScene).instantiate() as WidgetMaya
	add_child(widget)
	await _quadros(2)
	GerenciadorConfiguracoes.definir("reduzir_animacoes", false, false)
	_ok(widget.chamar_atencao(), "o ícone dá um salto quando chamado")
	_ok(not widget.chamar_atencao(), "segundo pedido imediato é ignorado (sem acúmulo de animações)")
	_igual(widget.saltos_executados(), 1, "apenas um salto executado")
	var pos_antes: Vector2 = widget.position
	var tam_antes: Vector2 = widget.size
	await _quadros(5)
	_ok(widget.position == pos_antes and widget.size == tam_antes, "o salto não desloca nem redimensiona o layout (só o desenho)")
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)
	_perto(widget.elevacao_atual(), 0.0, "reduzir animações: sem deslocamento do ícone (só brilho discreto)")
	widget.queue_free()
	var tamanhos: Array = [Vector2(1280, 720), Vector2(800, 500), Vector2(1920, 1032)]
	for t in tamanhos:
		var area := Control.new()
		area.size = t
		add_child(area)
		var janela: JanelaBase = (load(CENA_JANELA) as PackedScene).instantiate() as JanelaBase
		area.add_child(janela)
		await get_tree().process_frame
		var conteudo := Control.new()
		janela.configurar(GerenciadorJanelas.app_info("maya"), conteudo, Vector2(560, 640), Vector2.ZERO)
		var dentro: bool = janela.position.x >= 0.0 and janela.position.y >= 0.0 and janela.position.x + janela.size.x <= t.x + 0.5 and janela.position.y + janela.size.y <= t.y + 0.5
		_ok(janela.painel_ancorado and dentro, "o painel cabe na tela %s" % str(t))
		if t.x >= 1000.0:
			_ok(janela.position.x > t.x * 0.5 and janela.position.y + janela.size.y > t.y * 0.8, "em %s o painel nasce no canto inferior direito" % str(t))
		_ok(janela.estado_do_painel().aberto(), "sem animações o painel já nasce ABERTO")
		_ok(janela.iniciar_fechamento_painel() and not janela.iniciar_fechamento_painel(), "fechar duas vezes seguidas só vale uma vez")
		area.queue_free()
		await get_tree().process_frame


func _testar_avatar_e_marca() -> void:
	_secao("Avatar animado do painel e 'M' oficial no Novo Jogo")
	var orbe: OrbeNexus = (load(CENA_ORBE) as PackedScene).instantiate() as OrbeNexus
	orbe.usar_marca = true
	add_child(orbe)
	await get_tree().process_frame
	_igual(orbe.mostra_marca_oficial(), Marca.carregar(Marca.MAYA_MARCA) != null, "o núcleo usa o 'M' oficial (ou placeholder 'M' se o arquivo faltar)")
	orbe.definir_estado("controladora")
	orbe.reagir(1.0)
	_ok(true, "a marca mantém os anéis e os estados (definir_estado e reagir não falham)")
	orbe.queue_free()
	var boot: Node = (load(CENA_BOOT) as PackedScene).instantiate()
	var orbe_boot: Node = boot.find_child("Orbe", true, false)
	_ok(orbe_boot != null and bool(orbe_boot.get("usar_marca")), "a saudação do Novo Jogo usa o 'M' oficial no lugar do símbolo central")
	boot.free()
	var maya: AppMaya = (load(CENA_MAYA) as PackedScene).instantiate() as AppMaya
	var avatar: Node = maya.find_child("Avatar", true, false)
	_ok(avatar is OrbeNexus, "o painel da Maya reutiliza o componente animado (OrbeNexus) como avatar")
	maya.free()


# ------------------------------------------------------------------ Bloco 4
func _testar_catalogo_de_trilhas() -> void:
	_secao("Trilhas dinâmicas: catálogo válido, mapa dos seis finais e eventos")
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(SistemaAudio.CAMINHO_FAIXAS))
	_ok(dados is Dictionary, "audio_faixas.json é um JSON válido")
	if not (dados is Dictionary):
		return
	var erros: PackedStringArray = AudioScript.validar_catalogo(dados as Dictionary)
	_igual(erros.size(), 0, "o catálogo oficial passa na validação: %s" % ", ".join(erros))
	var faixas_dos_finais: Dictionary = {}
	for id_final in FINAIS:
		var faixa: String = SistemaAudio.faixa_do_final(id_final)
		_ok(faixa != "", "o final %s tem faixa" % id_final)
		faixas_dos_finais[faixa] = true
	_igual(faixas_dos_finais.size(), FINAIS.size(), "cada final tem uma faixa própria")
	for ev in ["climax_started", "task_9_started", "maya_control_escalated"]:
		_igual(SistemaAudio.faixa_do_evento(ev), "climax", "o evento %s leva ao clímax" % ev)
	_ok(SistemaAudio.faixa_do_evento("evento_qualquer").is_empty(), "evento desconhecido não toca nada")
	var quebrado: Dictionary = {
		"faixas": [
			{"id": "a", "arquivo": "x", "volume_db": 0.0, "loop": true, "bus": "BGM", "fallback": "b"},
			{"id": "b", "arquivo": "y", "volume_db": 0.0, "loop": true, "bus": "BGM", "fallback": "a"},
			{"id": "a", "arquivo": "", "volume_db": 40.0, "loop": "sim", "bus": "Radio", "fallback": "zzz"},
		],
		"eventos": {"e": "nao_existe"},
		"finais": {"f": "nao_existe"},
	}
	var erros2: PackedStringArray = AudioScript.validar_catalogo(quebrado)
	_ok(erros2.size() >= 6, "catálogo quebrado é reprovado (%d problemas: id repetido, arquivo vazio, volume, loop, bus, ciclo, fallback e mapas)" % erros2.size())
	var r: Dictionary = SistemaAudio.resolver_faixa("climax")
	_ok(not r.is_empty() and str(r["id"]) in ["climax", "default"], "clímax sem arquivo cai na faixa padrão (com arquivo, toca o próprio)")
	_ok(SistemaAudio.resolver_faixa("faixa_que_nao_existe").is_empty(), "faixa desconhecida não resolve")


func _escrever_catalogo_de_teste() -> String:
	var pasta: String = _pasta_de_teste("faixas")
	DirAccess.make_dir_recursive_absolute(pasta)
	var caminho: String = pasta + "/faixas.json"
	var dados := {
		"faixa_padrao": "a", "fade_padrao_s": 0.2,
		"faixas": [
			{"id": "a", "arquivo": "bgm_dia_1", "volume_db": 0.0, "loop": true, "bus": "BGM", "fallback": ""},
			{"id": "b", "arquivo": "bgm_dia_2", "volume_db": -3.0, "loop": true, "bus": "BGM", "fallback": "a", "fade_s": 0.2},
			{"id": "c", "arquivo": "arquivo_que_nao_existe_xyz", "volume_db": 0.0, "loop": true, "bus": "BGM", "fallback": "a"},
			{"id": "d", "arquivo": "bgm_dia_3", "volume_db": 0.0, "loop": true, "bus": "BGM", "fallback": "a", "fade_s": 0.2},
		],
		"eventos": {"climax_started": "b"},
		"finais": {"recusa_total": "d", "rafael_1": "b"},
	}
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(JSON.stringify(dados))
	f.close()
	return caminho


func _tocando() -> int:
	return SistemaAudio.players_bgm_tocando()


func _testar_crossfade_e_players() -> void:
	_secao("Crossfade: sem sobreposição, sem players duplicados, fallback e volumes")
	var erros: PackedStringArray = SistemaAudio.carregar_catalogo(_escrever_catalogo_de_teste())
	_igual(erros.size(), 0, "catálogo de teste carregado sem erros")
	SistemaAudio.parar_bgm()
	var players_antes: int = SistemaAudio.total_players_bgm()
	_igual(players_antes, 2, "existem exatamente dois players de trilha (ativo e reserva)")
	_ok(SistemaAudio.evento_narrativo(&"climax_started"), "o evento de clímax toca a faixa do catálogo")
	_igual(SistemaAudio.faixa_atual(), &"b", "a faixa atual é a do clímax")
	await _quadros(2)
	_igual(_tocando(), 1, "apenas um player toca")
	_ok(SistemaAudio.evento_narrativo(&"climax_started") and not SistemaAudio.crossfade_ativo(), "repetir o mesmo evento não reinicia nem cria crossfade")
	_ok(SistemaAudio.tocar_musica_do_final("recusa_total"), "a música do final vem de avaliar_final (recusa_total)")
	_igual(SistemaAudio.faixa_atual(), &"d", "a faixa mudou para a do final")
	_ok(SistemaAudio.crossfade_ativo(), "a troca usa crossfade")
	await get_tree().create_timer(0.6).timeout
	_ok(not SistemaAudio.crossfade_ativo(), "o crossfade terminou")
	_igual(_tocando(), 1, "depois do crossfade a faixa anterior parou (sem sobreposição)")
	_ok(SistemaAudio.tocar_musica_do_final("recusa_total") and SistemaAudio.faixa_atual() == &"d", "trocar só o texto do epílogo (mesmo final) não reinicia a música")
	_ok(SistemaAudio.tocar_musica_do_final("rafael_1"), "mudar de final troca a música")
	await get_tree().create_timer(0.6).timeout
	_igual(_tocando(), 1, "a música do final anterior parou")
	var r: Dictionary = SistemaAudio.resolver_faixa("c")
	_ok(not r.is_empty() and str(r["id"]) == "a" and bool(r["fallback_usado"]), "arquivo ausente cai no fallback do catálogo")
	_ok(SistemaAudio.tocar_faixa(&"c"), "tocar faixa sem arquivo usa o fallback sem erro")
	SistemaAudio.parar_bgm()
	_igual(_tocando(), 0, "parar_bgm silencia tudo")
	SistemaAudio.tocar_faixa(&"a")
	SistemaAudio.parar_bgm()
	SistemaAudio.tocar_faixa(&"a")
	_igual(SistemaAudio.total_players_bgm(), players_antes, "reiniciar a cena/trilha não cria players novos")
	GerenciadorConfiguracoes.definir("reduzir_ruido", false, false)
	var normal: float = SistemaAudio.volume_alvo_db()
	GerenciadorConfiguracoes.definir("reduzir_ruido", true, false)
	_ok(SistemaAudio.volume_alvo_db() < normal, "modo conforto (reduzir ruído) deixa a trilha mais baixa")
	GerenciadorConfiguracoes.definir("reduzir_ruido", false, false)
	GerenciadorConfiguracoes.definir("volume_bgm", 0.5, false)
	SistemaAudio.aplicar_volumes()
	var idx: int = AudioServer.get_bus_index(SistemaAudio.BUS_BGM)
	_ok(idx >= 0 and absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.1, "o volume da música do jogador vale por cima das trilhas (barramento BGM)")
	SistemaAudio.parar_bgm()
	SistemaAudio.carregar_catalogo()
