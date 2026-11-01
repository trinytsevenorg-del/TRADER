# Projeto Telhado: TPS com parkour para Android (Godot 4)

Jogo original de tiro em terceira pessoa com parkour, feito em **Godot 4.3+ (GDScript)**.
O nome é provisório; dá para trocar em *Projeto > Configurações > Aplicação > Nome*.

## Estrutura de pastas

```
jogo/
├── project.godot        configuração do projeto (renderizador leve, 60 FPS, paisagem)
├── scenes/              cenas de fase (test/ = pistas de teste de cada etapa)
├── scripts/             lógica geral
│   ├── autoload/        singletons: Config (opções salvas) e Controles (entrada unificada)
│   ├── jogador/         controlador do personagem
│   ├── camera/          câmera por cima do ombro
│   └── util/            geradores de geometria low-poly
├── characters/          cenas de personagem (.tscn); provisorio/ = modelo gerado por código
├── weapons/             cenas das armas (modelo + pontos Mao/Cano/Mira)
├── data/                Resources .tres: armas (data/armas) e skins (data/skins_armas)
├── ai/                  IA dos bots
├── network/             multiplayer ENet (sala, busca na rede, sincronização)
├── ui/                  HUD de toque, mira, menus
├── assets/              modelos, animações e texturas (CC0; veja assets/CREDITOS.md)
│   ├── characters/  weapons/  map/  animations/
├── tools/               geradores (mapa, texturas, armas, skins, roupas)
└── tests/               testes automáticos (rodam sem tela)
```

## Personagens humanos (modelos 3D)

Os personagens agora são humanos de verdade (não mais bonecos de caixas):

- **Modelos:** *Universal Base Characters* (homem e mulher, ~13 mil triângulos cada),
  de Quaternius, licença **CC0** (uso livre). Pasta `assets/characters/`.
- **Animações:** *Universal Animation Library* (43 animações: parado, andar, correr, sprint,
  pulo, rolamento, morte, mira/tiro/recarga de pistola…), Quaternius, **CC0**.
  Arquivo `assets/animations/animacoes_humanas.glb`. Mesmo esqueleto dos personagens.
- **Cabelo/barba:** do mesmo pacote, presos ao osso da cabeça.
- **Roupas:** o pacote grátis só traz o corpo base, então `tools/gerar_roupas.py` pinta
  camiseta, calça, botas, luvas e cinto direto na textura (mantendo o relevo do corpo).
  São 4 roupas × 2 tons de pele = **8 skins** por personagem. Para mudar as cores, edite
  `SKINS` no script e rode `python3 tools/gerar_roupas.py`.
- **Escolher personagem/skin:** por enquanto em Configurações (II / Esc). A tela de seleção
  própria vem na etapa 7.
- Texturas reduzidas para 1024 px (corpo) e 512 px (cabelo) para pesar pouco no celular.

Cena de cada personagem: `characters/humano/humano_masculino.tscn` e `humano_feminino.tscn`.
Para trocar o modelo por outro .glb **com o mesmo esqueleto**, basta mudar `cena_modelo`
no Inspetor, sem mexer no código.

## APK (Android)

`export_presets.cfg` já está configurado (ARM 32/64 bits, tela cheia, permissões de rede).
Para gerar o APK no seu PC: *Projeto > Exportar > Android > Exportar Projeto*. Antes, instale
os modelos de exportação e configure o SDK Android (veja "Como testar no celular" abaixo).

Para instalar um APK no celular: copie o arquivo para o celular, abra pelo gerenciador de
arquivos e permita "instalar apps desconhecidos" para esse app quando o Android pedir.

## Roteiro

| Etapa | Conteúdo | Status |
|---|---|---|
| 1 | Personagem, câmera e controles | **pronta** |
| 2 | Parkour e rolamento | **pronta** |
| 3 | Armas e tiro | **pronta** |
| 4 | Mapa urbano | **pronta** |
| 5 | Bots e mata-mata | **pronta** |
| 6 | Modelos 3D e animações | **pronta** |
| 7 | Personagens, skins, roleta, caixas, progressão | **pronta** |
| 8 | Multiplayer com um amigo (Wi-Fi) | **pronta** |
| 9 | Exportar APK | **pronta** |

---

## Etapa 1: personagem, câmera e controles

### O que foi feito

- **Movimento fluido**: aceleração de 50 m/s² (chega a 7,5 m/s em ~0,15 s), freio de 60 m/s²,
  controle reduzido no ar, joystick analógico (meio joystick = anda devagar).
- **Pulo**: *coyote time* (pula até 0,12 s depois de sair da beirada), *buffer* (apertar
  0,13 s antes de tocar o chão ainda vale) e gravidade mais forte na queda.
- **Câmera por cima do ombro** (`scripts/camera/camera_tps.gd`): dois `SpringArm3D`, um para o
  ombro e outro para trás. Os dois detectam paredes, então a câmera **não atravessa paredes**,
  nem de lado. A rotação é aplicada na hora (mira responsiva) e a posição segue com suavização.
  Ao mirar, a câmera aproxima e o FOV fecha.
