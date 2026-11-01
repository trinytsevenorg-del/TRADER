# Rodada 2: diagnóstico e evolução (referência de gameplay: vídeo do usuário)

Referência disponível no ambiente: **1 vídeo de 17 s** (o mesmo enviado antes). Ele foi usado
só como referência de comportamento (câmera alta, parkour fluido, armas de duas mãos). Nada
foi copiado do jogo de referência (código, modelos, texturas, sons ou mapas).

## 1. Diagnóstico (antes desta rodada)

| Área | Situação encontrada | Arquivo |
|---|---|---|
| Personagem / rig | Modelos humanos CC0 (esqueleto estilo UE, 65 ossos), 86 animações CC0, AnimationTree (locomoção + tronco mirando + tiro/recarga) | `characters/humano/modelo_humano.gd` |
| Armas na mão | **Problema**: só a mão direita era usada (arma presa ao osso da mão, calibrada pela pose de pistola). Em fuzis/snipers a **mão esquerda ficava colada na direita** e a **coronha não encostava no ombro** (arma "flutuando" à frente) | `modelo_humano.gd`, `scripts/armas/*` |
| Parkour | Parede, parede-a-parede, subir parede, beirada, rolamento, deslize-prancha, pulo duplo: funcionando e testados | `scripts/jogador/jogador.gd` (860 linhas, script grande) |
| Faltava no parkour | Transpor obstáculo baixo (vault), recuperação de equilíbrio ao aterrissar | |
| Combate | Hitscan pela câmera (preciso), mas **a câmera podia "ver por cima" de um obstáculo que o corpo não via** (tiro passando onde a arma não alcança) | `scripts/armas/portador_armas.gd` |
| Sons | **Inexistentes** | |
| Skins de arma | Funcionavam, mas **substituíam o material da arma inteira** (perdia madeira/metal/vidro); sem suporte a textura/material próprios | `scripts/skins/*`, `scripts/armas/arma.gd` |
| Câmera / controles | Câmera de ombro com 2 SpringArm (não atravessa parede), HUD de toque multitoque e personalizável | `scripts/camera/camera_tps.gd`, `ui/hud/controles_toque.gd` |
| Multiplayer | ENet com sala, busca na rede local, interpolação, host autoridade. Faltava: recarga e troca de arma nos outros aparelhos, skins dos bots iguais para todos | `network/*` |
| Sistemas duplicados | Nenhum encontrado (um único controlador de personagem para jogador/bot/remoto) | |
| SkeletonIK3D da Godot | Testado: **não convergiu** (ficou a 45 cm do alvo) e está marcado como obsoleto na 4.3 | |

## 2. O que foi implementado (por etapa do pedido)

**Etapa 2: rig e armas nas mãos**
- `characters/humano/ik_dois_ossos.gd`: IK analítico próprio de 2 ossos (SkeletonModifier3D da
  Godot 4.3). Testado: mão exatamente no alvo (erro 0,0000 m), seguindo alvos em movimento.
- Armas longas presas a um **encaixe no peito**, com a **coronha no ombro direito** (calculada
  pelo comprimento real de cada modelo). **Mão direita** no cabo (com a orientação da
  empunhadura) e **mão esquerda** no guarda-mão (`MaoEsquerda`), com os **dedos fechados**.
- Orientação da arma = direção do personagem + inclinação da mira (não herda a curvatura do
  tronco de cada animação): mirando, a arma aponta para onde a mira está.
- Posição de **prontidão** fora da mira (arma inclinada para baixo, duas mãos).
- IK desliga suave em rolamento, escalada, subida de parede e morte.

**Etapa 3: rolamento e deslize**: já estavam completos (rolamento controlável, deslize
prancha). Mantidos e testados de novo.

**Etapa 4: parkour**
- Parkour separado em módulo: `scripts/jogador/parkour.gd` (`ControladorParkour`).
- **Transpor obstáculos** (0,35 a 1,35 m) correndo + PULAR: arco por cima mantendo a
  velocidade; obstáculo fino = cai do outro lado; largo = sobe nele; se houver parede mais alta
  logo depois, prefere o pulo normal (que agarra a beirada).
- **Recuperação de equilíbrio** em queda alta (sem deslizar/rolar), com animação de aterrissar.

**Etapa 5: animações**: estados novos `transpondo` e `aterrissando`, troca de arma animada
(abaixa e levanta durante o tempo de equipar), tiro e recarga no tronco (já existiam).

**Etapa 6: armas com empunhadura individual**: `DadosArma` ganhou o grupo *Empunhadura
(ajuste individual)*: posição X/Y/Z, rotação X/Y/Z, escala e ângulo de prontidão, por arma.
Cada cena de arma tem `Mao`, `MaoEsquerda`, `Cano` e `Mira` (gerados pela geometria e
editáveis). Som de tiro por arma (`som_tiro` ou padrão do tipo).

**Etapa 7: skins**: cada parte da arma recebe o material certo (corpo = padrão/textura;
metais = cor de detalhe; vidro intacto). Cada skin pode ter **textura própria** e **materiais
próprios** (inclusive ShaderMaterial). +2 skins por arma (Dourada épica, Futurista lendária):
72 no total, capacidade para 64 por arma.

**Etapa 8: câmera e controles**: o tiro agora respeita a posição real do corpo/arma (bala
bate no obstáculo se só a câmera vê por cima). Volume nas configurações.

**Etapa 9: multiplayer**: recarga e troca de arma aparecem (animação + som) nos outros
aparelhos; skins dos bots combinadas pelo host; estados novos (transpondo, aterrissando) viajam
no estado já sincronizado.

**Sons** (`tools/gerar_sons.py` → `assets/sons/`): sintetizados, sem gravações de terceiros:
7 tiros (pistola, revólver, SMG, fuzil, escopeta, LMG, sniper), recarga, troca, gatilho vazio,
passos, pulo, aterrissagem, rolamento, deslize, acerto, acerto na cabeça, abate, dano.

## 3. Testes (todos passando)
Etapas 1, 2 (+ transpor e aterrissagem), 3, 4, 5, 7 e o teste de rede com 2 processos.
Renderizações de diagnóstico conferiram as mãos nas 4 classes de arma (pistola, fuzil,
metralhadora, sniper), mirando e em prontidão.

## 4. O que ainda falta / limitações honestas
- **Animações de fuzil**: ✅ feitas na v1.2 (mira de fuzil gerada no esqueleto + recarga com a
  mão esquerda por IK). Ainda são procedurais: uma animação de fuzil capturada (Mixamo) seria
  mais rica em detalhes de ombro/cotovelo. Na v1.3 a mão esquerda passou a segurar o
  guarda-mão de verdade (palma por baixo, dedos fechados em volta) e a pistola é segurada com
  as duas mãos.
- **Pendurar em beiradas (shimmy)**: ✅ feito na v1.2 (pendurar, andar de lado, subir, saltar
  para trás, soltar). A pose das pernas usa a animação parada (não há animação de "pendurado"
  no pacote CC0); as mãos ficam na borda por IK.
- **Sons**: sintetizados (funcionais e leves); trocar por sons gravados CC0 é só substituir os
  arquivos em `assets/sons/` mantendo os nomes.
- **Não testado em celular real** nesta rodada (todos os testes rodaram no PC/servidor).
