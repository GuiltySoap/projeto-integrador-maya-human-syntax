class_name TelaFinal
extends Control
## Tela dos SEIS FINAIS do roteiro v2.0/v2.1 (AV) em formato de CRÉDITOS CINEMATOGRÁFICOS:
##   1. toda a sequência do final alcançado (título, cenas/desdobramentos condicionais, falas, epílogo, resumo da jornada e ficha da equipe
##      Squad 1) sobe suavemente na tela como créditos de filme falando sobre o final;
##   2. o jogador pode Pausar/Retomar, Acelerar 2x, rolar com o mouse/setas ou clicar em Continuar a qualquer momento (com "Reduzir animações",
##      começa estático no topo para leitura manual);
##   3. ao terminar (ou avançar), exibe o CARTÃO DE ENCERRAMENTO (dois pedidos de permissão fictícios; nada é gravado) e depois a Tela de Fim
##      de Jogo com as saídas (recomeçar, tentar de novo na Task 9, rever final e créditos, menu).

const ATRASO_FIM_DE_JOGO := 0.4
const VELOCIDADE_CREDITOS := 46.0
const VELOCIDADE_CREDITOS_FAST := 135.0
const PAUSA_FIM_CREDITOS_S := 1.4
const COR_FALA := {"narracao": "#e2e8f0", "maya": "#c4b5fd", "sistema": "#fbbf24", "mensagem": "#7dd3fc", "comparacao": "#94a3b8"}
const COR_FINAL := {
	"aceitacao_total": "#ef4444",
	"recusa_total": "#22c55e",
	"meio_termo_1": "#38bdf8",
	"meio_termo_2": "#f59e0b",
	"rafael_1": "#a855f7",
	"rafael_2": "#10b981",
}
const FINAIS_POSITIVOS: PackedStringArray = ["recusa_total", "meio_termo_1", "rafael_2"]

var _id: String = ""
var _dados: Dictionary = {}
var _passos: Array = []
var _fase: String = "creditos"   # creditos | cartao | fim
var _cartao_indice: int = 0
var _concluida: bool = false
var _saindo: bool = false
var _scroll_creditos: float = 0.0
var _creditos_pausados: bool = false
var _creditos_acelerados: bool = false
var _pausa_pos_creditos: float = -1.0
var _btn_pausar_creditos: Button = null
var _btn_acelerar_creditos: Button = null

var _rot_titulo: Label = null
var _rot_faixa: Label = null
var _rot_resumo_sessao: Label = null
var _rot_passo: Label = null
var _texto: RichTextLabel = null
var _caixa_botoes: HBoxContainer = null
var _rolagem: ScrollContainer = null

@onready var _fundo: ColorRect = %Fundo
@onready var _fim_de_jogo: TelaFimDeJogo = %TelaFimDeJogo


func _ready() -> void:
	if not UiKit.refs_ok(self, {"Fundo": _fundo, "TelaFimDeJogo": _fim_de_jogo}):
		return
	_id = GerenciadorEstado.final_id
	if _id == "" or FluxoRoteiro.final_def(_id).is_empty():
		_id = "meio_termo_2"   # cena aberta direto no editor
	_dados = FluxoRoteiro.final_def(_id)
	TemaNexus.aplicar(get_tree())
	_fundo.color = Color(0.02, 0.03, 0.05, 1.0) if not bool(GerenciadorConfiguracoes.obter("alto_contraste")) else Color(0.0, 0.0, 0.0, 1.0)
	_montar()
	_passos = _passos_validos()
	# Música do epílogo: escolhida pelo final alcançado (resultado de avaliar_final), com crossfade a partir da trilha da Task 9. Sem trilha nem
	# fallback no catálogo, silêncio como antes. Trocar só o texto do epílogo NÃO reinicia a música (tocar_faixa ignora a faixa que já toca).
	if not SistemaAudio.tocar_musica_do_final(_id):
		SistemaAudio.parar_bgm()
	SistemaAudio.tocar_sfx("final_bom" if FINAIS_POSITIVOS.has(_id) else "final_mau", -2.0)
	_mostrar_creditos_do_final()


func _cor_do_final() -> Color:
	return Color.html(str(COR_FINAL.get(_id, "#8b5cf6")))


