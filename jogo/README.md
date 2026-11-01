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
├── weapons/             (etapa 3) cenas e scripts das armas
├── data/                (etapa 3+) Resources .tres: armas, skins, raridades…
├── ai/                  (etapa 5) bots
├── network/             (etapa 8) multiplayer ENet
├── ui/                  HUD de toque, mira, menus
├── assets/              modelos .glb e animações (etapa 6)
│   ├── characters/  weapons/  map/  animations/
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
| 3 | Armas e tiro | próxima |
| 4 | Mapa urbano | |
| 5 | Bots e mata-mata | |
| 6 | Modelos 3D e animações | |
| 7 | Personagens, skins, roleta, caixas, progressão | |
| 8 | Multiplayer com um amigo (Wi-Fi) | |
| 9 | Exportar APK | |

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
| Rolamento | ROLAR. 0,3 s invencível, recarga de 0,8 s. No ar, fica guardado e sai ao aterrissar | Shift |
| Deslizar | DESLIZ. correndo. Cair de alto correndo também desliza sozinho. Passa por baixo de vãos baixos | C ou Ctrl |

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

### Ajustar a "sensação" do movimento

Clique no nó **Jogador** dentro de `characters/jogador.tscn`: no Inspetor aparecem os grupos
*Movimento no chão*, *Pulo*, *Parede (wall run)*, *Escalar beirada*, *Rolamento*, *Deslize* e *Visual* com todos os números (velocidade, aceleração, gravidade,
altura do pulo…). A câmera (nó **CameraRig**) tem distância, ombro, FOV e suavização.
