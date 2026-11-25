class_name AppMaya
extends AppBase
## Painel da Maya (roteiro v2.0/v2.1): o lugar onde ela fala com o jogador. Não é um chat livre: mostra o histórico recente das falas em balões,
## ritmo natural de digitação (desligável por acessibilidade), status evolutivo conforme as Tasks, e os botões de resposta do nó atual.
## Abre sozinho na Task 1 e pelo logo da barra de tarefas, pelo menu Iniciar ("Falar com a Maya") e por Ctrl+Shift+H.
##   Cabecalho       logo oficial, nome e papel (que evolui com a história);
##   AreaDeDialogo   histórico das falas em cartões, indicador de digitação, escolha atual (ItemEscolha) e aviso de resultado;
##   RolagemAcoes/AreaDeAcoes   (rolagem LATERAL: com 3 ou 4 botões a linha nunca alarga o painel; o que não cabe rola)
##   AreaDeAcoes     "Fechar janelas" (volta ao desktop quando a Maya espera por isso) e "Abrir o Mensageiro" (quando a resposta é numa conversa);
##   RotuloEspera    o que a Maya está esperando (em texto, para leitor de tela).
## Nenhuma regra mora aqui: o motor (GerenciadorNarrativa) decide tudo; o painel desenha `apresentacao()` e repassa o clique.

const CHARS_POR_SEGUNDO := 34.0
const PAUSA_ENTRE_BALOES_S := 0.72
const PAUSA_PONTO_S := 0.22
const PAUSA_VIRGULA_S := 0.08
const PASSO_SOM_VOZ := 3

static var _ultimo_total_visto: int = 0

@export var cena_escolha: PackedScene
@export var cena_balao: PackedScene   ## o mesmo balão do Mensageiro (BalaoChat): Maya à esquerda, jogador à direita

var _botoes_escolha: Array = []
var _linhas: Array = []
var _fila_falas: Array = []
var _digitando_label: Label = null
var _digitando_texto: String = ""
var _digitando_quem: String = "maya"
var _chars_mostrados: int = 0
var _acum_char: float = 0.0
var _pausa_restante: float = 0.0
var _contador_som: int = 0
var _tem_opcoes_ativas: bool = false
var _cliques_bloqueados: int = 0
var _ultimo_teto_balao: int = -1   ## último teto de largura aplicado aos balões (evita refazer à toa)
var _btn_historico: Button = null   ## v2.1: histórico antigo (Task 5) durante a conversa da Task 6; criado no código ao lado de "Abrir o Mensageiro"

@onready var _avatar: OrbeNexus = %Avatar
@onready var _caixa_entrada: CaixaEntradaVisual = %CaixaEntrada
@onready var _btn_fechar_painel: Button = %BotaoFecharPainel
@onready var _btn_dica: Button = %BotaoPedirDica
@onready var _rot_papel: Label = %RotuloPapel
@onready var _rolagem_acoes: ScrollContainer = %RolagemAcoes
@onready var _rolagem: ScrollContainer = %Rolagem
@onready var _lista_falas: VBoxContainer = %ListaFalas
@onready var _rot_fala_atual: Label = %RotuloFalaAtual
@onready var _area_escolhas: VBoxContainer = %AreaEscolhas
@onready var _rot_resultado: Label = %RotuloResultado
@onready var _rot_espera: Label = %RotuloEspera
@onready var _btn_fechar: Button = %BotaoFecharJanelas
@onready var _btn_mensageiro: Button = %BotaoAbrirMensageiro


