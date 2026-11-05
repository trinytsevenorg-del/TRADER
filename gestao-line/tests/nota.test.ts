import { describe, expect, it } from 'vitest';
import { calcularJogador, colocacaoMedia, nivelDoCriterio, pontosPresenca, REGRAS_PADRAO, faixaDaNota, type Dados, type Meta } from '../src/lib/nota';

const METAS: Meta[] = [
  { funcao: 'rush', criterio: 'abates', base: 1.5, meta: 2.5, destaque: 3.5, ordem: 1 },
  { funcao: 'rush', criterio: 'derrubados', base: 2, meta: 3, destaque: 4, ordem: 2 },
  { funcao: 'rush', criterio: 'dano', base: 600, meta: 900, destaque: 1300, ordem: 3 },
  { funcao: 'granadeiro', criterio: 'dano', base: 500, meta: 800, destaque: 1100, ordem: 1 },
  { funcao: 'granadeiro', criterio: 'assistencias', base: 1, meta: 1.5, destaque: 2, ordem: 2 },
  { funcao: 'granadeiro', criterio: 'utilitario', base: 3, meta: 4, destaque: 5, ordem: 3 },
];
const rush = { id: 'j1', nick: 'Kaio', funcao: 'rush' as const, capitao: false, ativo: true };

function base(): Dados {
  return {
    jogadores: [rush], metas: METAS, regras: REGRAS_PADRAO,
    eventos: [{ id: 'c1', tipo: 'campeonato', nome: 'Copa', data: '2026-11-03', quedas_previstas: null }],
    quedas: [{ id: 'q1', evento_id: 'c1', numero: 1, colocacao: 2 }, { id: 'q2', evento_id: 'c1', numero: 2, colocacao: 6 }],
    estatisticas: [
      { queda_id: 'q1', jogador_id: 'j1', abates: 4, derrubados: 5, dano: 1500, assistencias: 0, revividos: 0, print_enviado: true },
      { queda_id: 'q2', jogador_id: 'j1', abates: 3, derrubados: 3, dano: 1100, assistencias: 1, revividos: 0, print_enviado: true },
    ],
    presencas: [], divulgacoes: [], notas: [],
  };
}

describe('nível de cada critério', () => {
  const m = METAS[0];
  it('Destaque 100%, Meta 80%, Base 50%, abaixo 0', () => {
    expect(nivelDoCriterio(3.5, m, false, REGRAS_PADRAO)).toEqual({ nivel: 'destaque', fator: 1 });
    expect(nivelDoCriterio(2.5, m, false, REGRAS_PADRAO)).toEqual({ nivel: 'meta', fator: 0.8 });
    expect(nivelDoCriterio(1.5, m, false, REGRAS_PADRAO)).toEqual({ nivel: 'base', fator: 0.5 });
    expect(nivelDoCriterio(1.4, m, false, REGRAS_PADRAO)).toEqual({ nivel: 'abaixo', fator: 0 });
  });
  it('capitão tem uma faixa de tolerância', () => {
    expect(nivelDoCriterio(2.5, m, true, REGRAS_PADRAO).nivel).toBe('destaque');
    expect(nivelDoCriterio(1.5, m, true, REGRAS_PADRAO).nivel).toBe('meta');
    expect(nivelDoCriterio(1.05, m, true, REGRAS_PADRAO).nivel).toBe('base'); // 70% de 1,5
    expect(nivelDoCriterio(1.0, m, true, REGRAS_PADRAO).nivel).toBe('abaixo');
  });
});

describe('presença e faixas', () => {
  it('80% = 20, 70% = 12, 60% = 6, menos = 0', () => {
    expect(pontosPresenca(100, REGRAS_PADRAO)).toBe(20);
    expect(pontosPresenca(80, REGRAS_PADRAO)).toBe(20);
    expect(pontosPresenca(75, REGRAS_PADRAO)).toBe(12);
    expect(pontosPresenca(60, REGRAS_PADRAO)).toBe(6);
    expect(pontosPresenca(59, REGRAS_PADRAO)).toBe(0);
  });
  it('resultado', () => {
    expect(faixaDaNota(85, REGRAS_PADRAO)).toBe('destaque');
    expect(faixaDaNota(84, REGRAS_PADRAO)).toBe('meta');
    expect(faixaDaNota(55, REGRAS_PADRAO)).toBe('base');
    expect(faixaDaNota(54, REGRAS_PADRAO)).toBe('recuperacao');
  });
});

