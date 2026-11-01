#!/usr/bin/env python3
"""
Gera scenes/mapas/vila_telhado.tscn: o mapa "Vila Telhado" montado com as peças
de scenes/mapa/pecas/. Depois de gerado, dá para mover/editar tudo no editor da
Godot normalmente. (Rodar de novo SOBRESCREVE as edições feitas no editor.)

Layout (60 x 60 m, x para a direita, -z = norte):
  - Fileira norte: Prédio NO (6 m), Prédio N-meio (3,5 m), Prédio NE (6,5 m) com becos de 4 m
  - Fileira sul:   Prédio SO (5 m),  Prédio S-meio (7 m),   Prédio SE (6 m)
  - Oeste: Prédio O (4,5 m); Leste: pátio de containers (empilhados até 5,2 m)
  - Centro: praça de mosaico com fonte, quiosque, bancas de feira, canteiros
  - Passarelas ligando telhados: NO-O, O-SO, NE-containers, containers-SE, SO-Smeio, Smeio-SE
  - Escadas externas e caixotes para subir; vielas atrás das fileiras (sem becos sem saída)
Uso: python3 tools/gerar_mapa.py
"""
import math, os
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

pecas = []      # (tipo, nome, pos, yaw_graus, props)
def P(tipo, nome, pos, yaw=0.0, **props):
    pecas.append((tipo, nome, pos, yaw, props))

def cor(r, g, b): return ("Color", (r, g, b))

LAJE = 0.12  # espessura da laje no topo dos prédios

# ---------------- chão ----------------
P("bloco", "ChaoRua", (0, -0.5, 0), tamanho=("V3", (110, 0.5, 110)), textura="chao_rua", cor=cor(0.66, 0.58, 0.48))
P("bloco", "PisoPraca", (0, 0, 0), tamanho=("V3", (26, 0.04, 22)), textura="mosaico", cor=cor(1, 1, 1))
P("bloco", "CalcadaNorte", (0, 0, -14.2), tamanho=("V3", (58, 0.12, 2.6)), textura="concreto", cor=cor(0.74, 0.72, 0.68))
P("bloco", "CalcadaSul", (0, 0, 14.2), tamanho=("V3", (58, 0.12, 2.6)), textura="concreto", cor=cor(0.74, 0.72, 0.68))

# ---------------- prédios ----------------
predios = [
    # nome, centro x, z, w, h, d, cor
    ("PredioNO", -19, -21.5, 18, 6.0, 12, (0.82, 0.44, 0.30)),
    ("PredioNMeio", 0, -21.5, 12, 3.5, 12, (0.26, 0.58, 0.60)),
    ("PredioNE", 19, -21.5, 18, 6.5, 12, (0.93, 0.75, 0.33)),
    ("PredioSO", -19, 21.5, 18, 5.0, 12, (0.86, 0.53, 0.56)),
    ("PredioSMeio", 0, 21.5, 12, 7.0, 12, (0.30, 0.45, 0.76)),
    ("PredioSE", 19, 21.5, 18, 6.0, 12, (0.91, 0.56, 0.26)),
    ("PredioO", -23, 0, 10, 4.5, 18, (0.56, 0.62, 0.36)),
]
for nome, x, z, w, h, d, c in predios:
    sul = z < 0  # prédios do norte têm a porta virada para a praça (+z)
    P("predio", nome, (x, 0, z), 0 if sul else 180, tamanho=("V3", (w, h, d)), cor=cor(*c),
      parapeito=False, ar_condicionado=2, caixa_dagua=(w >= 12 and nome != "PredioNMeio"))
TOPO = {n: h + LAJE for n, x, z, w, h, d, c in predios}