- **Controles de toque com multitoque real** (`ui/hud/controles_toque.gd`):
  joystick flutuante à esquerda, arrastar à direita para mirar, botões ATIRAR (dois: direita e
  esquerda), PULAR, ROLAR, MIRA, REC, TROCA e II (configurações). Arrastar em cima do ATIRAR
  também mira.
- **Configurações salvas no celular**: sensibilidade (toque, mouse e mirando), aim assist,
  inverter Y, mostrar FPS, qualidade gráfica (resolução 3D 70/85/100%, sombras, MSAA).
- **Desempenho**: renderizador *Compatibility* (OpenGL ES 3, o mais leve e compatível no
  Android), física e desenho travados em 60 Hz (sem tremida), materiais reaproveitados,
  céu e luz ambiente baratos.

### Como testar no PC

1. Instale a **Godot 4.3 ou mais nova** (versão padrão, não a .NET): https://godotengine.org/download
2. Abra a Godot, clique em **Importar**, escolha `jogo/project.godot`.
3. Aperte **F5** (ou o botão ▶). Abre a pista de testes.

| Ação | Tecla |
|---|---|
| Andar | W A S D / setas |
| Olhar / mirar com a câmera | mouse (clique na janela para prender o mouse) |
| Pular | Espaço |
| Mirar (aproxima a câmera) | botão direito do mouse (segurar) |
| Configurações | Esc |

**O que conferir:**
- [ ] Arrancar e parar são rápidos mas sem tranco; virar faz o boneco girar suave.
- [ ] O pulo responde mesmo apertando um pouco antes de cair, ou logo depois de sair da beirada.
- [ ] Suba a **escada** (à esquerda) e a **rampa** (à direita) andando, sem engasgar.
- [ ] Entre no **corredor estreito com teto** (ao fundo, atrás do ponto de início): a câmera
      encosta, mas nunca mostra o outro lado da parede.
- [ ] Encoste no **muro azul comprido** e gire a câmera: ela não atravessa.
- [ ] Segure o botão direito: a câmera aproxima e o corpo vira para onde você mira.
- [ ] Esc → mude a sensibilidade → Voltar. Feche e abra o jogo: o valor continua salvo.
- [ ] Para ver os controles de toque no PC: Esc → ligue *Forçar controles de toque*.
      O mouse vira "um dedo" (só um por vez, mas dá para ver o layout e testar o joystick).

**Teste automático** (opcional, sem tela):
```
godot --headless --path jogo res://tests/teste_auto_etapa1.tscn
```
Deve terminar com `RESULTADO: 0 falha(s)`. Ele simula entradas e confere aceleração, pulo,
direção relativa à câmera, câmera no corredor e subida da escada.

### Como testar no celular (antes da etapa 9)

O jeito mais rápido é o **Deploy com um clique** da Godot:
1. Na Godot: *Editor > Gerenciar Modelos de Exportação > Baixar e Instalar*.
2. Instale o **Android Studio** (ou só o SDK + JDK 17) e configure em
   *Editor > Configurações do Editor > Exportar > Android* (caminho do SDK e do `java`).
3. *Projeto > Exportar > Adicionar… > Android* (pode deixar tudo padrão por enquanto).
4. No celular: ative **Opções do desenvolvedor > Depuração USB** e ligue no PC por cabo.
5. Vai aparecer um ícone do Android no canto superior direito da Godot: clique e o jogo
   instala e abre no celular.

A etapa 9 detalha tudo isso (chave de assinatura, APK final etc.).

**No celular, confira:** o FPS no canto (deve ficar em 60), mirar com um dedo enquanto anda
com outro e aperta um botão com um terceiro, e se o tamanho dos botões está confortável.
Os botões ficam em `ui/hud/controles_toque.gd`, na lista `botoes` (posição e raio), fáceis de
ajustar.

---

## Etapa 2: parkour, rolamento, câmera nova e HUD personalizável

### Como funciona

| Ação | Como fazer | Tecla no PC |
|---|---|---|
| Pulo duplo | PULAR de novo no ar (sem parede por perto) | Espaço |
| **Correr na parede** | Pule, fique ao lado da parede e, caindo, aperte PULAR: gruda e corre pela parede, escorregando devagar (até 1,6 s) | Espaço |
| Pular da parede | Na parede, PULAR de novo: salta para longe, mantendo o embalo (dá para ir de uma parede a outra) | Espaço |
| Correr parede acima | No ar, **de frente** para a parede, aperte PULAR | Espaço |
| Agarrar e subir beirada | Automático: no ar, empurrando contra uma parede cujo topo está ao alcance das mãos | — |
| Rolamento | ROLAR. Suave (~0,7 s), 0,3 s invencível, recarga curta (0,35 s). O joystick muda a direção durante o rolamento. Apertar na recarga ou no ar fica guardado e sai na hora certa | Shift |
| Deslizar (prancha) | DESLIZ. correndo. Mantém o embalo como uma prancha; joystick para os lados = zigue-zague rápido, com o corpo inclinando. Dá para atirar deslizando e emendar deslize → rolamento → deslize. Cair de alto correndo também desliza sozinho | C ou Ctrl |

