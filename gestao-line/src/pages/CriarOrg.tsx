import { useState } from 'react';
import { useApp } from '../lib/app';
import { msgErro, supabase } from '../lib/supabase';

export default function CriarOrg() {
  const { recarregarOrgs, trocarOrg, session } = useApp();
  const [nome, setNome] = useState('');
  const [linha, setLinha] = useState('');
  const [tag, setTag] = useState('');
  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function criar(e: React.FormEvent) {
    e.preventDefault();
    setEnviando(true); setErro('');
    const { data, error } = await supabase.rpc('criar_organizacao', { p_nome: nome, p_linha: linha, p_tag: tag });
    setEnviando(false);
    if (error) { setErro(msgErro(error)); return; }
    trocarOrg(data as string);
    await recarregarOrgs();
  }

  return (
    <div className="centro">
      <form className="caixa" onSubmit={criar}>
        <h1>Criar organização</h1>
        <p className="muted">Você será o dono: vê tudo, ajusta metas e regras e convida o capitão. Recebeu um convite? Abra o link dele.</p>
        <div className="campo"><label htmlFor="n">Nome da organização</label><input id="n" required maxLength={80} value={nome} onChange={(e) => setNome(e.target.value)} /></div>
        <div className="campo"><label htmlFor="l">Nome da line</label><input id="l" placeholder="Line principal" maxLength={80} value={linha} onChange={(e) => setLinha(e.target.value)} /></div>
        <div className="campo"><label htmlFor="t">Tag nos nicks (opcional)</label><input id="t" placeholder="Ex.: RDN" maxLength={12} value={tag} onChange={(e) => setTag(e.target.value)} /></div>
        {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
        <button className="btn-prim btn-bloco" disabled={enviando}>{enviando ? 'Criando…' : 'Criar'}</button>
        <button type="button" className="btn-txt btn-bloco" style={{ marginTop: 8 }} onClick={() => supabase.auth.signOut()}>Sair ({session?.user.email})</button>
      </form>
    </div>
  );
}
