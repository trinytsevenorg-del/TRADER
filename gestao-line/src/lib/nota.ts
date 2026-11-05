// Cálculo da nota de 0 a 100 do contrato (regras da seção "Regras de cálculo").
// Funções puras: recebem as linhas do banco e devolvem a nota de cada jogador num mês. Testadas em tests/nota.test.ts.

export type Funcao = 'rush' | 'suporte' | 'granadeiro';
export type Criterio = 'abates' | 'derrubados' | 'dano' | 'assistencias' | 'revividos' | 'utilitario';
export type StatusPresenca = 'presente' | 'atrasado' | 'falta_avisada' | 'falta_sem_aviso';
export type Faixa = 'destaque' | 'meta' | 'base' | 'recuperacao';
export type Nivel = 'destaque' | 'meta' | 'base' | 'abaixo';

export type Jogador = { id: string; nick: string; funcao: Funcao; capitao: boolean; ativo: boolean; ff_id?: string | null; apelidos_leitura?: string[] };
export type Evento = { id: string; tipo: 'treino' | 'campeonato'; nome: string; data: string; quedas_previstas?: number | null };
export type Queda = { id: string; evento_id: string; numero: number; colocacao: number | null; hash_print?: string | null };
export type Estatistica = { queda_id: string; jogador_id: string; abates: number; derrubados: number; dano: number; assistencias: number; revividos: number; print_enviado: boolean; corrigido?: boolean; confianca?: Record<string, string> };
export type Presenca = { evento_id: string; jogador_id: string; status: StatusPresenca };
export type Divulgacao = { evento_id: string; jogador_id: string; story_antes: boolean; resultado_24h: boolean };
export type NotaCapitao = { jogador_id: string; mes: string; postura: number | null; utilitario: number | null };
export type Meta = { funcao: Funcao; criterio: Criterio; base: number; meta: number; destaque: number; ordem: number };

export type Regras = {
  pesos: { desempenho: number; presenca: number; divulgacao: number; postura: number };
  niveis: { destaque: number; meta: number; base: number };
  tolerancia_capitao: { ativa: boolean; fracao_base: number };
  presenca_faixas: { min: number; pontos: number }[];
  atrasos_por_falta: number;
  falta_avisada_conta: boolean;
  resultado_faixas: { destaque: number; meta: number; base: number };
  inclui_treinos_no_desempenho: boolean;
  divulgacao_em: ('treino' | 'campeonato')[];
  dono_pode_lancar: boolean;
};

export const REGRAS_PADRAO: Regras = {
  pesos: { desempenho: 50, presenca: 20, divulgacao: 15, postura: 15 },
  niveis: { destaque: 100, meta: 80, base: 50 },
  tolerancia_capitao: { ativa: true, fracao_base: 0.7 },
  presenca_faixas: [{ min: 80, pontos: 20 }, { min: 70, pontos: 12 }, { min: 60, pontos: 6 }],
  atrasos_por_falta: 3,
  falta_avisada_conta: true,
  resultado_faixas: { destaque: 85, meta: 70, base: 55 },
  inclui_treinos_no_desempenho: true,
  divulgacao_em: ['campeonato'],
  dono_pode_lancar: false,
};

// junta o que veio do banco com o padrão (campos novos que ainda não existiam na organização)
export function regrasCompletas(r: Partial<Regras> | null | undefined): Regras {
  const x = r || {};
  return {
    ...REGRAS_PADRAO, ...x,
    pesos: { ...REGRAS_PADRAO.pesos, ...(x.pesos || {}) },
    niveis: { ...REGRAS_PADRAO.niveis, ...(x.niveis || {}) },
    tolerancia_capitao: { ...REGRAS_PADRAO.tolerancia_capitao, ...(x.tolerancia_capitao || {}) },
    resultado_faixas: { ...REGRAS_PADRAO.resultado_faixas, ...(x.resultado_faixas || {}) },
    presenca_faixas: Array.isArray(x.presenca_faixas) ? x.presenca_faixas : REGRAS_PADRAO.presenca_faixas,
    divulgacao_em: Array.isArray(x.divulgacao_em) ? x.divulgacao_em : REGRAS_PADRAO.divulgacao_em,
  };
}