Nenhuma ação "mata" a velocidade: sair do deslize pulando, pular no fim do rolamento,
pular da parede e terminar uma escalada, tudo herda o embalo.

### Câmera
- **Explorando:** longe (5,4 m) e alta, vendo bastante do mapa.
- **Mirando** (MIRA / botão direito): vem para o ombro. Na etapa 3 cada arma decide se
  aproxima ao atirar (luneta/zoom leve, como snipers e alguns fuzis) ou não (pistolas, a
  maioria dos fuzis).

### HUD personalizável
Configurações (II / Esc) > **PERSONALIZAR BOTÕES**: arraste qualquer botão; toque num botão
e use **− / +** para o tamanho; **Padrão** restaura; **Concluir** salva no celular.
Também há a opção **Tiro automático** (usada a partir da etapa 3).

### O que testar
- [ ] Muro azul comprido (à direita): corra ao lado dele, pule e aperte PULAR caindo → corre na parede.
- [ ] Paredes paralelas laranja/azul (no fundo, à direita): pule de uma parede para a outra.
- [ ] Caixas laranja: pule correndo de frente para a caixa de 2,2 m (agarra a beirada sozinho) e
      use correr parede acima na de 3 m.
- [ ] Muro baixo (à esquerda): pule por cima correndo.
- [ ] Túnel baixo laranja (à esquerda): entre deslizando, saia do outro lado.
- [ ] Role várias vezes seguidas e veja a recarga; role no ar e veja sair ao aterrissar.
- [ ] Personalize o HUD, feche e abra o jogo: o layout continua.

Teste automático: `godot --headless --path jogo res://tests/teste_auto_etapa2.tscn`
(17 verificações: pulo duplo, parede, parede a parede, beiradas, rolamento, deslize, túnel).

Animações que o pacote CC0 não tem (deslize, corrida na parede) usam uma animação parecida
mais a inclinação do corpo. Na etapa 6 dá para trocar por animações do Mixamo.

---

## Etapa 3: armas e tiro

### As 12 armas (nomes originais)

| Arma | Tipo | Modo | Vantagem | Fraqueza |
|---|---|---|---|---|
| Vespa P9 | pistola | semi | precisa, troca/recarga rápidas | dano baixo |
| Rinoceronte .50 | pistola | semi | 2 tiros derrubam; zoom leve | 6 balas, coice forte |
| Zumbido MK2 | submetralhadora | auto | cadência altíssima, boa correndo/no ar | perde dano de longe |
| Faísca R3 | submetralhadora | rajada 3 | rajada controlável | pausa entre rajadas |
| Corisco AR | fuzil | auto | dano alto | recuo forte, **sem** aproximação |
| Falcão BR | fuzil | rajada 3 | longe e preciso, **aproxima ao atirar** | fraco correndo/no ar |
| Patrulha DMR | fuzil | semi | longo alcance, zoom 2x | ruim de perto |
| Trovão 12 | escopeta | semi | 1 tiro derruba de perto | inútil de longe, lenta |
| Ciclone A12 | escopeta | auto | chuva de chumbo de perto | alcance curtíssimo |
| Bigorna LMG | metralhadora | auto | 100 balas, precisa mirando | lenta, recarga de 4,5 s |
| Agulha SR | sniper | ferrolho | luneta 4x, cabeça = 1 tiro | sem luneta não acerta |
| Coruja SX | sniper | semi | luneta 3x, mais rápida | 2 tiros no corpo |

**Ajustar números:** abra `data/armas/<arma>.tres` na Godot. O Inspetor mostra tudo agrupado:
disparo, dano, precisão, recuo, munição, mira/movimento.
(`tools/gerar_armas.py` gerou os arquivos iniciais. Não rode de novo depois de editar,
porque ele sobrescreve tudo.)

### Como atirar
- **ATIRAR**: modo depende da arma (semi = um por toque, rajada = 3 por toque, auto = segurando).
  Arraste o dedo em cima do botão para mirar enquanto atira.
- **Armas com zoom** (Falcão BR, Patrulha DMR, Rinoceronte, Bigorna): a câmera aproxima um
  pouco enquanto você atira. As outras (Corisco AR, pistola Vespa...) não aproximam.
- **Snipers**: **segure** ATIRAR para abrir a luneta e **solte** para atirar.
- **MIRA**: câmera no ombro + menos dispersão (com qualquer arma).
- **REC** recarrega (também recarrega sozinho ao tentar atirar sem bala). **TROCA** alterna
  principal/secundária.
- Dá para atirar correndo, no ar, na parede e rolando (com mais dispersão).
- **Tiro automático** (Configurações): atira sozinho quando a mira passa num inimigo.
- **Aim assist** (Configurações, 0 a 1): a mira "gruda" ao passar no inimigo e puxa de leve
  enquanto você atira.
