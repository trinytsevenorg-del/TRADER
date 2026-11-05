// Tela "Conferir números": uma tabela por queda (jogador, colocação, abates, derrubados, dano, assistências, revividos).
// Campos em que a leitura teve dúvida ficam em amarelo; o capitão corrige com um toque e confirma.
import { useEffect, useState } from 'react';
import { NOMES_FUNCAO, type Jogador } from '../lib/nota';
import { Icone } from './ui';

export const CAMPOS = ['abates', 'derrubados', 'dano', 'assistencias', 'revividos'] as const;
export type Campo = typeof CAMPOS[number];
const CAB: Record<Campo, string> = { abates: 'Abat.', derrubados: 'Derr.', dano: 'Dano', assistencias: 'Assist.', revividos: 'Reviv.' };
const MAX: Record<Campo, number> = { abates: 60, derrubados: 80, dano: 20000, assistencias: 60, revividos: 40 };

export type Linha = {
  key: string;
  jogador_id: string | null; // null = "Quem é este?"
  ignorar?: boolean; // não é da line
  nick_seen: string | null;
  valores: Record<Campo, number | null>;
  lido: Record<Campo, number | null> | null; // o que a IA leu (para saber o que foi corrigido)
  duvida: Partial<Record<Campo | 'nick', boolean>>;
  duvidaIa?: Campo[]; // campos em que a IA teve dúvida (fica guardado para medir a confiabilidade)
};
export type Rascunho = {
  key: string;
  queda_id?: string;
  numero: number;
  colocacao: number | null;
  colocacao_duvida: boolean;
  hash?: string;
  thumb?: string;
  status: 'lendo' | 'pronto' | 'erro' | 'repetido';
  aviso?: string;
  sem_print: boolean;
  linhas: Linha[];
  salvando?: boolean;
};

export const linhaVazia = (jogador_id: string | null): Linha => ({
  key: Math.random().toString(36).slice(2), jogador_id, nick_seen: null,
  valores: { abates: 0, derrubados: 0, dano: 0, assistencias: 0, revividos: 0 }, lido: null, duvida: {},
});

export function pendenciasDoRascunho(r: Rascunho) {
  const p: string[] = [];
  if (r.linhas.some((l) => !l.ignorar && !l.jogador_id)) p.push('Responda “Quem é este?”');
  if (r.linhas.some((l) => !l.ignorar && CAMPOS.some((c) => l.valores[c] === null))) p.push('Preencha os campos vazios');
  if (!r.linhas.some((l) => !l.ignorar && l.jogador_id)) p.push('Nenhum jogador da line');
  return p;
}

function CampoNum({ valor, duvida, onChange, max, rotulo }: { valor: number | null; duvida: boolean; onChange: (v: number | null) => void; max: number; rotulo: string }) {
  const [txt, setTxt] = useState(valor === null ? '' : String(valor));
  useEffect(() => { setTxt(valor === null ? '' : String(valor)); }, [valor]);
  return (
    <input aria-label={rotulo} inputMode="numeric" className={duvida ? 'duvida' : ''} value={txt}
      onFocus={(e) => e.target.select()}
      onChange={(e) => {
        const t = e.target.value.replace(/\D/g, '').slice(0, 5);
        setTxt(t);
        onChange(t === '' ? null : Math.min(max, Number(t)));
      }} />
  );
}

