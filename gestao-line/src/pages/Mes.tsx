import { useCallback, useEffect, useState } from 'react';
import { useApp } from '../lib/app';
import { msgErro, supabase } from '../lib/supabase';
import { mesAtual, somarMes, type NotaCapitao } from '../lib/nota';
import { LancamentoEvento } from '../components/LancamentoEvento';
import { Carregando, Estrelas, MesSeletor, Topo } from '../components/ui';
import { dataBR } from './Agenda';

type Ev = { id: string; tipo: 'treino' | 'campeonato'; nome: string; data: string; presencas: { count: number }[]; divulgacoes: { count: number }[] };

export default function Mes() {
  const { org, jogadores, podeLancar } = useApp();
  const [mes, setMes] = useState(mesAtual());
  const [aba, setAba] = useState<'eventos' | 'notas'>('eventos');
  const [eventos, setEventos] = useState<Ev[] | null>(null);
  const [aberto, setAberto] = useState<string | null>(null);
  const [notas, setNotas] = useState<Record<string, NotaCapitao>>({});
  const [erro, setErro] = useState('');
  const ativos = jogadores.filter((j) => j.ativo);

  const carregar = useCallback(async () => {
    if (!org) return;
    const [e, n] = await Promise.all([
      supabase.from('eventos').select('id, tipo, nome, data, presencas(count), divulgacoes(count)').eq('org_id', org.id)
        .gte('data', mes + '-01').lt('data', somarMes(mes, 1) + '-01').order('data'),
      supabase.from('notas_capitao').select('jogador_id, mes, postura, utilitario').eq('org_id', org.id).eq('mes', mes),
    ]);
    setEventos((e.data as Ev[]) || []);
    setNotas(Object.fromEntries(((n.data || []) as NotaCapitao[]).map((x) => [x.jogador_id, x])));
  }, [org, mes]);
  useEffect(() => { setEventos(null); setAberto(null); carregar(); }, [carregar]);

  async function nota(jid: string, campo: 'postura' | 'utilitario', v: number | null) {
    setErro('');
    const ant = notas[jid];
    const atual: NotaCapitao = { jogador_id: jid, mes, postura: ant?.postura ?? null, utilitario: ant?.utilitario ?? null, [campo]: v };
    setNotas({ ...notas, [jid]: atual });
    const { error } = await supabase.from('notas_capitao').upsert({ ...atual, org_id: org!.id }, { onConflict: 'jogador_id,mes' });
    if (error) { setErro(msgErro(error)); carregar(); }
  }

  const comDivulgacao = (t: Ev['tipo']) => !!org?.regras.divulgacao_em.includes(t);

  return (
    <>
      <Topo titulo="Mês" />
      <MesSeletor mes={mes} onChange={setMes} />
      <div className="seg" style={{ marginBottom: 12 }}>
        <button className={aba === 'eventos' ? 'ativo' : ''} onClick={() => setAba('eventos')}>Presença e divulgação</button>
        <button className={aba === 'notas' ? 'ativo' : ''} onClick={() => setAba('notas')}>Notas do capitão</button>
      </div>
      {erro && <div className="erro" style={{ marginBottom: 12 }}>{erro}</div>}

      {aba === 'eventos' && (eventos === null ? <Carregando /> : !eventos.length ? <div className="card vazio">Nenhum evento neste mês.</div> : eventos.map((e) => {
        const pres = e.presencas?.[0]?.count || 0, div = e.divulgacoes?.[0]?.count || 0;
        const falta = (e.tipo === 'treino' && pres < ativos.length) || (comDivulgacao(e.tipo) && div < ativos.length);
        if (e.tipo !== 'treino' && !comDivulgacao(e.tipo)) return null;
        return (
          <div key={e.id}>
            <button className="card btn-bloco" style={{ justifyContent: 'flex-start', textAlign: 'left', marginBottom: aberto === e.id ? 0 : 12 }} onClick={() => setAberto(aberto === e.id ? null : e.id)} aria-expanded={aberto === e.id}>
              <span className="num muted" style={{ width: 44 }}>{dataBR(e.data)}</span>
              <span className="cresce" style={{ flex: 1 }}>
                <strong>{e.nome}</strong>
                <span className="small muted" style={{ display: 'block' }}>
                  {e.tipo === 'treino' ? `Presença ${pres}/${ativos.length}` : 'Campeonato'}{comDivulgacao(e.tipo) ? ` · Divulgação ${div}/${ativos.length}` : ''}
                </span>
              </span>
              {falta && <span className="chip" style={{ borderColor: 'var(--warn-border)' }}>pendente</span>}
            </button>
            {aberto === e.id && <div style={{ marginTop: 6 }}><LancamentoEvento evento={e} /></div>}
          </div>
        );
      }))}

      {aba === 'notas' && (
        <div className="card">
          <p className="small muted">Postura de todos (vale até {org?.regras.pesos.postura} pontos) e utilitário do granadeiro (critério de desempenho). Toque de novo para limpar.</p>
          <ul className="lista">
            {ativos.map((j) => (
              <li key={j.id}>
                <strong>{j.nick}</strong>
                <div className="entre" style={{ marginTop: 6 }}><span className="small sec">Postura</span><Estrelas valor={notas[j.id]?.postura ?? null} disabled={!podeLancar} onChange={(v) => nota(j.id, 'postura', v)} /></div>
                {j.funcao === 'granadeiro' && (
                  <div className="entre" style={{ marginTop: 6 }}><span className="small sec">Utilitário</span><Estrelas valor={notas[j.id]?.utilitario ?? null} disabled={!podeLancar} onChange={(v) => nota(j.id, 'utilitario', v)} /></div>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </>
  );
}
