import { useCallback, useEffect, useState } from 'react';
import { useApp } from '../lib/app';
import { carregarDados } from '../lib/dados';
import { msgErro, supabase } from '../lib/supabase';
import { mediasReaisPorFuncao, mesAtual, NOMES_CRITERIO, NOMES_FUNCAO, REGRAS_PADRAO, somarMes, type Criterio, type Funcao, type Meta, type Regras } from '../lib/nota';
import { Icone, Topo } from '../components/ui';

type Membro = { usuario_id: string; papel: 'dono' | 'capitao' | 'jogador'; email: string | null };
type Convite = { token: string; papel: string; expira_em: string; usado_por: string | null; jogador_id: string | null };
const PAPEL = { dono: 'Dono', capitao: 'Capitão', jogador: 'Jogador' };
const linkConvite = (t: string) => window.location.origin + window.location.pathname + '#/convite/' + t;

function Num({ valor, onChange, passo = 'any', rotulo }: { valor: number; onChange: (v: number) => void; passo?: string; rotulo: string }) {
  return <input aria-label={rotulo} type="number" inputMode="decimal" step={passo} min={0} value={Number.isFinite(valor) ? valor : ''} onChange={(e) => onChange(Number(e.target.value))} style={{ padding: '6px 4px', minHeight: 38, textAlign: 'center' }} />;
}