- **Escolher armas**: Configurações > Arma principal / Arma secundária (o inventário de
  verdade vem na etapa 7).

### Na tela
Mira que abre com a dispersão (fica vermelha sobre um inimigo), marcador de acerto
(branco, amarelo na cabeça, vermelho no abate), números de dano, munição, barra de recarga e
tela de luneta.

### Bonecos de treino
Cinco bonecos na pista (perto, médio, longe, andando de lado e um em cima da plataforma).
Têm 100 de vida, morrem e voltam em 2,5 s.

### Animação
Agora o personagem usa um **AnimationTree**: as pernas fazem a locomoção (correr, pular,
rolar) e o tronco/braços miram para onde a câmera aponta (para cima e para baixo também).
A arma é presa no osso da mão e alinhada automaticamente pela pose de mira.

### O que testar
- [ ] Cada arma em Configurações: cadência, recuo, zoom e recarga diferentes.
- [ ] Sniper: segure para a luneta, solte para atirar; tente tiro na cabeça (número amarelo).
- [ ] Escopeta: de perto derruba, de longe quase não faz dano.
- [ ] Atire correndo, pulando e na parede.
- [ ] Ligue o tiro automático e passe a mira pelos bonecos.
- [ ] Mude o aim assist de 0 para 1 e sinta a diferença no boneco que anda.

Teste automático: `godot --headless --path jogo res://tests/teste_auto_etapa3.tscn` (20 verificações).

Sem sons ainda: os efeitos sonoros entram junto com o mapa (etapa 4) ou o polimento.

---

## Etapa 4: mapa "Vila Telhado"

Agora o jogo abre direto no mapa (`scenes/mapas/vila_telhado.tscn`). A pista de testes
continua em `scenes/test/teste_etapa1.tscn`.

### Layout (60 × 60 m, para até 5 jogadores)

```
            viela de trás (liga os becos)
   ┌────────────┐ beco ┌────────┐ beco ┌────────────┐
   │ Prédio NO  │  4m  │N-meio  │  4m  │ Prédio NE  │   fileira norte
   │   6 m      │      │ 3,5 m  │      │   6,5 m    │
   └─────┬──────┘      └──┬─────┘      └─────┬──────┘
 passarela│        rua norte (escada)   passarela│
   ┌──────┴─┐    ┌───────────────────┐  ┌───────┴────┐
   │Prédio O│    │  PRAÇA (mosaico)  │  │ pátio de   │
   │ 4,5 m  │    │ fonte · quiosque  │  │ containers │
   │(escada)│    │ bancas · canteiros│  │ até 5,2 m  │
   └──────┬─┘    └───────────────────┘  └───────┬────┘
 passarela│          rua sul           passarela│
   ┌──────┴─────┐      ┌────────┐      ┌───────┴────┐
   │ Prédio SO  │─pas.─│ S-meio │─pas.─│ Prédio SE  │   fileira sul
   │   5 m      │      │  7 m   │      │   6 m      │
   └────────────┘      └────────┘      └────────────┘
            viela de trás (liga os becos)
```

- **3 níveis de altura**: chão, telhados baixos (3,5 a 5,2 m) e altos (6 a 7 m).
- **Rotas variadas e sem becos sem saída**: os becos ligam a rua à viela de trás; cada telhado
  tem pelo menos 2 saídas (escada, passarela, caixote ou pular/escalar para o vizinho).
- **Parkour**: becos de 4 m (correr na parede de um lado e pular para o outro), caixotes para
  subir, containers em "escadinha" (caixote → 2,6 m → 5,2 m → passarela → telhado), toldos
  das bancas e o telhado do quiosque também dão para subir.
- **Cobertura**: fonte, canteiros, muretas, bancas, caixotes, caixas d'água e aparelhos de
  ar-condicionado nos telhados.
- **10 pontos de renascimento** espalhados (8 no chão em vielas e esquinas protegidas, 2 em
  telhados), todos a mais de 9 m uns dos outros. O jogo escolhe o mais longe dos inimigos.
- **Limites**: paredes invisíveis na borda; quem cair para fora renasce.

### Peças (cada uma em uma cena separada)

`scenes/mapa/pecas/`: `predio`, `container`, `caixa_madeira`, `muro`, `bloco`, `escada`,
`passarela`, `banca`, `fonte`, `canteiro`, `quiosque`. Cada peça gera sua geometria pelos
parâmetros (tamanho, cor...) e **aparece pronta no editor**. Para editar o mapa, abra
`vila_telhado.tscn`, selecione uma peça em *Pecas* e mova/mude os números no Inspetor.

Trocar uma peça por um modelo `.glb`: desmarque **gerar** na peça, arraste o `.glb` para
dentro dela e adicione as colisões (StaticBody3D, camada 1).

