#!/usr/bin/env python3
"""Verificador estático de escopos GDScript (complementa o validar_projeto.py).

Pega o tipo de erro que derruba o jogo em tempo de execução quando o script é carregado pela primeira vez:
  - variável/constante local redeclarada no mesmo escopo ou num escopo que a envolve ("There is already a variable named X");
  - função duplicada na mesma classe;
  - membro de classe (var/const/signal/enum) duplicado;
  - parâmetro de função redeclarado como variável local.
Não substitui o compilador do Godot (veja tests/sistemas_novos/modulo_compilacao.gd), mas roda em qualquer máquina, sem o motor.

Uso: python3 -I tools/verificar_escopos_gd.py [pasta_do_projeto]   (sai com código 1 se achar problemas)
"""
import os
import re
import sys

RE_FUNC = re.compile(r"^(\s*)(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)")
RE_VAR = re.compile(r"^(\s*)(?:@[A-Za-z_]+(?:\([^)]*\))?\s+)*(?:static\s+)?(var|const)\s+([A-Za-z_][A-Za-z0-9_]*)")
RE_SIGNAL = re.compile(r"^(\s*)signal\s+([A-Za-z_][A-Za-z0-9_]*)")
RE_ENUM = re.compile(r"^(\s*)enum\s+([A-Za-z_][A-Za-z0-9_]*)")
RE_FOR = re.compile(r"^\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b")
RE_CLASS = re.compile(r"^(\s*)class\s+([A-Za-z_][A-Za-z0-9_]*)")


def _limpar(linha: str) -> str:
    """Remove comentário e conteúdo de strings simples (suficiente para achar palavras-chave no início da linha)."""
    saida = []
    aspas = ""
    i = 0
    while i < len(linha):
        c = linha[i]
        if aspas:
            if c == "\\":
                i += 2
                continue
            if c == aspas:
                aspas = ""
            i += 1
            continue
        if c in "\"'":
            aspas = c
            saida.append(c)
            i += 1
            continue
        if c == "#":
            break
        saida.append(c)
        i += 1
    return "".join(saida)


def _params(resto: str) -> list:
    dentro = resto.split(")")[0]
    nomes = []
    for p in dentro.split(","):
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", p)
        if m:
            nomes.append(m.group(1))
    return nomes


def verificar_arquivo(caminho: str) -> list:
    problemas = []
    try:
        linhas = open(caminho, encoding="utf-8").read().split("\n")
    except OSError as e:
        return [(0, "não foi possível ler: %s" % e)]
    membros = {}
    funcoes = {}
    pilha = []            # blocos abertos da função atual: [indent_do_corpo, set(nomes)]
    func_indent = None    # indent da linha 'func' atual (None = fora de função)
    params = set()
    anterior_abre = False  # a última linha significativa terminou em ':'
    anterior_indent = 0
    em_texto = False
    for n, bruta in enumerate(linhas, 1):
        if bruta.count('"""') % 2 == 1:
            em_texto = not em_texto
            continue
        if em_texto:
            continue
        linha = _limpar(bruta)
        if not linha.strip():
            continue
        indent = len(linha) - len(linha.lstrip("\t "))
        mf = RE_FUNC.match(linha)
        if mf:
            ind = len(mf.group(1))
            chave = (ind, mf.group(2))
            if chave in funcoes:
                problemas.append((n, "função '%s' duplicada (já declarada na linha %d)" % (mf.group(2), funcoes[chave])))
            funcoes[chave] = n
            func_indent = ind
            params = set(_params(mf.group(3)))
            pilha = []
            anterior_abre = linha.rstrip().endswith(":")
            anterior_indent = indent
            continue
        if func_indent is not None and indent <= func_indent:
            func_indent = None
            pilha = []
        if func_indent is None:
            for rx, g in ((RE_VAR, 3), (RE_SIGNAL, 2), (RE_ENUM, 2)):
                mm = rx.match(linha)
                if mm:
                    nome = mm.group(g)
                    chave = (len(mm.group(1)), nome)
                    if chave in membros:
                        problemas.append((n, "membro '%s' duplicado (já declarado na linha %d)" % (nome, membros[chave])))
                    membros[chave] = n
            anterior_abre = linha.rstrip().endswith(":")
            anterior_indent = indent
            continue
        # dentro de função: fecha blocos que terminaram e abre o novo (linha anterior terminou em ':' e a indentação cresceu)
        while pilha and indent < pilha[-1][0]:
            pilha.pop()
        if anterior_abre and indent > anterior_indent:
            pilha.append([indent, set()])
        if not pilha:
            pilha.append([indent, set()])
        mv = RE_VAR.match(linha)
        if mv:
            nome = mv.group(3)
            if nome in params:
                problemas.append((n, "variável '%s' redeclara um parâmetro da função" % nome))
            else:
                for _, nomes in pilha:
                    if nome in nomes:
                        problemas.append((n, "variável '%s' já declarada neste escopo (There is already a variable named '%s')" % (nome, nome)))
                        break
            pilha[-1][1].add(nome)
        anterior_abre = linha.rstrip().endswith(":")
        anterior_indent = indent
    return problemas