export type Dados = {
  jogadores: Jogador[]; eventos: Evento[]; quedas: Queda[]; estatisticas: Estatistica[];
  presencas: Presenca[]; divulgacoes: Divulgacao[]; notas: NotaCapitao[]; metas: Meta[]; regras: Regras;
};

export type ResultadoCriterio = { criterio: Criterio; media: number | null; nivel: Nivel; fator: number; pontos: number; meta: Meta };
export type ResultadoJogador = {
  jogador: Jogador;
  nota: number;
  faixa: Faixa;
  quedas: number;
  desempenho: { pontos: number; max: number; criterios: ResultadoCriterio[] };
  presenca: { pontos: number; max: number; pct: number | null; treinos: number; faltas: number; atrasos: number; faltasEfetivas: number; pendentes: number; contagem: Record<StatusPresenca, number> };
  divulgacao: { pontos: number; max: number; feitos: number; devidos: number };
  postura: { pontos: number; max: number; nota: number | null };
  comprometimento: { pontos: number; max: number };
  pendencias: string[];
};

export const NOMES_FAIXA: Record<Faixa, string> = { destaque: 'Destaque', meta: 'Meta', base: 'Base', recuperacao: 'Plano de Recuperação' };
export const NOMES_FUNCAO: Record<Funcao, string> = { rush: 'Rush', suporte: 'Suporte', granadeiro: 'Granadeiro' };
export const NOMES_CRITERIO: Record<Criterio, string> = { abates: 'Abates', derrubados: 'Derrubados', dano: 'Dano', assistencias: 'Assistências', revividos: 'Revividos', utilitario: 'Utilitário' };

export const doMes = (data: string, mes: string) => data.slice(0, 7) === mes;
const r1 = (n: number) => Math.round(n * 10) / 10;

// Destaque = 100%, Meta = 80%, Base = 50%, abaixo = 0. Capitão: uma faixa de tolerância
// (Meta conta como Destaque, Base como Meta e 70% da Base como Base).
export function nivelDoCriterio(media: number, m: Meta, capitao: boolean, regras: Regras): { nivel: Nivel; fator: number } {
  const n = regras.niveis;
  const tol = capitao && regras.tolerancia_capitao.ativa;
  const corte = tol
    ? { destaque: m.meta, meta: m.base, base: m.base * regras.tolerancia_capitao.fracao_base }
    : { destaque: m.destaque, meta: m.meta, base: m.base };
  const eps = 1e-9;
  if (media + eps >= corte.destaque) return { nivel: 'destaque', fator: n.destaque / 100 };
  if (media + eps >= corte.meta) return { nivel: 'meta', fator: n.meta / 100 };
  if (media + eps >= corte.base) return { nivel: 'base', fator: n.base / 100 };
  return { nivel: 'abaixo', fator: 0 };
}

export function faixaDaNota(nota: number, regras: Regras): Faixa {
  const f = regras.resultado_faixas;
  if (nota >= f.destaque) return 'destaque';
  if (nota >= f.meta) return 'meta';
  if (nota >= f.base) return 'base';
  return 'recuperacao';
}

export function pontosPresenca(pct: number, regras: Regras) {
  const faixas = [...regras.presenca_faixas].sort((a, b) => b.min - a.min);
  for (const f of faixas) if (pct + 1e-9 >= f.min) return Math.min(f.pontos, regras.pesos.presenca);
  return 0;
}

// as quedas que valem para o desempenho de um jogador no mês.
// Queda sem print enviado conta como zero. Se o evento tem "quedas previstas" e faltam quedas lançadas,
// as que faltam também contam como zero para quem jogou aquele evento.
export function quedasDoJogador(d: Dados, jogadorId: string, mes: string) {
  const eventos = d.eventos.filter((e) => doMes(e.data, mes) && (e.tipo === 'campeonato' || d.regras.inclui_treinos_no_desempenho));
  const linhas: { evento: Evento; queda: Queda | null; est: Estatistica | null }[] = [];
  for (const ev of eventos) {
    const quedas = d.quedas.filter((q) => q.evento_id === ev.id);
    const minhas = quedas.map((q) => ({ q, est: d.estatisticas.find((s) => s.queda_id === q.id && s.jogador_id === jogadorId) || null })).filter((x) => x.est);
    if (!minhas.length) continue;
    for (const x of minhas) linhas.push({ evento: ev, queda: x.q, est: x.est });
    const faltam = Math.max(0, (ev.quedas_previstas || 0) - quedas.length);
    for (let i = 0; i < faltam; i++) linhas.push({ evento: ev, queda: null, est: null });
  }
  return linhas;
}

