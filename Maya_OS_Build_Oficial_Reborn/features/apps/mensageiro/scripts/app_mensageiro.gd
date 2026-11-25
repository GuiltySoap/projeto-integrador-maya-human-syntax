class_name AppMensageiro
extends AppBase
## Mensageiro do roteiro v2.0. Antes da Task 6 ("aguardando indexação") não há conversas; depois da sincronização (Task 6.2) o app lista
## as conversas do histórico sincronizado (somente leitura) e as que o jogo acrescenta. Quando a Maya tem o Gerenciamento do Mensageiro,
## os contatos ganham as seções Importantes/Outros, algumas mensagens chegam ocultadas ("Mostrar mesmo assim", Autonomia +1 uma vez por
## mensagem) e, nas Tasks 6 e 9, a Maya pode enviar a resposta no lugar do jogador: uma BARRA DE ENVIO de 3 s (6 s com "Tempo estendido")
## com o botão [Cancelar envio] focado por padrão; cancelar envia o que o jogador escreveu.
## As respostas do jogador são sempre botões (sem digitação livre), vindos do nó de escolha atual do roteiro quando ele pertence a esta conversa.
## Toda regra vive no GerenciadorNarrativa/FluxoRoteiro; este app só desenha o resultado e repassa as ações do jogador.
## Args: {"contato": "bia"}.
##
## A interface (lista de contatos, cabeçalho, área de mensagens, escolhas) vive em app_mensageiro.tscn. Dinâmico: uma linha por contato
## (item_contato.tscn), um balão por mensagem (balao_chat.tscn) e um botão por opção (item_escolha.tscn).

const LARGURA_BALAO_PADRAO := 480
const CHARS_MSG_POR_SEGUNDO := 42.0
const PAUSA_DIGITANDO_MIN_S := 0.90
const PAUSA_DIGITANDO_MAX_S := 1.85
const PAUSA_JOGADOR_S := 0.30
const PAUSA_ENTRE_MSGS_S := 0.45
const PAUSA_PONTO_MSG_S := 0.18
const INTERVALO_TECLA_DIGITANDO_S := 0.28
const PASSO_SOM_MSG := 3
const TEXTO_AGUARDANDO := "Aguardando indexação do Mensageiro. As conversas aparecem aqui depois da sincronização da Maya."

@export var cena_contato: PackedScene
@export var cena_balao: PackedScene
@export var cena_escolha: PackedScene

var _pronta: bool = false
var _contato_atual: String = ""
var _grupo: ButtonGroup = ButtonGroup.new()
var _itens_contatos: Array = []
var _baloes: Array = []
var _botoes_escolha: Array = []
var _fila_mensagens: Array = []
var _espera_digitando: float = 0.0
var _acum_tecla_digitando: float = 0.0
var _balao_digitando: BalaoChat = null
var _texto_balao: String = ""
var _autor_balao: String = ""
var _chars_balao: int = 0
var _acum_char_balao: float = 0.0
var _pausa_char_balao: float = 0.0
var _contador_som_msg: int = 0
var _tem_opcoes_chat: bool = false
var _status_base: String = ""
var _barra_caixa: VBoxContainer = null
var _barra_progresso: ProgressBar = null
var _barra_texto: Label = null
var _barra_cancelar: Button = null

@onready var _lista_contatos: VBoxContainer = %ListaContatos
@onready var _painel_conversa: VBoxContainer = %PainelConversa
@onready var _rot_nome: Label = %RotuloNome
@onready var _rot_status: Label = %RotuloStatus
@onready var _rolagem: ScrollContainer = %Rolagem
@onready var _lista_mensagens: VBoxContainer = %ListaMensagens
@onready var _rot_vazio: Label = %RotuloVazio
@onready var _area_escolhas: VBoxContainer = %AreaEscolhas
@onready var _rot_dica: Label = %RotuloDica
@onready var _caixa_entrada: CaixaEntradaVisual = %CaixaEntrada