export default function Config() {
  const { org, session, podeConfigurar, recarregarOrgs, recarregar, metas: metasCtx, jogadores } = useApp();
  const [regras, setRegras] = useState<Regras | null>(null);
  const [metas, setMetas] = useState<Meta[]>([]);
  const [info, setInfo] = useState({ nome: '', linha_nome: '', tag: '' });
  const [membros, setMembros] = useState<Membro[]>([]);
  const [convites, setConvites] = useState<Convite[]>([]);
  const [reais, setReais] = useState<ReturnType<typeof mediasReaisPorFuncao>>({});
  const [acerto, setAcerto] = useState<{ campos: number; corrigidos: number; leituras: number; falhas: number } | null>(null);
  const [msg, setMsg] = useState<{ tipo: 'ok' | 'erro'; texto: string } | null>(null);
  const mesPassado = somarMes(mesAtual(), -1);

  const carregar = useCallback(async () => {
    if (!org) return;
    setRegras(structuredClone(org.regras));
    setMetas(structuredClone(metasCtx));
    setInfo({ nome: org.nome, linha_nome: org.linha_nome, tag: org.tag || '' });
    if (org.papel === 'jogador') return;
    const [m, c, l, e] = await Promise.all([
      supabase.from('membros').select('usuario_id, papel, email').eq('org_id', org.id),
      supabase.from('convites').select('token, papel, expira_em, usado_por, jogador_id').eq('org_id', org.id).order('criado_em', { ascending: false }).limit(20),
      supabase.from('leituras_ia').select('ok').eq('org_id', org.id).gte('em', new Date(Date.now() - 60 * 864e5).toISOString()),
      supabase.from('estatisticas_queda').select('confianca').eq('org_id', org.id).eq('confianca->>_ia', 'true').limit(5000),
    ]);
    setMembros((m.data as Membro[]) || []);
    setConvites((c.data as Convite[]) || []);
    const linhas = (e.data || []) as { confianca: { _corrigidos?: number } }[];
    setAcerto({ campos: linhas.length * 5, corrigidos: linhas.reduce((s, x) => s + (Number(x.confianca?._corrigidos) || 0), 0), leituras: (l.data || []).length, falhas: (l.data || []).filter((x) => !x.ok).length });
    const d = await carregarDados(org.id, mesPassado, mesAtual(), jogadores, metasCtx, org.regras);
    setReais({ ...mediasReaisPorFuncao(d, mesPassado) });
  }, [org, metasCtx]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { carregar(); }, [carregar]);

  async function salvarTudo() {
    if (!org || !regras) return;
    setMsg(null);
    for (const m of metas) if (!(m.base <= m.meta && m.meta <= m.destaque)) { setMsg({ tipo: 'erro', texto: `${NOMES_FUNCAO[m.funcao]} · ${NOMES_CRITERIO[m.criterio]}: Base ≤ Meta ≤ Destaque.` }); return; }
    const f = regras.resultado_faixas;
    if (!(f.base <= f.meta && f.meta <= f.destaque)) { setMsg({ tipo: 'erro', texto: 'Faixas de nota: Base ≤ Meta ≤ Destaque.' }); return; }
    const p = regras.pesos;
    if (p.desempenho + p.presenca + p.divulgacao + p.postura !== 100) { setMsg({ tipo: 'erro', texto: 'Os pesos precisam somar 100.' }); return; }
    const { error: e1 } = await supabase.from('organizacoes').update({ nome: info.nome.trim(), linha_nome: info.linha_nome.trim(), tag: info.tag.trim() || null, regras }).eq('id', org.id);
    const { error: e2 } = await supabase.from('metas').upsert(metas.map((m) => ({ ...m, org_id: org.id })), { onConflict: 'org_id,funcao,criterio' });
    if (e1 || e2) { setMsg({ tipo: 'erro', texto: msgErro(e1 || e2) }); return; }
    setMsg({ tipo: 'ok', texto: 'Configurações salvas.' });
    await recarregarOrgs(); await recarregar();
  }

  async function convidar(papel: 'capitao' | 'jogador') {
    const { data, error } = await supabase.from('convites').insert({ org_id: org!.id, papel }).select('token').single();
    if (error) { setMsg({ tipo: 'erro', texto: msgErro(error) }); return; }
    try { await navigator.clipboard.writeText(linkConvite(data.token)); setMsg({ tipo: 'ok', texto: 'Link do convite copiado. Mande para a pessoa.' }); } catch { /* fica na lista */ }
    carregar();
  }
  async function remover(m: Membro) {
    if (!confirm(`Remover ${m.email || 'este membro'} da organização?`)) return;
    const { error } = await supabase.from('membros').delete().eq('org_id', org!.id).eq('usuario_id', m.usuario_id);
    if (error) setMsg({ tipo: 'erro', texto: msgErro(error) }); else carregar();
  }
  async function apagarConvite(t: string) {
    await supabase.from('convites').delete().eq('token', t);
    carregar();
  }

  const setR = (f: (r: Regras) => void) => setRegras((r) => { const x = structuredClone(r!); f(x); return x; });
  const setM = (fn: Funcao, cr: Criterio, k: 'base' | 'meta' | 'destaque', v: number) => setMetas((ms) => ms.map((m) => (m.funcao === fn && m.criterio === cr ? { ...m, [k]: v } : m)));
  const so = !podeConfigurar;

  return (
    <>
      <Topo titulo={podeConfigurar ? 'Configurações' : 'Conta'} />
      <div className="card entre">
        <div className="cresce"><div className="small muted">Conectado como</div><div className="corta">{session?.user.email}</div><div className="small muted">{org ? PAPEL[org.papel] + ' em ' + org.nome : ''}</div></div>
        <button onClick={() => supabase.auth.signOut()}><Icone nome="sair" />Sair</button>
      </div>
      {msg && <div className={msg.tipo} style={{ marginBottom: 12 }}>{msg.texto}</div>}
      {org?.papel === 'jogador' || !regras ? null : (
        <>
          {acerto && (
            <div className="card">
              <h2>Leitura automática</h2>
              <div className="grade3">
                <div className="tile"><div className="v">{acerto.campos ? Math.round((1 - acerto.corrigidos / acerto.campos) * 100) + '%' : '—'}</div><div className="r">números certos sem correção</div></div>
                <div className="tile"><div className="v">{acerto.leituras}</div><div className="r">prints lidos (60 dias)</div></div>
                <div className="tile"><div className="v">{acerto.falhas}</div><div className="r">leituras que falharam</div></div>
              </div>
              <p className="small muted" style={{ marginTop: 8 }}>Meta do teste: 90% ou mais sem correção.</p>
            </div>
          )}

          <div className="card">
            <h2>Equipe</h2>
            <ul className="lista">
              {membros.map((m) => (
                <li key={m.usuario_id} className="entre">
                  <div className="cresce"><div className="corta">{m.email || m.usuario_id.slice(0, 8)}</div><div className="small muted">{PAPEL[m.papel]}</div></div>
                  {podeConfigurar && m.papel !== 'dono' && <button className="btn-icone btn-perigo" aria-label="Remover" onClick={() => remover(m)}><Icone nome="lixo" /></button>}
                </li>
              ))}
            </ul>
            {podeConfigurar && <button className="btn-prim btn-bloco" style={{ marginTop: 8 }} onClick={() => convidar('capitao')}><Icone nome="link" />Convidar capitão</button>}
            {convites.filter((c) => !c.usado_por && new Date(c.expira_em) > new Date()).map((c) => (
              <div key={c.token} className="linha" style={{ marginTop: 8 }}>
                <input readOnly value={linkConvite(c.token)} aria-label={'Convite de ' + c.papel} onFocus={(e) => e.target.select()} />
                <span className="chip">{PAPEL[c.papel as 'capitao']}{c.jogador_id ? ' · ' + (jogadores.find((j) => j.id === c.jogador_id)?.nick || '') : ''}</span>
                {(podeConfigurar || c.papel === 'jogador') && <button className="btn-icone" aria-label="Cancelar convite" onClick={() => apagarConvite(c.token)}><Icone nome="x" /></button>}
              </div>
            ))}
            <p className="small muted" style={{ marginTop: 8 }}>O link vale por 7 dias e para uma pessoa. Para dar acesso a um jogador (fase 2), abra a ficha dele.</p>
          </div>

          <fieldset disabled={so} style={{ border: 0, padding: 0, margin: 0 }}>
            <div className="card">
              <h2>Organização</h2>
              <div className="campo"><label htmlFor="cn">Nome</label><input id="cn" value={info.nome} onChange={(e) => setInfo({ ...info, nome: e.target.value })} /></div>
              <div className="grade2">
                <div className="campo"><label htmlFor="cl">Line</label><input id="cl" value={info.linha_nome} onChange={(e) => setInfo({ ...info, linha_nome: e.target.value })} /></div>
                <div className="campo"><label htmlFor="ct">Tag nos nicks</label><input id="ct" maxLength={12} value={info.tag} onChange={(e) => setInfo({ ...info, tag: e.target.value })} /></div>
              </div>
              <div className="linha"><input id="dl" type="checkbox" checked={regras.dono_pode_lancar} onChange={(e) => setR((r) => { r.dono_pode_lancar = e.target.checked; })} /><label htmlFor="dl" style={{ margin: 0 }}>O dono também pode lançar números (normalmente só lê)</label></div>
            </div>

            <div className="card">
              <h2>Metas por função</h2>
              <p className="small muted">Média por queda no mês. “Real” = média da line em {mesPassado.slice(5)}/{mesPassado.slice(0, 4)}, para ajustar as metas.</p>
              {(['rush', 'suporte', 'granadeiro'] as Funcao[]).map((fn) => (
                <div key={fn} style={{ marginTop: 10 }}>
                  <h3>{NOMES_FUNCAO[fn]}</h3>
                  <table className="tab">
                    <thead><tr><th>Critério</th><th>Base</th><th>Meta</th><th>Destaque</th><th>Real</th></tr></thead>
                    <tbody>
                      {metas.filter((m) => m.funcao === fn).sort((a, b) => a.ordem - b.ordem).map((m) => (
                        <tr key={m.criterio}>
                          <td className="small">{NOMES_CRITERIO[m.criterio]}{m.criterio === 'utilitario' ? ' (1–5)' : ''}</td>
                          {(['base', 'meta', 'destaque'] as const).map((k) => <td key={k} style={{ width: '20%' }}><Num rotulo={`${k} de ${NOMES_CRITERIO[m.criterio]} (${NOMES_FUNCAO[fn]})`} valor={m[k]} onChange={(v) => setM(fn, m.criterio, k, v)} /></td>)}
                          <td className="small num muted">{reais[fn]?.[m.criterio] ?? '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ))}
            </div>

            <div className="card">
              <h2>Nota de 0 a 100</h2>
              <h3>Pesos (somam 100)</h3>
              <div className="grade2">
                {(['desempenho', 'presenca', 'divulgacao', 'postura'] as const).map((k) => (
                  <div key={k} className="campo"><label>{{ desempenho: 'Desempenho', presenca: 'Presença', divulgacao: 'Divulgação', postura: 'Postura' }[k]}</label>
                    <Num rotulo={'Peso ' + k} passo="1" valor={regras.pesos[k]} onChange={(v) => setR((r) => { r.pesos[k] = v; })} /></div>
                ))}
              </div>
              <h3>Quanto vale cada nível do critério (%)</h3>
              <div className="grade3">
                {(['destaque', 'meta', 'base'] as const).map((k) => (
                  <div key={k} className="campo"><label>{{ destaque: 'Destaque', meta: 'Meta', base: 'Base' }[k]}</label><Num rotulo={'Nível ' + k} passo="1" valor={regras.niveis[k]} onChange={(v) => setR((r) => { r.niveis[k] = v; })} /></div>
                ))}
              </div>
              <div className="linha campo"><input id="tc" type="checkbox" checked={regras.tolerancia_capitao.ativa} onChange={(e) => setR((r) => { r.tolerancia_capitao.ativa = e.target.checked; })} />
                <label htmlFor="tc" style={{ margin: 0 }}>Capitão com uma faixa de tolerância (Meta = Destaque, Base = Meta, {Math.round(regras.tolerancia_capitao.fracao_base * 100)}% da Base = Base)</label></div>
              <div className="campo"><label>Fração da Base que conta como Base para o capitão (%)</label>
                <Num rotulo="Fração da base" passo="1" valor={Math.round(regras.tolerancia_capitao.fracao_base * 100)} onChange={(v) => setR((r) => { r.tolerancia_capitao.fracao_base = v / 100; })} /></div>
              <div className="linha campo"><input id="it" type="checkbox" checked={regras.inclui_treinos_no_desempenho} onChange={(e) => setR((r) => { r.inclui_treinos_no_desempenho = e.target.checked; })} />
                <label htmlFor="it" style={{ margin: 0 }}>Quedas de treino contam no desempenho (desmarcado: só campeonatos)</label></div>
              <h3>Resultado (nota mínima)</h3>
              <div className="grade3">
                {(['destaque', 'meta', 'base'] as const).map((k) => (
                  <div key={k} className="campo"><label>{{ destaque: 'Destaque', meta: 'Meta', base: 'Base' }[k]}</label><Num rotulo={'Faixa ' + k} passo="1" valor={regras.resultado_faixas[k]} onChange={(v) => setR((r) => { r.resultado_faixas[k] = v; })} /></div>
                ))}
              </div>
              <p className="small muted">Abaixo da Base: Plano de Recuperação.</p>
            </div>

            <div className="card">
              <h2>Presença e divulgação</h2>
              <h3>Faixas de presença</h3>
              {regras.presenca_faixas.map((f, i) => (
                <div key={i} className="grade2">
                  <div className="campo"><label>A partir de (%)</label><Num rotulo={'Presença mínima ' + (i + 1)} passo="1" valor={f.min} onChange={(v) => setR((r) => { r.presenca_faixas[i].min = v; })} /></div>
                  <div className="campo"><label>Pontos</label><Num rotulo={'Pontos ' + (i + 1)} passo="1" valor={f.pontos} onChange={(v) => setR((r) => { r.presenca_faixas[i].pontos = v; })} /></div>
                </div>
              ))}
              <p className="small muted">Abaixo da menor faixa: 0 ponto.</p>
              <div className="campo"><label>Atrasos que valem 1 falta</label><Num rotulo="Atrasos por falta" passo="1" valor={regras.atrasos_por_falta} onChange={(v) => setR((r) => { r.atrasos_por_falta = v; })} /></div>
              <div className="linha campo"><input id="fa" type="checkbox" checked={regras.falta_avisada_conta} onChange={(e) => setR((r) => { r.falta_avisada_conta = e.target.checked; })} /><label htmlFor="fa" style={{ margin: 0 }}>Falta avisada conta como falta</label></div>
              <h3>Divulgação cobrada em</h3>
              {(['campeonato', 'treino'] as const).map((t) => (
                <div key={t} className="linha campo"><input id={'dv' + t} type="checkbox" checked={regras.divulgacao_em.includes(t)}
                  onChange={(e) => setR((r) => { r.divulgacao_em = e.target.checked ? [...new Set([...r.divulgacao_em, t])] : r.divulgacao_em.filter((x) => x !== t); })} />
                  <label htmlFor={'dv' + t} style={{ margin: 0 }}>{t === 'campeonato' ? 'Campeonatos' : 'Treinos'} (story antes + resultado em 24 h)</label></div>
              ))}
            </div>
          </fieldset>

          {podeConfigurar && (
            <div className="linha" style={{ marginBottom: 16 }}>
              <button className="btn-txt" onClick={() => { if (confirm('Voltar todas as regras de nota aos valores iniciais? (as metas não mudam)')) setRegras({ ...structuredClone(REGRAS_PADRAO), dono_pode_lancar: regras.dono_pode_lancar }); }}>Valores iniciais</button>
              <div className="cresce" />
              <button className="btn-prim" onClick={salvarTudo}>Salvar configurações</button>
            </div>
          )}
        </>
      )}
    </>
  );
}
