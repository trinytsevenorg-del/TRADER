#!/usr/bin/env python3
"""
Gera os arquivos iniciais das armas:
  data/armas/<id>.tres       números da arma (Resource DadosArma) - edite no Inspetor
  weapons/modelos/<id>.tscn  modelo provisório + pontos Mao/Cano/Mira

ATENÇÃO: rodar de novo SOBRESCREVE os arquivos. Depois de ajustar números no
Inspetor, não rode mais este script (ou mude os valores aqui também).
Uso: python3 tools/gerar_armas.py
"""
import os
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# Modo: 0 SEMI, 1 RAJADA, 2 AUTO. Categoria: 0 pistola, 1 SMG, 2 fuzil, 3 escopeta, 4 metralhadora, 5 sniper
ARMAS = [
  dict(id="vespa_p9", nome="Vespa P9", categoria=0, modo=0, cadencia=400, dano=24, mult_cabeca=1.8,
       alcance_efetivo=20, alcance_maximo=45, dano_minimo=0.55, dispersao_base=1.0, dispersao_movendo=1.0, dispersao_ar=2.0,
       dispersao_por_tiro=0.5, dispersao_extra_max=3.0, recuperacao_dispersao=12, recuo_vertical=1.2, recuo_horizontal=0.4,
       pente=15, reserva=60, tempo_recarga=1.3, tempo_equipar=0.3, zoom=1.0, mult_velocidade=1.05,
       descricao="Pistola leve e precisa. Troca e recarrega rápido, mas o dano é baixo.",
       modelo=dict(comprimento_corpo=0.2, altura_corpo=0.07, largura=0.04, comprimento_cano=0.04, diametro_cano=0.02, tamanho_pente=0.0, comprimento_coronha=0.0, cor="0.15,0.15,0.17", cor_detalhe="0.25,0.25,0.27")),
  dict(id="rinoceronte_50", nome="Rinoceronte .50", categoria=0, modo=0, cadencia=140, dano=48, mult_cabeca=2.0,
       alcance_efetivo=25, alcance_maximo=50, dano_minimo=0.5, dispersao_base=1.4, dispersao_movendo=2.0, dispersao_ar=3.0,
       dispersao_por_tiro=1.5, dispersao_extra_max=4.0, recuperacao_dispersao=6, recuo_vertical=4.5, recuo_horizontal=1.0,
       pente=6, reserva=30, tempo_recarga=2.0, tempo_equipar=0.5, zoom=1.15, mult_velocidade=1.0,
       descricao="Revólver pesado: dois tiros derrubam. Pente pequeno, coice forte e lento.",
       modelo=dict(comprimento_corpo=0.24, altura_corpo=0.09, largura=0.05, comprimento_cano=0.12, diametro_cano=0.03, tamanho_pente=0.0, comprimento_coronha=0.0, cor="0.55,0.55,0.58", cor_detalhe="0.35,0.2,0.12")),
  dict(id="zumbido_mk2", nome="Zumbido MK2", categoria=1, modo=2, cadencia=900, dano=16, mult_cabeca=1.5,
       alcance_efetivo=12, alcance_maximo=35, dano_minimo=0.4, dispersao_base=2.0, dispersao_movendo=0.8, dispersao_ar=1.5,
       dispersao_por_tiro=0.25, dispersao_extra_max=5.0, recuperacao_dispersao=14, recuo_vertical=0.55, recuo_horizontal=0.55,
       pente=30, reserva=150, tempo_recarga=1.7, tempo_equipar=0.35, zoom=1.0, mult_velocidade=1.08,
       descricao="Cadência altíssima e ótima correndo e no ar. Perde muito dano de longe.",
       modelo=dict(comprimento_corpo=0.32, altura_corpo=0.1, largura=0.05, comprimento_cano=0.08, diametro_cano=0.03, tamanho_pente=0.2, comprimento_coronha=0.12, cor="0.2,0.22,0.25", cor_detalhe="0.12,0.12,0.13")),
  dict(id="faisca_r3", nome="Faísca R3", categoria=1, modo=1, cadencia=1000, tiros_por_rajada=3, pausa_rajada=0.28, dano=20, mult_cabeca=1.6,
       alcance_efetivo=18, alcance_maximo=40, dano_minimo=0.5, dispersao_base=1.4, dispersao_movendo=1.0, dispersao_ar=1.8,
       dispersao_por_tiro=0.2, dispersao_extra_max=3.0, recuperacao_dispersao=12, recuo_vertical=0.8, recuo_horizontal=0.3,
       pente=30, reserva=120, tempo_recarga=1.8, tempo_equipar=0.35, zoom=1.0, mult_velocidade=1.06,
       descricao="Rajadas de 3 muito controláveis. Se errar a rajada, a pausa custa caro.",
       modelo=dict(comprimento_corpo=0.3, altura_corpo=0.1, largura=0.055, comprimento_cano=0.1, diametro_cano=0.03, tamanho_pente=0.18, comprimento_coronha=0.15, cor="0.3,0.32,0.2", cor_detalhe="0.15,0.15,0.15")),
  dict(id="corisco_ar", nome="Corisco AR", categoria=2, modo=2, cadencia=600, dano=27, mult_cabeca=1.7,
       alcance_efetivo=30, alcance_maximo=70, dano_minimo=0.55, dispersao_base=1.8, dispersao_movendo=2.2, dispersao_ar=3.5,
       dispersao_por_tiro=0.35, dispersao_extra_max=6.0, recuperacao_dispersao=9, recuo_vertical=1.6, recuo_horizontal=0.8,
       pente=30, reserva=120, tempo_recarga=2.3, tempo_equipar=0.5, zoom=1.0, mult_velocidade=1.0,
       descricao="Fuzil automático de dano alto. Recuo forte e sem aproximação: difícil de controlar de longe.",
       modelo=dict(comprimento_corpo=0.42, altura_corpo=0.11, largura=0.06, comprimento_cano=0.3, diametro_cano=0.035, tamanho_pente=0.2, comprimento_coronha=0.24, cor="0.17,0.17,0.18", cor_detalhe="0.45,0.3,0.15")),
  dict(id="falcao_br", nome="Falcão BR", categoria=2, modo=1, cadencia=750, tiros_por_rajada=3, pausa_rajada=0.3, dano=23, mult_cabeca=1.7,
       alcance_efetivo=40, alcance_maximo=80, dano_minimo=0.6, dispersao_base=1.0, dispersao_movendo=2.5, dispersao_ar=4.0,
       dispersao_por_tiro=0.2, dispersao_extra_max=3.0, recuperacao_dispersao=10, recuo_vertical=1.0, recuo_horizontal=0.3,
       pente=30, reserva=120, tempo_recarga=2.5, tempo_equipar=0.55, zoom=1.4, mult_velocidade=0.98,
       descricao="Fuzil de rajada com mira óptica leve: aproxima ao atirar. Fraco correndo e no ar.",
       modelo=dict(comprimento_corpo=0.5, altura_corpo=0.12, largura=0.065, comprimento_cano=0.18, diametro_cano=0.035, tamanho_pente=0.18, comprimento_coronha=0.05, tem_luneta="true", cor="0.4,0.42,0.32", cor_detalhe="0.18,0.18,0.18")),
  dict(id="patrulha_dmr", nome="Patrulha DMR", categoria=2, modo=0, cadencia=260, dano=42, mult_cabeca=2.0,
       alcance_efetivo=55, alcance_maximo=110, dano_minimo=0.65, dispersao_base=0.5, dispersao_movendo=3.0, dispersao_ar=5.0,
       dispersao_por_tiro=1.2, dispersao_extra_max=4.0, recuperacao_dispersao=8, recuo_vertical=2.5, recuo_horizontal=0.5,
       pente=12, reserva=60, tempo_recarga=2.4, tempo_equipar=0.6, zoom=2.0, mult_velocidade=0.95,
       descricao="Semiautomático de longo alcance com zoom 2x. Ruim de perto e se movendo.",
       modelo=dict(comprimento_corpo=0.52, altura_corpo=0.11, largura=0.06, comprimento_cano=0.36, diametro_cano=0.03, tamanho_pente=0.14, comprimento_coronha=0.26, tem_luneta="true", cor="0.24,0.2,0.15", cor_detalhe="0.12,0.12,0.12")),
  dict(id="trovao_12", nome="Trovão 12", categoria=3, modo=0, cadencia=70, projeteis=8, dano=13, mult_cabeca=1.25,
       alcance_efetivo=7, alcance_maximo=22, dano_minimo=0.2, dispersao_base=5.5, dispersao_movendo=0.5, dispersao_ar=1.0,
       dispersao_por_tiro=0.0, dispersao_extra_max=0.0, recuperacao_dispersao=10, recuo_vertical=5.0, recuo_horizontal=1.5, mult_dispersao_mirando=0.8,
       pente=6, reserva=30, tempo_recarga=2.8, tempo_equipar=0.6, zoom=1.0, mult_velocidade=0.98,
       descricao="Escopeta de bomba: derruba com 1 tiro de pertinho. Inútil de longe e lenta entre tiros.",
       modelo=dict(comprimento_corpo=0.42, altura_corpo=0.1, largura=0.06, comprimento_cano=0.4, diametro_cano=0.045, tamanho_pente=0.0, comprimento_coronha=0.26, cor="0.15,0.15,0.15", cor_detalhe="0.4,0.25,0.12")),
  dict(id="ciclone_a12", nome="Ciclone A12", categoria=3, modo=2, cadencia=240, projeteis=7, dano=8, mult_cabeca=1.2,
       alcance_efetivo=6, alcance_maximo=16, dano_minimo=0.2, dispersao_base=6.5, dispersao_movendo=0.5, dispersao_ar=1.0,
       dispersao_por_tiro=0.3, dispersao_extra_max=2.0, recuperacao_dispersao=8, recuo_vertical=3.0, recuo_horizontal=1.2, mult_dispersao_mirando=0.85,
       pente=10, reserva=40, tempo_recarga=3.0, tempo_equipar=0.6, zoom=1.0, mult_velocidade=0.97,
       descricao="Escopeta automática: chuva de chumbo de perto. Alcance curtíssimo e recarga longa.",
       modelo=dict(comprimento_corpo=0.45, altura_corpo=0.13, largura=0.07, comprimento_cano=0.25, diametro_cano=0.05, tamanho_pente=0.16, comprimento_coronha=0.2, tambor="true", cor="0.22,0.24,0.22", cor_detalhe="0.1,0.1,0.1")),
  dict(id="bigorna_lmg", nome="Bigorna LMG", categoria=4, modo=2, cadencia=700, dano=24, mult_cabeca=1.5,
       alcance_efetivo=35, alcance_maximo=75, dano_minimo=0.55, dispersao_base=3.0, dispersao_movendo=3.5, dispersao_ar=5.0,
       dispersao_por_tiro=0.2, dispersao_extra_max=6.0, recuperacao_dispersao=7, recuo_vertical=0.9, recuo_horizontal=0.9, mult_dispersao_mirando=0.35,
       pente=100, reserva=200, tempo_recarga=4.5, tempo_equipar=0.9, zoom=1.15, mult_velocidade=0.86,
       descricao="Metralhadora pesada: 100 balas e precisa mirando. Deixa você lento e a recarga é enorme.",
       modelo=dict(comprimento_corpo=0.58, altura_corpo=0.14, largura=0.08, comprimento_cano=0.36, diametro_cano=0.045, tamanho_pente=0.18, comprimento_coronha=0.24, tambor="true", cor="0.2,0.22,0.17", cor_detalhe="0.1,0.1,0.1")),
  dict(id="agulha_sr", nome="Agulha SR", categoria=5, modo=0, cadencia=45, dano=95, mult_cabeca=2.5, atira_ao_soltar="true",
       alcance_efetivo=120, alcance_maximo=200, dano_minimo=0.85, dispersao_base=7.0, dispersao_movendo=3.0, dispersao_ar=5.0,
       dispersao_por_tiro=0.0, dispersao_extra_max=0.0, recuperacao_dispersao=10, recuo_vertical=7.0, recuo_horizontal=1.0, mult_dispersao_mirando=0.0,
       pente=5, reserva=20, tempo_recarga=3.2, tempo_equipar=0.8, zoom=4.0, mult_velocidade=0.9,
       descricao="Sniper de ferrolho com luneta 4x: um tiro na cabeça derruba. Sem luneta não acerta nada.",
       modelo=dict(comprimento_corpo=0.6, altura_corpo=0.1, largura=0.06, comprimento_cano=0.5, diametro_cano=0.03, tamanho_pente=0.1, comprimento_coronha=0.3, tem_luneta="true", cor="0.12,0.14,0.12", cor_detalhe="0.3,0.36,0.25")),
  dict(id="coruja_sx", nome="Coruja SX", categoria=5, modo=0, cadencia=150, dano=62, mult_cabeca=2.0, atira_ao_soltar="true",
       alcance_efetivo=90, alcance_maximo=160, dano_minimo=0.8, dispersao_base=5.0, dispersao_movendo=3.0, dispersao_ar=5.0,
       dispersao_por_tiro=0.0, dispersao_extra_max=0.0, recuperacao_dispersao=10, recuo_vertical=4.0, recuo_horizontal=1.0, mult_dispersao_mirando=0.05,
       pente=8, reserva=32, tempo_recarga=2.8, tempo_equipar=0.7, zoom=3.0, mult_velocidade=0.92,
       descricao="Sniper semiautomática 3x: atira mais rápido que a Agulha, mas precisa de 2 tiros no corpo.",
       modelo=dict(comprimento_corpo=0.56, altura_corpo=0.11, largura=0.06, comprimento_cano=0.4, diametro_cano=0.032, tamanho_pente=0.14, comprimento_coronha=0.26, tem_luneta="true", cor="0.3,0.3,0.32", cor_detalhe="0.15,0.15,0.15")),
]


