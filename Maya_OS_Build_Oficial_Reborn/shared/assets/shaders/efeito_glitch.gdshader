shader_type canvas_item;
// Distorção de glitch em tempo real sobre a tela do HumaxOS: rasgo horizontal em fatias,
// aberração cromática ciano/magenta, linhas de varredura CRT e barras de interferência.
// Acessibilidade:
//   - intensidade = 0 desliga completamente (e o nó fica invisível);
//   - animar = 0 congela o efeito em modo suave e estático ("sem flashes").

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
uniform float animar : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (intensidade <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float t = floor(TIME * 14.0) * animar;
		float fatia = floor(SCREEN_UV.y * 42.0);
		float r_fatia = hash(vec2(fatia, t));
		float ativa_fatia = step(0.86 - intensidade * 0.24, r_fatia) * animar;
		float direcao = (hash(vec2(fatia + 17.0, t)) - 0.5) * 2.0;
		float desloc_x = direcao * ativa_fatia * (0.008 + 0.026 * intensidade);

		// Pequena tremulação fina em linhas de alta frequência
		float linha_fina = floor(SCREEN_UV.y * 160.0);
		float r_fina = hash(vec2(linha_fina, t + 3.0));
		desloc_x += (r_fina - 0.5) * step(0.92 - intensidade * 0.12, r_fina) * 0.012 * intensidade * animar;

		vec2 uv_base = clamp(SCREEN_UV + vec2(desloc_x, 0.0), vec2(0.001), vec2(0.999));

		// Aberração cromática RGB (mais intensa nos pulsos, sutil no ambiente)
		float chroma = (0.0018 + 0.010 * intensidade) * intensidade;
		vec2 uv_r = clamp(uv_base + vec2(chroma, 0.0), vec2(0.001), vec2(0.999));
		vec2 uv_b = clamp(uv_base - vec2(chroma, 0.0), vec2(0.001), vec2(0.999));

		float r = texture(SCREEN_TEXTURE, uv_r).r;
		float g = texture(SCREEN_TEXTURE, uv_base).g;
		float b = texture(SCREEN_TEXTURE, uv_b).b;
		vec3 cor = vec3(r, g, b);

		// Linhas de varredura CRT sutis
		float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * 920.0);
		cor *= 1.0 - (scan * 0.075 * intensidade);

		// Barras neon ciano/magenta discretas de interferência (sem flash de tela cheia)
		float barra = step(0.955 - intensidade * 0.04, r_fatia) * intensidade * animar;
		vec3 tint = mix(vec3(0.95, 0.18, 0.65), vec3(0.18, 0.90, 1.0), hash(vec2(fatia, t + 5.0)));
		cor = mix(cor, tint, clamp(barra * 0.34, 0.0, 0.34));

		// Granulação digital leve
		float gran = (hash(SCREEN_UV * vec2(780.0, 440.0) + t) - 0.5) * 0.11 * intensidade;
		cor = clamp(cor + vec3(gran), vec3(0.0), vec3(1.0));

		COLOR = vec4(cor, 1.0);
	}
}
