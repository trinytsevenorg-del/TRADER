#!/usr/bin/env python3
"""
Gera os efeitos sonoros do jogo por síntese (sem gravações de terceiros):
tiros por tipo de arma, recarga, troca, passos, pulo, aterrissagem, rolamento,
deslize e marcador de acerto. WAV mono 16 bits, 22 050 Hz (leve no celular).
Uso: python3 tools/gerar_sons.py   (requer numpy)
"""
import os, wave
import numpy as np

PASTA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sons")
os.makedirs(PASTA, exist_ok=True)
SR = 22050
rng = np.random.default_rng(3)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, ataque=0.002, queda=0.1):
    x = np.arange(n) / SR
    a = np.clip(x / max(ataque, 1e-4), 0, 1)
    return a * np.exp(-x / queda)


def ruido(n):
    return rng.uniform(-1, 1, n)


def passa_baixa(x, corte):
    # filtro simples de um polo
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def salvar(nome, x, ganho=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * ganho
    dados = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(PASTA, nome + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print("gerado", nome)


def tiro(dur, corte, grave_hz, grave_amp, queda, cauda=0.0):
    n = int(SR * dur)
    estalo = passa_baixa(ruido(n), corte) * env(n, 0.0005, queda)
    tt = t(dur)
    grave = np.sin(2 * np.pi * grave_hz * tt * (1 - 0.5 * tt / dur)) * env(n, 0.001, queda * 1.6) * grave_amp
    x = estalo + grave
    if cauda > 0:  # eco/reverberação curta
        atraso = int(SR * 0.045)
        eco = np.zeros_like(x); eco[atraso:] = x[:-atraso] * cauda
        x = x + eco
    return x


salvar("tiro_pistola", tiro(0.35, 3500, 120, 0.8, 0.045, 0.25))
salvar("tiro_revolver", tiro(0.6, 2500, 80, 1.2, 0.08, 0.35))
salvar("tiro_smg", tiro(0.22, 4200, 150, 0.5, 0.03, 0.15))
salvar("tiro_fuzil", tiro(0.5, 3000, 95, 1.0, 0.06, 0.3))
salvar("tiro_escopeta", tiro(0.7, 1800, 60, 1.4, 0.1, 0.4))
salvar("tiro_lmg", tiro(0.4, 2600, 85, 1.1, 0.05, 0.25))
salvar("tiro_sniper", tiro(1.0, 2200, 55, 1.5, 0.12, 0.5))


def clique(freq, dur=0.03, amp=1.0):
    n = int(SR * dur)
    return np.sin(2 * np.pi * freq * t(dur)) * env(n, 0.0005, dur / 4) * amp + ruido(n) * env(n, 0.0002, dur / 8) * 0.6 * amp


def juntar(partes):
    total = max(int(SR * ini) + len(x) for ini, x in partes)
    y = np.zeros(total)
    for ini, x in partes:
        i = int(SR * ini); y[i:i + len(x)] += x
    return y


salvar("recarga", juntar([(0.0, clique(900, 0.05)), (0.25, passa_baixa(ruido(int(SR * 0.12)), 2500) * env(int(SR * 0.12), 0.01, 0.05)),
                          (0.55, clique(1400, 0.04)), (0.62, clique(700, 0.06, 1.2))]), 0.7)
salvar("troca_arma", juntar([(0.0, passa_baixa(ruido(int(SR * 0.15)), 1800) * env(int(SR * 0.15), 0.02, 0.06)), (0.18, clique(1100, 0.04))]), 0.6)
salvar("vazio", clique(1800, 0.04, 0.8), 0.5)

n = int(SR * 0.09)
salvar("passo", passa_baixa(ruido(n), 900) * env(n, 0.003, 0.025), 0.45)
n = int(SR * 0.18)
salvar("pulo", passa_baixa(ruido(n), 1400) * env(n, 0.02, 0.05), 0.4)
n = int(SR * 0.25)
salvar("aterrissar", passa_baixa(ruido(n), 600) * env(n, 0.002, 0.06) + np.sin(2 * np.pi * 70 * t(0.25)) * env(n, 0.002, 0.05) * 0.6, 0.7)
n = int(SR * 0.45)
sopro = passa_baixa(ruido(n), 1200) * np.sin(np.pi * np.arange(n) / n)
salvar("rolar", sopro, 0.5)
n = int(SR * 0.6)
salvar("deslizar", passa_baixa(ruido(n), 3000) * np.sin(np.pi * np.arange(n) / n) ** 0.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 30 * t(0.6))), 0.45)
salvar("acerto", np.sin(2 * np.pi * 1700 * t(0.06)) * env(int(SR * 0.06), 0.001, 0.02), 0.5)
salvar("acerto_cabeca", juntar([(0.0, np.sin(2 * np.pi * 2300 * t(0.08)) * env(int(SR * 0.08), 0.001, 0.03)), (0.04, np.sin(2 * np.pi * 3100 * t(0.08)) * env(int(SR * 0.08), 0.001, 0.03))]), 0.55)
salvar("abate", juntar([(0.0, np.sin(2 * np.pi * 880 * t(0.12)) * env(int(SR * 0.12), 0.002, 0.05)), (0.09, np.sin(2 * np.pi * 1320 * t(0.18)) * env(int(SR * 0.18), 0.002, 0.07))]), 0.6)
salvar("dano", passa_baixa(ruido(int(SR * 0.15)), 700) * env(int(SR * 0.15), 0.002, 0.04), 0.6)