export function mediasDoJogador(d: Dados, jogadorId: string, mes: string) {
  const linhas = quedasDoJogador(d, jogadorId, mes);
  const soma = { abates: 0, derrubados: 0, dano: 0, assistencias: 0, revividos: 0 };
  for (const l of linhas) {
    if (!l.est || !l.est.print_enviado) continue; // zero
    soma.abates += l.est.abates; soma.derrubados += l.est.derrubados; soma.dano += l.est.dano;
    soma.assistencias += l.est.assistencias; soma.revividos += l.est.revividos;
  }
  const n = linhas.length;
  const media = (v: number) => (n ? v / n : null);
  return {
    quedas: n,
    medias: { abates: media(soma.abates), derrubados: media(soma.derrubados), dano: media(soma.dano), assistencias: media(soma.assistencias), revividos: media(soma.revividos) } as Record<Exclude<Criterio, 'utilitario'>, number | null>,
  };
}

export function calcularJogador(d: Dados, j: Jogador, mes: string): ResultadoJogador {
  const R = d.regras;
  const pendencias: string[] = [];
  const nota = d.notas.find((n) => n.jogador_id === j.id && n.mes === mes) || null;

  // Desempenho
  const { quedas, medias } = mediasDoJogador(d, j.id, mes);
  const metas = d.metas.filter((m) => m.funcao === j.funcao).sort((a, b) => a.ordem - b.ordem);
  const porCriterio = metas.length ? R.pesos.desempenho / metas.length : 0;
  const criterios: ResultadoCriterio[] = metas.map((m) => {
    const media = m.criterio === 'utilitario' ? (nota?.utilitario ?? null) : medias[m.criterio];
    if (m.criterio === 'utilitario' && media === null) pendencias.push('Nota de utilitário do capitão');
    const { nivel, fator } = media === null ? { nivel: 'abaixo' as Nivel, fator: 0 } : nivelDoCriterio(media, m, j.capitao, R);
    return { criterio: m.criterio, media, nivel, fator, pontos: porCriterio * fator, meta: m };
  });
  if (!quedas) pendencias.push('Nenhuma queda no mês');
  const desempenho = criterios.reduce((s, c) => s + c.pontos, 0);

  // Presença (só treinos)
  const treinos = d.eventos.filter((e) => e.tipo === 'treino' && doMes(e.data, mes));
  const contagem: Record<StatusPresenca, number> = { presente: 0, atrasado: 0, falta_avisada: 0, falta_sem_aviso: 0 };
  let pendentes = 0;
  for (const t of treinos) {
    const p = d.presencas.find((x) => x.evento_id === t.id && x.jogador_id === j.id);
    if (p) contagem[p.status]++; else pendentes++;
  }
  const lancados = treinos.length - pendentes;
  const faltas = contagem.falta_sem_aviso + (R.falta_avisada_conta ? contagem.falta_avisada : 0);
  const porAtraso = R.atrasos_por_falta > 0 ? Math.floor(contagem.atrasado / R.atrasos_por_falta) : 0;
  const faltasEfetivas = Math.min(lancados, faltas + porAtraso);
  const pct = lancados ? ((lancados - faltasEfetivas) / lancados) * 100 : null;
  const presenca = pct === null ? R.pesos.presenca : pontosPresenca(pct, R);
  if (pendentes) pendencias.push(pendentes + ' treino(s) sem presença lançada');

  // Divulgação: story antes e resultado em 24 h em cada evento dos tipos configurados
  const comDivulgacao = d.eventos.filter((e) => doMes(e.data, mes) && R.divulgacao_em.includes(e.tipo));
  let feitos = 0;
  for (const e of comDivulgacao) {
    const x = d.divulgacoes.find((v) => v.evento_id === e.id && v.jogador_id === j.id);
    if (x) feitos += (x.story_antes ? 1 : 0) + (x.resultado_24h ? 1 : 0);
  }
  const devidos = comDivulgacao.length * 2;
  const divulgacao = devidos ? (R.pesos.divulgacao * feitos) / devidos : R.pesos.divulgacao;

  // Postura: nota do capitão de 1 a 5 × 3
  const posturaNota = nota?.postura ?? null;
  if (posturaNota === null) pendencias.push('Nota de postura do capitão');
  const postura = posturaNota === null ? 0 : (posturaNota / 5) * R.pesos.postura;

  const total = Math.round(desempenho + presenca + divulgacao + postura);
  return {
    jogador: j,
    nota: total,
    faixa: faixaDaNota(total, R),
    quedas,
    desempenho: { pontos: r1(desempenho), max: R.pesos.desempenho, criterios },
    presenca: { pontos: r1(presenca), max: R.pesos.presenca, pct: pct === null ? null : Math.round(pct), treinos: treinos.length, faltas, atrasos: contagem.atrasado, faltasEfetivas, pendentes, contagem },
    divulgacao: { pontos: r1(divulgacao), max: R.pesos.divulgacao, feitos, devidos },
    postura: { pontos: r1(postura), max: R.pesos.postura, nota: posturaNota },
    comprometimento: { pontos: r1(presenca + divulgacao), max: R.pesos.presenca + R.pesos.divulgacao },
    pendencias,
  };
}

