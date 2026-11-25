extends ModuloDeTeste
## Módulo 11: layout do Painel da Maya com TODOS os botões do topo ("Fechar janelas", "Pedir dica", "Abrir o Mensageiro", "Abrir o histórico antigo").
## Regressão de um defeito real: depois que a Maya ganha acesso ao Mensageiro a linha de botões ficava mais larga que a janela, o conteúdo
## crescia para os dois lados e era cortado na esquerda e na direita, sem como o jogador consertar sem redimensionar a janela.
## Agora a linha rola de lado e o resto do painel (cabeçalho, mensagens, caixa de entrada) nunca muda de largura nem de espaçamento.

const CENA_MAYA := "res://features/apps/maya/scenes/app_maya.tscn"
## Larguras testadas: a mínima da janela (420), a padrão (560) e uma bem larga (900). Alturas: mínima e padrão.
const TAMANHOS: Array = [Vector2(420, 460), Vector2(560, 640), Vector2(900, 700)]

var _altura_acoes: Array = []


func executar(banca_do_executor: BancaDeTestes) -> void:
	banca = banca_do_executor
	_isolar_configuracoes()
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)
	_novo_jogo()
	for t in TAMANHOS:
		await _testar_tamanho(t as Vector2)
	_secao("Painel da Maya: a altura da linha de botões é a mesma com e sem rolagem (nada pula de lugar)")
	_ok(_altura_acoes.size() == TAMANHOS.size(), "medida nas três larguras")
	var iguais: bool = true
	for h in _altura_acoes:
		iguais = iguais and absf(float(h) - float(_altura_acoes[0])) < 0.5
	_ok(iguais, "altura da linha igual em 420, 560 e 900 px (%s): as mensagens não mudam de lugar" % ", ".join(PackedStringArray(_altura_acoes.map(func(h): return "%.0f" % h))))
	_restaurar_configuracoes()
	await get_tree().process_frame


func _montar(tam: Vector2) -> Array:
	var host := Control.new()
	host.custom_minimum_size = tam
	host.size = tam
	add_child(host)
	var maya: AppMaya = (load(CENA_MAYA) as PackedScene).instantiate() as AppMaya
	host.add_child(maya)
	maya.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	# o pior caso do jogo: os 4 botões visíveis, com os textos mais compridos que o jogo usa
	(maya.find_child("BotaoFecharJanelas", true, false) as Button).visible = true
	(maya.find_child("BotaoFecharJanelas", true, false) as Button).text = "Continuar com a Maya"
	(maya.find_child("BotaoPedirDica", true, false) as Button).visible = true
	(maya.find_child("BotaoAbrirMensageiro", true, false) as Button).visible = true
	(maya.find_child("BotaoAbrirMensageiro", true, false) as Button).text = "Abrir o desafio de lógica"
	var hist: Button = maya.find_child("BotaoAbrirHistorico", true, false) as Button
	if hist != null:
		hist.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	return [host, maya]


func _dentro(interno: Rect2, externo: Rect2) -> bool:
	return interno.position.x >= externo.position.x - 0.5 and interno.end.x <= externo.end.x + 0.5