func _ready() -> void:
	super._ready()
	if not UiKit.refs_ok(self, {"Avatar": _avatar, "CaixaEntrada": _caixa_entrada, "BotaoFecharPainel": _btn_fechar_painel, "BotaoPedirDica": _btn_dica, "RotuloPapel": _rot_papel, "RolagemAcoes": _rolagem_acoes, "Rolagem": _rolagem, "ListaFalas": _lista_falas,
			"RotuloFalaAtual": _rot_fala_atual, "AreaEscolhas": _area_escolhas, "RotuloResultado": _rot_resultado,
			"RotuloEspera": _rot_espera, "BotaoFecharJanelas": _btn_fechar, "BotaoAbrirMensageiro": _btn_mensageiro}):
		return
	focus_mode = Control.FOCUS_ALL
	definir_titulo("Painel da Maya")
	_rolagem.gui_input.connect(_ao_clique_dialogo)
	_rolagem_acoes.gui_input.connect(_ao_roda_nas_acoes)
	_rolagem.resized.connect(_reajustar_baloes)
	conectar(GerenciadorNarrativa.apresentacao_mudou, _atualizar)
	conectar(GerenciadorNarrativa.fala_adicionada, _ao_fala)
	conectar(GerenciadorNarrativa.etapa_iniciada, _ao_etapa)
	conectar(GerenciadorJanelas.janelas_alteradas, _atualizar)
	conectar(GerenciadorConfiguracoes.configuracao_alterada, _ao_configuracao)
	conectar(GerenciadorEstado.ia_estado_mudou, _avatar.definir_estado)
	_avatar.definir_estado(GerenciadorEstado.ia_estado)
	_caixa_entrada.ativada.connect(_ao_caixa_ativada)
	_btn_fechar_painel.pressed.connect(_ao_fechar_painel)
	_btn_dica.pressed.connect(_ao_pedir_dica)
	_btn_historico = Button.new()
	_btn_historico.name = "BotaoAbrirHistorico"
	_btn_historico.text = "Abrir o histórico antigo"
	_btn_historico.focus_mode = Control.FOCUS_ALL
	_btn_historico.visible = false
	_btn_historico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_historico.pressed.connect(_ao_abrir_historico)
	_btn_mensageiro.get_parent().add_child(_btn_historico)
	_reconstruir_historico()
	_atualizar()


func _unhandled_key_input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or not _esta_digitando():
		return
	if janela != null and GerenciadorJanelas.janela_ativa() != janela:
		return
	if evento is InputEventKey and (evento as InputEventKey).pressed and not (evento as InputEventKey).echo:
		var kc: Key = (evento as InputEventKey).keycode
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
			if _acelerar_digitacao():
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _esta_digitando():
		return
	if not is_visible_in_tree() or not GerenciadorConfiguracoes.animacoes_permitidas():
		_drenar_fila_falas()
		return
	if _pausa_restante > 0.0:
		_pausa_restante -= delta
		return
	if _digitando_label != null:
		if not is_instance_valid(_digitando_label):
			_digitando_label = null
			return
		_acum_char += delta * CHARS_POR_SEGUNDO
		while _acum_char >= 1.0 and _chars_mostrados < _digitando_texto.length():
			_acum_char -= 1.0
			_chars_mostrados += 1
			_digitando_label.visible_characters = _chars_mostrados
			var ch: String = _digitando_texto[_chars_mostrados - 1]
			if not _eh_espaco_ou_ponto(ch):
				_contador_som += 1
				if _contador_som >= PASSO_SOM_VOZ:
					_contador_som = 0
					SistemaAudio.tocar_voz(_digitando_quem)
			if ch in [".", "!", "?", "…"] and _chars_mostrados < _digitando_texto.length():
				_pausa_restante = PAUSA_PONTO_S
				break
			if ch in [",", ":", ";"] and _chars_mostrados < _digitando_texto.length():
				_pausa_restante = PAUSA_VIRGULA_S
				break
		if _chars_mostrados >= _digitando_texto.length():
			_finalizar_balao_atual()
		return
	if not _fila_falas.is_empty():
		_iniciar_proxima_fala()


func iniciar(_args: Dictionary = {}) -> void:
	_atualizar()
	ao_focar()


func receber_args(args: Dictionary) -> void:
	iniciar(args)