RE_IDENT = re.compile(r"(?<![A-Za-z0-9_.\"'$%&@])([a-z_][A-Za-z0-9_]*)\b")
PALAVRAS = set("""if elif else for while match break continue pass return class class_name extends is in as and or not var const static func signal enum
await self super true false null void int float bool String Array Dictionary Vector2 Vector3 Color Rect2 Callable Variant when preload load
print push_error push_warning range str int float bool len min max abs""".split())


def verificar_nao_declarados(caminho: str) -> list:
    """Usa de uma variável local fora do escopo onde foi declarada: o nome é 'var' local em outra função do arquivo, não é membro da
    classe, parâmetro, nem variável de 'for'/'match' desta função, e aparece aqui sem declaração visível."""
    try:
        linhas = open(caminho, encoding="utf-8").read().split("\n")
    except OSError:
        return []
    membros = set()
    locais_em_funcoes = set()
    funcoes = []   # (inicio, fim_exclusivo, params)
    func_ind = None
    ini = 0
    params = set()
    texto = False
    limpas = []
    for n, bruta in enumerate(linhas):
        if bruta.count('"""') % 2 == 1:
            texto = not texto
            limpas.append("")
            continue
        limpas.append("" if texto else _limpar(bruta))
    for n, linha in enumerate(limpas):
        if not linha.strip():
            continue
        ind = len(linha) - len(linha.lstrip("\t "))
        mf = RE_FUNC.match(linha)
        if mf:
            if func_ind is not None:
                funcoes.append((ini, n, params))
            func_ind, ini, params = len(mf.group(1)), n, set(_params(mf.group(3)))
            continue
        if func_ind is not None and ind <= func_ind:
            funcoes.append((ini, n, params))
            func_ind = None
        mv = RE_VAR.match(linha)
        if mv:
            if func_ind is None:
                membros.add(mv.group(3))
            else:
                locais_em_funcoes.add(mv.group(3))
        ms = RE_SIGNAL.match(linha) or RE_ENUM.match(linha)
        if ms and func_ind is None:
            membros.add(ms.group(2))
    if func_ind is not None:
        funcoes.append((ini, len(limpas), params))
    candidatos = locais_em_funcoes - membros
    problemas = []
    for ini, fim, params in funcoes:
        visiveis = set(params)
        for n in range(ini, fim):
            linha = limpas[n]
            mv = RE_VAR.match(linha)
            mfor = RE_FOR.match(linha)
            # declarações (também as de 'for', 'match ... var x' e lambdas) entram antes de verificar a própria linha
            if mv:
                visiveis.add(mv.group(3))
            if mfor:
                visiveis.add(mfor.group(1))
            for m in re.finditer(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)", linha):
                visiveis.add(m.group(1))
            for m in re.finditer(r"func\s*\(([^)]*)\)", linha):
                visiveis.update(_params(m.group(1) + ")"))
            for m in RE_IDENT.finditer(linha):
                nome = m.group(1)
                if nome in candidatos and nome not in visiveis and nome not in PALAVRAS:
                    problemas.append((n + 1, "'%s' usado sem declaração neste escopo (é variável local de outra função)" % nome))
                    visiveis.add(nome)   # uma vez por função basta
    return problemas


def main() -> int:
    raiz = sys.argv[1] if len(sys.argv) > 1 else "."
    total = 0
    arquivos = 0
    for pasta, dirs, nomes in os.walk(raiz):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", "addons", "_saida")]
        for nome in nomes:
            if not nome.endswith(".gd"):
                continue
            arquivos += 1
            caminho = os.path.join(pasta, nome)
            for linha, texto in verificar_arquivo(caminho) + verificar_nao_declarados(caminho):
                total += 1
                print("%s:%d: %s" % (os.path.relpath(caminho, raiz), linha, texto))
    print("verificar_escopos_gd: %d arquivo(s) lido(s), %d problema(s)" % (arquivos, total))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
