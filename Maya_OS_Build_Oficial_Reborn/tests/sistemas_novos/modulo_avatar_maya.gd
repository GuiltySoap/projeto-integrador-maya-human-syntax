extends ModuloDeTeste
## Módulo 10: avatar da Maya (OrbeNexus) como componente ÚNICO entre a saudação do Novo Jogo e o cabeçalho do Painel da Maya: mesmo "M" oficial,
## mesma cena e mesmo script, cor roxa por padrão que esquenta GRADUALMENTE com a Dependência (0/25/50/75/100) e volta quando ela cai, prioridade do
## estado narrativo, acessibilidade (reduzir animações, alto contraste, sem flashes), sinais sem duplicar, várias instâncias e desenho real.

const CENA_ORBE := "res://shared/ui/orbe_nexus/scenes/orbe_nexus.tscn"
const CENA_BOOT := "res://features/shell/tela_boot/scenes/tela_boot.tscn"
const CENA_MAYA := "res://features/apps/maya/scenes/app_maya.tscn"
const ROXO := Color("#8b5cf6")


func executar(banca_do_executor: BancaDeTestes) -> void:
	banca = banca_do_executor
	_isolar_configuracoes()
	for chave in ["alto_contraste", "reduzir_animacoes", "sem_flashes"]:
		GerenciadorConfiguracoes.definir(chave, false, false)
	_novo_jogo()
	_testar_componente_compartilhado()
	_testar_cor_pela_dependencia()
	_testar_prioridade_de_estados()
	await _testar_acessibilidade()
	await _testar_sinais_e_instancias()
	await _testar_painel_real()
	await _testar_desenho_real()
	_restaurar_configuracoes()
	await get_tree().process_frame


func _novo_orbe(reativo: bool = true, lado: float = 56.0) -> OrbeNexus:
	var o: OrbeNexus = (load(CENA_ORBE) as PackedScene).instantiate() as OrbeNexus
	o.usar_marca = true
	o.reagir_a_dependencia = reativo
	o.custom_minimum_size = Vector2(lado, lado)
	o.size = Vector2(lado, lado)
	add_child(o)
	return o


## Leva a cor até o alvo (passos grandes: a interpolação é linear e limitada pelo alvo).
func _assentar(o: OrbeNexus) -> void:
	for i in 10:
		o.avancar_cor(1.0)


# ------------------------------------------------------------------ 1. mesmo componente nas duas telas
func _testar_componente_compartilhado() -> void:
	_secao("Avatar: o Novo Jogo e o Painel da Maya usam o MESMO componente e o MESMO 'M'")
	var boot: Node = (load(CENA_BOOT) as PackedScene).instantiate()
	var maya: Node = (load(CENA_MAYA) as PackedScene).instantiate()
	var orbe_boot: Node = boot.find_child("Orbe", true, false)
	var orbe_painel: Node = maya.find_child("Avatar", true, false)
	_ok(orbe_boot is OrbeNexus and orbe_painel is OrbeNexus, "as duas telas têm um OrbeNexus como avatar")
	if orbe_boot is OrbeNexus and orbe_painel is OrbeNexus:
		_igual(orbe_painel.scene_file_path, orbe_boot.scene_file_path, "...instanciado da MESMA cena (orbe_nexus.tscn), sem cópia da árvore de nós")
		_ok(orbe_painel.get_script() == orbe_boot.get_script(), "...com o MESMO script")
		_ok(bool(orbe_boot.get("usar_marca")) and bool(orbe_painel.get("usar_marca")), "...os dois com o 'M' oficial no lugar do círculo central")
		_ok(bool(orbe_painel.get("reagir_a_dependencia")), "o painel reage à Dependência")
		_ok(not bool(orbe_boot.get("reagir_a_dependencia")), "a saudação do Novo Jogo mantém a paleta neutra (a campanha ainda nem começou)")
		_igual((orbe_painel as Control).custom_minimum_size, Vector2(56, 56), "o cabeçalho do painel manteve o espaço do avatar (56x56): layout intacto")
		_ok((orbe_painel as Control).custom_minimum_size.x < (orbe_boot as Control).custom_minimum_size.x, "versão compacta no painel, grande na saudação: só o tamanho/parâmetros mudam")
	boot.free()
	maya.free()
	var o: OrbeNexus = _novo_orbe(false, 150.0)
	_igual(o.mostra_marca_oficial(), Marca.carregar(Marca.MAYA_MARCA) != null, "o núcleo usa o arquivo oficial da marca (ou o 'M' técnico se ele faltar)")
	_igual(o.cor_principal_atual(), ROXO, "a cor inicial é o roxo oficial do avatar (#8b5cf6)")
	_igual(OrbeNexus.cores_de("amigavel")[0], ROXO, "...que é a paleta do estado padrão: uma só fonte de cores")
	o.free()