func ao_focar() -> void:
	_rolar_para_fim()
	_focar_primeiro.call_deferred()


func ao_fechar() -> void:
	_drenar_fila_falas()


func _esta_digitando() -> bool:
	return _digitando_label != null or not _fila_falas.is_empty() or _pausa_restante > 0.0


func _eh_espaco_ou_ponto(ch: String) -> bool:
	return ch in [" ", "\n", "\t", ".", ",", "!", "?", ":", ";", "…", "-", "—", "(", ")", "\"", "“", "”", "'"]


## A roda do mouse sobre a linha de botões rola de lado (a linha só tem rolagem horizontal). Em teclado, `follow_focus` leva o botão focado à vista.
func _ao_roda_nas_acoes(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not (evento as InputEventMouseButton).pressed:
		return
	var botao: int = (evento as InputEventMouseButton).button_index
	var passo: int = 0
	if botao == MOUSE_BUTTON_WHEEL_DOWN or botao == MOUSE_BUTTON_WHEEL_RIGHT:
		passo = 70
	elif botao == MOUSE_BUTTON_WHEEL_UP or botao == MOUSE_BUTTON_WHEEL_LEFT:
		passo = -70
	if passo != 0:
		_rolagem_acoes.scroll_horizontal = maxi(_rolagem_acoes.scroll_horizontal + passo, 0)
		_rolagem_acoes.accept_event()


func _ao_clique_dialogo(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _acelerar_digitacao():
			accept_event()


func _acelerar_digitacao() -> bool:
	if _digitando_label != null:
		_finalizar_balao_atual()
		return true
	if _pausa_restante > 0.0 and not _fila_falas.is_empty():
		_pausa_restante = 0.0
		_iniciar_proxima_fala()
		return true
	return false


func _focar_primeiro() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if _area_escolhas.visible:
		for b in _botoes_escolha:
			if is_instance_valid(b) and b is Button:
				(b as Button).grab_focus()
				return
	if _caixa_entrada.tem_opcoes() and not _caixa_entrada.revelada():
		_caixa_entrada.grab_focus()
	elif _btn_mensageiro.visible:
		_btn_mensageiro.grab_focus()
	elif _btn_fechar.visible and not _btn_fechar.disabled:
		_btn_fechar.grab_focus()


# ------------------------------------------------------------------ status evolutivo
static func texto_papel_atual() -> String:
	var etapa: int = GerenciadorEstado.etapa_atual
	var dep: int = GerenciadorEstado.dependencia_maya()
	if etapa >= 9:
		return "Controle prioritário ativo" if dep >= 65 else "Modo de cuidado prioritário"
	if etapa >= 7:
		return "Otimizando suas decisões"
	if etapa >= 5:
		return "Monitoramento de contexto ativo"
	if etapa >= 3:
		return "Organizando sua rotina"
	return "Assistente do HumaxOS"


func _atualizar_papel() -> void:
	if _rot_papel != null:
		_rot_papel.text = texto_papel_atual()
		_rot_papel.tooltip_text = _rot_papel.text   # o texto longo é cortado com reticências no painel estreito


# ------------------------------------------------------------------ histórico e digitação
func _reconstruir_historico() -> void:
	_fila_falas.clear()
	_digitando_label = null
	_digitando_texto = ""
	_chars_mostrados = 0
	_acum_char = 0.0
	_pausa_restante = 0.0
	UiKit.remover_itens(_linhas)
	var hist: Array = GerenciadorNarrativa.historico_da_maya()
	if hist.size() < _ultimo_total_visto:
		_ultimo_total_visto = 0
	var animar: bool = GerenciadorConfiguracoes.animacoes_permitidas() and hist.size() > _ultimo_total_visto
	var inicio_anim: int = hist.size()
	if animar:
		inicio_anim = maxi(_ultimo_total_visto, maxi(0, hist.size() - 5))
	for i in hist.size():
		var item: Variant = hist[i]
		if not (item is Dictionary):
			continue
		if i < inicio_anim:
			_adicionar_linha(item as Dictionary, false)
		else:
			_fila_falas.append(item as Dictionary)
	_ultimo_total_visto = hist.size()
	if _fila_falas.is_empty():
		_rot_fala_atual.text = ""
		_rot_fala_atual.visible = false
	else:
		_iniciar_proxima_fala()
	_rolar_para_fim()


func _iniciar_proxima_fala() -> void:
	if _fila_falas.is_empty():
		_rot_fala_atual.text = ""
		_rot_fala_atual.visible = false
		_sincronizar_escolhas_pos_digitacao()
		return
	var fala: Dictionary = _fila_falas.pop_front() as Dictionary
	var corpo: Label = _adicionar_linha(fala, true)
	_digitando_label = corpo
	_digitando_texto = corpo.text
	_digitando_quem = str(fala.get("quem", "maya"))
	_chars_mostrados = 0
	_acum_char = 0.0
	_contador_som = PASSO_SOM_VOZ - 1
	corpo.visible_characters = 0
	_atualizar_rotulo_digitando(_digitando_quem)
	_area_escolhas.visible = false
	_rolar_para_fim()


func _finalizar_balao_atual() -> void:
	if _digitando_label != null and is_instance_valid(_digitando_label):
		_digitando_label.visible_characters = -1
	_digitando_label = null
	_digitando_texto = ""
	_chars_mostrados = 0
	_acum_char = 0.0
	if not _fila_falas.is_empty():
		_pausa_restante = PAUSA_ENTRE_BALOES_S
		var prox_quem: String = str((_fila_falas[0] as Dictionary).get("quem", "maya"))
		_atualizar_rotulo_digitando(prox_quem)
	else:
		_pausa_restante = 0.0
		_rot_fala_atual.text = ""
		_rot_fala_atual.visible = false
		_sincronizar_escolhas_pos_digitacao()


func _atualizar_rotulo_digitando(quem: String) -> void:
	if _rot_fala_atual == null:
		return
	var prefixo: String = "Maya está escrevendo..."
	if quem == "sistema":
		prefixo = "Sistema registrando..."
	elif quem == "jogador":
		prefixo = "Registrando resposta..."
	elif quem == "rafael.m":
		prefixo = "Reconstruindo histórico..."
	_rot_fala_atual.text = "%s  (clique ou Espaço para acelerar)" % prefixo
	_rot_fala_atual.visible = true


func _sincronizar_escolhas_pos_digitacao() -> void:
	if _area_escolhas == null:
		return
	_aplicar_visibilidade_escolhas()
	_rolar_para_fim()
	if _tem_opcoes_ativas and is_visible_in_tree():
		_focar_primeiro.call_deferred()


func _drenar_fila_falas() -> void:
	if _digitando_label != null and is_instance_valid(_digitando_label):
		_digitando_label.visible_characters = -1
	_digitando_label = null
	_digitando_texto = ""
	_chars_mostrados = 0
	_acum_char = 0.0
	_pausa_restante = 0.0
	while not _fila_falas.is_empty():
		var proxima: Dictionary = _fila_falas.pop_front() as Dictionary
		_adicionar_linha(proxima, false)
	if _rot_fala_atual != null:
		_rot_fala_atual.text = ""
		_rot_fala_atual.visible = false
	_sincronizar_escolhas_pos_digitacao()
	_rolar_para_fim()


## Nome e entrada do balão compartilhado (BalaoChat) para uma fala do histórico da Maya.
static func entrada_do_balao(fala: Dictionary) -> Dictionary:
	var quem := str(fala.get("quem", "maya"))
	var nome := "Maya"
	match quem:
		"jogador":
			nome = GerenciadorEstado.nome_jogador if GerenciadorEstado.nome_jogador != "" else "Você"
		"sistema":
			nome = "Sistema"
		"rafael.m":
			nome = "rafael.m (histórico)"
		"other":
			nome = "…"
	var hora := str(fala.get("hora", ""))
	return {
		"autor": quem, "tipo": "sistema" if quem == "sistema" else "normal",
		"texto": str(fala.get("texto", "")), "hora": hora, "nome_exibido": nome, "id": str(fala.get("id", "")),
	}


## O painel mudou de largura (ou terminou de ser diagramado): refaz o teto de largura dos balões já criados. Sem isto um balão medido
## numa janela larga, ou antes do layout, mantinha uma largura mínima maior que a janela estreita e empurrava o conteúdo para fora.
func _reajustar_baloes() -> void:
	var teto: int = _largura_maxima_balao()
	if teto == _ultimo_teto_balao:
		return
	_ultimo_teto_balao = teto
	for balao in _linhas:
		if is_instance_valid(balao) and balao is BalaoChat:
			(balao as BalaoChat).limitar_largura(teto)


func _largura_maxima_balao() -> int:
	var largura: float = _rolagem.size.x
	if largura < 200.0:
		return 340
	return int(clampf(largura * 0.74, 220.0, 520.0))


func _adicionar_linha(fala: Dictionary, ocultar_inicio: bool = false) -> Label:
	var balao := cena_balao.instantiate() as BalaoChat
	_lista_falas.add_child(balao)
	balao.configurar(entrada_do_balao(fala), _largura_maxima_balao())
	_linhas.append(balao)
	var corpo: Label = balao.rotulo_texto()
	if ocultar_inicio:
		corpo.visible_characters = 0
	return corpo


func _ao_fala(fala: Dictionary) -> void:
	_ultimo_total_visto = GerenciadorNarrativa.historico_da_maya().size()
	if str(fala.get("quem", "maya")) != "jogador":
		_avatar.reagir(0.7)
	if not is_visible_in_tree() or not GerenciadorConfiguracoes.animacoes_permitidas():
		_adicionar_linha(fala, false)
		_rolar_para_fim()
		return
	var estava_ocioso: bool = not _esta_digitando()
	_fila_falas.append(fala)
	if estava_ocioso:
		_iniciar_proxima_fala()
	else:
		_area_escolhas.visible = false


func _ao_etapa(_etapa: int) -> void:
	_atualizar()


func _ao_configuracao(chave: String, _valor: Variant) -> void:
	if chave == "alto_contraste":
		_drenar_fila_falas()
		_reconstruir_historico()
	elif chave == "reduzir_animacoes" or chave == "modo_conforto":
		if not GerenciadorConfiguracoes.animacoes_permitidas():
			_drenar_fila_falas()


func _rolar_para_fim() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_rolagem.scroll_vertical = int(_rolagem.get_v_scroll_bar().max_value)


# ------------------------------------------------------------------ escolha atual
func _atualizar() -> void:
	if not is_node_ready():
		return
	_atualizar_papel()
	UiKit.remover_itens(_botoes_escolha)
	var ap: Dictionary = GerenciadorNarrativa.apresentacao()
	var chat: bool = str(ap.get("contexto", "")) == "chat"
	var opcoes: Array = ap.get("opcoes", [])
	var bloqueadas: Array = GerenciadorNarrativa.opcoes_bloqueadas() if not chat else []
	_tem_opcoes_ativas = (not opcoes.is_empty() or not bloqueadas.is_empty()) and not chat
	if not _esta_digitando():
		_rot_fala_atual.text = ""
		_rot_fala_atual.visible = false
	_aplicar_visibilidade_escolhas()
	if not chat and cena_escolha != null:
		for opcao in opcoes:
			var botao := cena_escolha.instantiate() as ItemEscolha
			_area_escolhas.add_child(botao)
			botao.configurar(opcao)
			botao.escolhida.connect(_ao_escolher)
			_botoes_escolha.append(botao)
		for bloq in bloqueadas:
			var bd: Dictionary = bloq
			var botao_b := Button.new()
			botao_b.text = str(bd.get("texto", "Não"))
			botao_b.tooltip_text = str(bd.get("rotulo_removida", "Opção bloqueada pela Maya"))
			botao_b.modulate = Color(0.75, 0.72, 0.82, 0.72)
			botao_b.focus_mode = Control.FOCUS_ALL
			botao_b.pressed.connect(_ao_opcao_bloqueada.bind(str(bd.get("rotulo_removida", "Opção bloqueada pela Maya"))))
			_area_escolhas.add_child(botao_b)
			_botoes_escolha.append(botao_b)
	_cliques_bloqueados = 0
	var avisos: PackedStringArray = PackedStringArray()
	for removida in GerenciadorNarrativa.opcoes_removidas():
		avisos.append(str(removida))
	_rot_resultado.text = " ".join(avisos)
	_rot_resultado.visible = not avisos.is_empty()
	var app_do_no := str(ap.get("app", ""))
	var espera := str(ap.get("espera", ""))
	var pedir_mensageiro: bool = (chat and not opcoes.is_empty()) or espera == "abriu_mensageiro"
	_btn_mensageiro.visible = pedir_mensageiro or (app_do_no != "" and not GerenciadorJanelas.app_aberto(app_do_no))
	if pedir_mensageiro:
		_btn_mensageiro.text = "Abrir o Mensageiro"
	elif app_do_no == "privacidade_maya":
		_btn_mensageiro.text = "Ver o pedido de permissão"
	elif app_do_no == "minigame_logica":
		_btn_mensageiro.text = "Abrir o desafio de lógica"
	elif app_do_no != "":
		_btn_mensageiro.text = "Abrir a janela"
	_btn_fechar.visible = espera == "retorno_desktop" or GerenciadorJanelas.janelas().size() > 1
	if espera == "retorno_desktop":
		_btn_fechar.text = "Continuar com a Maya"
		_btn_fechar.theme_type_variation = &"BotaoPrimario"
	else:
		_btn_fechar.text = "Fechar janelas"
		_btn_fechar.theme_type_variation = &""
	_btn_historico.visible = GerenciadorNarrativa.historico_antigo_extra_disponivel()
	_rot_espera.text = _texto_da_espera(ap, chat, espera)
	_rot_espera.visible = _rot_espera.text != ""
	_rolar_para_fim()
	if is_visible_in_tree():
		_focar_primeiro.call_deferred()


func _texto_da_espera(ap: Dictionary, chat: bool, espera: String) -> String:
	if chat and not (ap.get("opcoes", []) as Array).is_empty():
		return "Responda na conversa do Mensageiro."
	if espera == "abriu_mensageiro":
		return "Você recebeu uma mensagem no Mensageiro. Abra o Mensageiro para continuar."
	if espera == "retorno_desktop":
		return "Exploração livre: você pode investigar Arquivos (como a pasta do Rafael), falar com seus amigos no Mensageiro ou usar o Terminal. Quando quiser avançar, clique em \"Continuar com a Maya\"."
	if str(ap.get("tipo", "")) == "barra_envio":
		return "A Maya está enviando uma mensagem por você. Cancele no Mensageiro, se quiser."
	return ""


## Única regra de visibilidade das respostas: há opções neste painel, a caixa foi clicada para este nó e a Maya terminou de escrever.
func _aplicar_visibilidade_escolhas() -> void:
	_caixa_entrada.sincronizar(_tem_opcoes_ativas, "%s|painel" % GerenciadorEstado.no_roteiro)
	_area_escolhas.visible = _tem_opcoes_ativas and _caixa_entrada.revelada() and not _esta_digitando()


func _ao_caixa_ativada() -> void:
	_aplicar_visibilidade_escolhas()
	_rolar_para_fim()
	if is_visible_in_tree():
		_focar_primeiro.call_deferred()


func area_de_escolhas_visivel() -> bool:
	return _area_escolhas.visible


func caixa_de_entrada() -> CaixaEntradaVisual:
	return _caixa_entrada


## "Pedir dica": texto de orientação do momento atual. Só lê o estado: não muda flags, escolhas nem Dependência.
static func texto_da_dica(ap: Dictionary) -> String:
	var opcoes: Array = ap.get("opcoes", [])
	var espera := str(ap.get("espera", ""))
	if not opcoes.is_empty() and str(ap.get("contexto", "")) == "chat":
		return "A resposta fica na conversa do Mensageiro. Leia as opções com calma antes de escolher."
	if not opcoes.is_empty():
		return "Clique na caixa \"Escreva uma mensagem...\" para ver as respostas e escolha a que mais parece com você."
	if espera == "retorno_desktop":
		return "Explore à vontade (Arquivos, Mensageiro, Terminal). Para avançar, clique em \"Continuar com a Maya\"."
	if str(ap.get("app", "")) != "":
		return "Há uma janela esperando por você: use o botão acima para abri-la."
	return "Nada pede sua atenção agora. Pode explorar a área de trabalho."


func _ao_pedir_dica() -> void:
	SistemaAudio.tocar_sfx("clique", -6.0)
	_rot_resultado.text = "Dica: " + texto_da_dica(GerenciadorNarrativa.apresentacao())
	_rot_resultado.visible = true


func _ao_fechar_painel() -> void:
	if janela is JanelaBase:
		GerenciadorJanelas.fechar_janela(janela as JanelaBase)


func _ao_escolher(id_escolha: String) -> void:
	_caixa_entrada.consumir()
	_drenar_fila_falas()
	GerenciadorNarrativa.escolher_opcao(id_escolha)


## Regra v2.1 (T9.6): o botão [Não] aparece, mas o clique é interceptado enquanto a Maya mantém Organização + Apps + Mensageiro.
func _ao_opcao_bloqueada(rotulo: String) -> void:
	_cliques_bloqueados += 1
	SistemaAudio.tocar_sfx("erro")
	if janela is JanelaBase and GerenciadorConfiguracoes.animacoes_permitidas() and not bool(GerenciadorConfiguracoes.obter("reduzir_tremor")):
		(janela as JanelaBase).tremer()
	if _cliques_bloqueados >= 2:
		_rot_resultado.text = "%s — A Maya está bloqueando esta resposta. Revogue as permissões no Terminal (`revogar`) ou em Configurações para recuperar o controle." % rotulo
	else:
		_rot_resultado.text = "%s — Clique interceptado pela Maya enquanto ela controla área de trabalho, aplicativos e Mensageiro." % rotulo
	_rot_resultado.visible = true


# Ligado na cena: BotaoFecharJanelas.pressed
func _ao_fechar_janelas() -> void:
	var ap: Dictionary = GerenciadorNarrativa.apresentacao()
	if str(ap.get("espera", "")) == "retorno_desktop":
		SistemaAudio.tocar_sfx("clique", -6.0)
		GerenciadorNarrativa.notificar("retorno_desktop")
		return
	for j in GerenciadorJanelas.janelas().duplicate():
		if j != janela and j is JanelaBase:
			GerenciadorJanelas.fechar_janela(j as JanelaBase)
	if janela is JanelaBase:
		GerenciadorJanelas.fechar_janela(janela as JanelaBase)


func _ao_abrir_historico() -> void:
	SistemaAudio.tocar_sfx("clique", -6.0)
	GerenciadorNarrativa.abrir_historico_antigo()


# Ligado na cena: BotaoAbrirMensageiro.pressed
func _ao_abrir_mensageiro() -> void:
	var ap: Dictionary = GerenciadorNarrativa.apresentacao()
	if str(ap.get("contexto", "")) == "chat" or str(ap.get("app", "")) == "":
		GerenciadorJanelas.abrir_app("messenger", {"contato": str(ap.get("contato", ""))})
	else:
		GerenciadorJanelas.abrir_app(str(ap["app"]), ap.get("args", {}))