`tools/gerar_mapa.py` gerou o layout inicial. Não rode de novo depois de editar no editor,
porque ele sobrescreve. `tools/gerar_texturas_mapa.py` gera as 7 texturas
(`assets/map/texturas/`).

### Desempenho (para rodar a 60 FPS no celular)
- **Mesclagem de malhas** ao carregar: cerca de 2.900 pecinhas viram cerca de 90 malhas
  (agrupadas por textura e por região de 32 m; a cor de cada peça vai para a cor do vértice).
  Na visão do jogador ficam entre 170 e 240 draw calls, contando sombras e personagens.
- Uma leitura de textura por pixel (o UV é calculado na mesclagem) e sombra de contato no pé
  das paredes "pintada" nos vértices (dá profundidade sem custo de luz).
- Objetos pequenos (ar-condicionado, arbustos, mercadorias) somem a mais de 40 m e não
  projetam sombra.
- Texturas de 256 px, sombras só até 40 m, sem luzes dinâmicas extras.
- O carregamento + mesclagem leva cerca de 1 s no PC (no celular deve levar 2 a 3 s).

### O que testar
- [ ] Ande pelo mapa todo: tente achar um lugar onde fique preso ou que não tenha saída.
- [ ] Suba em todos os telhados (escadas, caixotes, containers, passarelas).
- [ ] Corra na parede nos becos entre os prédios.
- [ ] Veja o FPS no canto, principalmente olhando para a praça de cima de um telhado.
- [ ] Caia de propósito para fora (pelas bordas não dá; o limite segura).

Teste automático: `godot --headless --path jogo res://tests/teste_auto_etapa4.tscn`
(renascimentos, limites, queda, escadas, passarelas e a rota caixote → containers).

---

## Etapa 5: bots e mata-mata

A partida (`scenes/partida.tscn`) monta o mapa, você, os bots e o HUD.

### Bots (`ai/cerebro_bot.gd`)
Os bots usam **exatamente** o mesmo personagem e as mesmas armas que você; a IA só
"aperta os botões". Comportamento:
- **Patrulha** pelo mapa usando a malha de navegação (gerada ao carregar, ~40 ms).
- **Combate**: mira com erro e tempo de reação, atira em toques/rajadas, anda de lado,
  mantém a distância boa para a arma e faz parkour (pula, rola, desliza).
- **Cobertura**: com pouca vida vai para um ponto fora da visão do inimigo, recarrega e
  espera a vida regenerar.
- **Busca**: vai até onde viu/ouviu o inimigo pela última vez (ouvem tiros a ~28 m).
- **Destravar**: se ficarem presos, pulam (e agarram beiradas) ou mudam de destino.

| Dificuldade | Reação | Erro de mira | Parkour | Cobertura |
|---|---|---|---|---|
| Fácil | 0,9 s | 7° | quase nada | não |
| Médio | 0,55 s | 4,2° | às vezes | abaixo de 40 de vida |
| Difícil | 0,32 s | 2,6° | bastante | abaixo de 55 de vida |

Todos os números ficam em `PERFIS`, no começo do script. Medido em simulação: o líder
chega a 20 abates em ~5 min (fácil), ~6 min (médio) e ~4 min (difícil).

### Mata-mata (`scripts/modos/modo_mata_mata.gd`)
- Vence quem fizer **20 abates** primeiro, ou quem tiver mais quando os **8 minutos** acabarem.
- 5 participantes (você + 4 bots); renasce em 3 s no ponto mais longe dos inimigos, com 1,5 s
  de proteção. Vida regenera após 4 s sem tomar dano.
- HUD: tempo, placar (você × líder), feed de abates (✦ = na cabeça), barra de vida,
  indicador de direção do dano, borda vermelha com pouca vida, tela de "ELIMINADO",
  **PLACAR** (botão ou Tab) e tela de fim com recompensas.

Teste automático: `godot --headless --path jogo res://tests/teste_auto_etapa5.tscn`.

---

## Etapa 6: modelos 3D e animações

### O que já está no jogo (tudo CC0, baixado e ligado)
| O quê | Arquivo | Origem |
|---|---|---|
| Personagem masculino e feminino | `assets/characters/humano_*/` | Universal Base Characters (Quaternius) |
| 43 + 43 animações | `assets/animations/animacoes_humanas*.glb` | Universal Animation Library 1 e 2 (Quaternius) |
| 12 armas | `assets/weapons/<arma>.fbx` | Ultimate Gun Pack (Quaternius) |
| Cabelos/barba | `assets/characters/humano_*/` | Universal Base Characters |

### AnimationTree (`characters/humano/modelo_humano.gd`)
```
locomoção (Transition): parado · parado_arma · andar · trote · correr · pulo · parede ·
                         subindo_parede · escalar · rolar · deslizar · morrer
      └─ velocidade (TimeScale)
mira (BlendSpace1D: baixo / reto / cima) ──┐
                     Blend2 só no tronco ──┴─> OneShot "tiro" ─> OneShot "recarga" ─> saída
```
As pernas fazem a locomoção e o tronco mira, atira e recarrega por cima (dá para recarregar
correndo). A tabela `ANIM` no topo do script diz qual animação cada estado usa: para trocar
uma animação, mude só o nome ali.

