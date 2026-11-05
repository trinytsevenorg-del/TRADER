import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useApp } from '../lib/app';
import { chamarFuncao, msgErro, supabase } from '../lib/supabase';
import { comprimir, hashArquivo, paraBase64 } from '../lib/imagem';
import { guardarPrint, lerPrint } from '../lib/prints-db';
import { associar } from '../lib/nicks';
import type { Estatistica, Queda } from '../lib/nota';
import { CAMPOS, CartaoRascunho, linhaVazia, pendenciasDoRascunho, type Campo, type Linha, type Rascunho } from '../components/Conferir';
import { LancamentoEvento } from '../components/LancamentoEvento';
import { Carregando, Icone, Modal, Topo } from '../components/ui';
import { dataBR } from './Agenda';

type Ev = { id: string; org_id: string; tipo: 'treino' | 'campeonato'; nome: string; data: string; quedas_previstas: number | null };
type JogadorLido = { nick_seen: string; confianca: Record<string, string> } & Record<Campo, number | null>;
type Lido = { colocacao: number | null; colocacao_confianca: 'alta' | 'baixa'; jogadores: JogadorLido[] };

const chave = () => Math.random().toString(36).slice(2);
const SIMULTANEAS = 2;

export default function Evento() {
  const { id = '' } = useParams();
  const nav = useNavigate();
  const { org, jogadores, podeLancar, recarregar } = useApp();
  const [ev, setEv] = useState<Ev | null | undefined>(undefined);
  const [quedas, setQuedas] = useState<Queda[]>([]);
  const [est, setEst] = useState<Estatistica[]>([]);
  const [rascunhos, setRascunhos] = useState<Rascunho[]>([]);
  const [progresso, setProgresso] = useState<{ feitos: number; total: number } | null>(null);
  const [thumbs, setThumbs] = useState<Record<string, string>>({});
  const [editarEv, setEditarEv] = useState(false);
  const [erro, setErro] = useState('');
  const arquivo = useRef<HTMLInputElement>(null);
  const ref = useRef<Rascunho[]>([]);
  ref.current = rascunhos;

  const carregar = useCallback(async () => {
    const { data } = await supabase.from('eventos').select('id, org_id, tipo, nome, data, quedas_previstas').eq('id', id).maybeSingle();
    setEv((data as Ev) || null);
    const { data: qs } = await supabase.from('quedas').select('id, evento_id, numero, colocacao, hash_print').eq('evento_id', id).order('numero');
    setQuedas((qs as Queda[]) || []);
    const ids = (qs || []).map((q) => q.id);
    const { data: es } = ids.length
      ? await supabase.from('estatisticas_queda').select('queda_id, jogador_id, abates, derrubados, dano, assistencias, revividos, print_enviado, corrigido, confianca').in('queda_id', ids)
      : { data: [] };
    setEst((es as Estatistica[]) || []);
  }, [id]);
  useEffect(() => { carregar(); }, [carregar]);

  // miniaturas dos prints salvos neste celular
  useEffect(() => {
    let vivo = true;
    (async () => {
      const out: Record<string, string> = {};
      for (const q of quedas) {
        if (!q.hash_print || thumbs[q.hash_print]) continue;
        const p = await lerPrint(q.hash_print);
        if (p) out[q.hash_print] = URL.createObjectURL(p.blob);
      }
      if (vivo && Object.keys(out).length) setThumbs((t) => ({ ...t, ...out }));
    })();
    return () => { vivo = false; };
  }, [quedas]); // eslint-disable-line react-hooks/exhaustive-deps

  const proximoNumero = () => Math.max(0, ...quedas.map((q) => q.numero), ...ref.current.map((r) => r.numero)) + 1;
  const atualizar = (k: string, f: (r: Rascunho) => Rascunho) => setRascunhos((rs) => rs.map((r) => (r.key === k ? f(r) : r)));

  function montarLinhas(lidos: JogadorLido[]): Linha[] {
    const ativos = jogadores.filter((j) => j.ativo).map((j) => ({ id: j.id, nick: j.nick, apelidos_leitura: j.apelidos_leitura || [] }));
    const ids = associar(lidos.map((l) => l.nick_seen), ativos, org?.tag);
    return lidos.map((l, i) => {
      const valores = Object.fromEntries(CAMPOS.map((c) => [c, l[c]])) as Record<Campo, number | null>;
      const duvida = Object.fromEntries([...CAMPOS, 'nick'].map((c) => [c, l.confianca?.[c] === 'baixa'])) as Linha['duvida'];
      return { key: chave(), jogador_id: ids[i], nick_seen: l.nick_seen, valores, lido: { ...valores }, duvida, duvidaIa: CAMPOS.filter((c) => duvida[c]) };
    });
  }

  async function processar(files: File[]) {
    if (!org || !ev) return;
    setErro('');
    // cada arquivo vira uma queda, na ordem escolhida
    const itens = files.map((f) => ({ f, r: { key: chave(), numero: 0, colocacao: null, colocacao_duvida: false, status: 'lendo', sem_print: false, linhas: [] } as Rascunho }));
    let n = proximoNumero();
    for (const it of itens) it.r.numero = n++;
    setRascunhos((rs) => [...rs, ...itens.map((i) => i.r)]);
    setProgresso({ feitos: 0, total: itens.length });
    const hashesDoLote = new Set<string>();

    const um = async ({ f, r }: { f: File; r: Rascunho }) => {
      try {
        const hash = await hashArquivo(f);
        const blob = await comprimir(f);
        const thumb = URL.createObjectURL(blob);
        // print repetido: no lote, nos rascunhos abertos ou já salvo em qualquer evento da organização
        const { data: ja } = await supabase.from('quedas').select('numero, eventos(nome, data)').eq('org_id', org.id).eq('hash_print', hash).maybeSingle();
        const noLote = hashesDoLote.has(hash) || ref.current.some((x) => x.key !== r.key && x.hash === hash);
        hashesDoLote.add(hash);
        if (ja || noLote) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const e = ja && (ja as any).eventos;
          atualizar(r.key, (x) => ({ ...x, status: 'repetido', hash, thumb, aviso: ja ? `Já enviado na queda ${ja.numero} de ${e?.nome || 'outro evento'}${e?.data ? ' (' + dataBR(e.data) + ')' : ''}.` : 'Você escolheu o mesmo print duas vezes.' }));
          return;
        }
        await guardarPrint({ hash, blob, evento_id: ev.id, criado_em: Date.now() });
        atualizar(r.key, (x) => ({ ...x, hash, thumb }));
        try {
          const lido = await chamarFuncao<Lido>('ler-print', { org_id: org.id, imagem: await paraBase64(blob), media: 'image/jpeg' });
          const linhas = montarLinhas(lido.jogadores || []);
          atualizar(r.key, (x) => ({ ...x, status: 'pronto', colocacao: lido.colocacao, colocacao_duvida: lido.colocacao_confianca === 'baixa', linhas: linhas.length ? linhas : jogadores.filter((j) => j.ativo).slice(0, 4).map((j) => linhaVazia(j.id)), aviso: linhas.length ? undefined : 'Nenhum jogador lido. Digite os números.' }));
        } catch (e) {
          // leitura falhou: o capitão digita na mesma tela
          atualizar(r.key, (x) => ({ ...x, status: 'pronto', aviso: msgErro(e), linhas: jogadores.filter((j) => j.ativo).slice(0, 4).map((j) => linhaVazia(j.id)) }));
        }
      } catch (e) {
        atualizar(r.key, (x) => ({ ...x, status: 'pronto', aviso: 'Não deu para abrir a imagem: ' + msgErro(e), linhas: [] }));
      } finally {
        setProgresso((p) => (p ? { ...p, feitos: p.feitos + 1 } : p));
      }
    };
    const fila = [...itens];
    await Promise.all(Array.from({ length: Math.min(SIMULTANEAS, fila.length) }, async () => { while (fila.length) await um(fila.shift()!); }));
    setTimeout(() => setProgresso(null), 800);
  }

  function aMao() {
    const ativos = jogadores.filter((j) => j.ativo);
    setRascunhos((rs) => [...rs, { key: chave(), numero: proximoNumero(), colocacao: null, colocacao_duvida: false, status: 'pronto', sem_print: false, linhas: ativos.slice(0, 4).map((j) => linhaVazia(j.id)) }]);
  }

  function editar(q: Queda) {
    if (rascunhos.some((r) => r.queda_id === q.id)) return;
    const linhas: Linha[] = est.filter((s) => s.queda_id === q.id).map((s) => ({
      key: chave(), jogador_id: s.jogador_id, nick_seen: null, lido: null, duvida: {},
      valores: { abates: s.abates, derrubados: s.derrubados, dano: s.dano, assistencias: s.assistencias, revividos: s.revividos },
    }));
    const semPrint = est.some((s) => s.queda_id === q.id && !s.print_enviado);
    setRascunhos((rs) => [...rs, { key: chave(), queda_id: q.id, numero: q.numero, colocacao: q.colocacao, colocacao_duvida: false, hash: q.hash_print || undefined, thumb: q.hash_print ? thumbs[q.hash_print] : undefined, status: 'pronto', sem_print: semPrint, linhas }]);
  }

  async function salvar(r: Rascunho) {
    if (!ev) return false;
    atualizar(r.key, (x) => ({ ...x, salvando: true, aviso: undefined }));
    const validas = r.linhas.filter((l) => !l.ignorar && l.jogador_id);
    const antigas = new Map(est.filter((s) => s.queda_id === r.queda_id).map((s) => [s.jogador_id, s]));
    const linhas = validas.map((l) => {
      const corrigidos = l.lido ? CAMPOS.filter((c) => l.lido![c] !== l.valores[c]).length : 0;
      const antiga = antigas.get(l.jogador_id!);
      const confianca = l.lido
        ? { ...Object.fromEntries((l.duvidaIa || []).map((c) => [c, 'baixa'])), _ia: true, _corrigidos: corrigidos }
        : (antiga?.confianca || {});
      return {
        jogador_id: l.jogador_id, ...Object.fromEntries(CAMPOS.map((c) => [c, l.valores[c] ?? 0])),
        print_enviado: !r.sem_print, confianca, corrigido: l.lido ? corrigidos > 0 : !!antiga?.corrigido,
      };
    });
    const { error } = await supabase.rpc('salvar_queda', { p_evento: ev.id, p_queda: r.queda_id || null, p_numero: r.numero, p_colocacao: r.colocacao, p_hash: r.hash || null, p_linhas: linhas });
    if (error) {
      atualizar(r.key, (x) => ({ ...x, salvando: false, aviso: /quedas_evento_id_numero_key|duplicate key.*numero/.test(error.message) ? 'Já existe uma queda com este número.' : msgErro(error) }));
      return false;
    }
    // "Quem é este?" respondido: o nick lido vira apelido de leitura do jogador
    const novos = validas.filter((l) => l.nick_seen && l.jogador_id);
    let mudou = false;
    for (const l of novos) {
      const j = jogadores.find((x) => x.id === l.jogador_id);
      if (!j) continue;
      const conhecido = [j.nick, ...(j.apelidos_leitura || [])].some((a) => a.trim() === l.nick_seen!.trim());
      const ids = associar([l.nick_seen!], jogadores.filter((x) => x.ativo).map((x) => ({ id: x.id, nick: x.nick, apelidos_leitura: x.apelidos_leitura || [] })), org?.tag);
      if (!conhecido && ids[0] !== j.id) { await supabase.rpc('adicionar_apelido', { p_jogador: j.id, p_apelido: l.nick_seen }); mudou = true; }
    }
    if (mudou) recarregar();
    setRascunhos((rs) => rs.filter((x) => x.key !== r.key));
    await carregar();
    return true;
  }

  async function salvarTodas() {
    for (const r of ref.current.filter((x) => x.status === 'pronto' && !pendenciasDoRascunho(x).length)) await salvar(r);
  }

  async function apagarQueda(q: Queda) {
    if (!confirm(`Apagar a queda ${q.numero}?`)) return;
    const { error } = await supabase.from('quedas').delete().eq('id', q.id);
    if (error) setErro(msgErro(error)); else carregar();
  }

  async function salvarEvento(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const qp = String(f.get('qp') || '');
    const { error } = await supabase.from('eventos').update({ nome: String(f.get('nome')).trim(), data: String(f.get('data')), quedas_previstas: qp ? Number(qp) : null }).eq('id', id);
    if (error) { setErro(msgErro(error)); return; }
    setEditarEv(false); carregar();
  }
  async function apagarEvento() {
    if (!confirm('Apagar este evento com todas as quedas, presenças e divulgações?')) return;
    const { error } = await supabase.from('eventos').delete().eq('id', id);
    if (error) setErro(msgErro(error)); else nav('/agenda', { replace: true });
  }

  if (ev === undefined) return <Carregando />;
  if (!ev) return <><Topo titulo="Evento" voltar={() => nav(-1)} /><div className="card vazio">Evento não encontrado.</div></>;

  const nick = (jid: string) => jogadores.find((j) => j.id === jid)?.nick || '—';
  const prontos = rascunhos.filter((r) => r.status === 'pronto' && !pendenciasDoRascunho(r).length).length;
  const faltam = ev.quedas_previstas ? Math.max(0, ev.quedas_previstas - quedas.length) : 0;

  return (
    <>
      <Topo titulo={ev.nome} voltar={() => nav('/agenda')} direita={podeLancar && <button className="btn-icone" aria-label="Editar evento" onClick={() => setEditarEv(true)}><Icone nome="lapis" /></button>} />
      <p className="sec small" style={{ marginTop: -6 }}>{ev.tipo === 'treino' ? 'Treino' : 'Campeonato'} · {dataBR(ev.data)} · {quedas.length}{ev.quedas_previstas ? '/' + ev.quedas_previstas : ''} queda(s){faltam ? ` · ${faltam} sem print contam zero` : ''}</p>
      {erro && <div className="erro" style={{ marginBottom: 12 }}>{erro}</div>}

      {podeLancar && (
        <div className="card">
          <input ref={arquivo} type="file" accept="image/*" multiple hidden onChange={(e) => { const fs = [...(e.target.files || [])]; e.target.value = ''; if (fs.length) processar(fs); }} />
          <button className="btn-prim btn-bloco" onClick={() => arquivo.current?.click()} disabled={!!progresso}><Icone nome="imagem" />Adicionar queda</button>
          <p className="small muted" style={{ margin: '8px 0 0' }}>Escolha um ou vários prints da tela de resultado. Cada print vira uma queda.</p>
          <button className="btn-txt" onClick={aMao}>Lançar à mão</button>
          {progresso && (
            <div style={{ marginTop: 8 }}>
              <div className="entre small"><span>Lendo prints…</span><span className="num">{progresso.feitos}/{progresso.total}</span></div>
              <div className="progresso" style={{ marginTop: 4 }}><i style={{ width: (progresso.feitos / progresso.total) * 100 + '%' }} /></div>
            </div>
          )}
        </div>
      )}

      {rascunhos.length > 0 && (
        <>
          <div className="entre" style={{ margin: '16px 0 8px' }}>
            <h2 style={{ margin: 0 }}>Conferir números</h2>
            {prontos > 1 && <button className="btn-prim btn-peq" onClick={salvarTodas}>Confirmar todas ({prontos})</button>}
          </div>
          <p className="small muted">Amarelo = a leitura teve dúvida. Toque no número para corrigir.</p>
          {[...rascunhos].sort((a, b) => a.numero - b.numero).map((r) => (
            <CartaoRascunho key={r.key} r={r} jogadores={jogadores} podeSalvar={podeLancar}
              onChange={(n) => atualizar(r.key, () => n)} onSalvar={() => salvar(r)} onDescartar={() => setRascunhos((rs) => rs.filter((x) => x.key !== r.key))} />
          ))}
        </>
      )}

      <h2 style={{ margin: '16px 0 8px' }}>Quedas</h2>
      {!quedas.length ? <div className="card vazio">Nenhuma queda lançada.</div> : quedas.map((q) => {
        const linhas = est.filter((s) => s.queda_id === q.id);
        const semPrint = linhas.some((s) => !s.print_enviado);
        return (
          <div key={q.id} className="card">
            <div className="linha" style={{ marginBottom: 8 }}>
              {q.hash_print && thumbs[q.hash_print] && <a href={thumbs[q.hash_print]} target="_blank" rel="noreferrer"><img src={thumbs[q.hash_print]} className="thumb" alt={'Print da queda ' + q.numero} /></a>}
              <div className="cresce">
                <strong>Queda {q.numero}</strong> <span className="sec">· {q.colocacao ? q.colocacao + 'º lugar' : 'sem colocação'}</span>
                <div className="small muted">{semPrint ? 'Sem print (conta zero)' : q.hash_print ? (thumbs[q.hash_print] ? 'Print neste celular' : 'Print no celular de quem enviou') : 'Lançada à mão'}</div>
              </div>
              {podeLancar && <>
                <button className="btn-icone" aria-label={'Editar queda ' + q.numero} onClick={() => editar(q)}><Icone nome="lapis" /></button>
                <button className="btn-icone btn-perigo" aria-label={'Apagar queda ' + q.numero} onClick={() => apagarQueda(q)}><Icone nome="lixo" /></button>
              </>}
            </div>
            <div className="rolar-x">
              <table className="tab num">
                <thead><tr><th>Jogador</th><th>Abat.</th><th>Derr.</th><th>Dano</th><th>Assist.</th><th>Reviv.</th></tr></thead>
                <tbody>
                  {linhas.map((s) => (
                    <tr key={s.jogador_id}><td className="corta" style={{ maxWidth: 110 }}>{nick(s.jogador_id)}</td><td>{s.abates}</td><td>{s.derrubados}</td><td>{s.dano}</td><td>{s.assistencias}</td><td>{s.revividos}</td></tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}

      <LancamentoEvento evento={ev} />

      <Modal aberto={editarEv} fechar={() => setEditarEv(false)} titulo="Editar evento">
        <form onSubmit={salvarEvento}>
          <div className="campo"><label htmlFor="en">Nome</label><input id="en" name="nome" required maxLength={80} defaultValue={ev.nome} /></div>
          <div className="grade2">
            <div className="campo"><label htmlFor="ed">Data</label><input id="ed" name="data" type="date" required defaultValue={ev.data} /></div>
            <div className="campo"><label htmlFor="eq">Quedas previstas</label><input id="eq" name="qp" inputMode="numeric" pattern="[0-9]{0,2}" defaultValue={ev.quedas_previstas ?? ''} /></div>
          </div>
          <button className="btn-prim btn-bloco">Salvar</button>
          <button type="button" className="btn-txt btn-perigo btn-bloco" style={{ marginTop: 8 }} onClick={apagarEvento}>Apagar evento</button>
        </form>
      </Modal>
    </>
  );
}
