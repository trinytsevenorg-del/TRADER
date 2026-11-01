#!/usr/bin/env python3
"""
Gera texturas de ROUPA (skins) para os personagens humanos base.

O pacote gratuito traz só o corpo base. Este script lê a malha do corpo
(.gltf), descobre para cada triângulo em que parte do corpo ele está
(pela posição na pose T: altura e distância lateral) e pinta a textura UV:
camiseta, calça, botas, luvas e cinto. O relevo (músculos, dobras) da
textura original é preservado, então parece um traje justo/tático.

Uso:  python3 tools/gerar_roupas.py
Requer: Python 3, numpy e Pillow  (pip install numpy pillow)
As skins ficam definidas em SKINS abaixo: mude as cores e rode de novo.
"""
import json, os, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "characters")

# Cores: camisa, calça, botas, luvas, cinto (RGB 0-255)
SKINS = {
    "tatico":  dict(camisa=(78, 92, 60),   calca=(52, 50, 44),  botas=(32, 28, 24), luvas=(30, 30, 30), cinto=(25, 22, 20)),
    "urbano":  dict(camisa=(170, 40, 38),  calca=(48, 66, 110), botas=(235, 235, 230), luvas=(40, 40, 40), cinto=(30, 30, 30)),
    "noturno": dict(camisa=(30, 32, 38),   calca=(24, 25, 30),  botas=(18, 18, 20), luvas=(18, 18, 20), cinto=(60, 140, 200)),
    # tons de cáqui/marrom bem diferentes da pele (o bege claro parecia "sem roupa")
    "deserto": dict(camisa=(128, 108, 64), calca=(82, 66, 44), botas=(52, 38, 26), luvas=(60, 46, 32), cinto=(40, 30, 22)),
}

PERSONAGENS = {
    # pasta: (gltf, textura original escura, textura clara)
    "humano_masculino": ("humano_masculino.gltf", "T_Superhero_Male_Dark.png", "T_Superhero_Male_Light.png"),
    "humano_feminino": ("humano_feminino.gltf", "T_Superhero_Female_Dark_BaseColor.png", "T_Superhero_Female_Light.png"),
}

TIPOS = {"float": "f", 5126: "f", 5123: "H", 5125: "I", 5121: "B"}
COMPS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def ler_accessor(g, binario, idx):
    a = g["accessors"][idx]
    bv = g["bufferViews"][a["bufferView"]]
    n, c = a["count"], COMPS[a["type"]]
    fmt = TIPOS[a["componentType"]]
    tam = struct.calcsize(fmt)
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    passo = bv.get("byteStride", tam * c)
    out = np.empty((n, c), dtype=np.float64)
    for i in range(n):
        out[i] = struct.unpack_from("<" + fmt * c, binario, off + i * passo)
    return out


# Regiões (índices na máscara)
PELE, CAMISA, CALCA, BOTAS, LUVAS, CINTO = 0, 1, 2, 3, 4, 5


def regiao(P, altura):
    """Decide a região de cada ponto (N x 3) na pose T (y para cima, braços no eixo X)."""
    x, y = P[:, 0], P[:, 1]
    h = y / altura  # altura normalizada 0..1
    ax = np.abs(x)
    r = np.full(len(P), PELE, dtype=np.uint8)
    tronco = ax < 0.40
    r[tronco & (h < 0.845)] = CAMISA
    r[tronco & (h < 0.865) & (ax > 0.085)] = CAMISA      # topo dos ombros (pescoço fica de fora)
    r[tronco & (h < 0.555)] = CINTO
    r[tronco & (h < 0.525)] = CALCA
    r[(h < 0.13) & (ax < 0.25)] = BOTAS                     # cano da bota
    r[h < 0.075] = BOTAS
    braco = (h > 0.68) & (ax >= 0.40)                       # braço esticado (pose T)
    r[braco & (ax < 0.52)] = CAMISA                         # manga até perto do cotovelo
    r[braco & (ax >= 0.66)] = LUVAS
    return r