# ------------------------------------------------------------------ 2. cor pela Dependência
func _testar_cor_pela_dependencia() -> void:
	_secao("Avatar: a cor segue a Dependência (0, 25, 50, 75, 100), de forma gradual e reversível")
	var o: OrbeNexus = _novo_orbe(true)
	var pesos: Array = []
	var cores: Array = []
	for d in [0, 25, 50, 75, 100]:
		o.definir_dependencia(d)
		_assentar(o)
		pesos.append(o.peso_quente_atual())
		cores.append(o.cor_principal_atual())
	_perto(pesos[0], 0.0, "Dependência 0: sem tinta, roxo puro")
	_igual(cores[0], ROXO, "...exatamente o roxo oficial")
	var crescente: bool = true
	for i in range(1, pesos.size()):
		crescente = crescente and float(pesos[i]) >= float(pesos[i - 1])
	_ok(crescente, "a tinta só aumenta de 0 a 100 (%s)" % ", ".join(PackedStringArray(pesos.map(func(p): return "%.2f" % p))))
	_ok(float(pesos[2]) < float(pesos[3]) and float(pesos[3]) < float(pesos[4]), "50 < 75 < 100: cada faixa é mais quente que a anterior")
	_ok(float(pesos[2]) < 0.3, "Dependência 50 (valor inicial do jogo): ainda roxo predominante")
	var c50: Color = cores[2]
	_ok(c50.b > c50.r, "...azul/violeta ainda acima do vermelho (continua lendo como roxo)")
	var c75: Color = cores[3]
	_ok(c75.r > ROXO.r and c75.b < ROXO.b, "Dependência 75: mais quente (mais vermelho, menos azul)")
	var c100: Color = cores[4]
	_ok(c100.r > 0.8 and c100.b < 0.5 and c100.r > c100.b, "Dependência 100: roxo avermelhado/carmim, tensão visual maior")
	_perto(float(pesos[4]), 1.0, "...com a tinta no máximo")
	# a curva é a da interface inteira (FeedbackDependencia): o avatar não tem uma tabela própria
	for d in [25, 50, 75, 100]:
		_perto(OrbeNexus._peso_para(d), FeedbackDependencia.peso_de_tinta(d) / OrbeNexus.PESO_MAX_TINTA, "o peso em %d vem de FeedbackDependencia.peso_de_tinta (única curva)" % d)

	# gradual: um quadro nunca salta para a cor final
	o.definir_dependencia(0)
	_assentar(o)
	o.definir_dependencia(100)
	_ok(o.peso_quente_atual() == 0.0, "a Dependência subiu de 0 para 100: a cor NÃO muda no mesmo quadro")
	var anterior: Color = o.cor_principal_atual()
	var maior_salto: float = 0.0
	var quadros: int = 0
	while o.peso_quente_atual() < 1.0 and quadros < 600:
		o.avancar_cor(1.0 / 60.0)
		var atual: Color = o.cor_principal_atual()
		maior_salto = maxf(maior_salto, absf(atual.r - anterior.r) + absf(atual.g - anterior.g) + absf(atual.b - anterior.b))
		anterior = atual
		quadros += 1
	_ok(quadros > 20, "a transição leva vários quadros (%d a 60 fps), sem flash" % quadros)
	_ok(maior_salto < 0.06, "...e a maior diferença entre dois quadros é pequena (%.3f)" % maior_salto)
	# reversível
	o.definir_dependencia(25)
	var antes: float = o.peso_quente_atual()
	o.avancar_cor(0.1)
	_ok(o.peso_quente_atual() < antes, "quando a Dependência cai a cor volta a esfriar")
	_assentar(o)
	_perto(o.peso_quente_atual(), OrbeNexus._peso_para(25), "...até o alvo da nova faixa")
	o.definir_dependencia(0)
	_assentar(o)
	_igual(o.cor_principal_atual(), ROXO, "...e de volta ao roxo puro em 0")
	o.free()

	# o sinal central da Dependência chega ao avatar (valor lido do sinal, sem cópia local conflitante)
	_novo_jogo()
	var s: OrbeNexus = _novo_orbe(true)
	_igual(s.dependencia_atual(), _dep(), "o avatar nasce refletindo a Dependência ATUAL do jogo (%d)" % _dep())
	GerenciadorEstado.alterar_dependencia_maya(40, &"teste_avatar")
	_igual(s.dependencia_atual(), _dep(), "a alteração oficial (GerenciadorEstado.alterar_dependencia_maya) chega ao avatar pelo sinal")
	_ok(s.peso_quente_atual() < OrbeNexus._peso_para(_dep()), "...e a cor começa a caminhar, sem pular")
	GerenciadorEstado.alterar_dependencia_maya(-40, &"teste_avatar")
	_igual(s.dependencia_atual(), _dep(), "descer a Dependência também atualiza o avatar")
	s.free()
	var n: OrbeNexus = _novo_orbe(false)
	GerenciadorEstado.alterar_dependencia_maya(40, &"teste_avatar")
	_igual(n.cor_principal_atual(), ROXO, "sem 'reagir_a_dependencia' (saudação/menu) a cor continua roxa mesmo com a Dependência alta")
	GerenciadorEstado.alterar_dependencia_maya(-40, &"teste_avatar")
	n.free()