export function calcularMes(d: Dados, mes: string): ResultadoJogador[] {
  return d.jogadores.filter((j) => j.ativo).map((j) => calcularJogador(d, j, mes)).sort((a, b) => b.nota - a.nota || a.jogador.nick.localeCompare(b.jogador.nick));
}

export function colocacaoMedia(d: Dados, mes: string) {
  const ids = new Set(d.eventos.filter((e) => doMes(e.data, mes) && (e.tipo === 'campeonato' || d.regras.inclui_treinos_no_desempenho)).map((e) => e.id));
  const cs = d.quedas.filter((q) => ids.has(q.evento_id) && q.colocacao).map((q) => q.colocacao as number);
  return { media: cs.length ? r1(cs.reduce((a, b) => a + b, 0) / cs.length) : null, quedas: cs.length };
}

// médias reais da line por função e critério (para ajustar as metas depois de um mês)
export function mediasReaisPorFuncao(d: Dados, mes: string) {
  const out: Partial<Record<Funcao, Partial<Record<Criterio, number>>>> = {};
  for (const f of ['rush', 'suporte', 'granadeiro'] as Funcao[]) {
    const js = d.jogadores.filter((j) => j.ativo && j.funcao === f);
    const acc: Partial<Record<Criterio, number[]>> = {};
    for (const j of js) {
      const { quedas, medias } = mediasDoJogador(d, j.id, mes);
      if (!quedas) continue;
      for (const [k, v] of Object.entries(medias)) if (v !== null) (acc[k as Criterio] ||= []).push(v);
      const n = d.notas.find((x) => x.jogador_id === j.id && x.mes === mes)?.utilitario;
      if (n) (acc.utilitario ||= []).push(n);
    }
    out[f] = Object.fromEntries(Object.entries(acc).map(([k, v]) => [k, r1(v!.reduce((a, b) => a + b, 0) / v!.length)]));
  }
  return out;
}

export function mesAtual(hoje = new Date()) {
  return hoje.getFullYear() + '-' + String(hoje.getMonth() + 1).padStart(2, '0');
}
export function somarMes(mes: string, delta: number) {
  const [a, m] = mes.split('-').map(Number);
  const d = new Date(a, m - 1 + delta, 1);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
}
const MESES = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const MESES_LONGO = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
export const nomeMesCurto = (mes: string) => MESES[Number(mes.slice(5, 7)) - 1] + '/' + mes.slice(2, 4);
export const nomeMes = (mes: string) => MESES_LONGO[Number(mes.slice(5, 7)) - 1] + ' de ' + mes.slice(0, 4);
