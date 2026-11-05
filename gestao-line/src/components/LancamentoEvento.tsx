// Presença (treinos) e checklist de divulgação (story antes e resultado em 24 h) de um evento.
// Cada toque grava na hora.
import { useCallback, useEffect, useState } from 'react';
import { useApp } from '../lib/app';
import { msgErro, supabase } from '../lib/supabase';
import type { StatusPresenca } from '../lib/nota';

const STATUS: { v: StatusPresenca; nome: string }[] = [
  { v: 'presente', nome: 'Presente' }, { v: 'atrasado', nome: 'Atrasado' }, { v: 'falta_avisada', nome: 'Falta avisada' }, { v: 'falta_sem_aviso', nome: 'Falta s/ aviso' },
];

export function LancamentoEvento({ evento }: { evento: { id: string; tipo: 'treino' | 'campeonato' } }) {
  const { org, jogadores, podeLancar } = useApp();
  const [pres, setPres] = useState<Record<string, StatusPresenca>>({});
  const [div, setDiv] = useState<Record<string, { story_antes: boolean; resultado_24h: boolean }>>({});
  const [erro, setErro] = useState('');
  const ativos = jogadores.filter((j) => j.ativo);
  const temPresenca = evento.tipo === 'treino';
  const temDivulgacao = !!org?.regras.divulgacao_em.includes(evento.tipo);

  const carregar = useCallback(async () => {
    const [p, d] = await Promise.all([
      supabase.from('presencas').select('jogador_id, status').eq('evento_id', evento.id),
      supabase.from('divulgacoes').select('jogador_id, story_antes, resultado_24h').eq('evento_id', evento.id),
    ]);
    setPres(Object.fromEntries((p.data || []).map((x) => [x.jogador_id, x.status])));
    setDiv(Object.fromEntries((d.data || []).map((x) => [x.jogador_id, { story_antes: x.story_antes, resultado_24h: x.resultado_24h }])));
  }, [evento.id]);
  useEffect(() => { carregar(); }, [carregar]);

  async function marcar(jid: string, s: StatusPresenca) {
    setErro('');
    const antes = pres[jid];
    setPres({ ...pres, [jid]: s });
    const { error } = await supabase.from('presencas').upsert({ evento_id: evento.id, jogador_id: jid, status: s, org_id: org!.id }, { onConflict: 'evento_id,jogador_id' });
    if (error) { setErro(msgErro(error)); setPres((x) => ({ ...x, [jid]: antes })); }
  }
  async function todosPresentes() {
    const linhas = ativos.filter((j) => !pres[j.id]).map((j) => ({ evento_id: evento.id, jogador_id: j.id, status: 'presente' as const, org_id: org!.id }));
    if (!linhas.length) return;
    const { error } = await supabase.from('presencas').upsert(linhas, { onConflict: 'evento_id,jogador_id' });
    if (error) setErro(msgErro(error)); else carregar();
  }
  async function marcarDiv(jid: string, campo: 'story_antes' | 'resultado_24h', v: boolean) {
    setErro('');
    const atual = { ...{ story_antes: false, resultado_24h: false }, ...div[jid], [campo]: v };
    setDiv({ ...div, [jid]: atual });
    const { error } = await supabase.from('divulgacoes').upsert({ evento_id: evento.id, jogador_id: jid, org_id: org!.id, ...atual }, { onConflict: 'evento_id,jogador_id' });
    if (error) { setErro(msgErro(error)); carregar(); }
  }

  if (!temPresenca && !temDivulgacao) return null;
  return (
    <div className="card">
      {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
      {temPresenca && (
        <>
          <div className="entre" style={{ marginBottom: 8 }}>
            <h2 style={{ margin: 0 }}>Presença</h2>
            {podeLancar && ativos.some((j) => !pres[j.id]) && <button className="btn-peq" onClick={todosPresentes}>Restantes presentes</button>}
          </div>
          <ul className="lista">
            {ativos.map((j) => (
              <li key={j.id}>
                <div className="small" style={{ marginBottom: 6 }}><strong>{j.nick}</strong>{!pres[j.id] && <span className="muted"> · não lançado</span>}</div>
                <div className="pres" role="radiogroup" aria-label={'Presença de ' + j.nick}>
                  {STATUS.map((s) => (
                    <button key={s.v} role="radio" aria-checked={pres[j.id] === s.v} disabled={!podeLancar} className={pres[j.id] === s.v ? 'ativo' : ''} onClick={() => marcar(j.id, s.v)}>{s.nome}</button>
                  ))}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
      {temDivulgacao && (
        <>
          <h2 style={{ marginTop: temPresenca ? 16 : 0 }}>Divulgação</h2>
          <table className="tab">
            <thead><tr><th>Jogador</th><th style={{ textAlign: 'center' }}>Story antes</th><th style={{ textAlign: 'center' }}>Resultado 24 h</th></tr></thead>
            <tbody>
              {ativos.map((j) => (
                <tr key={j.id}>
                  <td>{j.nick}</td>
                  {(['story_antes', 'resultado_24h'] as const).map((c) => (
                    <td key={c} style={{ textAlign: 'center' }}>
                      <input type="checkbox" aria-label={(c === 'story_antes' ? 'Story antes' : 'Resultado em 24 h') + ' de ' + j.nick} disabled={!podeLancar}
                        checked={!!div[j.id]?.[c]} onChange={(e) => marcarDiv(j.id, c, e.target.checked)} />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