func _resumo_sessao_texto() -> String:
	var perms: int = GerenciadorEstado.permissoes_ativas()
	var rafael_txt: String = "Não investigado"
	if GerenciadorEstado.investigacao_profunda_concluida():
		rafael_txt = "Investigação profunda concluída"
	elif GerenciadorEstado.tem_flag("rafael_investigado"):
		rafael_txt = "Investigação parcial"
	return "Permissões ativas ao final: %d/5  ·  Caso Rafael: %s" % [perms, rafael_txt]


func _estilo_painel(borda: Color, fundo: Color, largura_esq: int = 1) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.set_corner_radius_all(10)
	caixa.content_margin_left = 20
	caixa.content_margin_right = 20
	caixa.content_margin_top = 16
	caixa.content_margin_bottom = 16
	var contraste: bool = bool(GerenciadorConfiguracoes.obter("alto_contraste"))
	caixa.bg_color = Color(0.03, 0.03, 0.05, 1.0) if contraste else fundo
	caixa.border_color = Color.WHITE if contraste else borda
	caixa.border_width_left = maxi(largura_esq, 2) if contraste else largura_esq
	caixa.border_width_top = 2 if contraste else 1
	caixa.border_width_right = 2 if contraste else 1
	caixa.border_width_bottom = 2 if contraste else 1
	return caixa


# ------------------------------------------------------------------ montagem
func _montar() -> void:
	var cor_acento: Color = _cor_do_final()
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	move_child(centro, _fundo.get_index() + 1)
	var margem := MarginContainer.new()
	var vp_tam: Vector2 = get_viewport_rect().size
	var larg_box: float = clampf(vp_tam.x * 0.86, 560.0, 920.0) if vp_tam.x > 0.0 else 860.0
	var alt_box: float = clampf(vp_tam.y * 0.86, 420.0, 680.0) if vp_tam.y > 0.0 else 600.0
	margem.custom_minimum_size = Vector2(larg_box, alt_box)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	centro.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 14)
	margem.add_child(coluna)
	var cabecalho := PanelContainer.new()
	cabecalho.add_theme_stylebox_override("panel", _estilo_painel(cor_acento, Color(0.08, 0.10, 0.16, 0.96), 4))
	coluna.add_child(cabecalho)
	var col_cab := VBoxContainer.new()
	col_cab.add_theme_constant_override("separation", 4)
	cabecalho.add_child(col_cab)
	_rot_titulo = Label.new()
	_rot_titulo.theme_type_variation = &"RotuloTitulo18"
	_rot_titulo.text = str(_dados.get("nome", "FIM"))
	col_cab.add_child(_rot_titulo)
	_rot_faixa = Label.new()
	_rot_faixa.theme_type_variation = &"RotuloFraco"
	_rot_faixa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rot_faixa.text = str(_dados.get("faixa", ""))
	col_cab.add_child(_rot_faixa)
	_rot_resumo_sessao = Label.new()
	_rot_resumo_sessao.theme_type_variation = &"RotuloFraco12"
	_rot_resumo_sessao.text = _resumo_sessao_texto()
	if not bool(GerenciadorConfiguracoes.obter("alto_contraste")):
		_rot_resumo_sessao.add_theme_color_override("font_color", cor_acento)
	col_cab.add_child(_rot_resumo_sessao)
	var painel_corpo := PanelContainer.new()
	painel_corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	painel_corpo.add_theme_stylebox_override("panel", _estilo_painel(Color(0.24, 0.30, 0.42, 0.75), Color(0.06, 0.08, 0.13, 0.94), 1))
	coluna.add_child(painel_corpo)
	var col_corpo := VBoxContainer.new()
	col_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_corpo.add_theme_constant_override("separation", 10)
	painel_corpo.add_child(col_corpo)
	_rot_passo = Label.new()
	_rot_passo.theme_type_variation = &"RotuloAcento"
	col_corpo.add_child(_rot_passo)
	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_corpo.add_child(_rolagem)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.selection_enabled = true
	_texto.focus_mode = Control.FOCUS_ALL
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto.custom_minimum_size = Vector2(1, 0)
	_rolagem.add_child(_texto)
	_caixa_botoes = HBoxContainer.new()
	_caixa_botoes.add_theme_constant_override("separation", 10)
	coluna.add_child(_caixa_botoes)