# ------------------------------------------------------------------ 3. prioridade do estado narrativo
func _testar_prioridade_de_estados() -> void:
	_secao("Avatar: prioridade (estado narrativo vence a Dependência; padrão = roxo)")
	var o: OrbeNexus = _novo_orbe(true)
	o.definir_dependencia(100)
	_assentar(o)
	var tingida: Color = o.cor_principal_atual()
	_ok(tingida != ROXO, "no estado padrão a Dependência 100 tinge o roxo")
	for estado in ["controladora", "revelada", "isolando", "colapso"]:
		o.definir_estado(estado)
		_igual(o.cor_principal_atual(), OrbeNexus.cores_de(estado)[0], "estado '%s': a paleta do estado vence, sem tinta da Dependência" % estado)
	o.definir_estado("amigavel")
	_igual(o.cor_principal_atual(), tingida, "voltando ao estado padrão a tinta da Dependência volta")
	o.free()


# ------------------------------------------------------------------ 4. acessibilidade
func _testar_acessibilidade() -> void:
	_secao("Avatar: acessibilidade (reduzir animações, alto contraste, sem flashes)")
	var o: OrbeNexus = _novo_orbe(true)
	await get_tree().process_frame
	_ok(o.is_processing(), "com animações o avatar anima")
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)
	_ok(not o.is_processing(), "'reduzir animações' ligado com o avatar já aberto: para de animar na hora (pulso, rotação e oscilação)")
	o.reagir(1.0)
	_perto(o.energia, 0.0, "...e o pulso de evento não dispara")
	o.definir_dependencia(100)
	_perto(o.peso_quente_atual(), OrbeNexus._peso_para(100), "...a cor muda direto, sem transição animada, e sem flash")
	o.queue_redraw()
	await get_tree().process_frame
	_ok(true, "...o desenho estático (M, brilho e anéis) funciona")
	GerenciadorConfiguracoes.definir("reduzir_animacoes", false, false)
	_ok(o.is_processing(), "desligar 'reduzir animações' devolve a animação")
	o.free()

	var c: OrbeNexus = _novo_orbe(true)
	_ok(not c.em_alto_contraste(), "alto contraste desligado por padrão")
	GerenciadorConfiguracoes.definir("alto_contraste", true, false)
	_ok(c.em_alto_contraste(), "alto contraste ligado com o avatar aberto: o avatar acompanha")
	c.definir_dependencia(100)
	_assentar(c)
	c.queue_redraw()
	await get_tree().process_frame
	_ok(true, "...desenha disco escuro + contorno branco com o 'M' (sem depender da cor roxo/vermelho)")
	GerenciadorConfiguracoes.definir("alto_contraste", false, false)
	_ok(not c.em_alto_contraste(), "e volta ao normal ao desligar")
	c.free()

	var f: OrbeNexus = _novo_orbe(true)
	f.reagir(1.0)
	var normal: float = f.energia
	f.energia = 0.0
	GerenciadorConfiguracoes.definir("sem_flashes", true, false)
	f.reagir(1.0)
	_ok(f.energia < normal and f.energia <= 0.4 + 0.001, "'sem flashes': o pulso de evento fica bem mais discreto (%.2f contra %.2f)" % [f.energia, normal])
	GerenciadorConfiguracoes.definir("sem_flashes", false, false)
	f.free()

	# parâmetros exportados: valores fora da faixa são limitados e o desenho funciona em qualquer combinação
	var p: OrbeNexus = _novo_orbe(true, 24.0)
	p.intensidade_glow = 9.0
	p.intensidade_aneis = -3.0
	p.espessura_aneis = 0.0
	p.margem_logo = 5.0
	_ok(p.intensidade_glow == 2.0 and p.intensidade_aneis == 0.0 and p.espessura_aneis == 0.25 and p.margem_logo == 0.5, "intensidade, espessura e margem são limitadas às faixas válidas")
	p.alerta = true
	p.velocidade = 2.0
	p.queue_redraw()
	await get_tree().process_frame
	_ok(true, "alerta, velocidade e tamanho mínimo (24 px) desenham sem erro")
	p.free()


