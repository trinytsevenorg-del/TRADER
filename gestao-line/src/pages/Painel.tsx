import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useApp } from '../lib/app';
import { carregarDados } from '../lib/dados';
import { msgErro } from '../lib/supabase';
import { calcularMes, colocacaoMedia, mesAtual, NOMES_CRITERIO, NOMES_FAIXA, NOMES_FUNCAO, type Dados } from '../lib/nota';
import { Barra, Carregando, FaixaBadge, Icone, MesSeletor, Topo } from '../components/ui';

export default function Painel() {
  const { org, jogadores, metas } = useApp();
  const [mes, setMes] = useState(mesAtual());
  const [dados, setDados] = useState<Dados | null>(null);
  const [erro, setErro] = useState('');

  useEffect(() => {
    if (!org) return;
    setDados(null); setErro('');
    carregarDados(org.id, mes, mes, jogadores, metas, org.regras).then(setDados).catch((e) => setErro(msgErro(e)));
  }, [org, mes, jogadores, metas]);

  const ranking = useMemo(() => (dados ? calcularMes(dados, mes) : []), [dados, mes]);
  const col = dados ? colocacaoMedia(dados, mes) : null;
  const eventosMes = dados?.eventos.length || 0;

  function exportar() {
    const cab = ['Posição', 'Jogador', 'Função', 'Capitão', 'Nota', 'Resultado', 'Desempenho', 'Presença', 'Divulgação', 'Postura', 'Quedas',
      ...['abates', 'derrubados', 'dano', 'assistencias', 'revividos', 'utilitario'].map((c) => 'Média ' + NOMES_CRITERIO[c as 'abates']), 'Presença %', 'Pendências'];
    const linhas = ranking.map((r, i) => {
      const med = (c: string) => { const x = r.desempenho.criterios.find((k) => k.criterio === c); return x && x.media !== null ? String(Math.round(x.media * 100) / 100).replace('.', ',') : ''; };
      return [i + 1, r.jogador.nick, NOMES_FUNCAO[r.jogador.funcao], r.jogador.capitao ? 'sim' : '', r.nota, NOMES_FAIXA[r.faixa],
        r.desempenho.pontos, r.presenca.pontos, r.divulgacao.pontos, r.postura.pontos, r.quedas,
        med('abates'), med('derrubados'), med('dano'), med('assistencias'), med('revividos'), med('utilitario'),
        r.presenca.pct ?? '', r.pendencias.join('; ')].map((v) => (typeof v === 'number' ? String(v).replace('.', ',') : v));
    });
    const csv = '﻿' + [cab, ...linhas].map((l) => l.map((v) => '"' + String(v).replace(/"/g, '""') + '"').join(';')).join('\r\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    a.download = `notas-${org?.linha_nome || 'line'}-${mes}.csv`.replace(/\s+/g, '-');
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  return (
    <>
      <Topo titulo="Painel da line" direita={ranking.length > 0 && <button className="btn-icone" aria-label="Exportar relatório (CSV)" title="Exportar relatório" onClick={exportar}><Icone nome="baixar" /></button>} />
      <MesSeletor mes={mes} onChange={setMes} />
      {erro && <div className="erro">{erro}</div>}
      {!dados && !erro ? <Carregando /> : dados && (
        <>
          <div className="grade3" style={{ marginBottom: 12 }}>
            <div className="tile"><div className="v">{col?.media ?? '—'}{col?.media ? 'º' : ''}</div><div className="r">colocação média</div></div>
            <div className="tile"><div className="v">{col?.quedas ?? 0}</div><div className="r">quedas</div></div>
            <div className="tile"><div className="v">{eventosMes}</div><div className="r">eventos</div></div>
          </div>
          {!jogadores.some((j) => j.ativo) ? (
            <div className="card vazio">Cadastre os jogadores no <Link to="/elenco">Elenco</Link> para ver o ranking.</div>
          ) : (
            <div className="card" style={{ padding: '4px 14px' }}>
              <ul className="lista">
                {ranking.map((r, i) => (
                  <li key={r.jogador.id}>
                    <Link to={'/jogador/' + r.jogador.id} className="linha" style={{ color: 'inherit' }}>
                      <span className="rank-pos">{i + 1}</span>
                      <div className="cresce">
                        <div className="entre">
                          <strong className="corta">{r.jogador.nick}</strong>
                          <span className="num" style={{ fontSize: '1.2rem', fontWeight: 700 }}>{r.nota}</span>
                        </div>
                        <div className="entre" style={{ marginTop: 2 }}>
                          <span className="small muted corta">{NOMES_FUNCAO[r.jogador.funcao]}{r.jogador.capitao ? ' · Capitão' : ''} · {r.quedas} queda(s)</span>
                          <FaixaBadge faixa={r.faixa} />
                        </div>
                        <div style={{ marginTop: 6 }}><Barra pct={r.nota} /></div>
                        {r.pendencias.length > 0 && <div className="small" style={{ color: 'var(--warning)', marginTop: 4 }}>Falta: {r.pendencias.join(', ')}</div>}
                      </div>
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          )}
          <p className="small muted">
            Nota = desempenho ({org!.regras.pesos.desempenho}) + comprometimento ({org!.regras.pesos.presenca + org!.regras.pesos.divulgacao}) + postura ({org!.regras.pesos.postura}).
            Destaque ≥ {org!.regras.resultado_faixas.destaque} · Meta ≥ {org!.regras.resultado_faixas.meta} · Base ≥ {org!.regras.resultado_faixas.base} · abaixo: Plano de Recuperação.
          </p>
        </>
      )}
    </>
  );
}
