#!/usr/bin/env python3
"""
Gera as texturas do mapa (256x256, repetíveis/"tileable"), em assets/map/texturas/.
Quase todas são claras/neutras: a COR vem do material (albedo_color), então uma
textura serve para paredes de várias cores (menos memória e menos arquivos).
Uso: python3 tools/gerar_texturas_mapa.py   (requer numpy e Pillow)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PASTA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "map", "texturas")
os.makedirs(PASTA, exist_ok=True)
N = 256
rng = np.random.default_rng(7)


def ruido_tileavel(n, escala, oitavas=4, semente=0):
    """Ruído suave e repetível (soma de senos aleatórios em frequências inteiras)."""
    r = np.random.default_rng(semente)
    y, x = np.mgrid[0:n, 0:n] / n
    out = np.zeros((n, n))
    amp = 1.0
    for o in range(oitavas):
        f = escala * (2 ** o)
        for _ in range(6):
            fx, fy = r.integers(-f, f + 1, 2)
            fase = r.random() * 6.283
            out += amp * np.sin(6.283 * (fx * x + fy * y) + fase)
        amp *= 0.5
    out -= out.min(); out /= out.max()
    return out


def salvar(nome, arr):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(PASTA, nome), optimize=True)
    print("gerado", nome)


# Reboco (parede pintada): quase branco com manchas suaves e grão.
r = ruido_tileavel(N, 2, 4, 1)
grao = rng.random((N, N))
v = 200 + r * 40 + grao * 15
salvar("reboco.png", np.stack([v, v, v], -1))

# Concreto (lajes, calçadas): cinza claro com poros.
r = ruido_tileavel(N, 3, 4, 2)
v = 170 + r * 50 + rng.random((N, N)) * 20
salvar("concreto.png", np.stack([v, v * 0.98, v * 0.95], -1))

# Asfalto/terra batida da rua.
r = ruido_tileavel(N, 4, 4, 3)
v = 120 + r * 40 + rng.random((N, N)) * 35
salvar("chao_rua.png", np.stack([v * 1.05, v, v * 0.9], -1))

# Zinco ondulado (telhados, containers): faixas verticais com brilho.
x = np.arange(N) / N
onda = 0.5 + 0.5 * np.sin(x * 6.283 * 16)
v = 150 + onda * 90
img = np.tile(v, (N, 1)) + ruido_tileavel(N, 2, 3, 4) * 25
salvar("zinco.png", np.stack([img, img, img], -1))

# Madeira (caixas, bancas): tábuas horizontais.
img = np.zeros((N, N, 3))
for i in range(4):
    tom = 0.85 + rng.random() * 0.25
    veio = ruido_tileavel(N, 6, 2, 10 + i)[:, :]
    faixa = slice(i * 64, (i + 1) * 64)
    base = np.array([170, 120, 75]) * tom
    img[faixa] = base * (0.8 + 0.3 * veio[faixa, :, None])
    img[i * 64:i * 64 + 3] = base * 0.45  # vão entre tábuas
salvar("madeira.png", img)

# Mosaico (piso da praça): ladrilhos coloridos em padrão geométrico original.
img = Image.new("RGB", (N, N), (226, 210, 180))
d = ImageDraw.Draw(img)
cores = [(196, 92, 60), (48, 120, 140), (226, 178, 70), (226, 210, 180)]
t = 32
for j in range(N // t):
    for i in range(N // t):
        x0, y0 = i * t, j * t
        c = cores[(i + j) % 2 * 3]  # base alternando
        d.rectangle([x0, y0, x0 + t - 1, y0 + t - 1], fill=c)
        if (i + j) % 2 == 0:
            d.polygon([(x0 + t // 2, y0 + 3), (x0 + t - 4, y0 + t // 2), (x0 + t // 2, y0 + t - 4), (x0 + 3, y0 + t // 2)],
                      fill=cores[(i // 2 + j // 2) % 3])
        else:
            d.ellipse([x0 + 10, y0 + 10, x0 + t - 11, y0 + t - 11], fill=cores[(i + j // 2) % 3])
        d.rectangle([x0, y0, x0 + t - 1, y0 + t - 1], outline=(150, 140, 120))
arr = np.asarray(img).astype(float) * (0.92 + 0.08 * ruido_tileavel(N, 3, 3, 5)[..., None])
salvar("mosaico.png", arr)

# Listras de toldo (tecido): branco e cinza claro, a cor vem do material.
x = np.arange(N)
v = np.where((x // 32) % 2 == 0, 245, 175).astype(float)
img = np.tile(v, (N, 1)) * (0.95 + 0.05 * ruido_tileavel(N, 8, 2, 6))
salvar("toldo.png", np.stack([img, img, img], -1))
