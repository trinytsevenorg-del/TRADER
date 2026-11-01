#!/usr/bin/env python3
"""
Gera as skins de arma em data/skins_armas/<arma>_<n>.tres (4 por arma = 48 skins).
Depois disso, edite no Inspetor da Godot (rodar de novo sobrescreve).
Padrões: 0 liso, 1 listras, 2 camuflagem, 3 digital, 4 gradiente, 5 brilho
"""
import os
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ARMAS = ["vespa_p9", "rinoceronte_50", "zumbido_mk2", "faisca_r3", "corisco_ar", "falcao_br",
         "patrulha_dmr", "trovao_12", "ciclone_a12", "bigorna_lmg", "agulha_sr", "coruja_sx"]
# (nome, raridade, padrão, cor_a, cor_b, metálico, rugosidade, emissão)
MODELOS = [
    [("Areia", "comum", 0, (0.76, 0.66, 0.48), (0.6, 0.5, 0.35), 0.1, 0.8, 0),
     ("Floresta", "comum", 2, (0.3, 0.38, 0.22), (0.18, 0.22, 0.12), 0.1, 0.8, 0),
     ("Oceano", "rara", 4, (0.1, 0.35, 0.6), (0.05, 0.12, 0.25), 0.5, 0.4, 0),
     ("Lava", "epica", 2, (0.15, 0.05, 0.02), (1.0, 0.35, 0.05), 0.2, 0.6, 1.2)],
    [("Grafite", "comum", 0, (0.2, 0.21, 0.23), (0.1, 0.1, 0.1), 0.6, 0.4, 0),
     ("Pixel Urbano", "comum", 3, (0.55, 0.57, 0.6), (0.25, 0.27, 0.3), 0.2, 0.7, 0),
     ("Tigre", "rara", 1, (0.95, 0.55, 0.1), (0.08, 0.06, 0.05), 0.2, 0.6, 0),
     ("Aurora", "lendaria", 5, (0.08, 0.1, 0.2), (0.3, 1.0, 0.7), 0.6, 0.3, 1.6)],
    [("Concreto", "comum", 3, (0.6, 0.6, 0.58), (0.45, 0.45, 0.44), 0.1, 0.9, 0),
     ("Selva", "rara", 2, (0.25, 0.45, 0.2), (0.6, 0.55, 0.25), 0.1, 0.7, 0),
     ("Ouro Velho", "epica", 0, (0.85, 0.65, 0.25), (0.5, 0.35, 0.1), 1.0, 0.3, 0),
     ("Neon", "epica", 5, (0.06, 0.06, 0.1), (1.0, 0.2, 0.8), 0.4, 0.3, 1.4)],
]


def cor(c):
    return "Color(%s, %s, %s, 1)" % c


n = 0
for i, arma in enumerate(ARMAS):
    conj = MODELOS[i % len(MODELOS)]
    for k, (nome, rar, pad, a, b, met, rug, emi) in enumerate(conj):
        sid = "%s_%d" % (arma, k + 1)
        # Variação por arma para não ficarem todas idênticas
        desloc = (i % 4) * 0.03
        a2 = tuple(min(1.0, max(0.0, x + desloc - 0.045)) for x in a)
        txt = f'''[gd_resource type="Resource" script_class="DadosSkinArma" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/skins/dados_skin_arma.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{sid}"
nome = "{nome}"
arma = "{arma}"
raridade = "{rar}"
padrao = {pad}
cor_a = {cor(tuple(round(x, 3) for x in a2))}
cor_b = {cor(b)}
metalico = {met}
rugosidade = {rug}
emissao = {float(emi)}
'''
        open(os.path.join(RAIZ, "data", "skins_armas", sid + ".tres"), "w").write(txt)
        n += 1
print("geradas", n, "skins")
