import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useApp } from '../lib/app';
import { esquecerConvite, guardarConvite, msgErro, supabase } from '../lib/supabase';
import { Carregando } from '../components/ui';
import Login from './Login';

const PAPEL = { dono: 'dono', capitao: 'capitão', jogador: 'jogador' } as const;
type Info = { org: string; linha: string; papel: keyof typeof PAPEL; valido: boolean; jogador: string | null };

export default function Convite() {
  const { token = '' } = useParams();
  const { session, carregando, recarregarOrgs, trocarOrg } = useApp();
  const nav = useNavigate();
  const [info, setInfo] = useState<Info | null | undefined>(undefined);
  const [erro, setErro] = useState('');
  const [aceitando, setAceitando] = useState(false);

  useEffect(() => {
    guardarConvite(token);
    supabase.rpc('ver_convite', { p_token: token }).then(({ data }) => {
      const i = (data as Info) || null;
      if (!i || !i.valido) esquecerConvite();
      setInfo(i);
    });
  }, [token]);

  async function aceitar() {
    setAceitando(true); setErro('');
    const { data, error } = await supabase.rpc('aceitar_convite', { p_token: token });
    setAceitando(false);
    if (error) { esquecerConvite(); setErro(msgErro(error)); return; }
    esquecerConvite();
    await recarregarOrgs();
    trocarOrg(data as string);
    nav('/painel', { replace: true });
  }

  if (info === undefined || carregando) return <Carregando />;
  if (!info) return <div className="centro"><div className="caixa erro">Convite não encontrado. Peça um novo link.</div></div>;
  const texto = `Convite para entrar em ${info.org} · ${info.linha} como ${PAPEL[info.papel]}${info.jogador ? ' (' + info.jogador + ')' : ''}.`;
  if (!info.valido) return <div className="centro"><div className="caixa erro">{texto} Este link já foi usado ou expirou.</div></div>;
  if (!session) return <Login aviso={texto + ' Entre ou crie sua conta para aceitar.'} />;
  return (
    <div className="centro">
      <div className="caixa card">
        <h2>Convite</h2>
        <p>{texto}</p>
        <p className="muted small">Conta: {session.user.email}</p>
        {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
        <button className="btn-prim btn-bloco" onClick={aceitar} disabled={aceitando}>{aceitando ? 'Entrando…' : 'Aceitar convite'}</button>
        <button className="btn-txt btn-bloco" style={{ marginTop: 8 }} onClick={() => { esquecerConvite(); nav('/painel', { replace: true }); }}>Agora não</button>
      </div>
    </div>
  );
}