def rasterizar(pos, uv, ind, W, H, altura):
    """Pinta a máscara pixel a pixel: interpola a posição 3D dentro de cada
    triângulo UV (coordenadas baricêntricas) e classifica. Bordas ficam lisas."""
    m = np.full((H, W), 255, dtype=np.uint8)
    U = uv[:, 0] * W - 0.5
    V = uv[:, 1] * H - 0.5
    for a, b, c in ind:
        xs = (U[a], U[b], U[c]); ys = (V[a], V[b], V[c])
        x0, x1 = int(max(min(xs) - 1, 0)), int(min(max(xs) + 2, W))
        y0, y1 = int(max(min(ys) - 1, 0)), int(min(max(ys) + 2, H))
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1), np.arange(y0, y1))
        det = (V[b] - V[c]) * (U[a] - U[c]) + (U[c] - U[b]) * (V[a] - V[c])
        if abs(det) < 1e-9:
            continue
        l1 = ((V[b] - V[c]) * (gx - U[c]) + (U[c] - U[b]) * (gy - V[c])) / det
        l2 = ((V[c] - V[a]) * (gx - U[c]) + (U[a] - U[c]) * (gy - V[c])) / det
        l3 = 1.0 - l1 - l2
        dentro = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not dentro.any():
            continue
        P = (l1[dentro, None] * pos[a] + l2[dentro, None] * pos[b] + l3[dentro, None] * pos[c])
        m[gy[dentro], gx[dentro]] = regiao(P, altura)
    return m


def gerar(pasta, gltf, tex_escura, tex_clara):
    d = os.path.join(RAIZ, pasta)
    g = json.load(open(os.path.join(d, gltf)))
    binario = open(os.path.join(d, g["buffers"][0]["uri"]), "rb").read()
    # Malha do corpo = a que tem mais vértices
    melhor = max((p for m in g["meshes"] for p in m["primitives"]),
                 key=lambda p: g["accessors"][p["attributes"]["POSITION"]]["count"])
    pos = ler_accessor(g, binario, melhor["attributes"]["POSITION"])
    uv = ler_accessor(g, binario, melhor["attributes"]["TEXCOORD_0"])
    ind = ler_accessor(g, binario, melhor["indices"]).astype(int).reshape(-1, 3)
    altura = pos[:, 1].max()
    print(pasta, "vertices", len(pos), "triangulos", len(ind), "altura %.2f" % altura)

    base = Image.open(os.path.join(d, tex_escura)).convert("RGB")
    W, H = base.size
    m = rasterizar(pos, uv, ind, W, H, altura)
    # Dilata as bordas das ilhas UV para não aparecer "costura" de outra cor.
    for _ in range(4):
        vazio = m == 255
        viz = np.array(Image.fromarray(m).filter(ImageFilter.MinFilter(3)))
        m = np.where(vazio, viz, m)
    m[m == 255] = PELE
    # Depuração: descomente para ver a máscara de regiões.
    # Image.fromarray((m * 40).astype(np.uint8)).save(os.path.join(d, "_mascara_debug.png"))

    for tom, arq in (("escura", tex_escura), ("clara", tex_clara)):
        orig = np.asarray(Image.open(os.path.join(d, arq)).convert("RGB").resize((W, H)), dtype=np.float32) / 255.0
        lum = orig @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        detalhe = np.clip(lum / max(lum[m == CAMISA].mean(), 1e-3), 0.55, 1.45)[..., None]
        # Detalhe suavizado: mantém o volume, mas tira as manchas/poros da pele.
        for nome, cores in SKINS.items():
            out = orig.copy()
            for reg, chave in ((CAMISA, "camisa"), (CALCA, "calca"), (BOTAS, "botas"), (LUVAS, "luvas"), (CINTO, "cinto")):
                cor = np.array(cores[chave], dtype=np.float32) / 255.0
                sel = m == reg
                out[sel] = np.clip(cor * (0.35 + 0.65 * detalhe[sel]), 0, 1)
            arq_saida = os.path.join(d, "skin_%s_%s.png" % (nome, tom))
            Image.fromarray((out * 255).astype(np.uint8)).save(arq_saida, optimize=True)
            print("  ->", os.path.relpath(arq_saida, RAIZ))


if __name__ == "__main__":
    for pasta, (gltf, e, c) in PERSONAGENS.items():
        gerar(pasta, gltf, e, c)