# ---------------- praça ----------------
P("fonte", "Fonte", (0, 0.04, 0))
P("quiosque", "Quiosque", (-7, 0.04, -6))
P("banca", "BancaA", (6, 0.04, -7), 0, cor_toldo=cor(0.85, 0.25, 0.25))
P("banca", "BancaB", (8.7, 0.04, -7), 0, cor_toldo=cor(0.2, 0.55, 0.75))
P("banca", "BancaC", (-7, 0.04, 6.5), 180, cor_toldo=cor(0.95, 0.7, 0.2))
P("banca", "BancaD", (-4.3, 0.04, 6.5), 180, cor_toldo=cor(0.35, 0.65, 0.35))
P("canteiro", "Canteiro1", (5, 0.04, 4))
P("canteiro", "Canteiro2", (-9, 0.04, -1), 90)
P("canteiro", "Canteiro3", (9.5, 0.04, 2.5), 90)
P("canteiro", "Canteiro4", (2, 0.04, -7.5))
P("muro", "MuroPraca1", (11.5, 0.04, -3), 90, tamanho=("V3", (4, 1.1, 0.4)), cor=cor(0.92, 0.86, 0.72))
P("muro", "MuroPraca2", (-11.5, 0.04, 7.5), 90, tamanho=("V3", (3, 1.1, 0.4)), cor=cor(0.92, 0.86, 0.72))
P("caixa_madeira", "CaixaPraca1", (3.2, 0.04, 7.2))
P("caixa_madeira", "CaixaPraca2", (4.1, 0.04, 7.4), 15)
P("caixa_madeira", "CaixaPraca3", (3.6, 1.04, 7.3), 40)

# ---------------- subir no N-meio (3,5 m) ----------------
P("caixa_madeira", "CaixaNM1", (-3.2, 0, -14.8))
P("caixa_madeira", "CaixaNM2", (-1.8, 0, -14.9), 0, tamanho=("V3", (1.3, 2.2, 1.2)))
P("escada", "EscadaNMeio", (3.5, 0, -10.5), 0, altura=TOPO["PredioNMeio"], comprimento=5.0)
# caixotes no telhado do N-meio para pular para os prédios altos vizinhos
P("caixa_madeira", "CaixaNMTeto1", (-5.2, TOPO["PredioNMeio"], -19))
P("caixa_madeira", "CaixaNMTeto2", (5.2, TOPO["PredioNMeio"], -24), 0, tamanho=("V3", (1.2, 1.2, 1.2)))

# ---------------- escadas externas ----------------
P("escada", "EscadaO", (-17.1, 0, 7), 0, altura=TOPO["PredioO"], comprimento=7.0)
P("escada", "EscadaSE", (13, 0, 8), 180, altura=TOPO["PredioSE"], comprimento=7.5)
P("escada", "EscadaSO", (-14, 0, 8.5), 180, altura=TOPO["PredioSO"], comprimento=7.0)
P("escada", "EscadaNE", (27, 0, -7.5), 0, altura=TOPO["PredioNE"], comprimento=8.0, lado_mureta=-1)

# ---------------- pátio de containers (leste) ----------------
cont = [
    ("Container1", (17, 0, -8), 0, (0.78, 0.24, 0.2)),
    ("Container2", (19, 2.6, -8), 0, (0.2, 0.38, 0.7)),   # deslocado: a pilha vira "escadinha"
    ("Container3", (24, 0, -4), 90, (0.25, 0.55, 0.3)),
    ("Container4", (16.5, 0, 0), 0, (0.92, 0.72, 0.2)),
    ("Container5", (22, 0, 5), 0, (0.88, 0.45, 0.15)),
    ("Container6", (23.5, 2.6, 5), 0, (0.2, 0.6, 0.62)),  # deslocado: a pilha vira "escadinha"
    ("Container7", (26.8, 0, 9.5), 90, (0.55, 0.55, 0.58)),
    ("Container8", (15.2, 0, 8), 90, (0.6, 0.25, 0.45)),
]
for nome, pos, yaw, c in cont:
    P("container", nome, pos, yaw, cor=cor(*c))
P("caixa_madeira", "CaixaCont1", (15, 0, -6.0))
P("caixa_madeira", "CaixaCont2", (19.7, 0, 2.7), 20)
P("caixa_madeira", "CaixaCont3", (18.2, 0, 2.4), 0, tamanho=("V3", (1.2, 1.6, 1.2)))

# ---------------- passarelas ----------------
# (origem no começo, vai para -z local; yaw gira; desnível = altura final - inicial)
P("passarela", "PassarelaNE", (17, 5.2, -9.0), 0, comprimento=6.5, desnivel=TOPO["PredioNE"] - 5.2)
P("passarela", "PassarelaSE", (22, 5.2, 6.0), 180, comprimento=9.5, desnivel=TOPO["PredioSE"] - 5.2)
P("passarela", "PassarelaNO", (-23, TOPO["PredioO"], -9.0), 0, comprimento=6.5, desnivel=TOPO["PredioNO"] - TOPO["PredioO"])
P("passarela", "PassarelaSO", (-23, TOPO["PredioO"], 9.0), 180, comprimento=6.5, desnivel=TOPO["PredioSO"] - TOPO["PredioO"])
P("passarela", "PassarelaSul1", (-10, TOPO["PredioSO"], 23), -90, comprimento=4.0, desnivel=TOPO["PredioSMeio"] - TOPO["PredioSO"])
P("passarela", "PassarelaSul2", (6, TOPO["PredioSMeio"], 20), -90, comprimento=4.0, desnivel=TOPO["PredioSE"] - TOPO["PredioSMeio"])