func _process(delta: float) -> void:
	if _fase != "creditos" or _rolagem == null or _creditos_pausados:
		return
	if not GerenciadorConfiguracoes.animacoes_permitidas():
		return
	var barra: VScrollBar = _rolagem.get_v_scroll_bar()
	var maximo: float = maxf(barra.max_value - barra.page, 0.0)
	if maximo <= 1.0:
		return
	if _scroll_creditos < maximo:
		var vel: float = VELOCIDADE_CREDITOS_FAST if _creditos_acelerados else VELOCIDADE_CREDITOS
		_scroll_creditos = minf(_scroll_creditos + delta * vel, maximo)
		_rolagem.scroll_vertical = int(_scroll_creditos)
		if _scroll_creditos >= maximo:
			_pausa_pos_creditos = PAUSA_FIM_CREDITOS_S
	elif _pausa_pos_creditos > 0.0:
		_pausa_pos_creditos -= delta
		if _pausa_pos_creditos <= 0.0:
			_iniciar_cartoes_ou_concluir()


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("nexus_forcar_desativar"):
		get_viewport().set_input_as_handled()
		GerenciadorConfiguracoes.ativar_modo_conforto()
	elif evento.is_action_pressed("nexus_tela_cheia"):
		get_viewport().set_input_as_handled()
		GerenciadorConfiguracoes.alternar_tela_cheia()
	elif _fase == "creditos" and evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_sincronizar_scroll_manual.call_deferred()


func _sincronizar_scroll_manual() -> void:
	if _rolagem != null and _fase == "creditos":
		_scroll_creditos = float(_rolagem.scroll_vertical)


## Esc, com a sequência inteira lida, abre a Tela de Fim de Jogo (a Pausa não existe aqui: o jogo já terminou).
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel") and _concluida and em_cena_principal() and abrir_fim_de_jogo():
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ passos
func _passos_validos() -> Array:
	var saida: Array = []
	for p in _dados.get("passos", []):
		var pd: Dictionary = p
		if pd.has("se") and not GerenciadorEstado.avaliar_condicao(pd["se"]):
			continue
		if pd.has("oculta_se") and GerenciadorEstado.avaliar_condicao(pd["oculta_se"]):
			continue
		saida.append(pd)
	return saida


## Linhas de um passo que valem agora (`se` / `oculta_se`), já com o texto formatado ({NOME_JOGADOR}...).
func linhas_do_passo(passo: Dictionary) -> Array:
	var saida: Array = []
	for l in passo.get("linhas", []):
		var ld: Dictionary = l
		if ld.has("se") and not GerenciadorEstado.avaliar_condicao(ld["se"]):
			continue
		if ld.has("oculta_se") and GerenciadorEstado.avaliar_condicao(ld["oculta_se"]):
			continue
		saida.append(ld)
	return saida


func _limpar_titulo_passo(bruto: String) -> String:
	var ponto: int = bruto.find(". ")
	if ponto > 0 and ponto <= 3:
		return bruto.substr(ponto + 2).strip_edges()
	return bruto.strip_edges()


func _formatar_linha_credito(ld: Dictionary) -> String:
	var tipo := str(ld.get("tipo", "narracao"))
	var texto := UtilTexto.escapar_bbcode(FluxoRoteiro.texto(str(ld.get("texto", ""))))
	var cor := str(COR_FALA.get(tipo, "#e2e8f0"))
	match tipo:
		"maya":
			return "[color=%s][b]Maya:[/b] “%s”[/color]" % [cor, texto]
		"sistema":
			return "[color=%s][i]%s[/i][/color]" % [cor, texto]
		"mensagem":
			var quem := str(ld.get("quem", ""))
			var nome := str(GerenciadorNarrativa.info_contato(quem).get("nome", quem)) if quem != "" else ""
			if nome != "":
				return "[color=%s][b]%s:[/b] %s[/color]" % [cor, UtilTexto.escapar_bbcode(nome), texto]
			return "[color=%s]%s[/color]" % [cor, texto]
		"comparacao":
			var voce := UtilTexto.escapar_bbcode(FluxoRoteiro.texto(str(ld.get("voce", ""))))
			return "[color=%s][b]Diário do Rafael:[/b] %s\n[b]O que você fez:[/b] %s[/color]" % [cor, texto, voce]
	return "[color=%s]%s[/color]" % [cor, texto]