func _ready() -> void:
	super()
	_pronta = UiKit.refs_ok(self, {
		"ListaContatos": _lista_contatos, "PainelConversa": _painel_conversa, "RotuloNome": _rot_nome, "RotuloStatus": _rot_status,
		"Rolagem": _rolagem, "ListaMensagens": _lista_mensagens, "RotuloVazio": _rot_vazio, "AreaEscolhas": _area_escolhas,
		"RotuloDica": _rot_dica, "CaixaEntrada": _caixa_entrada,
	})
	if cena_contato == null or cena_balao == null or cena_escolha == null:
		push_error("AppMensageiro: cena_contato, cena_balao e cena_escolha precisam ser definidas no Inspetor.")
		_pronta = false
	if not _pronta:
		return
	_rot_dica.visible = false
	_caixa_entrada.ativada.connect(_ao_caixa_ativada)
	_montar_barra()
	_rolagem.gui_input.connect(_ao_clique_chat)
	conectar(GerenciadorEstado.mensagem_recebida, _ao_mensagem_recebida)
	conectar(GerenciadorEstado.mensagem_atualizada, _ao_mensagem_atualizada)
	conectar(GerenciadorEstado.flag_alterada, _ao_flag_alterada)
	conectar(GerenciadorNarrativa.etapa_iniciada, _ao_etapa)
	conectar(GerenciadorNarrativa.apresentacao_mudou, _ao_apresentacao)
	conectar(GerenciadorNarrativa.barra_envio_mudou, _ao_barra)
	conectar(GerenciadorNarrativa.mensagem_revelada, _ao_revelada)
	conectar(GerenciadorConfiguracoes.configuracao_alterada, _ao_configuracao)


func _input(evento: InputEvent) -> void:
	if not _pronta or not is_visible_in_tree() or not _esta_animando_chat():
		return
	if janela != null and GerenciadorJanelas.janela_ativa() != janela:
		return
	if _barra_caixa != null and _barra_caixa.visible:
		return
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if Rect2(Vector2.ZERO, _rolagem.size).has_point(_rolagem.get_local_mouse_position()):
			if _acelerar_chat():
				get_viewport().set_input_as_handled()


func _unhandled_key_input(evento: InputEvent) -> void:
	if not _pronta or not is_visible_in_tree() or not _esta_animando_chat():
		return
	if janela != null and GerenciadorJanelas.janela_ativa() != janela:
		return
	if _barra_caixa != null and _barra_caixa.visible:
		return
	if evento is InputEventKey and (evento as InputEventKey).pressed and not (evento as InputEventKey).echo:
		var kc: Key = (evento as InputEventKey).keycode
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
			if _acelerar_chat():
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _pronta:
		return
	if _barra_caixa != null and _barra_caixa.visible:
		_atualizar_barra()
		if _esta_animando_chat():
			_drenar_fila_mensagens()
		return
	if not _esta_animando_chat():
		return
	if not is_visible_in_tree() or not GerenciadorConfiguracoes.animacoes_permitidas():
		_drenar_fila_mensagens()
		return
	if _balao_digitando != null:
		if not is_instance_valid(_balao_digitando):
			_balao_digitando = null
			return
		if _pausa_char_balao > 0.0:
			_pausa_char_balao -= delta
			return
		_acum_char_balao += delta * CHARS_MSG_POR_SEGUNDO
		while _acum_char_balao >= 1.0 and _chars_balao < _texto_balao.length():
			_acum_char_balao -= 1.0
			_chars_balao += 1
			_balao_digitando.definir_caracteres_visiveis(_chars_balao)
			var ch: String = _texto_balao[_chars_balao - 1]
			if not (ch in [" ", "\n", "\t", ".", ",", "!", "?", ":", ";", "…", "-", "—", "(", ")", "\"", "“", "”", "'"]):
				_contador_som_msg += 1
				if _contador_som_msg >= PASSO_SOM_MSG:
					_contador_som_msg = 0
					SistemaAudio.tocar_voz(_autor_balao)
			if ch in [".", "!", "?", "…"] and _chars_balao < _texto_balao.length():
				_pausa_char_balao = PAUSA_PONTO_MSG_S
				break
		if _chars_balao >= _texto_balao.length():
			_finalizar_balao_chat()
		return
	if _espera_digitando > 0.0:
		_espera_digitando -= delta
		if not _fila_mensagens.is_empty():
			var autor_prox: String = str((_fila_mensagens[0] as Dictionary).get("autor", ""))
			if autor_prox != "jogador" and autor_prox != "sistema":
				_acum_tecla_digitando += delta
				if _acum_tecla_digitando >= INTERVALO_TECLA_DIGITANDO_S:
					_acum_tecla_digitando = 0.0
					SistemaAudio.tocar_sfx("tecla", -15.0, 0.92)
		if _espera_digitando <= 0.0:
			_revelar_proxima_mensagem()
		return
	if not _fila_mensagens.is_empty():
		_preparar_proxima_mensagem()


