import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useApp } from '../lib/app';
import { msgErro, supabase } from '../lib/supabase';
import { mesAtual, somarMes } from '../lib/nota';
import { Carregando, Icone, MesSeletor, Modal, Topo } from '../components/ui';

type Ev = { id: string; tipo: 'treino' | 'campeonato'; nome: string; data: string; quedas_previstas: number | null; quedas: { count: number }[] };

export const dataBR = (d: string) => d.slice(8, 10) + '/' + d.slice(5, 7);
const hoje = () => { const d = new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };

export default function Agenda() {
  const { org, podeLancar } = useApp();
  const nav = useNavigate();
  const [mes, setMes] = useState(mesAtual());
  const [eventos, setEventos] = useState<Ev[] | null>(null);
  const [form, setForm] = useState<{ tipo: 'treino' | 'campeonato'; nome: string; data: string; quedas: string } | null>(null);
  const [erro, setErro] = useState('');

  const carregar = useCallback(async () => {
    if (!org) return;
    const { data } = await supabase.from('eventos').select('id, tipo, nome, data, quedas_previstas, quedas(count)')
      .eq('org_id', org.id).gte('data', mes + '-01').lt('data', somarMes(mes, 1) + '-01').order('data', { ascending: false }).order('criado_em', { ascending: false });
    setEventos((data as Ev[]) || []);
  }, [org, mes]);
  useEffect(() => { setEventos(null); carregar(); }, [carregar]);

  async function criar(e: React.FormEvent) {
    e.preventDefault();
    if (!form || !org) return;
    setErro('');
    const { data, error } = await supabase.from('eventos').insert({
      org_id: org.id, tipo: form.tipo, nome: form.nome.trim(), data: form.data, quedas_previstas: form.quedas ? Number(form.quedas) : null,
    }).select('id').single();
    if (error) { setErro(msgErro(error)); return; }
    setForm(null);
    nav('/evento/' + data.id);
  }

  return (
    <>
      <Topo titulo="Agenda" direita={podeLancar && <button className="btn-prim" onClick={() => { setErro(''); setForm({ tipo: 'campeonato', nome: '', data: hoje(), quedas: '' }); }}><Icone nome="mais" />Evento</button>} />
      <MesSeletor mes={mes} onChange={setMes} />
      {eventos === null ? <Carregando /> : !eventos.length ? <div className="card vazio">Nenhum treino ou campeonato neste mês.</div> : (
        <ul className="lista card" style={{ padding: '0 14px' }}>
          {eventos.map((e) => {
            const n = e.quedas?.[0]?.count || 0;
            return (
              <li key={e.id}>
                <Link to={'/evento/' + e.id} className="linha" style={{ color: 'inherit' }}>
                  <div className="num muted" style={{ width: 44 }}>{dataBR(e.data)}</div>
                  <div className="cresce">
                    <strong className="corta" style={{ display: 'block' }}>{e.nome}</strong>
                    <span className="small muted">{e.tipo === 'treino' ? 'Treino' : 'Campeonato'} · {n}{e.quedas_previstas ? '/' + e.quedas_previstas : ''} queda(s)</span>
                  </div>
                  <span className="chip">{e.tipo === 'treino' ? 'Treino' : 'Camp.'}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}

      <Modal aberto={!!form} fechar={() => setForm(null)} titulo="Novo evento">
        {form && (
          <form onSubmit={criar}>
            <div className="campo">
              <label>Tipo</label>
              <div className="seg">
                <button type="button" className={form.tipo === 'treino' ? 'ativo' : ''} onClick={() => setForm({ ...form, tipo: 'treino' })}>Treino</button>
                <button type="button" className={form.tipo === 'campeonato' ? 'ativo' : ''} onClick={() => setForm({ ...form, tipo: 'campeonato' })}>Campeonato</button>
              </div>
            </div>
            <div className="campo"><label htmlFor="nome">Nome</label><input id="nome" required maxLength={80} value={form.nome} onChange={(e) => setForm({ ...form, nome: e.target.value })} placeholder={form.tipo === 'treino' ? 'Ex.: Treino X-Treino' : 'Ex.: Copa Liga BR'} /></div>
            <div className="grade2">
              <div className="campo"><label htmlFor="data">Data</label><input id="data" type="date" required value={form.data} onChange={(e) => setForm({ ...form, data: e.target.value })} /></div>
              <div className="campo"><label htmlFor="qp">Quedas previstas</label><input id="qp" inputMode="numeric" placeholder="opcional" value={form.quedas} onChange={(e) => setForm({ ...form, quedas: e.target.value.replace(/\D/g, '').slice(0, 2) })} /></div>
            </div>
            <p className="small muted">Com “quedas previstas”, as quedas sem print enviado contam como zero para quem jogou.</p>
            {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
            <button className="btn-prim btn-bloco">Criar e abrir</button>
          </form>
        )}
      </Modal>
    </>
  );
}
