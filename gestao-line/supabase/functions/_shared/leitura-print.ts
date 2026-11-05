// Formato e instruções da IA que lê os prints do fim da partida do Free Fire.
// Base: _shared/leitura-print.ts do Battle Hub (lia só colocação e abates). Aqui a resposta foi ampliada para trazer,
// de cada jogador visível, abates, derrubados, dano, assistências e revividos, e a confiança de cada campo.
// Fica num arquivo próprio para os testes usarem exatamente as mesmas instruções e a mesma limpeza.

export const CAMPOS = ['abates', 'derrubados', 'dano', 'assistencias', 'revividos'] as const;
export type Campo = typeof CAMPOS[number];
export type Confianca = 'alta' | 'baixa';

export type JogadorLido = {
  nick_seen: string;
  abates: number | null;
  derrubados: number | null;
  dano: number | null;
  assistencias: number | null;
  revividos: number | null;
  confianca: Partial<Record<Campo | 'nick', Confianca>>;
};
export type Resultado = { colocacao: number | null; colocacao_confianca: Confianca; jogadores: JogadorLido[] };

const num = (desc: string) => ({ type: ['integer', 'null'], description: desc + ' null se não aparecer ou não der para ler.' });
const conf = { type: 'string', enum: ['alta', 'baixa'] };

export const TOOL = {
  name: 'leitura',
  description: 'Os números da tela de resultado do fim da partida do Free Fire (modo squad).',
  input_schema: {
    type: 'object',
    additionalProperties: false,
    required: ['is_result_screen', 'placement', 'placement_confidence', 'players'],
    properties: {
      is_result_screen: { type: 'boolean', description: 'true só se for a tela de resultado/fim de partida do Free Fire com os números dos jogadores.' },
      placement: num('Colocação da equipe: "BOOYAH!" = 1, "#5", "5º", "TOP 5" = 5.'),
      placement_confidence: { ...conf, description: '"baixa" se a colocação estiver cortada, borrada ou se você deduziu.' },
      players: {
        type: 'array',
        description: 'Cada jogador da equipe que aparece no print, na ordem em que aparece.',
        items: {
          type: 'object', additionalProperties: false,
          required: ['nick_seen', 'kills', 'knockdowns', 'damage', 'assists', 'revives', 'confidence'],
          properties: {
            nick_seen: { type: 'string', description: 'Nick exatamente como aparece, com a tag e os símbolos.' },
            kills: num('Abates / Eliminações.'),
            knockdowns: num('Derrubados (inimigos derrubados / knock).'),
            damage: num('Dano causado (número inteiro, sem pontos ou vírgulas).'),
            assists: num('Assistências.'),
            revives: num('Revividos / Reanimações (quantos companheiros ele levantou).'),
            confidence: {
              type: 'object', additionalProperties: false,
              description: 'Confiança da leitura de cada campo deste jogador: "baixa" quando o número estiver cortado, borrado, pequeno demais, coberto ou quando você não tem certeza do campo.',
              required: ['nick', 'kills', 'knockdowns', 'damage', 'assists', 'revives'],
              properties: { nick: conf, kills: conf, knockdowns: conf, damage: conf, assists: conf, revives: conf },
            },
          },
        },
      },
    },
  },
};

export const SYSTEM = `Você lê prints da TELA DE RESULTADO do fim da partida do jogo Free Fire (Garena), modo squad, enviados pelo capitão de uma equipe.
O print mostra a colocação da equipe ("BOOYAH!" = 1º, "#5", "5º", "TOP 5") e, para cada jogador da equipe, os números da partida:
Abates (ou Eliminações), Derrubados, Dano, Assistências e Revividos (ou Reanimações). Os nomes podem variar um pouco conforme a versão do jogo.
Se o print for a tabela geral com todas as equipes, devolva SOMENTE a equipe que tem os jogadores da lista enviada.
Regras:
- Nunca invente. Número ilegível, cortado ou ausente = null e confiança "baixa".
- Dano é um número inteiro (ex.: "1.234" = 1234).
- Marque confiança "baixa" em qualquer campo que você não tenha certeza.
- Se não for tela de resultado, is_result_screen = false e players vazio.
Responda chamando a ferramenta "leitura".`;

const LIMITES: Record<Campo, number> = { abates: 60, derrubados: 80, dano: 20000, assistencias: 60, revividos: 40 };
const DE_PARA: Record<Campo, string> = { abates: 'kills', derrubados: 'knockdowns', dano: 'damage', assistencias: 'assists', revividos: 'revives' };

function inteiro(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return Math.round(v);
  if (typeof v === 'string' && /^\s*[\d.,]+\s*$/.test(v)) return Number(v.replace(/[.,\s]/g, ''));
  return null;
}

// limpa a resposta da IA: números fora do possível viram null, e todo campo null ou estranho fica com confiança baixa
// deno-lint-ignore no-explicit-any
export function lerResultado(r: any): Resultado | null {
  if (!r || !r.is_result_screen) return null;
  const pos = inteiro(r.placement);
  const colocacao = pos && pos >= 1 && pos <= 60 ? pos : null;
  const jogadores: JogadorLido[] = (Array.isArray(r.players) ? r.players : [])
    // deno-lint-ignore no-explicit-any
    .filter((p: any) => p && typeof p.nick_seen === 'string' && p.nick_seen.trim())
    .slice(0, 6)
    // deno-lint-ignore no-explicit-any
    .map((p: any) => {
      const c = (p.confidence && typeof p.confidence === 'object') ? p.confidence : {};
      const out: JogadorLido = { nick_seen: p.nick_seen.trim(), abates: null, derrubados: null, dano: null, assistencias: null, revividos: null, confianca: {} };
      if (c.nick === 'baixa') out.confianca.nick = 'baixa';
      for (const k of CAMPOS) {
        const v = inteiro(p[DE_PARA[k]]);
        const ok = v !== null && v >= 0 && v <= LIMITES[k];
        out[k] = ok ? v : null;
        if (!ok || c[DE_PARA[k]] !== 'alta') out.confianca[k] = 'baixa';
      }
      return out;
    });
  return {
    colocacao,
    colocacao_confianca: colocacao === null || r.placement_confidence !== 'alta' ? 'baixa' : 'alta',
    jogadores,
  };
}