### Armas: pontos de encaixe
Cada `weapons/modelos/<arma>.tscn` tem `Modelo` (o .fbx), e os marcadores **Mao**,
**Cano** e **Mira**. A arma é presa no osso da mão direita e alinhada automaticamente pela
pose de mira (funciona com qualquer modelo com o mesmo esqueleto). Skins de arma trocam
só o material.

### Baixar animações do Mixamo (opcional, para trocar as provisórias)
O pacote CC0 já cobre quase tudo. Faltam animações próprias para **correr na parede**
(hoje usa a corrida inclinada) e de **fuzil** (hoje a pose de mira é de pistola).
O Mixamo (mixamo.com) é gratuito, mas exige login com conta Adobe.

1. Entre em mixamo.com, aba **Animations**. Busque e baixe (os nomes exatos variam;
   use a busca):
   - "wall run" (correr na parede)
   - "rifle aiming idle", "rifle run", "firing rifle", "rifle reload" (pose de fuzil)
   - opcionais: "running slide", "sprinting forward roll", "climbing", "rifle death"
2. Configuração de download de cada uma: **Format: FBX Binary (.fbx)** · **Skin: Without
   Skin** · **Frames per Second: 30** · **Keyframe Reduction: none** · nas de locomoção
   marque **In Place**.
3. Coloque os arquivos em `jogo/assets/animations/mixamo/`.
4. Na Godot, para cada .fbx do Mixamo e também para `humano_masculino.gltf`,
   `humano_feminino.gltf`, `animacoes_humanas.glb` e `animacoes_humanas_2.glb`: clique no
   arquivo > aba **Importar** > **Avançado...** > selecione o **Skeleton3D** > em
   *Retarget* crie um **BoneMap** com **SkeletonProfileHumanoid** (os ossos são ligados
   sozinhos; confira se não ficou nenhum vermelho) > **Reimportar**. Isso deixa todos
   com os mesmos nomes de ossos, e as animações de um servem no outro. O código já aceita
   os dois padrões de nomes.
5. Adicione o caminho do .fbx em `CAMINHOS_ANIMACOES` e troque o nome em `ANIM`
   (ex.: `"parede": "WallRun"`).

### Importar um modelo novo (passo a passo)
**Personagem** (`.glb` com esqueleto humanoide):
1. Coloque em `assets/characters/<nome>/`.
2. Duplique `characters/humano/humano_masculino.tscn` e, no Inspetor, troque `cena_modelo`
   para o novo arquivo (e as texturas de skin, se houver).
3. Adicione o caminho da cena em `MODELOS` (topo de `scripts/jogador/jogador.gd`).
4. Mesmo esqueleto dos atuais (estilo UE: pelvis, spine_01, hand_r...) = funciona direto.
   Outro esqueleto (Mixamo etc.) = faça o passo 4 da seção do Mixamo.

**Arma** (`.fbx` ou `.glb`):
1. Coloque em `assets/weapons/<id_da_arma>.fbx`, com o cano para +X, o topo para +Y e a
   origem perto do gatilho (padrão da maioria dos pacotes).
2. Rode `godot --headless --path jogo -s res://tools/montar_armas.gd`: ele escala, gira e
   acha Mao/Cano/Mira sozinho. Ou faça à mão: abra `weapons/modelos/<id>.tscn`, troque o
   nó `Modelo` e mova os 3 marcadores.

**Peça de mapa**: veja a etapa 4 (desmarque `gerar`, arraste o `.glb` e adicione a colisão).

---

## Etapa 7: personagens, skins, caixas, roleta e progressão

O jogo agora abre no **menu principal** (`ui/menus/menu_principal.tscn`):

| Tela | O que tem |
|---|---|
| Início | perfil (nível, XP, moedas, caixas, giros), dificuldade e **JOGAR**, multiplayer, estatísticas |
| Personagem | masculino/feminino, 8 roupas (só visual) com prévia 3D que gira com o dedo. Começa com 2 liberadas; as outras saem na roleta |
| Arsenal | as 12 armas com atributos em barras, descrição (vantagem/fraqueza), equipar principal/secundária, skins com moldura da raridade e prévia 3D |
| Caixas | abrir caixa com animação de sorteio (faixa que desacelera), chances visíveis, comprar caixa com moedas |
| Roleta | roda com fatias do **tamanho real da chance**, animação de giro, chances visíveis |

**Ganha-se jogando** (nunca dinheiro real):
- Partida: 100 XP + 50 por abate (+300 se vencer) · 40 moedas + 8 por abate (+100 se vencer).
- Vitória: +1 caixa. Cada nível: +1 caixa e +1 giro. A cada 10 abates (somando partidas): +1 giro.
- Caixa extra: 400 moedas.

