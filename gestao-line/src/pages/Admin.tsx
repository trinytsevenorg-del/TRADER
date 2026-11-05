// Tela do administrador da plataforma: gera os códigos de acesso que permitem criar uma equipe.
// Só aparece para quem está na tabela admins_plataforma.
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../lib/app';
import { msgErro, supabase } from '../lib/supabase';
import { Icone } from '../components/ui';

type Codigo = { codigo: string; para: string | null; expira_em: string; usado_em: string | null; usado_por_email: string | null; org_nome: string | null; criado_em: string };
const dia = (d: string) => new Date(d).toLocaleDateString('pt-BR');

export default function Admin() {
  const { souAdmin, org } = useApp();
  const nav = useNavigate();
  const [lista, setLista] = useState<Codigo[] | null>(null);
  const [para, setPara] = useState('');
  const [dias, setDias] = useState('30');
  const [novo, setNovo] = useState('');
  const [msg, setMsg] = useState<{ tipo: 'ok' | 'erro'; texto: string } | null>(null);

  const carregar = useCallback(async () => {
    const { data, error } = await supabase.rpc('listar_codigos');
    if (error) setMsg({ tipo: 'erro', texto: msgErro(error) });
    setLista((data as Codigo[]) || []);
  }, []);
  useEffect(() => { if (souAdmin) carregar(); }, [souAdmin, carregar]);

  async function gerar(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    const { data, error } = await supabase.rpc('gerar_codigo_acesso', { p_para: para, p_dias: Number(dias) || 30 });
    if (error) { setMsg({ tipo: 'erro', texto: msgErro(error) }); return; }
    setNovo(data as string);
    setPara('');
    try { await navigator.clipboard.writeText(data as string); setMsg({ tipo: 'ok', texto: 'Código copiado. Entregue ao dono da equipe.' }); } catch { /* fica na tela */ }
    carregar();
  }

  async function cancelar(c: string) {
    if (!confirm('Cancelar o código ' + c + '?')) return;
    const { error } = await supabase.from('codigos_acesso').delete().eq('codigo', c);
    if (error) setMsg({ tipo: 'erro', texto: msgErro(error) }); else carregar();
  }

  if (!souAdmin) return <div className="vazio">Só o administrador da plataforma acessa esta tela.</div>;
  const agora = Date.now();

  return (
    <>
      <header className="topo">
        <button className="btn-icone" onClick={() => nav(org ? '/config' : '/')} aria-label="Voltar"><Icone nome="voltar" /></button>
        <div className="titulo"><div className="org">Administrador</div><h1>Códigos de acesso</h1></div>
      </header>
      <div className="card">
        <p className="small sec">Só cria uma equipe quem tem um código. O dono usa o código uma vez, ao criar a organização, e depois cria o login do capitão.</p>
        <form onSubmit={gerar}>
          <div className="campo"><label htmlFor="para">Para quem (anotação)</label><input id="para" maxLength={80} placeholder="Ex.: Dono da equipe RDN" value={para} onChange={(e) => setPara(e.target.value)} /></div>
          <div className="campo"><label htmlFor="dias">Vale por (dias)</label><input id="dias" inputMode="numeric" value={dias} onChange={(e) => setDias(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <button className="btn-prim btn-bloco"><Icone nome="mais" />Gerar código</button>
        </form>
        {novo && <div className="tile" style={{ marginTop: 12, textAlign: 'center' }}><div className="v" style={{ letterSpacing: '0.05em' }}>{novo}</div><div className="r">novo código</div></div>}
        {msg && <div className={msg.tipo} style={{ marginTop: 12 }}>{msg.texto}</div>}
      </div>

      <h2 style={{ margin: '16px 0 8px' }}>Códigos gerados</h2>
      {lista === null ? <div className="vazio">Carregando…</div> : !lista.length ? <div className="card vazio">Nenhum código ainda.</div> : (
        <ul className="lista card" style={{ padding: '0 14px' }}>
          {lista.map((c) => {
            const vencido = !c.usado_em && new Date(c.expira_em).getTime() < agora;
            return (
              <li key={c.codigo} className="linha">
                <div className="cresce">
                  <strong className="num" style={{ letterSpacing: '0.03em' }}>{c.codigo}</strong>
                  <div className="small muted">{c.para || 'sem anotação'}</div>
                  <div className="small" style={{ color: c.usado_em ? 'var(--good)' : vencido ? 'var(--critical)' : 'var(--text-secondary)' }}>
                    {c.usado_em ? `Usado em ${dia(c.usado_em)} por ${c.usado_por_email || '—'}${c.org_nome ? ' · ' + c.org_nome : ''}` : vencido ? 'Vencido' : 'Livre · vence em ' + dia(c.expira_em)}
                  </div>
                </div>
                {!c.usado_em && <>
                  <button className="btn-icone" aria-label="Copiar" onClick={() => navigator.clipboard.writeText(c.codigo).catch(() => {})}><Icone nome="link" /></button>
                  <button className="btn-icone btn-perigo" aria-label="Cancelar código" onClick={() => cancelar(c.codigo)}><Icone nome="lixo" /></button>
                </>}
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}