## Apresentação principal do final em estilo créditos cinematográficos: conta todo o desfecho e segue para a equipe.
func _mostrar_creditos_do_final() -> void:
	_fase = "creditos"
	_scroll_creditos = 0.0
	_creditos_pausados = false
	_creditos_acelerados = false
	_pausa_pos_creditos = -1.0
	_btn_pausar_creditos = null
	_btn_acelerar_creditos = null
	_rot_passo.text = "Desfecho e Créditos"
	var cor_hex: String = str(COR_FINAL.get(_id, "#a78bfa"))
	var nome_final: String = UtilTexto.escapar_bbcode(str(_dados.get("nome", "FIM"))).to_upper()
	var faixa_final: String = UtilTexto.escapar_bbcode(str(_dados.get("faixa", "")))
	var epilogo_txt: String = UtilTexto.escapar_bbcode(FluxoRoteiro.texto(str(_dados.get("epilogo", ""))))
	var jogador_txt: String = UtilTexto.escapar_bbcode(GerenciadorEstado.nome_jogador if GerenciadorEstado.nome_jogador != "" else "Usuário")
	var resumo_txt: String = UtilTexto.escapar_bbcode(_resumo_sessao_texto())

	var blocos: PackedStringArray = PackedStringArray()
	if GerenciadorConfiguracoes.animacoes_permitidas():
		blocos.append("\n\n\n\n\n\n")
	blocos.append("[color=%s][b]MAYA: HUMAN SYNTAX[/b][/color]\n[color=#94a3b8]HumaxOS · Encerramento da Sessão[/color]" % cor_hex)
	blocos.append("[color=#94a3b8]FINAL ALCANÇADO[/color]\n[color=%s][b]%s[/b][/color]\n[color=#cbd5e1]%s[/color]" % [cor_hex, nome_final, faixa_final])
	blocos.append("[color=#94a3b8]REGISTRO DA SESSÃO[/color]\nUsuário: [b]%s[/b]\n%s" % [jogador_txt, resumo_txt])
	var novas_conq: PackedStringArray = SistemaConquistas.desbloqueadas_na_sessao()
	var bloco_conq: PackedStringArray = PackedStringArray()
	bloco_conq.append("[color=#fbbf24][b]CONQUISTAS (%d / %d)[/b][/color]" % [SistemaConquistas.contagem(), SistemaConquistas.total()])
	if novas_conq.is_empty():
		bloco_conq.append("[color=#cbd5e1]Consulte todas as conquistas no Menu Principal ou no comando `conquistas` do Terminal.[/color]")
	else:
		for cid in novas_conq:
			var cd: Dictionary = SistemaConquistas.definicao(str(cid))
			if not cd.is_empty():
				bloco_conq.append("[color=#fef08a]%s  [b]%s[/b][/color]\n[color=#cbd5e1]%s[/color]" % [
					str(cd.get("icone", "🏆")),
					UtilTexto.escapar_bbcode(str(cd.get("titulo", ""))),
					UtilTexto.escapar_bbcode(str(cd.get("descricao", ""))),
				])
	blocos.append("\n\n".join(bloco_conq))

	for passo in _passos:
		var pd: Dictionary = passo
		var linhas_validas: Array = linhas_do_passo(pd)
		if linhas_validas.is_empty():
			continue
		var titulo_cena: String = UtilTexto.escapar_bbcode(_limpar_titulo_passo(str(pd.get("titulo", "")))).to_upper()
		var trecho: PackedStringArray = PackedStringArray()
		if titulo_cena != "":
			trecho.append("[color=%s][b]%s[/b][/color]" % [cor_hex, titulo_cena])
		for ld in linhas_validas:
			trecho.append(_formatar_linha_credito(ld as Dictionary))
		blocos.append("\n\n".join(trecho))

	var respostas: Variant = _dados.get("respostas_obrigatorias")
	if respostas is Dictionary and not (respostas as Dictionary).is_empty():
		var bloco_resp: PackedStringArray = PackedStringArray()
		bloco_resp.append("[color=%s][b]O QUE FICOU DEPOIS[/b][/color]" % cor_hex)
		for pergunta in respostas:
			bloco_resp.append("[b]%s[/b]\n[color=#cbd5e1]%s[/color]" % [
				UtilTexto.escapar_bbcode(str(pergunta)),
				UtilTexto.escapar_bbcode(FluxoRoteiro.texto(str((respostas as Dictionary)[pergunta]))),
			])
		blocos.append("\n\n".join(bloco_resp))

	if epilogo_txt != "":
		blocos.append("[color=#94a3b8]EPÍLOGO[/color]\n[i][color=#f8fafc]“%s”[/color][/i]" % epilogo_txt)

	blocos.append(
		"[color=#94a3b8]DESENVOLVIDO POR[/color]\n"
		+ "[b]Squad 1 · CESAR School[/b]\n"
		+ "[color=#94a3b8]Projeto Integrador[/color]\n\n"
		+ "[b]Guilherme Santana Habib Lantyer de Araújo[/b]\n"
		+ "[color=#94a3b8]Design · Integração · Programação GDScript[/color]\n\n"
		+ "[b]Jennifer Dantas Machado Almeida[/b]\n"
		+ "[color=#94a3b8]Design · Roteiro · Arte[/color]\n\n"
		+ "[b]Linda Sabrina Rosal[/b]\n"
		+ "[color=#94a3b8]Wireframes · Experiência do Usuário (UX)[/color]\n\n"
		+ "[b]Tharcylo José[/b]\n"
		+ "[color=#94a3b8]Backend C (v2.1) · Testes · Integração · Rastreabilidade[/color]"
	)
	blocos.append("[color=#94a3b8]TECNOLOGIA[/color]\nGodot Engine 4 · GDScript · C11 · HumaxOS")
	blocos.append("[color=%s][b]Obrigado por jogar.[/b][/color]\n[i][color=#fbbf24]Você permite?[/color][/i]\n\n\n\n" % cor_hex)

	_texto.clear()
	_texto.append_text("[center]" + "\n\n\n".join(blocos) + "[/center]")
	_rolagem.scroll_vertical = 0
	_limpar_botoes()
	if GerenciadorConfiguracoes.animacoes_permitidas():
		_btn_pausar_creditos = _botao("Pausar", _ao_pausar_creditos)
		_btn_acelerar_creditos = _botao("Acelerar 2x", _ao_alternar_velocidade_creditos)
		_botao("Continuar", _ao_avancar_creditos)
	else:
		_botao("Continuar", _ao_avancar_creditos)
	_focar_primeiro()


