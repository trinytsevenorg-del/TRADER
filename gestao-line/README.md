# Gestão de Line

App web instalável (PWA) para testar na prática a gestão de desempenho do contrato de uma line de Free Fire.
O capitão envia os prints da tela de resultado, o app lê os números, calcula a nota de cada jogador (0 a 100) e mostra gráficos.
O dono acompanha tudo em modo de leitura. Depois do teste, o módulo vai para dentro do Battle Hub.

## Estrutura

| Caminho | O que é |
|---|---|
| `src/` | Front-end React + Vite + `vite-plugin-pwa` (tema escuro, feito para celular) |
| `src/lib/nota.ts` | Cálculo da nota (regras da seção "Regras de cálculo"), funções puras |
| `src/lib/nicks.ts` | Associação do nick lido ao elenco (`norm`, `quase`, `quaseNick` copiados do `_shared/campeonato.ts` do Battle Hub) |
| `src/lib/prints-db.ts` | Prints guardados só no celular (IndexedDB); para o Supabase vão só os números |
| `supabase/migrations/` | Tabelas, RLS, gatilhos e RPCs |
| `supabase/functions/_shared/ia.ts` | Copiado sem mudanças do Battle Hub (Gemini grátis, troca de modelo no 429, Claude se houver `ANTHROPIC_API_KEY`) |
| `supabase/functions/_shared/leitura-print.ts` | Base do Battle Hub, ampliada: abates, derrubados, dano, assistências, revividos e confiança de cada campo |
| `supabase/functions/ler-print` | Lê um print (a imagem não é guardada) |
| `supabase/functions/criar-acesso` | O dono cria o login do capitão/jogador (e-mail + senha provisória) |
| `supabase/functions/perfil-ff` | Estatísticas de carreira pela free-ff-api (opcional, uma foto por semana, só informativo) |
| `tests/` | Testes do cálculo e da associação de nicks (`npm test`) |

## Quem pode entrar

O acesso é fechado:

1. **Administrador da plataforma** (você) gera um código em *Ajustes > Códigos de acesso* (ou `#/admin`).
   Formato `LINE-XXXX-XXXX-XXXX`, uso único, vale 30 dias (ajustável). Dá para anotar para quem é e cancelar enquanto não for usado.
2. **Dono da equipe** cria a conta e usa o código uma vez para criar a organização. Sem código, não cria nada
   (10 tentativas erradas por hora, no máximo).
3. **Capitão**: o dono cria o login dele em *Ajustes > Equipe > Criar login do capitão* (e-mail + senha provisória,
   já confirmado), ou manda um link de convite. O capitão troca a senha em *Conta*.
4. **Jogador** (fase 2): o dono cria o login na ficha do jogador.

Quem cria conta sem código nem convite não vê nenhuma equipe. Para tornar alguém administrador:
`insert into admins_plataforma (email) values ('email@exemplo.com');` no SQL Editor.

## Supabase (projeto separado do BATTLEHUB)

Projeto: **GESTAO-LINE** (`absymxkaualewjgevsvt`, sa-east-1).

1. Aplicar as migrações de `supabase/migrations/` em ordem (SQL Editor ou `supabase db push`).
2. Secrets das Edge Functions: `GEMINI_API_KEY` (obrigatória para a leitura automática; plano gratuito do Google AI Studio).
   Opcionais: `ANTHROPIC_API_KEY`, `FF_API_BASE` (sua cópia da free-ff-api), `LEITURAS_POR_DIA` (padrão 300 por organização).
3. Publicar as funções: `supabase functions deploy ler-print perfil-ff criar-acesso`.
4. Auth > URL Configuration: colocar a URL onde o app está publicado em *Site URL* e *Redirect URLs* (link mágico e confirmação de e-mail).

## Rodar o front

```bash
cp .env.example .env   # preencha VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY
npm install
npm run dev            # http://localhost:5173
npm test
npm run build          # gera dist/ (qualquer hospedagem estática: Vercel, Netlify, Cloudflare Pages)
```

## Decisões

- **Uma queda por print.** "Adicionar queda" aceita vários prints; cada um vira uma queda numerada em sequência.
- **Quedas previstas** (opcional, no evento): as que faltam lançar contam como zero para quem jogou o evento.
  A opção "Queda sem print" faz os números daquela queda contarem como zero.
- **Tolerância do capitão** vale para o jogador marcado como capitão no elenco.
- **Presença** vem só dos treinos; treino sem presença lançada não conta e aparece como pendência.
  Sem nenhum treino lançado no mês, a presença vale os 20 pontos.
- **Divulgação** é cobrada nos campeonatos (configurável); sem eventos cobrados no mês, vale os 15 pontos.
- **Postura e utilitário** sem nota do capitão contam como 0 e aparecem como pendência.
- **Dono só lê** os números; ele pode ligar "O dono também pode lançar" em Configurações.
- **Taxa de acerto da leitura**: cada número que o capitão muda na conferência é contado (Configurações > Leitura automática).
- **free-ff-api**: o repositório jinix6/free-ff-api tem só a documentação (o código está em 0xMe/FreeFire-Api), então não houve código para revisar.
  A função usa só `/api/v1/account` e `/api/v1/playerstats`, com limite de tempo, e o app segue normal se ela cair.
