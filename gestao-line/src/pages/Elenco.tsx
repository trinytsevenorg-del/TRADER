import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useApp } from '../lib/app';
import { chamarFuncao, msgErro, supabase } from '../lib/supabase';
import { NOMES_FUNCAO, type Funcao, type Jogador } from '../lib/nota';
import { Icone, Modal, Topo } from '../components/ui';

type Form = { id?: string; nick: string; ff_id: string; funcao: Funcao; capitao: boolean; ativo: boolean; apelidos: string };
const novo = (): Form => ({ nick: '', ff_id: '', funcao: 'rush', capitao: false, ativo: true, apelidos: '' });

export default function Elenco() {
  const { org, jogadores, recarregar, podeLancar } = useApp();
  const [form, setForm] = useState<Form | null>(null);
  const [erro, setErro] = useState('');
  const [salvando, setSalvando] = useState(false);
  const [consulta, setConsulta] = useState('');
  const [verInativos, setVerInativos] = useState(false);

  const abrir = (j?: Jogador) => {
    setErro(''); setConsulta('');
    setForm(j ? { id: j.id, nick: j.nick, ff_id: j.ff_id || '', funcao: j.funcao, capitao: j.capitao, ativo: j.ativo, apelidos: (j.apelidos_leitura || []).join('\n') } : novo());
  };

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!form || !org) return;
    setSalvando(true); setErro('');
    const linha = {
      nick: form.nick.trim(), ff_id: form.ff_id.trim() || null, funcao: form.funcao, capitao: form.capitao, ativo: form.ativo,
      apelidos_leitura: [...new Set(form.apelidos.split('\n').map((x) => x.trim()).filter(Boolean))],
    };
    const { error } = form.id
      ? await supabase.from('jogadores').update(linha).eq('id', form.id)
      : await supabase.from('jogadores').insert({ ...linha, org_id: org.id });
    setSalvando(false);
    if (error) { setErro(/ff_id/.test(error.message) ? 'ID do Free Fire: só números (5 a 15 dígitos).' : msgErro(error)); return; }
    setForm(null);
    recarregar();
  }

  async function consultar() {
    if (!form?.ff_id || !org) return;
    setConsulta('Consultando…');
    try {
      const r = await chamarFuncao<{ resumo?: { nickname: string | null; nivel: number | null }; indisponivel?: boolean }>('perfil-ff', { org_id: org.id, ff_id: form.ff_id.trim() });
      setConsulta(r.resumo?.nickname ? `No jogo: ${r.resumo.nickname}${r.resumo.nivel ? ' · nível ' + r.resumo.nivel : ''}` : 'Estatísticas indisponíveis agora.');
    } catch (e) {
      setConsulta(msgErro(e));
    }
  }

  const lista = jogadores.filter((j) => verInativos || j.ativo);
  const inativos = jogadores.filter((j) => !j.ativo).length;

  return (
    <>
      <Topo titulo="Elenco" direita={podeLancar && <button className="btn-prim" onClick={() => abrir()}><Icone nome="mais" />Jogador</button>} />
      {!lista.length && <div className="card vazio">Nenhum jogador cadastrado.{podeLancar ? ' Toque em “Jogador” para começar.' : ''}</div>}
      {!!lista.length && (
        <ul className="lista card" style={{ padding: '0 14px' }}>
          {lista.map((j) => (
            <li key={j.id} className="linha">
              <Link to={'/jogador/' + j.id} className="cresce" style={{ color: 'inherit' }}>
                <div className="linha" style={{ gap: 6 }}>
                  <strong className="corta">{j.nick}</strong>
                  {j.capitao && <span className="chip">Capitão</span>}
                  {!j.ativo && <span className="chip">Inativo</span>}
                </div>
                <div className="small muted">{NOMES_FUNCAO[j.funcao]}{j.ff_id ? ' · ID ' + j.ff_id : ''}{j.apelidos_leitura?.length ? ' · ' + j.apelidos_leitura.length + ' apelido(s) de leitura' : ''}</div>
              </Link>
              {podeLancar && <button className="btn-icone" aria-label={'Editar ' + j.nick} onClick={() => abrir(j)}><Icone nome="lapis" /></button>}
            </li>
          ))}
        </ul>
      )}
      {inativos > 0 && <button className="btn-txt" onClick={() => setVerInativos(!verInativos)}>{verInativos ? 'Esconder' : 'Mostrar'} inativos ({inativos})</button>}

      <Modal aberto={!!form} fechar={() => setForm(null)} titulo={form?.id ? 'Editar jogador' : 'Novo jogador'}>
        {form && (
          <form onSubmit={salvar}>
            <div className="campo"><label htmlFor="nick">Nick</label><input id="nick" required maxLength={40} value={form.nick} onChange={(e) => setForm({ ...form, nick: e.target.value })} /></div>
            <div className="campo">
              <label htmlFor="ff">ID do Free Fire</label>
              <div className="linha">
                <input id="ff" inputMode="numeric" pattern="[0-9]{5,15}" value={form.ff_id} onChange={(e) => setForm({ ...form, ff_id: e.target.value.replace(/\D/g, '') })} />
                <button type="button" onClick={consultar} disabled={!form.ff_id}>Consultar</button>
              </div>
              {consulta && <div className="small sec" style={{ marginTop: 4 }}>{consulta}</div>}
            </div>
            <div className="campo">
              <label>Função</label>
              <div className="seg">
                {(['rush', 'suporte', 'granadeiro'] as Funcao[]).map((f) => (
                  <button type="button" key={f} className={form.funcao === f ? 'ativo' : ''} onClick={() => setForm({ ...form, funcao: f })}>{NOMES_FUNCAO[f]}</button>
                ))}
              </div>
            </div>
            <div className="campo linha"><input id="cap" type="checkbox" checked={form.capitao} onChange={(e) => setForm({ ...form, capitao: e.target.checked })} /><label htmlFor="cap" style={{ margin: 0 }}>Capitão da line (tem uma faixa de tolerância nas metas)</label></div>
            <div className="campo linha"><input id="atv" type="checkbox" checked={form.ativo} onChange={(e) => setForm({ ...form, ativo: e.target.checked })} /><label htmlFor="atv" style={{ margin: 0 }}>Ativo (entra no ranking)</label></div>
            <div className="campo">
              <label htmlFor="ap">Apelidos de leitura (um por linha)</label>
              <textarea id="ap" rows={3} value={form.apelidos} onChange={(e) => setForm({ ...form, apelidos: e.target.value })} placeholder="Formas como o nick já apareceu nos prints" />
              <div className="small muted">São preenchidos sozinhos quando você responde “Quem é este?” na conferência.</div>
            </div>
            {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
            <button className="btn-prim btn-bloco" disabled={salvando}>{salvando ? 'Salvando…' : 'Salvar'}</button>
          </form>
        )}
      </Modal>
    </>
  );
}