func _ao_pausar_creditos() -> void:
	SistemaAudio.tocar_sfx("clique", -4.0)
	_creditos_pausados = not _creditos_pausados
	if _btn_pausar_creditos != null and is_instance_valid(_btn_pausar_creditos):
		_btn_pausar_creditos.text = "Retomar" if _creditos_pausados else "Pausar"


func _ao_alternar_velocidade_creditos() -> void:
	SistemaAudio.tocar_sfx("clique", -4.0)
	_creditos_acelerados = not _creditos_acelerados
	if _btn_acelerar_creditos != null and is_instance_valid(_btn_acelerar_creditos):
		_btn_acelerar_creditos.text = "Velocidade normal" if _creditos_acelerados else "Acelerar 2x"


func _ao_avancar_creditos() -> void:
	SistemaAudio.tocar_sfx("clique", -4.0)
	_iniciar_cartoes_ou_concluir()


func _iniciar_cartoes_ou_concluir() -> void:
	_cartao_indice = 0
	if _concluida:
		_concluir()
	else:
		_mostrar_cartao()


## Cartão de encerramento: dois pedidos de permissão FICTÍCIOS. As duas respostas fecham o cartão sem registrar nada.
func _mostrar_cartao() -> void:
	_fase = "cartao"
	var cartoes: Array = FluxoRoteiro.cartao_de_encerramento()
	if _cartao_indice >= cartoes.size():
		_concluir()
		return
	_rot_passo.text = "Pedido de permissão"
	_texto.clear()
	_texto.append_text("[center]\n\n[color=#fbbf24][b]%s[/b][/color]\n\n[i][color=#94a3b8]Este pedido é só parte da história: nada que você escolher aqui é registrado.[/color][/i]\n[/center]" % UtilTexto.escapar_bbcode(FluxoRoteiro.texto(str((cartoes[_cartao_indice] as Dictionary).get("texto", "")))))
	_rolagem.scroll_vertical = 0
	_limpar_botoes()
	_botao("Permitir", _ao_cartao_respondido)
	_botao("Negar", _ao_cartao_respondido)
	_focar_primeiro()