describe('nota do mês', () => {
  it('jogador completo chega a 100', () => {
    const d = base();
    d.notas = [{ jogador_id: 'j1', mes: '2026-11', postura: 5, utilitario: null }];
    d.divulgacoes = [{ evento_id: 'c1', jogador_id: 'j1', story_antes: true, resultado_24h: true }];
    const r = calcularJogador(d, rush, '2026-11');
    // médias 3,5 abates, 4 derrubados, 1300 dano = tudo Destaque
    expect(r.desempenho.pontos).toBe(50);
    expect(r.presenca.pontos).toBe(20); // sem treinos no mês
    expect(r.divulgacao.pontos).toBe(15);
    expect(r.postura.pontos).toBe(15);
    expect(r.nota).toBe(100);
    expect(r.faixa).toBe('destaque');
  });

  it('queda sem print e queda prevista não lançada contam como zero', () => {
    const d = base();
    d.estatisticas[1].print_enviado = false;
    d.eventos[0].quedas_previstas = 4; // 2 lançadas, faltam 2
    const r = calcularJogador(d, rush, '2026-11');
    expect(r.quedas).toBe(4);
    const abates = r.desempenho.criterios.find((c) => c.criterio === 'abates')!;
    expect(abates.media).toBe(1); // 4 / 4
    expect(abates.nivel).toBe('abaixo');
  });

  it('presença: 3 atrasos = 1 falta, falta avisada conta', () => {
    const d = base();
    d.eventos = [...d.eventos, ...Array.from({ length: 10 }, (_, i) => ({ id: 't' + i, tipo: 'treino' as const, nome: 'T', data: '2026-11-1' + i }))];
    const st = ['presente', 'presente', 'presente', 'presente', 'atrasado', 'atrasado', 'atrasado', 'falta_avisada', 'presente', 'presente'] as const;
    d.presencas = st.map((s, i) => ({ evento_id: 't' + i, jogador_id: 'j1', status: s }));
    const r = calcularJogador(d, rush, '2026-11');
    expect(r.presenca.faltasEfetivas).toBe(2);
    expect(r.presenca.pct).toBe(80);
    expect(r.presenca.pontos).toBe(20);
  });

  it('divulgação proporcional e postura × 3', () => {
    const d = base();
    d.divulgacoes = [{ evento_id: 'c1', jogador_id: 'j1', story_antes: true, resultado_24h: false }];
    d.notas = [{ jogador_id: 'j1', mes: '2026-11', postura: 3, utilitario: null }];
    const r = calcularJogador(d, rush, '2026-11');
    expect(r.divulgacao.pontos).toBe(7.5);
    expect(r.postura.pontos).toBe(9);
  });

  it('granadeiro usa a nota de utilitário do capitão', () => {
    const d = base();
    const g = { id: 'j2', nick: 'Gran', funcao: 'granadeiro' as const, capitao: false, ativo: true };
    d.jogadores.push(g);
    d.estatisticas.push({ queda_id: 'q1', jogador_id: 'j2', abates: 0, derrubados: 0, dano: 800, assistencias: 2, revividos: 0, print_enviado: true });
    d.notas = [{ jogador_id: 'j2', mes: '2026-11', postura: 4, utilitario: 4 }];
    const r = calcularJogador(d, g, '2026-11');
    expect(r.desempenho.criterios.map((c) => c.nivel)).toEqual(['meta', 'destaque', 'meta']);
    expect(r.desempenho.pontos).toBeCloseTo((50 / 3) * (0.8 + 1 + 0.8), 1);
  });

  it('colocação média da line', () => {
    expect(colocacaoMedia(base(), '2026-11')).toEqual({ media: 4, quedas: 2 });
  });
});
