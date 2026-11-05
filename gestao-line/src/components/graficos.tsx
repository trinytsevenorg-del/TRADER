import { useRef, useState } from 'react';
import { NOMES_CRITERIO, type ResultadoCriterio } from '../lib/nota';

const fmt = (v: number, casas = 1) => v.toLocaleString('pt-BR', { maximumFractionDigits: casas });

// Linha de uma série só (o título do card nomeia a série; sem legenda). Linhas de referência tracejadas e rotuladas.
// Hover/toque: guia vertical + dica com o valor do mês.
export function GraficoLinha({ pontos, min = 0, max, refs = [], casas = 0, sufixo = '' }: {
  pontos: { rotulo: string; valor: number | null }[]; min?: number; max?: number; refs?: { y: number; rotulo: string }[]; casas?: number; sufixo?: string;
}) {
  const [ativo, setAtivo] = useState<number | null>(null);
  const caixa = useRef<HTMLDivElement>(null);
  const W = 340, H = 180, E = 30, D = 12, T = 12, B = 24;
  const vals = pontos.map((p) => p.valor).filter((v): v is number => v !== null);
  const topo = max ?? Math.max(1, ...vals, ...refs.map((r) => r.y)) * 1.1;
  const x = (i: number) => E + (pontos.length <= 1 ? (W - E - D) / 2 : (i * (W - E - D)) / (pontos.length - 1));
  const y = (v: number) => T + (1 - (v - min) / (topo - min || 1)) * (H - T - B);
  const ticks = [min, min + (topo - min) / 2, topo];
  // segmentos contínuos (mês sem dado quebra a linha)
  const segs: string[] = [];
  let atual = '';
  pontos.forEach((p, i) => {
    if (p.valor === null) { if (atual) segs.push(atual); atual = ''; return; }
    atual += (atual ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(p.valor).toFixed(1);
  });
  if (atual) segs.push(atual);

  const mover = (clientX: number) => {
    const r = caixa.current?.getBoundingClientRect();
    if (!r || !pontos.length) return;
    const px = ((clientX - r.left) / r.width) * W;
    let melhor = 0;
    pontos.forEach((_, i) => { if (Math.abs(x(i) - px) < Math.abs(x(melhor) - px)) melhor = i; });
    setAtivo(melhor);
  };
  const a = ativo !== null ? pontos[ativo] : null;

  return (
    <div ref={caixa} style={{ position: 'relative' }} onMouseLeave={() => setAtivo(null)}
      onMouseMove={(e) => mover(e.clientX)} onTouchStart={(e) => mover(e.touches[0].clientX)} onTouchMove={(e) => mover(e.touches[0].clientX)}>
      <svg className="viz" viewBox={`0 0 ${W} ${H}`} role="img" aria-label={pontos.map((p) => p.rotulo + ': ' + (p.valor === null ? 'sem dado' : fmt(p.valor, casas))).join(', ')}>
        {ticks.map((t) => (
          <g key={t}>
            <line className="grade" x1={E} x2={W - D} y1={y(t)} y2={y(t)} />
            <text x={E - 6} y={y(t) + 4} textAnchor="end">{fmt(t, 0)}</text>
          </g>
        ))}
        {refs.map((r) => (
          <g key={r.rotulo}>
            <line x1={E} x2={W - D} y1={y(r.y)} y2={y(r.y)} stroke="var(--ref)" strokeDasharray="3 4" strokeWidth={1} />
            <text x={W - D} y={y(r.y) - 4} textAnchor="end">{r.rotulo}</text>
          </g>
        ))}
        {pontos.map((p, i) => <text key={i} x={x(i)} y={H - 6} textAnchor="middle">{p.rotulo}</text>)}
        {a && <line x1={x(ativo!)} x2={x(ativo!)} y1={T} y2={H - B} stroke="var(--text-muted)" strokeWidth={1} />}
        {segs.map((d, i) => <path key={i} className="serie" d={d} strokeLinecap="round" strokeLinejoin="round" />)}
        {pontos.map((p, i) => p.valor !== null && <circle key={i} className="ponto" cx={x(i)} cy={y(p.valor)} r={ativo === i ? 5 : 4} />)}
        {/* rótulo direto só no último valor */}
        {(() => {
          const k = pontos.map((p) => p.valor).lastIndexOf(vals[vals.length - 1]);
          return k >= 0 && vals.length ? <text x={x(k)} y={y(vals[vals.length - 1]) - 9} textAnchor="middle" style={{ fill: 'var(--text-primary)', fontWeight: 600 }}>{fmt(vals[vals.length - 1], casas)}{sufixo}</text> : null;
        })()}
      </svg>
      {a && (
        <div className="dica" style={{ left: (x(ativo!) / W) * 100 + '%', top: (a.valor === null ? T : y(a.valor)) / H * 100 + '%' }}>
          <strong>{a.rotulo}</strong> · {a.valor === null ? 'sem dado' : fmt(a.valor, casas) + sufixo}
        </div>
      )}
    </div>
  );
}

const NOMES_NIVEL = { destaque: 'Destaque', meta: 'Meta', base: 'Base', abaixo: 'Abaixo da Base' };

// Cada critério comparado com as metas da função: barra = média do mês; marcas = Base, Meta e Destaque.
export function GraficoCriterios({ criterios }: { criterios: ResultadoCriterio[] }) {
  const [ativo, setAtivo] = useState<number | null>(null);
  const W = 340, E = 0, D = 8, ALT = 58;
  return (
    <div>
      {criterios.map((c, i) => {
        const fim = Math.max(c.meta.destaque * 1.25, c.media ?? 0);
        const x = (v: number) => E + (v / (fim || 1)) * (W - E - D);
        const casas = c.criterio === 'dano' ? 0 : 1;
        return (
          <div key={c.criterio} style={{ position: 'relative', marginBottom: 6 }} onMouseEnter={() => setAtivo(i)} onMouseLeave={() => setAtivo(null)} onClick={() => setAtivo(ativo === i ? null : i)}>
            <div className="entre small">
              <span>{NOMES_CRITERIO[c.criterio]}</span>
              <span className="num"><strong>{c.media === null ? '—' : fmt(c.media, casas)}</strong> <span className="muted">· {NOMES_NIVEL[c.nivel]} · {fmt(c.pontos, 1)} pts</span></span>
            </div>
            <svg className="viz" viewBox={`0 0 ${W} 30`} role="img"
              aria-label={`${NOMES_CRITERIO[c.criterio]}: ${c.media === null ? 'sem dado' : fmt(c.media, casas)}. Base ${fmt(c.meta.base, casas)}, Meta ${fmt(c.meta.meta, casas)}, Destaque ${fmt(c.meta.destaque, casas)}.`}>
              <rect x={E} y={8} width={W - E - D} height={10} rx={4} fill="var(--surface-3)" />
              {c.media !== null && c.media > 0 && <rect x={E} y={8} width={Math.max(4, x(c.media) - E)} height={10} rx={4} fill="var(--series-1)" />}
              {(['base', 'meta', 'destaque'] as const).map((k) => (
                <g key={k}>
                  <line x1={x(c.meta[k])} x2={x(c.meta[k])} y1={4} y2={22} stroke="var(--text-secondary)" strokeWidth={2} />
                  <text x={x(c.meta[k])} y={30} textAnchor="middle" style={{ fontSize: 9 }}>{k === 'base' ? 'B' : k === 'meta' ? 'M' : 'D'}</text>
                </g>
              ))}
            </svg>
            {ativo === i && (
              <div className="dica" style={{ left: '50%', top: 0 }}>
                Média {c.media === null ? '—' : fmt(c.media, casas)} · Base {fmt(c.meta.base, casas)} · Meta {fmt(c.meta.meta, casas)} · Destaque {fmt(c.meta.destaque, casas)}
              </div>
            )}
          </div>
        );
      })}
      <div className="legenda" style={{ minHeight: ALT - 40 }}>
        <span><i style={{ background: 'var(--series-1)' }} />Média do mês</span>
        <span>Marcas: B = Base · M = Meta · D = Destaque</span>
      </div>
    </div>
  );
}