func _ao_cartao_respondido() -> void:
	SistemaAudio.tocar_sfx("clique", -4.0)
	_cartao_indice += 1
	_mostrar_cartao()


func _concluir() -> void:
	_fase = "fim"
	_concluida = true
	_rot_passo.text = "Fim"
	_texto.clear()
	_texto.append_text("[center]\n[b]%s[/b]\n%s\n\n%s\n[/center]" % [UtilTexto.escapar_bbcode(str(_dados.get("nome", ""))), UtilTexto.escapar_bbcode(str(_dados.get("faixa", ""))), UtilTexto.escapar_bbcode(TelaFimDeJogo.resumo_da_jornada())])
	_rolagem.scroll_vertical = 0
	_limpar_botoes()
	if SistemaPersistencia.existe_checkpoint(9):
		_botao("Tentar de novo (início da Task 9)", _ao_repetir_task_9)
	_botao("Rever final e créditos", _mostrar_creditos_do_final)
	_botao("Mais opções", _ao_mais_opcoes)
	_botao("Voltar ao início", _ao_voltar_ao_inicio)
	_focar_primeiro()
	if em_cena_principal():
		var t := create_tween()
		t.tween_interval(ATRASO_FIM_DE_JOGO)
		t.tween_callback(abrir_fim_de_jogo)


# ------------------------------------------------------------------ botões
func _limpar_botoes() -> void:
	for b in _caixa_botoes.get_children():
		_caixa_botoes.remove_child(b)
		b.queue_free()


func _botao(rotulo: String, ao_apertar: Callable) -> Button:
	var b := Button.new()
	b.text = rotulo
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(ao_apertar)
	_caixa_botoes.add_child(b)
	return b


func botoes_atuais() -> Array:
	return _caixa_botoes.get_children()


func _focar_primeiro() -> void:
	await get_tree().process_frame
	if is_inside_tree() and _caixa_botoes.get_child_count() > 0:
		(_caixa_botoes.get_child(0) as Button).grab_focus()


func _rolar_para_fim() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_rolagem.scroll_vertical = int(_rolagem.get_v_scroll_bar().max_value)


# ------------------------------------------------------------------ saídas
## Esta tela é a cena em execução do jogo? (Os testes a instanciam como filha de outra cena: aí ela não abre nada sozinha.)
func em_cena_principal() -> bool:
	return is_inside_tree() and get_tree().current_scene == self


## Abre a Tela de Fim de Jogo por cima desta (uma única vez por vez). Devolve false se não abriu (já aberta, saindo ou em troca).
func abrir_fim_de_jogo() -> bool:
	if _saindo or not is_inside_tree():
		return false
	var motivo: String = "%s\n\nA história chegou ao fim. Escolha o que fazer agora." % str(_dados.get("nome", "FIM"))
	return _fim_de_jogo.abrir(motivo, TelaFimDeJogo.resumo_da_jornada(), _cor_do_final(), true)


func _ao_mais_opcoes() -> void:
	abrir_fim_de_jogo()


## "Rever epílogo": a Tela de Fim de Jogo fechou; o foco vai para a primeira saída desta tela.
func _ao_fim_de_jogo_revisto() -> void:
	_focar_primeiro()


## "Tentar de novo (início da Task 9)": pela fachada de sessão, que confere o checkpoint e carrega a cena antes de trocar o estado.
func _ao_repetir_task_9() -> void:
	if _saindo:
		return
	_saindo = true
	if not Sessao.carregar_checkpoint(get_tree(), 9, _ao_falha_ao_repetir):
		_ao_falha_ao_repetir("recusado")


func _ao_falha_ao_repetir(_motivo: String) -> void:
	_saindo = false
	SistemaNotificacoes.notificar("Checkpoint", "Não foi possível carregar o checkpoint da Task 9.", "erro", 5.0)


## "Voltar ao início": o Menu Principal, pela mesma fachada da Pausa (a campanha concluída continua salva).
func _ao_voltar_ao_inicio() -> void:
	if _saindo:
		return
	_saindo = true
	if not Sessao.voltar_ao_menu(get_tree(), _ao_falha_ao_sair):
		_ao_falha_ao_sair("recusado")


func _ao_falha_ao_sair(_motivo: String) -> void:
	_saindo = false