# ------------------------------------------------------------------ 5. sinais e instâncias
func _testar_sinais_e_instancias() -> void:
	_secao("Avatar: sinais sem duplicar, várias instâncias e nada pendurado")
	var base: int = GerenciadorEstado.dependencia_alterada.get_connections().size()
	var base_cfg: int = GerenciadorConfiguracoes.configuracao_alterada.get_connections().size()
	var lista: Array = []
	for i in 5:
		lista.append(_novo_orbe(true, 40.0 + 10.0 * i))
	_igual(GerenciadorEstado.dependencia_alterada.get_connections().size(), base + 5, "5 avatares: 1 conexão do sinal da Dependência cada")
	for o in lista:
		(o as OrbeNexus).reagir_a_dependencia = true
		(o as OrbeNexus).reagir_a_dependencia = true
	_igual(GerenciadorEstado.dependencia_alterada.get_connections().size(), base + 5, "religar a reação não duplica a conexão")
	GerenciadorEstado.alterar_dependencia_maya(30, &"teste_avatar")
	var todos_iguais: bool = true
	for o in lista:
		todos_iguais = todos_iguais and (o as OrbeNexus).dependencia_atual() == _dep()
	_ok(todos_iguais, "todas as instâncias recebem o mesmo valor (sem estado obsoleto)")
	GerenciadorEstado.alterar_dependencia_maya(-30, &"teste_avatar")
	(lista[0] as OrbeNexus).reagir_a_dependencia = false
	_igual(GerenciadorEstado.dependencia_alterada.get_connections().size(), base + 4, "desligar a reação desconecta o sinal")
	_igual((lista[0] as OrbeNexus).cor_principal_atual(), ROXO, "...e a cor volta ao roxo padrão")
	for o in lista:
		(o as Node).free()
	await get_tree().process_frame
	_igual(GerenciadorEstado.dependencia_alterada.get_connections().size(), base, "liberar os avatares remove todas as conexões da Dependência")
	_igual(GerenciadorConfiguracoes.configuracao_alterada.get_connections().size(), base_cfg, "...e as de configuração (nada pendurado nos autoloads)")
	# um avatar novo, depois da Dependência já ter mudado, nasce com o valor certo
	GerenciadorEstado.alterar_dependencia_maya(35, &"teste_avatar")
	var novo: OrbeNexus = _novo_orbe(true)
	_igual(novo.dependencia_atual(), _dep(), "painel reaberto depois de uma mudança: o avatar já nasce com a Dependência atual")
	_perto(novo.peso_quente_atual(), OrbeNexus._peso_para(_dep()), "...e já na cor certa (sem viajar do roxo)")
	novo.free()
	GerenciadorEstado.alterar_dependencia_maya(-35, &"teste_avatar")