# ---------------- cobertura em telhados e ruas ----------------
P("muro", "MuroTetoSM", (0, TOPO["PredioSMeio"], 18), 0, tamanho=("V3", (5, 1.1, 0.4)), cor=cor(0.8, 0.82, 0.86))
P("muro", "MuroTetoNO", (-19, TOPO["PredioNO"], -18.5), 0, tamanho=("V3", (4, 1.1, 0.4)), cor=cor(0.9, 0.82, 0.7))
P("muro", "MuroTetoSE", (19, TOPO["PredioSE"], 24.5), 90, tamanho=("V3", (4, 1.1, 0.4)), cor=cor(0.9, 0.82, 0.7))
P("muro", "MuroRuaN", (-12.5, 0.12, -13.2), 0, tamanho=("V3", (3, 1.1, 0.4)), cor=cor(0.85, 0.5, 0.35))
P("muro", "MuroRuaS", (12.5, 0.12, 13.2), 0, tamanho=("V3", (3, 1.1, 0.4)), cor=cor(0.4, 0.55, 0.7))
P("caixa_madeira", "CaixaViela1", (-8, 0, -24))
P("caixa_madeira", "CaixaViela2", (8.2, 0, 23.5), 0, tamanho=("V3", (1.2, 1.4, 1.2)))
P("caixa_madeira", "CaixaRuaO", (-14.5, 0, -3))

# ---------------- muro em volta do mapa ----------------
for nome, pos, yaw in [("MuroBordaN", (0, 0, -30.2), 0), ("MuroBordaS", (0, 0, 30.2), 0),
                       ("MuroBordaO", (-30.2, 0, 0), 90), ("MuroBordaL", (30.2, 0, 0), 90)]:
    P("muro", nome, pos, yaw, tamanho=("V3", (61, 3.0, 0.4)), cor=cor(0.78, 0.72, 0.62))

# ---------------- cidade de fundo (fora dos limites, só visual) ----------------
import random
random.seed(11)
paleta = [(0.82, 0.5, 0.36), (0.9, 0.78, 0.5), (0.55, 0.65, 0.72), (0.86, 0.62, 0.62), (0.62, 0.68, 0.48), (0.9, 0.86, 0.78)]
for lado in range(4):
    for i in range(6):
        t = -33 + i * 13.2 + random.uniform(-1, 1)
        dist = 36 + random.uniform(0, 4)
        w, h, d = random.uniform(8, 12), random.uniform(8, 17), random.uniform(7, 10)
        x, z = [(t, -dist), (t, dist), (-dist, t), (dist, t)][lado]
        P("predio", "Fundo%d_%d" % (lado, i), (round(x, 2), 0, round(z, 2)), [180, 0, 90, -90][lado],
          tamanho=("V3", (round(w, 1), round(h, 1), round(d, 1))), cor=cor(*random.choice(paleta)),
          parapeito=False, ar_condicionado=1, caixa_dagua=random.random() < 0.5)

# ---------------- renascimentos ----------------
spawns = [
    (-8, 0.15, -28.6), (8, 0.15, -28.6), (-8, 0.15, 28.6), (8, 0.15, 28.6),
    (-26, 0.15, -12.5), (-26, 0.15, 12.5), (27, 0.15, -12.8), (27.5, 0.15, 14.0),
    (-17, TOPO["PredioNO"], -24), (17, TOPO["PredioSE"], 24),
]

# ---------------- alvos (bonecos) até os bots da etapa 5 ----------------
alvos = [((0, 0.04, -6), False, 0, 4), ((-5, 0.04, 4.5), True, 1, 3),
         ((20, 5.2, -8), False, 0, 6), ((0, TOPO["PredioSMeio"], 23), False, 1, 2)]


