class_name FeedbackDependencia
extends RefCounted
## Regras PURAS do feedback visual da Dependência da Maya (a variável central é `GerenciadorEstado.dependencia_maya()`, 0 a 100; nada aqui guarda uma cópia).
## Faixas (a paleta é GRADUAL: o peso da tinta sobe por interpolação entre os pontos, nunca em degraus bruscos):
##   0–24  neutra            sem tinta
##   25–49 morna leve        leve tom quente
##   50–74 morna             tom quente claro
##   75–89 vermelha sutil    vermelho discreto + interferência ambiente muito baixa
##   90–100 vermelha intensa vermelho intenso + interferência ambiente baixa
## Glitch condicional: só com D >= 75 E num contexto de resistência (revogar/negar) ou de "a Maya recuperou o controle". Intensidade e duração
## são limitadas, escalam por `intensidade_glitch` das Configurações e respeitam o modo conforto/"reduzir glitch" (quem dispara confere
## `GerenciadorConfiguracoes.glitch_permitido()`). Nunca bloqueiam entrada.
## Aplicação: `AreaDeTrabalho.aplicar_feedback_dependencia(dependencia, contexto)` (a API central) lê estas funções.

const FAIXAS: Array = [
	[24, &"neutra"], [49, &"morna_leve"], [74, &"morna"], [89, &"vermelha_sutil"], [100, &"vermelha_intensa"],
]
const PONTOS_TINTA: Array = [[0, 0.0], [24, 0.0], [49, 0.10], [74, 0.24], [89, 0.38], [100, 0.60]]
const COR_MORNA := Color(0.96, 0.62, 0.04)
const COR_VERMELHA := Color(0.94, 0.27, 0.27)
const LIMIAR_GLITCH := 75
const FORCA_MAX_GLITCH := 0.45
const DURACAO_MAX_GLITCH := 0.5
const PREFIXOS_RESISTENCIA: PackedStringArray = ["revogar:", "negar:", "permissao_revogada", "resistencia", "controle_maya", "maya_recuperou_controle"]


static func faixa(dependencia: int) -> StringName:
	var d: int = clampi(dependencia, 0, 100)
	for par in FAIXAS:
		if d <= int((par as Array)[0]):
			return (par as Array)[1]
	return &"vermelha_intensa"


## Peso (0 a 0,6) com que a cor de destaque é puxada para o quente/vermelho. Interpolação linear entre PONTOS_TINTA.
static func peso_de_tinta(dependencia: int) -> float:
	var d: float = float(clampi(dependencia, 0, 100))
	for i in range(1, PONTOS_TINTA.size()):
		var a: Array = PONTOS_TINTA[i - 1]
		var b: Array = PONTOS_TINTA[i]
		if d <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var t: float = 0.0 if span <= 0.0 else (d - float(a[0])) / span
			return lerpf(float(a[1]), float(b[1]), t)
	return float(PONTOS_TINTA[PONTOS_TINTA.size() - 1][1])


## Cor para a qual a tinta aponta: morna até a metade, indo ao vermelho conforme D sobe de 50 a 90.
static func cor_alvo(dependencia: int) -> Color:
	var t: float = clampf((float(dependencia) - 50.0) / 40.0, 0.0, 1.0)
	return COR_MORNA.lerp(COR_VERMELHA, t)


## Cor de destaque tingida. `fator` < 1 enfraquece a tinta (quando o jogador escolheu uma cor de destaque manual).
static func tingir(base: Color, dependencia: int, fator: float = 1.0) -> Color:
	var peso: float = peso_de_tinta(dependencia) * clampf(fator, 0.0, 1.0)
	if peso <= 0.0:
		return base
	return base.lerp(cor_alvo(dependencia), peso)


## Interferência ambiente (0 a ~0,05) somada à base do shader de glitch: zero abaixo de 75, muito baixa nas faixas altas.
static func interferencia_ambiente(dependencia: int, intensidade_config: float = 1.0) -> float:
	var d: int = clampi(dependencia, 0, 100)
	var base: float = 0.0
	if d >= 90:
		base = 0.05
	elif d >= LIMIAR_GLITCH:
		base = 0.02
	return base * clampf(intensidade_config, 0.0, 1.0)


static func contexto_de_resistencia(contexto: StringName) -> bool:
	var c: String = str(contexto)
	for pref in PREFIXOS_RESISTENCIA:
		if c.begins_with(pref):
			return true
	return false


## Há motivo para um glitch pontual agora? (D alto E resistência/recuperação de controle). Não olha o modo conforto: quem dispara olha.
static func glitch_condicional(dependencia: int, contexto: StringName) -> bool:
	return dependencia >= LIMIAR_GLITCH and contexto_de_resistencia(contexto)


## {"intensidade": 0..FORCA_MAX, "duracao": s} do glitch pontual, escalados por `intensidade_config` (0 desliga).
static func parametros_glitch(dependencia: int, intensidade_config: float = 1.0) -> Dictionary:
	var t: float = clampf((float(dependencia) - float(LIMIAR_GLITCH)) / float(100 - LIMIAR_GLITCH), 0.0, 1.0)
	var k: float = clampf(intensidade_config, 0.0, 1.0)
	return {
		"intensidade": minf(lerpf(0.18, FORCA_MAX_GLITCH, t) * k, FORCA_MAX_GLITCH),
		"duracao": minf(lerpf(0.28, DURACAO_MAX_GLITCH, t), DURACAO_MAX_GLITCH),
	}