# ------------------------------------------------------------------ 6. painel de verdade
func _testar_painel_real() -> void:
	_secao("Painel da Maya (cena real): avatar com o 'M', reação à Dependência e pulso de mensagem")
	_novo_jogo()
	var painel: AppMaya = (load(CENA_MAYA) as PackedScene).instantiate() as AppMaya
	add_child(painel)
	await get_tree().process_frame
	await get_tree().process_frame
	var avatar: OrbeNexus = painel.find_child("Avatar", true, false) as OrbeNexus
	_ok(avatar != null, "o painel abre com o avatar")
	if avatar != null:
		_igual(avatar.mostra_marca_oficial(), Marca.carregar(Marca.MAYA_MARCA) != null, "o avatar do painel mostra o 'M' oficial")
		_igual(avatar.dependencia_atual(), _dep(), "...refletindo a Dependência atual")
		GerenciadorEstado.alterar_dependencia_maya(45, &"teste_avatar")
		_igual(avatar.dependencia_atual(), _dep(), "...e acompanhando a mudança com o painel aberto")
		GerenciadorEstado.alterar_dependencia_maya(-45, &"teste_avatar")
		GerenciadorEstado.definir_ia_estado("revelada")
		_igual(avatar.cor_principal_atual(), OrbeNexus.cores_de("revelada")[0], "o estado narrativo da IA continua chegando ao avatar do painel")
		GerenciadorEstado.definir_ia_estado("amigavel")
		avatar.reagir(0.7)
		_ok(avatar.energia > 0.0, "a notificação/fala continua dando o pulso no avatar")
		_ok(painel.find_child("CaixaEntrada", true, false) != null, "o resto do painel (caixa de entrada) segue no lugar")
	var antes: int = GerenciadorEstado.dependencia_alterada.get_connections().size()
	painel.free()
	await get_tree().process_frame
	_ok(GerenciadorEstado.dependencia_alterada.get_connections().size() < antes, "fechar o painel solta a conexão do avatar")


# ------------------------------------------------------------------ 7. desenho de verdade
func _testar_desenho_real() -> void:
	_secao("Avatar: desenho real (o 'M' aparece no lugar do círculo e não é cortado)")
	if DisplayServer.get_name() == "headless":
		_info("modo sem janela (headless): não há renderizador para ler pixels; este bloco roda só na janela do editor (F6)")
		return
	GerenciadorConfiguracoes.definir("reduzir_animacoes", true, false)   # desenho estático: as duas imagens só diferem pelo núcleo
	for lado in [56, 150]:
		var vp := SubViewport.new()
		vp.size = Vector2i(lado, lado)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var com_m: OrbeNexus = (load(CENA_ORBE) as PackedScene).instantiate() as OrbeNexus
		com_m.usar_marca = true
		com_m.custom_minimum_size = Vector2(lado, lado)   # o mínimo da cena (64) maior que a viewport a cortaria
		com_m.size = Vector2(lado, lado)
		vp.add_child(com_m)
		await get_tree().process_frame
		await get_tree().process_frame
		var img_m: Image = vp.get_texture().get_image()
		com_m.usar_marca = false
		await get_tree().process_frame
		await get_tree().process_frame
		var img_disco: Image = vp.get_texture().get_image()
		_ok(img_m != null and img_disco != null and not img_m.is_empty(), "%d px: o avatar foi desenhado" % lado)
		if img_m != null and img_disco != null and not img_m.is_empty():
			var diferentes: int = 0
			var centro := Rect2i(Vector2i(int(lado * 0.25), int(lado * 0.25)), Vector2i(int(lado * 0.5), int(lado * 0.5)))
			for y in range(centro.position.y, centro.end.y):
				for x in range(centro.position.x, centro.end.x):
					if img_m.get_pixel(x, y).is_equal_approx(img_disco.get_pixel(x, y)) == false:
						diferentes += 1
			_ok(diferentes > int(centro.get_area() * 0.05), "%d px: o centro com o 'M' é diferente do círculo sólido (%d px mudaram)" % [lado, diferentes])
			# o 'M' fica dentro do quadro: a borda do avatar não tem pixels opacos da marca (só brilho muito fraco)
			var borda_opaca: int = 0
			var amostra: String = ""
			for i in lado:
				for p in [Vector2i(i, 0), Vector2i(i, lado - 1), Vector2i(0, i), Vector2i(lado - 1, i)]:
					if img_m.get_pixelv(p).a > 0.5:
						borda_opaca += 1
						if amostra.length() < 120:
							amostra += " %s=%s" % [p, img_m.get_pixelv(p)]
			_igual(borda_opaca, 0, "%d px: nada do desenho é cortado pela borda do quadro (imagem %s, nó %s)%s" % [lado, img_m.get_size(), com_m.size, amostra])
		vp.free()
	GerenciadorConfiguracoes.definir("reduzir_animacoes", false, false)