# =================== escrita do .tscn ===================
def fmt(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str): return '"%s"' % v
    if isinstance(v, tuple) and v[0] == "V3": return "Vector3(%s, %s, %s)" % v[1]
    if isinstance(v, tuple) and v[0] == "Color": return "Color(%s, %s, %s, 1)" % v[1]
    raise ValueError(v)

def xf(pos, yaw):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    r = lambda x: round(x, 6)
    return "Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)" % (r(c), r(s), r(-s), r(c), pos[0], pos[1], pos[2])

tipos = sorted(set(p[0] for p in pecas))
ext = {t: i + 10 for i, t in enumerate(tipos)}
linhas = []
linhas.append('[gd_scene load_steps=%d format=3]\n' % (len(tipos) + 6))
linhas.append('[ext_resource type="Script" path="res://scripts/mapa/mapa.gd" id="1"]')
for t in tipos:
    linhas.append('[ext_resource type="PackedScene" path="res://scenes/mapa/pecas/%s.tscn" id="%d"]' % (t, ext[t]))
linhas.append('''
[sub_resource type="ProceduralSkyMaterial" id="ceu_mat"]
sky_top_color = Color(0.28, 0.5, 0.82, 1)
sky_horizon_color = Color(0.86, 0.82, 0.74, 1)
ground_bottom_color = Color(0.32, 0.27, 0.22, 1)
ground_horizon_color = Color(0.82, 0.76, 0.66, 1)
sun_angle_max = 25.0

[sub_resource type="Sky" id="ceu"]
sky_material = SubResource("ceu_mat")
radiance_size = 0

[sub_resource type="Environment" id="ambiente"]
background_mode = 2
sky = SubResource("ceu")
ambient_light_source = 2
ambient_light_color = Color(0.62, 0.66, 0.78, 1)
ambient_light_energy = 0.55
reflected_light_source = 1
tonemap_mode = 2
tonemap_white = 1.3
fog_enabled = true
fog_light_color = Color(0.88, 0.84, 0.76, 1)
fog_density = 0.006
fog_sky_affect = 0.3
adjustment_enabled = true
adjustment_saturation = 1.15
''')
linhas.append('[node name="VilaTelhado" type="Node3D"]\nscript = ExtResource("1")\n')
linhas.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("ambiente")\n')
# Sol da tarde vindo do sudoeste
el, az = math.radians(48), math.radians(35)
# direção da luz (para onde aponta) = -Z do nó
d = (-math.sin(az) * math.cos(el) * -1, -math.sin(el), -math.cos(az) * math.cos(el) * -1)
# monta base com -Z = d
import numpy as np
fz = -np.array(d); fz /= np.linalg.norm(fz)
fx = np.cross([0, 1, 0], fz); fx /= np.linalg.norm(fx)
fy = np.cross(fz, fx)
M = np.stack([fx, fy, fz], 1)  # colunas
rows = ", ".join("%.6f" % M[i][j] for i in range(3) for j in range(3))
linhas.append('[node name="Sol" type="DirectionalLight3D" parent="." groups=["luz_principal"]]\n'
              'transform = Transform3D(%s, 0, 30, 0)\nlight_color = Color(1, 0.93, 0.8, 1)\nlight_energy = 1.1\n'
              'shadow_enabled = true\nshadow_bias = 0.04\ndirectional_shadow_mode = 0\ndirectional_shadow_max_distance = 40.0\n' % rows)
linhas.append('[node name="Pecas" type="Node3D" parent="."]\n')
for tipo, nome, pos, yaw, props in pecas:
    s = '[node name="%s" parent="Pecas" instance=ExtResource("%d")]\ntransform = %s\n' % (nome, ext[tipo], xf(pos, yaw))
    for k, v in props.items():
        s += "%s = %s\n" % (k, fmt(v))
    linhas.append(s)
linhas.append('[node name="Renascimentos" type="Node3D" parent="."]\n')
for i, p in enumerate(spawns):
    dx, dz = -p[0], -p[2]
    yaw = math.degrees(math.atan2(-dx, -dz))
    linhas.append('[node name="Renasce%d" type="Marker3D" parent="Renascimentos" groups=["renascimento"]]\ntransform = %s\n' % (i + 1, xf(p, yaw)))
# Jogador, bots e HUD são criados pela cena da partida (scenes/partida.tscn).

saida = os.path.join(RAIZ, "scenes", "mapas", "vila_telhado.tscn")
open(saida, "w").write("\n".join(linhas))
print("gerado", saida, "com", len(pecas), "peças e", len(spawns), "renascimentos")