func _testar_tamanho(tam: Vector2) -> void:
	_secao("Painel da Maya com os 4 botões em %d x %d px" % [int(tam.x), int(tam.y)])
	var par: Array = await _montar(tam)
	var host: Control = par[0]
	var maya: AppMaya = par[1]
	var raiz: Control = maya.find_child("Raiz", true, false) as Control
	var rolagem: ScrollContainer = maya.find_child("RolagemAcoes", true, false) as ScrollContainer
	var acoes: Control = maya.find_child("AreaDeAcoes", true, false) as Control
	_ok(raiz != null and rolagem != null and acoes != null, "a cena tem Raiz, RolagemAcoes e AreaDeAcoes")
	if raiz == null or rolagem == null or acoes == null:
		host.free()
		return
	var quadro := Rect2(Vector2.ZERO, tam)
	var hist: Button = maya.find_child("BotaoAbrirHistorico", true, false) as Button
	_ok(hist != null, "o botão 'Abrir o histórico antigo' existe")
	var botoes: Array = [maya.find_child("BotaoFecharJanelas", true, false), maya.find_child("BotaoPedirDica", true, false), maya.find_child("BotaoAbrirMensageiro", true, false), hist]

	if raiz.get_combined_minimum_size().x > tam.x - 24.0 + 0.5:
		var larguras: Array = []
		for n in raiz.find_children("*", "Control", true, false):
			larguras.append([(n as Control).get_combined_minimum_size().x, str(raiz.get_path_to(n))])
		larguras.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
		for i in mini(6, larguras.size()):
			_info("mais largos: %.0f px  %s" % [float(larguras[i][0]), str(larguras[i][1])])
	# 1) o conteúdo nunca exige mais largura do que a janela tem
	_ok(raiz.get_combined_minimum_size().x <= tam.x - 24.0 + 0.5, "o conteúdo pede só %.0f px de largura (a janela dá %.0f): a linha de botões não alarga o painel" % [raiz.get_combined_minimum_size().x, tam.x - 24.0])
	_perto(raiz.position.x, 12.0, "o conteúdo continua com a margem esquerda de 12 px (nada empurrado para fora)", 0.5)
	_perto(raiz.size.x, tam.x - 24.0, "...e ocupa exatamente a largura da janela, sem sobrar para os lados", 0.5)
	for nome in ["Cabecalho", "AreaDeDialogo", "RolagemAcoes", "CaixaEntrada", "BotaoFecharPainel", "Avatar"]:
		var n: Control = maya.find_child(nome, true, false) as Control
		_ok(n != null and _dentro(n.get_global_rect(), quadro), "%s fica inteiro dentro da janela" % nome)

	# 2) o cabeçalho e as mensagens têm o mesmo espaçamento em qualquer largura
	var dialogo: Control = maya.find_child("AreaDeDialogo", true, false) as Control
	_perto(dialogo.size.x, raiz.size.x, "a área de mensagens ocupa toda a largura útil (espaçamento das mensagens intacto)", 0.5)
	_altura_acoes.append(rolagem.size.y)

	# 3) rolagem lateral: aparece só quando precisa e todos os botões são alcançáveis
	var barra: HScrollBar = rolagem.get_h_scroll_bar()
	var precisa: bool = acoes.get_combined_minimum_size().x > rolagem.size.x + 0.5
	_igual(barra.max_value > barra.page + 0.5, precisa, "a rolagem lateral existe quando os botões não cabem (largura dos botões %.0f, visível %.0f)" % [acoes.get_combined_minimum_size().x, rolagem.size.x])
	if tam.x <= 420.0:
		_ok(precisa, "na largura mínima os 4 botões NÃO cabem juntos: a rolagem é necessária")
	if tam.x >= 900.0:
		_ok(not precisa, "numa janela larga os 4 botões cabem: sem rolagem")
	var todos_alcancaveis: bool = true
	for b in botoes:
		if b == null:
			continue
		rolagem.ensure_control_visible(b as Control)
		await get_tree().process_frame
		await get_tree().process_frame
		var r: Rect2 = (b as Control).get_global_rect()
		if not _dentro(r, rolagem.get_global_rect()):
			todos_alcancaveis = false
			_info("botão '%s' fora da área visível: %s contra %s" % [(b as Button).text, str(r), str(rolagem.get_global_rect())])
	_ok(todos_alcancaveis, "cada um dos 4 botões pode ser trazido por inteiro para a área visível")
	rolagem.scroll_horizontal = 0
	await get_tree().process_frame
	var primeiro: Control = botoes[0] as Control
	_ok(_dentro(primeiro.get_global_rect(), rolagem.get_global_rect()), "com a rolagem no começo o primeiro botão está inteiro à vista")

	# 4) roda do mouse e teclado
	if precisa:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		rolagem.gui_input.emit(ev)
		_ok(rolagem.scroll_horizontal > 0, "a roda do mouse sobre a linha rola de lado")
		var ev2 := InputEventMouseButton.new()
		ev2.button_index = MOUSE_BUTTON_WHEEL_UP
		ev2.pressed = true
		var antes: int = rolagem.scroll_horizontal
		rolagem.gui_input.emit(ev2)
		_ok(rolagem.scroll_horizontal < antes, "...e de volta com a roda para cima")
		rolagem.scroll_horizontal = 0
		hist.grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(_dentro(hist.get_global_rect(), rolagem.get_global_rect()), "foco por teclado no último botão o leva à vista sozinho")
	_ok(rolagem.follow_focus, "a rolagem segue o foco do teclado")

	# 5) texto longo do papel não alarga o cabeçalho
	var papel: Label = maya.find_child("RotuloPapel", true, false) as Label
	papel.text = "Controle prioritário ativo — monitoramento de contexto e de decisões em andamento"
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(raiz.get_combined_minimum_size().x <= tam.x - 24.0 + 0.5, "um texto de papel muito longo é cortado com reticências e não alarga o painel")
	_ok(_dentro((maya.find_child("BotaoFecharPainel", true, false) as Control).get_global_rect(), quadro), "...e o botão Fechar continua à vista")

	await _capturar(maya, tam)
	host.free()


## Guarda uma imagem do painel (só na janela do editor) para conferência visual: user://nexus_os_teste/layout_painel_maya_<largura>.png
func _capturar(maya: AppMaya, tam: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var host: Node = maya.get_parent()
	var vp := SubViewport.new()
	vp.size = Vector2i(tam)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	host.remove_child(maya)
	vp.add_child(maya)
	maya.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://nexus_os_teste"))
		img.save_png("user://nexus_os_teste/layout_painel_maya_%d.png" % int(tam.x))
	vp.remove_child(maya)
	host.add_child(maya)
	vp.free()