**Chances da caixa**: comum 60% · rara 27% · épica 10% · lendária 3%. Repetida vira
moedas (40 / 120 / 350 / 1000). Testado: 10 000 sorteios batem com essas chances.

**Roleta**: 100 moedas 28% · 300 XP 18% · 300 moedas 18% · caixa 14% · roupa nova 10% ·
800 XP 7% · 1000 moedas 4% · skin épica ou lendária garantida 1%.

**Skins de arma**: 48 skins (4 por arma), só visuais, em `data/skins_armas/<arma>_<n>.tres`.
Cada uma tem raridade, padrão (liso, listras, camuflagem, digital, gradiente, brilho), duas
cores, metal e brilho. Para criar outra: duplique um `.tres`, mude o número e as cores; ela
entra sozinha nas caixas e no arsenal. Os bots usam skins aleatórias.

**Tudo salvo no celular** em `user://progresso.save` (e as opções em `user://config.cfg`).

Teste automático: `godot --headless --path jogo res://tests/teste_auto_etapa7.tscn`
(XP/nível, recompensas, chances de 10 000 caixas e 3 000 giros, repetidas, compra,
equipar, salvar/carregar e abertura de todas as telas).

---

## Etapa 8: multiplayer com um amigo (mesma rede Wi-Fi)

### Como jogar
1. Os dois celulares na **mesma rede Wi-Fi**.
2. No celular A: **MULTIPLAYER** > digite seu nome > **CRIAR SALA**.
3. No celular B: **MULTIPLAYER**. A sala de A aparece sozinha na lista ("ENTRAR: sala de ...").
   Se não aparecer (alguns roteadores bloqueiam a busca), digite o IP que aparece na tela
   de A e toque em ENTRAR.
4. No celular A aparece o nome do amigo: escolha a dificuldade dos bots no INÍCIO e toque em
   **INICIAR PARTIDA**. Bots completam até 5 participantes.

### Como funciona (`network/rede.gd`, `network/sincronizador_personagem.gd`)
- **ENet** nativo da Godot: a sala é um servidor na porta UDP **7777**. A busca automática usa
  broadcast UDP na porta **7778** (o host anuncia a sala 1 vez por segundo).
- **Movimento**: cada celular simula o próprio personagem (resposta imediata) e envia o estado
  20× por segundo. Os outros são mostrados **100 ms no passado, interpolando** entre os estados
  (suave mesmo com rede instável) e extrapolando um pouco se faltar pacote.
- **Tiros**: quem atira calcula o acerto na hora (sem atraso na tela) e pede o dano ao host. O
  rastro do tiro aparece nos outros celulares.
- **Host = autoridade**: vida, invencibilidade do rolamento, abates, placar, tempo, renascimento
  e os bots (que rodam no host e são mostrados nos outros como remotos).
- Se o host sair, quem estava junto volta ao menu. Se o amigo sair, a partida continua.

Teste automático com **2 processos** (host + cliente na mesma máquina): o cliente acha a sala
pela busca, entra, se mexe, vê os bots, recebe o placar e o tiro dele mata o host.
```
PAPEL=host    godot --headless --path jogo -s res://tests/teste_rede.gd &
PAPEL=cliente godot --headless --path jogo -s res://tests/teste_rede.gd
```

### Jogar pela INTERNET (opções)
O jogo já funciona por IP; o problema da internet é **alcançar** o celular do host.

| Opção | Mexe no código? | Como | Prós / contras |
|---|---|---|---|
| **1. Rede virtual (VPN)**: Tailscale ou ZeroTier | não | instale o app nos 2 celulares, entrem na mesma rede; o amigo digita o IP **virtual** do host (ex.: 100.x.x.x) | mais fácil e grátis para uso pessoal; a busca automática não atravessa o Tailscale (digite o IP); ZeroTier pode deixar a busca funcionar |
| **2. Redirecionar porta** no roteador do host | não | no roteador, mande a porta UDP 7777 para o IP do celular host; o amigo digita o IP público | não funciona em 4G/5G (as operadoras usam CGNAT) e expõe a porta |
| **3. Servidor dedicado** numa VPS (servidor na nuvem) | um pouco | exportar a versão "servidor" do jogo (Godot headless) para Linux e rodar 24 h; os dois conectam no IP da VPS | o melhor para jogar sempre; custa alguns dólares por mês; precisa criar o modo "host sem jogador" |
| **4. Serviço de salas/relay**: Nakama (código aberto), W4 Cloud (feito para Godot), WebRTC com servidor de sinalização | sim | trocar a criação da sala por chamadas do serviço | busca de partidas pela internet de verdade; mais trabalho e dependência do serviço |

**Recomendação**: teste já com o **Tailscale ou ZeroTier** (zero código). Se for jogar sempre,
o próximo passo é o **servidor dedicado** numa VPS barata.

---

## Etapa 9: exportar o APK (passo a passo)

O `export_presets.cfg` já está pronto: arm64-v8a + armeabi-v7a, tela cheia, permissões de rede
(INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE), sem os
testes e ferramentas dentro do APK.