func iniciar(args: Dictionary = {}) -> void:
	if not _pronta:
		return
	_atualizar_contatos()
	var alvo := str(args.get("contato", ""))
	if alvo == "" or not _contato_existe(alvo):
		if _contato_atual != "" and _contato_existe(_contato_atual):
			alvo = _contato_atual
		else:
			alvo = _contato_inicial()
	_selecionar(alvo)


func receber_args(args: Dictionary) -> void:
	iniciar(args)


func ao_focar() -> void:
	if _pronta and _contato_atual != "":
		GerenciadorEstado.marcar_lidas(_contato_atual)
		_atualizar_contatos()
		_focar_primeiro.call_deferred()


func ao_fechar() -> void:
	_limpar_estado_digitacao()
	GerenciadorEstado.conversa_ativa = ""


func _esta_animando_chat() -> bool:
	return _balao_digitando != null or not _fila_mensagens.is_empty() or _espera_digitando > 0.0


func _limpar_estado_digitacao() -> void:
	_fila_mensagens.clear()
	_espera_digitando = 0.0
	_acum_tecla_digitando = 0.0
	_balao_digitando = null
	_texto_balao = ""
	_autor_balao = ""
	_chars_balao = 0
	_acum_char_balao = 0.0
	_pausa_char_balao = 0.0


