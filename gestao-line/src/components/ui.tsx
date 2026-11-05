import { useEffect, type ReactNode } from 'react';
import { NOMES_FAIXA, nomeMes, somarMes, type Faixa } from '../lib/nota';
import { useApp } from '../lib/app';

export function FaixaBadge({ faixa }: { faixa: Faixa }) {
  return <span className={'faixa faixa-' + faixa}><span className="ponto" aria-hidden />{NOMES_FAIXA[faixa]}</span>;
}

export function Topo({ titulo, direita, voltar }: { titulo: string; direita?: ReactNode; voltar?: () => void }) {
  const { org, orgs, trocarOrg } = useApp();
  return (
    <header className="topo">
      {voltar && <button className="btn-icone" onClick={voltar} aria-label="Voltar"><Icone nome="voltar" /></button>}
      <div className="titulo">
        {org && (orgs.length > 1
          ? <select aria-label="Organização" value={org.id} onChange={(e) => trocarOrg(e.target.value)}
              style={{ background: 'none', border: 0, padding: 0, minHeight: 0, color: 'var(--text-muted)', fontSize: '0.8rem', width: 'auto' }}>
              {orgs.map((o) => <option key={o.id} value={o.id}>{o.nome} · {o.linha_nome}</option>)}
            </select>
          : <div className="org">{org.nome} · {org.linha_nome}</div>)}
        <h1 className="corta">{titulo}</h1>
      </div>
      {direita}
    </header>
  );
}

export function MesSeletor({ mes, onChange }: { mes: string; onChange: (m: string) => void }) {
  return (
    <div className="entre card" style={{ padding: 6 }}>
      <button className="btn-icone" aria-label="Mês anterior" onClick={() => onChange(somarMes(mes, -1))}><Icone nome="voltar" /></button>
      <strong>{nomeMes(mes)}</strong>
      <button className="btn-icone" aria-label="Próximo mês" onClick={() => onChange(somarMes(mes, 1))}><span style={{ transform: 'rotate(180deg)', display: 'inline-flex' }}><Icone nome="voltar" /></span></button>
    </div>
  );
}

export function Modal({ aberto, fechar, titulo, children }: { aberto: boolean; fechar: () => void; titulo: string; children: ReactNode }) {
  useEffect(() => {
    if (!aberto) return;
    const f = (e: KeyboardEvent) => e.key === 'Escape' && fechar();
    window.addEventListener('keydown', f);
    return () => window.removeEventListener('keydown', f);
  }, [aberto, fechar]);
  if (!aberto) return null;
  return (
    <div className="modal-fundo" onClick={fechar}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={titulo} onClick={(e) => e.stopPropagation()}>
        <div className="entre" style={{ marginBottom: 12 }}>
          <h2 style={{ margin: 0 }}>{titulo}</h2>
          <button className="btn-icone" onClick={fechar} aria-label="Fechar"><Icone nome="x" /></button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Estrelas({ valor, onChange, disabled }: { valor: number | null; onChange: (v: number | null) => void; disabled?: boolean }) {
  return (
    <div className="estrelas" role="radiogroup">
      {[1, 2, 3, 4, 5].map((n) => (
        <button key={n} type="button" role="radio" aria-checked={valor === n} disabled={disabled} className={valor === n ? 'ativo' : ''}
          onClick={() => onChange(valor === n ? null : n)}>{n}</button>
      ))}
    </div>
  );
}

export function Barra({ pct }: { pct: number }) {
  return <div className="barra" aria-hidden><i style={{ width: Math.max(0, Math.min(100, pct)) + '%' }} /></div>;
}

const PATHS: Record<string, string> = {
  painel: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  agenda: 'M7 3v3M17 3v3M4 8h16M5 5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z',
  mes: 'M9 11l3 3 8-8M20 12v7a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h11',
  elenco: 'M16 20v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 20v-1a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8',
  config: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z',
  voltar: 'M15 18l-6-6 6-6',
  x: 'M18 6 6 18M6 6l12 12',
  mais: 'M12 5v14M5 12h14',
  imagem: 'M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1ZM8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM20 15l-5-5L5 20',
  lapis: 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z',
  lixo: 'M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6',
  baixar: 'M12 3v12M7 10l5 5 5-5M5 21h14',
  link: 'M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7',
  sair: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
};
export function Icone({ nome }: { nome: string }) {
  return (
    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d={PATHS[nome]} />
    </svg>
  );
}

export function Carregando() {
  return <div className="vazio">Carregando…</div>;
}