1. **Godot 4.3** (padrão, não .NET): godotengine.org.
2. **Modelos de exportação**: *Editor > Gerenciar Modelos de Exportação > Baixar e Instalar*.
3. **JDK 17** (ex.: Adoptium Temurin 17) e **Android SDK** (pelo Android Studio, ou só as
   "command line tools" com `platform-tools`, `build-tools;34.0.0` e `platforms;android-34`).
4. *Editor > Configurações do Editor > Exportar > Android*: preencha **Java SDK Path** e
   **Android SDK Path**. A chave de depuração é criada sozinha.
5. **Chave de assinatura própria** (para o APK "release"; guarde o arquivo e a senha!):
   ```
   keytool -genkeypair -v -keystore telhado.keystore -alias telhado -keyalg RSA -keysize 2048 -validity 10000
   ```
   Em *Projeto > Exportar > Android > Keystore > Release* aponte o arquivo, o alias e a senha.
   **Nunca** suba o `.keystore` para o git (o `.gitignore` já bloqueia).
6. *Projeto > Exportar > Android > **Exportar Projeto*** (desmarque "Exportar com Debug" para
   o APK mais rápido). Sai um `.apk`.
7. **Instalar**: copie o APK para o celular e abra (permita "instalar apps desconhecidos"), ou
   com o celular no cabo e a Depuração USB ligada: `adb install -r ProjetoTelhado.apk`.

Dicas:
- Cada versão nova: aumente *Version > Code* no preset para instalar por cima.
- Um APK assinado com outra chave não atualiza o anterior: desinstale antes.
- Para a Play Store seria preciso **AAB** (*Gradle Build* + formato AAB). Para uso pessoal,
  o APK basta.
- O APK enviado nas conversas foi assinado com uma chave criada no servidor de
  desenvolvimento. O seu, gerado no PC, terá outra (desinstale o antigo antes de instalar).

---

## Rodada 2: evolução (empunhadura, parkour, sons, skins)

Diagnóstico completo, o que mudou e o que falta: **`docs/RODADA2_DIAGNOSTICO_E_EVOLUCAO.md`**.
Resumo:
- **Armas nas mãos de verdade**: armas longas com coronha no ombro e as duas mãos por IK
  próprio (`characters/humano/ik_dois_ossos.gd`), dedos da mão de apoio fechados, prontidão
  fora da mira, troca de arma animada. Ajuste individual por arma no `.tres` (grupo
  *Empunhadura*: posição, rotação, escala, ângulo de prontidão).
- **Parkour em módulo** (`scripts/jogador/parkour.gd`) + **transpor obstáculos** correndo e
  **recuperação de aterrissagem**.
- **Sons** sintetizados (`tools/gerar_sons.py`), volume nas configurações.
- **Skins por parte da arma** (corpo, metais, vidro) com textura/material próprios opcionais;
  72 skins (Dourada e Futurista em todas as armas).
- **Tiro alinhado ao corpo** (não atravessa o que só a câmera enxerga por cima).
- **Rede**: recarga, troca de arma e skins dos bots sincronizadas.

### Ajustar a empunhadura de uma arma
1. Abra `data/armas/<arma>.tres`, grupo **Empunhadura (ajuste individual)**:
   `ajuste_posicao` (m: x direita, y cima, z frente), `ajuste_rotacao` (graus),
   `ajuste_escala`, `angulo_pronto_baixo`.
2. Para mudar onde as mãos seguram: abra `weapons/modelos/<arma>.tscn` e mova os marcadores
   **Mao** (cabo) e **MaoEsquerda** (guarda-mão).

### Criar uma skin com textura/material próprios
Duplique um `data/skins_armas/<arma>_<n>.tres`, numere em sequência e, no grupo
*Personalizado*, arraste sua textura em `textura_albedo` ou seus materiais em
`material_principal` / `material_secundario`.

## Todos os testes automáticos

```
godot --headless --path jogo res://tests/teste_auto_etapa1.tscn   # movimento e câmera
godot --headless --path jogo res://tests/teste_auto_etapa2.tscn   # parkour
godot --headless --path jogo res://tests/teste_auto_etapa3.tscn   # armas
godot --headless --path jogo res://tests/teste_auto_etapa4.tscn   # mapa
godot --headless --path jogo res://tests/teste_auto_etapa5.tscn   # bots e mata-mata
godot --headless --path jogo res://tests/teste_auto_etapa7.tscn   # progressão, caixas, roleta
(teste de rede: veja a etapa 8)
```

### Ajustar a "sensação" do movimento

Clique no nó **Jogador** dentro de `characters/jogador.tscn`: no Inspetor aparecem os grupos
*Movimento no chão*, *Pulo*, *Parede (wall run)*, *Escalar beirada*, *Rolamento*, *Deslize* e *Visual* com todos os números (velocidade, aceleração, gravidade,
altura do pulo…). A câmera (nó **CameraRig**) tem distância, ombro, FOV e suavização.