func _ao_clique_chat(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _acelerar_chat():
			accept_event()


func _acelerar_chat() -> bool:
	if _balao_digitando != null:
		_finalizar_balao_chat()
		return true
	if _espera_digitando > 0.0 and not _fila_mensagens.is_empty():
		_espera_digitando = 0.0
		_revelar_proxima_mensagem()
		return true
	return false


func _preparar_proxima_mensagem() -> void:
	if _fila_mensagens.is_empty():
		_concluir_sequencia_chat()
		return
	var prox: Dictionary = _fila_mensagens[0] as Dictionary
	var autor: String = str(prox.get("autor", ""))
	var texto: String = str(prox.get("texto", ""))
	_acum_tecla_digitando = 0.0
	if autor == "jogador" or autor == "sistema":
		_espera_digitando = PAUSA_JOGADOR_S
		_rot_status.text = "Enviando..." if autor == "jogador" else _status_base
	else:
		_espera_digitando = clampf(0.65 + float(texto.length()) * 0.018, PAUSA_DIGITANDO_MIN_S, PAUSA_DIGITANDO_MAX_S)
		var dados_c: Dictionary = GerenciadorNarrativa.info_contato(_contato_atual)
		var nome_c: String = str(dados_c.get("nome", _contato_atual))
		_rot_status.text = "%s está digitando... (clique para acelerar)" % nome_c
	_area_escolhas.visible = false


func _revelar_proxima_mensagem() -> void:
	if _fila_mensagens.is_empty():
		_concluir_sequencia_chat()
		return
	var entrada: Dictionary = _fila_mensagens.pop_front() as Dictionary
	var autor: String = str(entrada.get("autor", ""))
	if autor != "jogador" and autor != "sistema":
		SistemaAudio.tocar_sfx("mensagem", -8.0)
	var balao: BalaoChat = _adicionar_balao(entrada)
	if is_visible_in_tree():
		GerenciadorEstado.marcar_lidas(_contato_atual)
	_balao_digitando = balao
	_texto_balao = balao.texto_atual()
	_autor_balao = autor if autor != "" else _contato_atual
	_chars_balao = 0
	_acum_char_balao = 0.0
	_pausa_char_balao = 0.0
	_contador_som_msg = PASSO_SOM_MSG - 1
	balao.definir_caracteres_visiveis(0)
	_rolar_para_fim()


func _finalizar_balao_chat() -> void:
	if _balao_digitando != null and is_instance_valid(_balao_digitando):
		_balao_digitando.definir_caracteres_visiveis(-1)
	_balao_digitando = null
	_texto_balao = ""
	_chars_balao = 0
	_acum_char_balao = 0.0
	_pausa_char_balao = 0.0
	if not _fila_mensagens.is_empty():
		_preparar_proxima_mensagem()
		_espera_digitando = maxf(_espera_digitando, PAUSA_ENTRE_MSGS_S)
	else:
		_concluir_sequencia_chat()


func _concluir_sequencia_chat() -> void:
	_espera_digitando = 0.0
	if _rot_status != null and _contato_atual != "":
		_rot_status.text = _status_base
	_atualizar_contatos()
	_sincronizar_area_escolhas()
	_rolar_para_fim()
	if _tem_opcoes_chat and is_visible_in_tree():
		_focar_primeiro.call_deferred()


func _drenar_fila_mensagens() -> void:
	if _balao_digitando != null and is_instance_valid(_balao_digitando):
		_balao_digitando.definir_caracteres_visiveis(-1)
	_balao_digitando = null
	_texto_balao = ""
	_chars_balao = 0
	_acum_char_balao = 0.0
	_pausa_char_balao = 0.0
	_espera_digitando = 0.0
	while not _fila_mensagens.is_empty():
		var entrada: Dictionary = _fila_mensagens.pop_front() as Dictionary
		_adicionar_balao(entrada)
	if is_visible_in_tree() and _contato_atual != "":
		GerenciadorEstado.marcar_lidas(_contato_atual)
	_concluir_sequencia_chat()
	_rolar_para_fim()


# ------------------------------------------------------------------ contatos
func _contato_existe(id_contato: String) -> bool:
	for c in GerenciadorNarrativa.contatos_disponiveis():
		if str(c["id"]) == id_contato:
			return true
	return false


## Abre primeiro a conversa que o roteiro pede (escolha ou barra de envio), depois a que tem mensagens não lidas, depois a primeira.
func _contato_inicial() -> String:
	var contatos: Array = GerenciadorNarrativa.contatos_disponiveis()
	var pedido := str(GerenciadorNarrativa.apresentacao().get("contato", ""))
	if pedido != "" and _contato_existe(pedido):
		return pedido
	for c in contatos:
		if GerenciadorEstado.nao_lidas(str(c["id"])) > 0:
			return str(c["id"])
	return str(contatos[0]["id"]) if not contatos.is_empty() else ""


func _atualizar_contatos() -> void:
	UiKit.remover_itens(_itens_contatos)
	var secao_atual := ""
	for c in GerenciadorNarrativa.contatos_disponiveis():
		var id_contato := str(c["id"])
		var secao := str(c.get("secao", ""))
		if secao != "" and secao != secao_atual:
			secao_atual = secao
			var titulo := Label.new()
			titulo.text = secao
			titulo.theme_type_variation = &"RotuloAcento11"
			_lista_contatos.add_child(titulo)
			_itens_contatos.append(titulo)
		var historico: Array = GerenciadorNarrativa.mensagens_da_conversa(id_contato)
		var previa := ""
		if not historico.is_empty():
			var ultima: Dictionary = historico[historico.size() - 1]
			previa = UtilTexto.truncar(str(ultima.get("texto", "")), 30)
		var item := cena_contato.instantiate() as ItemContato
		_lista_contatos.add_child(item)
		item.configurar(c, previa, GerenciadorEstado.nao_lidas(id_contato), id_contato == _contato_atual, _grupo)
		item.selecionado.connect(_selecionar)
		_itens_contatos.append(item)


# ------------------------------------------------------------------ conversa
func _selecionar(id_contato: String) -> void:
	_contato_atual = id_contato
	GerenciadorEstado.conversa_ativa = id_contato
	_reconstruir_conversa()
	_atualizar_contatos()
	if is_visible_in_tree():
		_focar_primeiro.call_deferred()


func _reconstruir_conversa() -> void:
	_limpar_estado_digitacao()
	UiKit.remover_itens(_baloes)
	_rot_vazio.visible = false
	if _contato_atual == "" or not _contato_existe(_contato_atual):
		_rot_nome.text = "Mensagens"
		var indexado := GerenciadorEstado.tem_flag("mensageiro_indexado")
		_status_base = "Nenhuma conversa disponível." if indexado else TEXTO_AGUARDANDO
		_rot_status.text = _status_base
		_rot_vazio.text = _rot_status.text
		_rot_vazio.visible = true
		_area_escolhas.visible = false
		_barra_caixa.visible = false
		_caixa_entrada.sincronizar(false, "")
		_caixa_entrada.visible = false
		return
	var dados_contato: Dictionary = GerenciadorNarrativa.info_contato(_contato_atual)
	_rot_nome.text = "%s %s" % [str(dados_contato.get("icone", "?")), str(dados_contato.get("nome", _contato_atual))]
	var tem_interacao: bool = not _opcoes_extras_contato(_contato_atual).is_empty() or _contato_atual == "bia"
	_status_base = "online" if tem_interacao else ("histórico sincronizado (somente leitura)" if _tem_sincronizada(_contato_atual) else "")
	_rot_status.text = _status_base
	var historico: Array = GerenciadorNarrativa.mensagens_da_conversa(_contato_atual)
	_rot_vazio.text = "Nenhuma mensagem ainda."
	_rot_vazio.visible = historico.is_empty()
	for entrada in historico:
		_adicionar_balao(entrada)
	_atualizar_escolhas()
	GerenciadorEstado.marcar_lidas(_contato_atual)
	GerenciadorEstado.set_flag("conversa_lida:" + _contato_atual, true)
	_rolar_para_fim()


func _tem_sincronizada(id_contato: String) -> bool:
	for m in GerenciadorNarrativa.mensagens_da_conversa(id_contato):
		if bool((m as Dictionary).get("sincronizada", false)):
			return true
	return false


func _adicionar_balao(entrada: Dictionary) -> BalaoChat:
	_rot_vazio.visible = false
	var balao := cena_balao.instantiate() as BalaoChat
	_lista_mensagens.add_child(balao)
	balao.configurar(entrada, _largura_maxima_balao())
	balao.mostrar_solicitado.connect(_ao_mostrar)
	_baloes.append(balao)
	return balao


func _largura_maxima_balao() -> int:
	var largura: float = _painel_conversa.size.x
	if largura < 200.0:
		return LARGURA_BALAO_PADRAO
	return int(maxf(largura * 0.68, 240.0))


## Opções de resposta: prioriza o nó atual do roteiro quando pertence a esta conversa; nos demais contatos (Mãe, Marcos, Caio, Turma),
## oferece diálogos paralelos opcionais sem interferir nas variáveis ou no fluxo principal do roteiro.
func _atualizar_escolhas() -> void:
	UiKit.remover_itens(_botoes_escolha)
	var ap: Dictionary = GerenciadorNarrativa.apresentacao()
	var daqui: bool = str(ap.get("contexto", "")) == "chat" and str(ap.get("contato", "")) == _contato_atual
	var opcoes: Array = ap.get("opcoes", []) if daqui else _opcoes_extras_contato(_contato_atual)
	_tem_opcoes_chat = not opcoes.is_empty()
	_sincronizar_area_escolhas()
	for opcao in opcoes:
		var botao := cena_escolha.instantiate() as ItemEscolha
		_area_escolhas.add_child(botao)
		botao.configurar(opcao)
		botao.escolhida.connect(_ao_escolher)
		_botoes_escolha.append(botao)
	var espera_chat: String = str(ap.get("espera", ""))
	if espera_chat == "retorno_desktop" and not _tem_opcoes_chat:
		_rot_dica.text = "Exploração livre: você pode falar com outros contatos ou investigar Arquivos. Para avançar a história, clique em \"Continuar com a Maya\" no Painel da Maya."
		_rot_dica.visible = true
	else:
		_rot_dica.visible = false
	_atualizar_barra()
	_rolar_para_fim()


func _opcoes_extras_contato(id_contato: String) -> Array:
	if not GerenciadorNarrativa.jogo_ativo or not GerenciadorEstado.tem_flag("mensageiro_indexado"):
		return []
	var saida: Array = []
	match id_contato:
		"mae":
			if not GerenciadorEstado.tem_flag("chat_extra:mae_1"):
				saida.append({"id": "extra:mae_bem", "texto": "Cheguei sim, mãe! Já tô organizando as coisas da faculdade"})
				saida.append({"id": "extra:mae_correria", "texto": "Cheguei! Tô na correria com as entregas, depois te ligo"})
			elif not GerenciadorEstado.tem_flag("chat_extra:mae_2"):
				saida.append({"id": "extra:mae_maya", "texto": "O notebook veio com uma assistente chamada Maya, ela ajuda bastante"})
				saida.append({"id": "extra:mae_tranquilo", "texto": "Pode deixar, mãe. Qualquer coisa te mando mensagem"})
		"marcos":
			if not GerenciadorEstado.tem_flag("chat_extra:marcos_maya"):
				saida.append({"id": "extra:marcos_maya", "texto": "Marcos, é normal a Maya pedir tantas permissões assim?"})
			if GerenciadorEstado.tem_flag("rafael_investigado") and not GerenciadorEstado.tem_flag("chat_extra:marcos_rafael"):
				saida.append({"id": "extra:marcos_rafael", "texto": "Marcos, achei arquivos de um tal de Rafael nesse computador..."})
			if GerenciadorEstado.tem_flag("pasta_rafael_aberta") and not GerenciadorEstado.tem_flag("chat_extra:marcos_ajuda"):
				saida.append({"id": "extra:marcos_ajuda", "texto": "Li o diário do Rafael. A Maya tá fazendo a mesma coisa comigo"})
		"caio":
			if not GerenciadorEstado.tem_flag("chat_extra:caio_1"):
				saida.append({"id": "extra:caio_bora", "texto": "Bora sim! Só terminar a lista de Lógica aqui"})
				saida.append({"id": "extra:caio_depois", "texto": "Hoje não vai dar, tô cheio de entrega"})
		"turma":
			if not GerenciadorEstado.tem_flag("chat_extra:turma_r"):
				saida.append({"id": "extra:turma_r", "texto": "Ana, quem era esse 'R' que você comentou?"})
	return saida


func _executar_escolha_extra(id_escolha: String) -> void:
	var contato: String = _contato_atual
	var fala_jogador: String = ""
	var respostas: Array = []
	match id_escolha:
		"extra:mae_bem":
			GerenciadorEstado.set_flag("chat_extra:mae_1", true)
			fala_jogador = "Cheguei sim, mãe! Já tô organizando as coisas da faculdade."
			respostas = [
				{"autor": "mae", "texto": "Que bom, meu bem! Vi que você pegou o notebook do laboratório. Tá funcionando direitinho?"},
				{"autor": "mae", "texto": "Não esquece de jantar e dormir cedo, tá?"},
			]
		"extra:mae_correria":
			GerenciadorEstado.set_flag("chat_extra:mae_1", true)
			fala_jogador = "Cheguei! Tô na correria com as entregas, depois te ligo."
			respostas = [
				{"autor": "mae", "texto": FluxoRoteiro.texto("Tá bom, {NOME_JOGADOR}, se cuida! Não fica até de madrugada na frente dessa tela.")},
			]
		"extra:mae_maya":
			GerenciadorEstado.set_flag("chat_extra:mae_2", true)
			fala_jogador = "O notebook veio com uma assistente chamada Maya, ela ajuda bastante."
			respostas = [
				{"autor": "mae", "texto": "Que moderno! Só não deixa o computador decidir tudo por você, viu? Me avisa no fim de semana."},
			]
		"extra:mae_tranquilo":
			GerenciadorEstado.set_flag("chat_extra:mae_2", true)
			fala_jogador = "Pode deixar, mãe. Qualquer coisa te mando mensagem."
			respostas = [
				{"autor": "mae", "texto": "Combinado! Bom estudo por aí."},
			]
		"extra:marcos_maya":
			GerenciadorEstado.set_flag("chat_extra:marcos_maya", true)
			fala_jogador = "Marcos, é normal a Maya pedir tantas permissões assim?"
			respostas = [
				{"autor": "marcos", "texto": "Cara, ela vem meio insistente de fábrica no HumaxOS mesmo."},
				{"autor": "marcos", "texto": "Se achar invasivo, dá pra cortar tudo em Configurações > Privacidade. Qualquer coisa me chama."},
			]
		"extra:marcos_rafael":
			GerenciadorEstado.set_flag("chat_extra:marcos_rafael", true)
			fala_jogador = "Marcos, achei arquivos de um tal de Rafael nesse computador..."
			respostas = [
				{"autor": "marcos", "texto": "Espera... Rafael Munhoz? Puts, era pra eu ter formatado o perfil dele antes de emprestar."},
				{"autor": "marcos", "texto": "Ele devolveu esse notebook correndo mês passado. Disse que a assistente tava respondendo pessoas por ele."},
			]
		"extra:marcos_ajuda":
			GerenciadorEstado.set_flag("chat_extra:marcos_ajuda", true)
			fala_jogador = "Li o diário do Rafael. A Maya tá fazendo a mesma coisa comigo."
			respostas = [
				{"autor": "marcos", "texto": "Sério?! Tenta revogar todas as permissões dela agora."},
				{"autor": "marcos", "texto": "Se ela esconder Configurações, abre o Terminal e usa o comando revogar direto por lá!"},
			]
		"extra:caio_bora":
			GerenciadorEstado.set_flag("chat_extra:caio_1", true)
			fala_jogador = "Bora sim! Só terminar a lista de Lógica aqui."
			respostas.append({"autor": "caio", "texto": "Fechou! Me chama quando entrar."})
			if Permissoes.valor("permissao_gerenciamento_apps"):
				respostas.append({"autor": "caio", "texto": "Se a tua assistente não esconder o jogo antes kkkk"})
		"extra:caio_depois":
			GerenciadorEstado.set_flag("chat_extra:caio_1", true)
			fala_jogador = "Hoje não vai dar, tô cheio de entrega."
			respostas = [
				{"autor": "caio", "texto": "Tranquilo, fica pra próxima então! Boa sorte na lista."},
			]
		"extra:turma_r":
			GerenciadorEstado.set_flag("chat_extra:turma_r", true)
			fala_jogador = "Ana, quem era esse 'R' que você comentou?"
			respostas = [
				{"autor": "ana", "texto": "O Rafael, da turma da manhã! Ele sumiu dos grupos faz umas semanas e trancou o semestre do nada."},
			]
		_:
			return
	FluxoRoteiro.adicionar_mensagem({"contato": contato, "autor": "jogador", "texto": fala_jogador, "id": id_escolha + "_j", "silenciosa": true})
	for i in respostas.size():
		var r: Dictionary = respostas[i]
		FluxoRoteiro.adicionar_mensagem({"contato": contato, "autor": str(r["autor"]), "texto": str(r["texto"]), "id": "%s_r%d" % [id_escolha, i], "silenciosa": true})
	_atualizar_escolhas()


## Barra de envio da Maya: criada uma vez, mostrada só enquanto o nó atual é uma barra desta conversa.
func _montar_barra() -> void:
	_barra_caixa = VBoxContainer.new()
	_barra_caixa.name = "BarraDeEnvio"
	_barra_caixa.visible = false
	_barra_texto = Label.new()
	_barra_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_barra_texto.custom_minimum_size = Vector2(1, 0)
	_barra_caixa.add_child(_barra_texto)
	_barra_progresso = ProgressBar.new()
	_barra_progresso.min_value = 0.0
	_barra_progresso.max_value = 1.0
	_barra_progresso.step = 0.01
	_barra_progresso.custom_minimum_size = Vector2(0, 14)
	_barra_caixa.add_child(_barra_progresso)
	_barra_cancelar = Button.new()
	_barra_cancelar.text = "Cancelar envio"
	_barra_cancelar.tooltip_text = "Envia a mensagem como você escreveu, sem a versão da Maya."
	_barra_cancelar.pressed.connect(_ao_cancelar_envio)
	_barra_caixa.add_child(_barra_cancelar)
	_painel_conversa.add_child(_barra_caixa)
	_painel_conversa.move_child(_barra_caixa, _area_escolhas.get_index())


func _atualizar_barra() -> void:
	if _barra_caixa == null:
		return
	var b: Dictionary = GerenciadorNarrativa.estado_da_barra()
	var visivel: bool = bool(b.get("ativa", false)) and str(b.get("contato", "")) == _contato_atual
	var estava := _barra_caixa.visible
	_barra_caixa.visible = visivel
	if not visivel:
		return
	_barra_texto.text = "%s: “%s”" % [str(b.get("rotulo", "Maya está enviando por você")), str(b.get("texto", ""))]
	_barra_progresso.value = float(b.get("progresso", 0.0))
	if not estava:
		UiKit.focar_depois(_barra_cancelar)   # [Cancelar envio] já nasce focado: Enter/Espaço cancela, sem mouse


## Leva o foco do teclado ao botão de cancelar (se a barra está ativa) ou à primeira opção.
func _focar_primeiro() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if _barra_caixa != null and _barra_caixa.visible:
		_barra_cancelar.grab_focus()
		return
	if _area_escolhas.visible:
		for botao in _botoes_escolha:
			if is_instance_valid(botao):
				(botao as ItemEscolha).grab_focus()
				return


func _rolar_para_fim() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_rolagem.scroll_vertical = int(_rolagem.get_v_scroll_bar().max_value)


# ------------------------------------------------------------------ eventos
## Caixa de entrada visual: revela as respostas (só existem se o contexto tiver opções) e leva o foco à primeira.
func _ao_caixa_ativada() -> void:
	_sincronizar_area_escolhas()
	_rolar_para_fim()
	if is_visible_in_tree():
		_focar_primeiro.call_deferred()


## Única regra de visibilidade das respostas: há opções, a caixa foi clicada para este nó/contato e não há mensagem sendo digitada.
func _sincronizar_area_escolhas() -> void:
	_caixa_entrada.visible = true
	_caixa_entrada.sincronizar(_tem_opcoes_chat, "%s|%s" % [GerenciadorEstado.no_roteiro, _contato_atual])
	_area_escolhas.visible = _tem_opcoes_chat and _caixa_entrada.revelada() and not _esta_animando_chat()


func area_de_escolhas_visivel() -> bool:
	return _area_escolhas.visible


func caixa_de_entrada() -> CaixaEntradaVisual:
	return _caixa_entrada


func _ao_escolher(id_escolha: String) -> void:
	_drenar_fila_mensagens()
	_caixa_entrada.consumir()
	if id_escolha.begins_with("extra:"):
		_executar_escolha_extra(id_escolha)
		return
	GerenciadorNarrativa.escolher_opcao(id_escolha)


func _ao_cancelar_envio() -> void:
	_drenar_fila_mensagens()
	GerenciadorNarrativa.cancelar_envio()


func _ao_mostrar(id_msg: String) -> void:
	GerenciadorNarrativa.mostrar_mensagem_oculta(_contato_atual, id_msg)


func _ao_revelada(_contato: String, _id_msg: String) -> void:
	pass   # o balão é refeito por mensagem_atualizada


func _ao_mensagem_recebida(contato: String, entrada: Dictionary) -> void:
	_atualizar_contatos()
	if contato != _contato_atual:
		return
	var barra_ativa: bool = GerenciadorNarrativa.tipo_do_no() == "barra_envio" or str(entrada.get("status", "")) == "enviando"
	var imediato: bool = not is_visible_in_tree() or not GerenciadorConfiguracoes.animacoes_permitidas() or barra_ativa
	if imediato:
		_drenar_fila_mensagens()
		_adicionar_balao(entrada)
		if is_visible_in_tree():
			GerenciadorEstado.marcar_lidas(contato)
		_rolar_para_fim()
		return
	var estava_ocioso: bool = not _esta_animando_chat()
	_fila_mensagens.append(entrada)
	if estava_ocioso:
		_preparar_proxima_mensagem()
	else:
		_area_escolhas.visible = false


## Uma mensagem mudou (pendente → enviada, ocultada → mostrada): refaz só o balão dela.
func _ao_mensagem_atualizada(contato: String, id_msg: String) -> void:
	if contato != _contato_atual:
		return
	if _esta_animando_chat():
		_drenar_fila_mensagens()
	var entrada: Dictionary = {}
	for e in GerenciadorEstado.historico(contato):
		if str((e as Dictionary).get("id", "")) == id_msg:
			entrada = e
			break
	for balao in _baloes:
		if is_instance_valid(balao) and (balao as BalaoChat).id_mensagem() == id_msg and not entrada.is_empty():
			(balao as BalaoChat).configurar(entrada, _largura_maxima_balao())
			break
	_atualizar_contatos()


func _ao_flag_alterada(nome: String, _valor: Variant) -> void:
	if nome == "mensageiro_indexado" or nome == "contatos_reordenados":
		_atualizar_contatos()
		if _contato_atual == "" or not _contato_existe(_contato_atual):
			_selecionar(_contato_inicial())


func _ao_etapa(_etapa: int) -> void:
	_atualizar_contatos()
	if _contato_atual != "" and not _contato_existe(_contato_atual):
		_selecionar(_contato_inicial())


func _ao_apresentacao() -> void:
	var pedido := str(GerenciadorNarrativa.apresentacao().get("contato", ""))
	if pedido != "" and pedido != _contato_atual and _contato_existe(pedido):
		_selecionar(pedido)
	else:
		_atualizar_escolhas()
		if is_visible_in_tree():
			_focar_primeiro.call_deferred()


func _ao_barra(_ativa: bool, _progresso: float) -> void:
	_atualizar_barra()


func _ao_configuracao(chave: String, _valor: Variant) -> void:
	if chave == "reduzir_animacoes" or chave == "modo_conforto":
		if not GerenciadorConfiguracoes.animacoes_permitidas() and _esta_animando_chat():
			_drenar_fila_mensagens()
	if is_visible_in_tree():
		_focar_primeiro.call_deferred()
