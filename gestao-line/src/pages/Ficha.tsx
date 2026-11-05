import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useApp } from '../lib/app';
import { carregarDados } from '../lib/dados';
import { chamarFuncao, msgErro, supabase } from '../lib/supabase';
import { calcularJogador, mesAtual, nomeMesCurto, NOMES_FUNCAO, quedasDoJogador, somarMes, type Dados } from '../lib/nota';
import { GraficoCriterios, GraficoLinha } from '../components/graficos';
import { Carregando, FaixaBadge, Icone, MesSeletor, Topo } from '../components/ui';
import { dataBR } from './Agenda';

const MESES_HIST = 6;
type Foto = { data: string; dados_json: { nickname: string | null; nivel: number | null; squad: { partidas: number; vitorias: number; abates: number; kd: number | null } | null } };

export default function Ficha({ idFixo }: { idFixo?: string }) {
  const params = useParams();
  const id = idFixo || params.id || '';
  const nav = useNavigate();
  const { org, jogadores, metas, podeConfigurar } = useApp();
  const [mes, setMes] = useState(mesAtual());
  const [dados, setDados] = useState<Dados | null>(null);
  const [erro, setErro] = useState('');
  const [perfil, setPerfil] = useState<{ fotos: Foto[]; indisponivel?: boolean; sem_id?: boolean } | null>(null);
  const [convite, setConvite] = useState('');
  const jogador = jogadores.find((j) => j.id === id);

  useEffect(() => {
    if (!org || !jogador) return;
    setDados(null); setErro('');
    carregarDados(org.id, somarMes(mes, -(MESES_HIST - 1)), mes, jogadores, metas, org.regras).then(setDados).catch((e) => setErro(msgErro(e)));
  }, [org, mes, jogadores, metas, jogador]);

  useEffect(() => {
    if (!jogador) return;
    setPerfil(null);
    chamarFuncao<{ fotos: Foto[]; indisponivel?: boolean; sem_id?: boolean }>('perfil-ff', { jogador_id: jogador.id })
      .then(setPerfil).catch(() => setPerfil({ fotos: [], indisponivel: true }));
  }, [jogador?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const r = useMemo(() => (dados && jogador ? calcularJogador(dados, jogador, mes) : null), [dados, jogador, mes]);
  const evolucao = useMemo(() => {
    if (!dados || !jogador) return [];
    return Array.from({ length: MESES_HIST }, (_, i) => somarMes(mes, i - (MESES_HIST - 1))).map((m) => {
      const tem = dados.eventos.some((e) => e.data.startsWith(m));
      return { rotulo: nomeMesCurto(m), valor: tem ? calcularJogador(dados, jogador, m).nota : null };
    });
  }, [dados, jogador, mes]);
  const historico = useMemo(() => (dados && jogador ? quedasDoJogador(dados, jogador.id, mes) : []), [dados, jogador, mes]);

  async function gerarConvite() {
    if (!org || !jogador) return;
    const { data, error } = await supabase.from('convites').insert({ org_id: org.id, papel: 'jogador', jogador_id: jogador.id }).select('token').single();
    if (error) { setErro(msgErro(error)); return; }
    const link = window.location.origin + window.location.pathname + '#/convite/' + data.token;
    setConvite(link);
    try { await navigator.clipboard.writeText(link); } catch { /* sem permissão: o link fica na tela */ }
  }

  if (!jogador) return <><Topo titulo="Jogador" voltar={idFixo ? undefined : () => nav(-1)} /><div className="card vazio">Jogador não encontrado.</div></>;
  const R = org!.regras;
  const fotos = (perfil?.fotos || []).filter((f) => f.dados_json?.squad);

  return (
    <>
      <Topo titulo={jogador.nick} voltar={idFixo ? undefined : () => nav(-1)} />
      <p className="sec small" style={{ marginTop: -6 }}>{NOMES_FUNCAO[jogador.funcao]}{jogador.capitao ? ' · Capitão (tolerância de uma faixa)' : ''}{jogador.ff_id ? ' · ID ' + jogador.ff_id : ''}</p>
      <MesSeletor mes={mes} onChange={setMes} />
      {erro && <div className="erro" style={{ marginBottom: 12 }}>{erro}</div>}
      {!r ? <Carregando /> : (
        <>
          <div className="card">
            <div className="entre">
              <div><div className="nota-grande">{r.nota}</div><div className="small muted">de 100 · {r.quedas} queda(s)</div></div>
              <FaixaBadge faixa={r.faixa} />
            </div>
            <div className="grade3" style={{ marginTop: 12 }}>
              <div className="tile"><div className="v">{r.desempenho.pontos}</div><div className="r">Desempenho /{r.desempenho.max}</div></div>
              <div className="tile"><div className="v">{r.comprometimento.pontos}</div><div className="r">Comprometimento /{r.comprometimento.max}</div></div>
              <div className="tile"><div className="v">{r.postura.pontos}</div><div className="r">Postura /{r.postura.max}</div></div>
            </div>
            {r.pendencias.length > 0 && <div className="small" style={{ color: 'var(--warning)', marginTop: 8 }}>Falta: {r.pendencias.join(', ')}</div>}
          </div>

          <div className="card">
            <h2>Nota mês a mês</h2>
            <GraficoLinha pontos={evolucao} min={0} max={100}
              refs={[{ y: R.resultado_faixas.destaque, rotulo: 'Destaque' }, { y: R.resultado_faixas.meta, rotulo: 'Meta' }, { y: R.resultado_faixas.base, rotulo: 'Base' }]} />
          </div>

          <div className="card">
            <h2>Critérios × metas de {NOMES_FUNCAO[jogador.funcao]}</h2>
            <p className="small muted">Média por queda no mês{jogador.capitao ? '. Como capitão, a Meta já conta como Destaque' : ''}.</p>
            <GraficoCriterios criterios={r.desempenho.criterios} />
          </div>

          <div className="card">
            <h2>Comprometimento</h2>
            <div className="grade2">
              <div className="tile">
                <div className="v">{r.presenca.pct === null ? '—' : r.presenca.pct + '%'}</div>
                <div className="r">Presença · {r.presenca.pontos}/{r.presenca.max} pts</div>
              </div>
              <div className="tile">
                <div className="v">{r.divulgacao.feitos}/{r.divulgacao.devidos}</div>
                <div className="r">Posts no prazo · {r.divulgacao.pontos}/{r.divulgacao.max} pts</div>
              </div>
            </div>
            <table className="tab num" style={{ marginTop: 10 }}>
              <tbody>
                <tr><td>Treinos no mês</td><td style={{ textAlign: 'right' }}>{r.presenca.treinos}</td></tr>
                <tr><td>Presente</td><td style={{ textAlign: 'right' }}>{r.presenca.contagem.presente}</td></tr>
                <tr><td>Atrasado ({R.atrasos_por_falta} = 1 falta)</td><td style={{ textAlign: 'right' }}>{r.presenca.contagem.atrasado}</td></tr>
                <tr><td>Falta avisada</td><td style={{ textAlign: 'right' }}>{r.presenca.contagem.falta_avisada}</td></tr>
                <tr><td>Falta sem aviso</td><td style={{ textAlign: 'right' }}>{r.presenca.contagem.falta_sem_aviso}</td></tr>
                <tr><td>Faltas que contam</td><td style={{ textAlign: 'right' }}>{r.presenca.faltasEfetivas}</td></tr>
                <tr><td>Postura (nota do capitão)</td><td style={{ textAlign: 'right' }}>{r.postura.nota ?? '—'}/5</td></tr>
              </tbody>
            </table>
          </div>

          <div className="card">
            <h2>Quedas do mês</h2>
            {!historico.length ? <div className="vazio">Nenhuma queda neste mês.</div> : (
              <div className="rolar-x">
                <table className="tab num">
                  <thead><tr><th>Evento</th><th>Col.</th><th>Abat.</th><th>Derr.</th><th>Dano</th><th>Assist.</th><th>Reviv.</th></tr></thead>
                  <tbody>
                    {historico.map((h, i) => {
                      const zero = !h.est || !h.est.print_enviado;
                      return (
                        <tr key={i} style={zero ? { color: 'var(--text-muted)' } : undefined}>
                          <td className="corta" style={{ maxWidth: 120 }}>{dataBR(h.evento.data)} {h.evento.nome}{h.queda ? ' #' + h.queda.numero : ''}</td>
                          <td>{h.queda?.colocacao ?? '—'}</td>
                          {zero ? <td colSpan={5}>{h.queda ? 'sem print · conta zero' : 'queda não lançada · conta zero'}</td> : <>
                            <td>{h.est!.abates}</td><td>{h.est!.derrubados}</td><td>{h.est!.dano}</td><td>{h.est!.assistencias}</td><td>{h.est!.revividos}</td>
                          </>}
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      <div className="card">
        <h2>Carreira no Free Fire</h2>
        <p className="small muted">Só informativo: não entra na nota (salas personalizadas provavelmente não contam na carreira).</p>
        {perfil === null ? <div className="small muted">Consultando…</div>
          : perfil.sem_id ? <div className="small muted">Cadastre o ID do Free Fire no Elenco para ver.</div>
          : !fotos.length ? <div className="small muted">Estatísticas indisponíveis.</div>
          : (() => {
            const u = fotos[fotos.length - 1].dados_json;
            return (
              <>
                {perfil.indisponivel && <div className="small muted" style={{ marginBottom: 6 }}>Estatísticas indisponíveis agora. Mostrando a última foto.</div>}
                <div className="small sec" style={{ marginBottom: 8 }}>{u.nickname}{u.nivel ? ' · nível ' + u.nivel : ''} · foto de {dataBR(fotos[fotos.length - 1].data)}</div>
                <div className="grade2">
                  <div className="tile"><div className="v">{u.squad!.partidas}</div><div className="r">Partidas (squad)</div></div>
                  <div className="tile"><div className="v">{u.squad!.vitorias}</div><div className="r">Vitórias</div></div>
                  <div className="tile"><div className="v">{u.squad!.abates}</div><div className="r">Abates</div></div>
                  <div className="tile"><div className="v">{u.squad!.kd ?? '—'}</div><div className="r">K/D</div></div>
                </div>
                {fotos.length > 1 && (
                  <div style={{ marginTop: 12 }}>
                    <h3>K/D semana a semana</h3>
                    <GraficoLinha pontos={fotos.slice(-12).map((f) => ({ rotulo: dataBR(f.data), valor: f.dados_json.squad?.kd ?? null }))} casas={2} />
                  </div>
                )}
              </>
            );
          })()}
      </div>

      {podeConfigurar && !idFixo && (
        <div className="card">
          <h2>Acesso do jogador (fase 2)</h2>
          <p className="small muted">Gera um link para o jogador entrar e ver só a própria nota, gráfico e histórico.</p>
          {!convite ? <button onClick={gerarConvite}><Icone nome="link" />Gerar convite</button> : <><input readOnly value={convite} onFocus={(e) => e.target.select()} /><div className="small muted" style={{ marginTop: 4 }}>Link copiado. Vale por 7 dias e para uma pessoa.</div></>}
        </div>
      )}
    </>
  );
}