def valor(v):
    if isinstance(v, str):
        if v in ("true", "false"):
            return v
        if v.count(",") == 2:
            return "Color(%s, 1)" % v.replace(",", ", ")
        return '"%s"' % v
    if isinstance(v, float):
        return repr(v)
    return str(v)


for a in ARMAS:
    mod = a.pop("modelo")
    aid = a["id"]
    # ---- modelo (.tscn)
    cc = mod.get("comprimento_corpo", 0.45); ac = mod.get("altura_corpo", 0.11)
    ccano = mod.get("comprimento_cano", 0.25)
    frente = -cc * 0.7
    cano = (0, round(ac * 0.7, 3), round(frente - ccano - 0.01, 3))
    luneta = mod.get("tem_luneta") == "true"
    mira = (0, round(ac + (0.07 if luneta else 0.03), 3), round(-cc * 0.25, 3))
    props = "\n".join("%s = %s" % (k, valor(v)) for k, v in mod.items())
    tscn = f'''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/armas/arma.gd" id="1"]
[ext_resource type="Script" path="res://weapons/modelos/arma_provisoria.gd" id="2"]

[node name="{a['nome'].replace(' ', '').replace('.', '')}" type="Node3D"]
script = ExtResource("1")

[node name="Modelo" type="Node3D" parent="."]
script = ExtResource("2")
{props}

[node name="Mao" type="Marker3D" parent="."]

[node name="Cano" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cano[0]}, {cano[1]}, {cano[2]})

[node name="Mira" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {mira[0]}, {mira[1]}, {mira[2]})
'''
    caminho_modelo = os.path.join(RAIZ, "weapons", "modelos", aid + ".tscn")
    # Não sobrescreve modelos de verdade (montados por tools/montar_armas.gd)
    if not os.path.exists(caminho_modelo):
        open(caminho_modelo, "w").write(tscn)
    # ---- dados (.tres)
    linhas = "\n".join("%s = %s" % (k, valor(v)) for k, v in a.items())
    tres = f'''[gd_resource type="Resource" script_class="DadosArma" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/armas/dados_arma.gd" id="1"]
[ext_resource type="PackedScene" path="res://weapons/modelos/{aid}.tscn" id="2"]

[resource]
script = ExtResource("1")
cena_modelo = ExtResource("2")
{linhas}
'''
    open(os.path.join(RAIZ, "data", "armas", aid + ".tres"), "w").write(tres)
    print("gerado", aid)