export function CartaoRascunho({ r, jogadores, onChange, onSalvar, onDescartar, podeSalvar }: {
  r: Rascunho; jogadores: Jogador[]; onChange: (r: Rascunho) => void; onSalvar: () => void; onDescartar: () => void; podeSalvar: boolean;
}) {
  const ativos = jogadores.filter((j) => j.ativo);
  const usados = new Set(r.linhas.map((l) => l.jogador_id).filter(Boolean));
  const nome = (id: string | null) => jogadores.find((j) => j.id === id)?.nick || '?';
  const mudarLinha = (k: string, f: (l: Linha) => Linha) => onChange({ ...r, linhas: r.linhas.map((l) => (l.key === k ? f(l) : l)) });
  const pend = pendenciasDoRascunho(r);
  const faltando = ativos.filter((j) => !usados.has(j.id));

  if (r.status === 'lendo') {
    return <div className="card linha">{r.thumb && <img src={r.thumb} className="thumb" alt="" />}<div className="cresce"><strong>Queda {r.numero}</strong><div className="small muted">Lendo o print…</div></div></div>;
  }
  if (r.status === 'repetido') {
    return (
      <div className="card aviso linha">
        {r.thumb && <img src={r.thumb} className="thumb" alt="" />}
        <div className="cresce"><strong>Print repetido</strong><div className="small">{r.aviso}</div></div>
        <button onClick={onDescartar}>Descartar</button>
      </div>
    );
  }

  return (
    <div className="card">
      <div className="linha" style={{ marginBottom: 10 }}>
        {r.thumb && <a href={r.thumb} target="_blank" rel="noreferrer"><img src={r.thumb} className="thumb" alt={'Print da queda ' + r.numero} /></a>}
        <div className="cresce">
          <strong>Queda {r.numero}</strong>
          <div className="small muted">{r.sem_print ? 'Sem print (conta zero)' : r.queda_id ? 'Editando' : r.thumb ? 'Lida do print' : 'Lançada à mão'}</div>
        </div>
        <div style={{ width: 92 }}>
          <label className="small" htmlFor={'col' + r.key} style={{ marginBottom: 2 }}>Colocação</label>
          <CampoNum rotulo="Colocação" valor={r.colocacao} duvida={r.colocacao_duvida} max={60}
            onChange={(v) => onChange({ ...r, colocacao: v, colocacao_duvida: false })} />
        </div>
      </div>
      {r.aviso && <div className="erro small" style={{ marginBottom: 10 }}>{r.aviso}</div>}

      <div className="conf" style={{ marginBottom: 4 }}>
        {CAMPOS.map((c) => <span key={c} className="cab">{CAB[c]}</span>)}
      </div>
      {r.linhas.map((l) => (
        <div key={l.key} style={{ marginBottom: 6 }}>
          {!l.jogador_id && !l.ignorar ? (
            <div className="quem" style={{ marginBottom: 4 }}>
              <div className="small" style={{ marginBottom: 6 }}>Quem é este? Lido: <strong>{l.nick_seen || '—'}</strong></div>
              <select aria-label="Quem é este?" value="" onChange={(e) => {
                const v = e.target.value;
                mudarLinha(l.key, (x) => (v === '__ignorar' ? { ...x, ignorar: true } : { ...x, jogador_id: v }));
              }}>
                <option value="" disabled>Escolha o jogador…</option>
                {ativos.filter((j) => !usados.has(j.id)).map((j) => <option key={j.id} value={j.id}>{j.nick} · {NOMES_FUNCAO[j.funcao]}</option>)}
                <option value="__ignorar">Não é da line (ignorar)</option>
              </select>
              <div className="small muted" style={{ marginTop: 4 }}>A resposta vira apelido de leitura, para não perguntar de novo.</div>
            </div>
          ) : null}
          {l.ignorar ? (
            <div className="entre small muted">
              <span>Ignorado: {l.nick_seen}</span>
              <button className="btn-txt" onClick={() => mudarLinha(l.key, (x) => ({ ...x, ignorar: false, jogador_id: null }))}>Desfazer</button>
            </div>
          ) : (
            <div className="conf">
              <div className="nome">
                <div className="linha" style={{ gap: 4 }}>
                  <strong className="corta small" style={{ flex: 'none', maxWidth: '45%' }}>{l.jogador_id ? nome(l.jogador_id) : '?'}</strong>
                  <button className="btn-icone btn-peq" style={{ minWidth: 28, minHeight: 28, border: 0, background: 'none' }} aria-label="Tirar da queda"
                    onClick={() => onChange({ ...r, linhas: r.linhas.filter((x) => x.key !== l.key) })}><Icone nome="x" /></button>
                  {l.nick_seen && l.jogador_id && <span className="small corta cresce" style={{ color: l.duvida.nick ? 'var(--warning)' : 'var(--text-muted)' }}>lido: {l.nick_seen}</span>}
                </div>
              </div>
              {CAMPOS.map((c) => (
                <CampoNum key={c} rotulo={CAB[c] + ' de ' + (l.jogador_id ? nome(l.jogador_id) : l.nick_seen)} valor={l.valores[c]} duvida={!!l.duvida[c]} max={MAX[c]}
                  onChange={(v) => mudarLinha(l.key, (x) => ({ ...x, valores: { ...x.valores, [c]: v }, duvida: { ...x.duvida, [c]: false } }))} />
              ))}
            </div>
          )}
        </div>
      ))}
      {faltando.length > 0 && (
        <select aria-label="Adicionar jogador" value="" style={{ marginTop: 4 }}
          onChange={(e) => onChange({ ...r, linhas: [...r.linhas, linhaVazia(e.target.value)] })}>
          <option value="" disabled>+ Jogador que não apareceu no print…</option>
          {faltando.map((j) => <option key={j.id} value={j.id}>{j.nick}</option>)}
        </select>
      )}
      <div className="linha" style={{ marginTop: 10 }}>
        <input id={'sp' + r.key} type="checkbox" checked={r.sem_print} onChange={(e) => onChange({ ...r, sem_print: e.target.checked })} />
        <label htmlFor={'sp' + r.key} className="small" style={{ margin: 0 }}>Queda sem print (os números contam como zero)</label>
      </div>
      {pend.length > 0 && <div className="small" style={{ color: 'var(--warning)', marginTop: 8 }}>{pend.join(' · ')}</div>}
      <div className="linha" style={{ marginTop: 10 }}>
        <button className="btn-txt btn-perigo" onClick={onDescartar}>Descartar</button>
        <div className="cresce" />
        <button className="btn-prim" disabled={!podeSalvar || pend.length > 0 || r.salvando} onClick={onSalvar}>{r.salvando ? 'Salvando…' : 'Confirmar'}</button>
      </div>
    </div>
  );
}
