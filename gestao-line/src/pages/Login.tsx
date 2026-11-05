import { useState } from 'react';
import { msgErro, supabase, urlRetorno } from '../lib/supabase';

export default function Login({ aviso }: { aviso?: string }) {
  const [modo, setModo] = useState<'senha' | 'link' | 'criar'>('senha');
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [msg, setMsg] = useState<{ tipo: 'ok' | 'erro'; texto: string } | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setEnviando(true); setMsg(null);
    try {
      if (modo === 'senha') {
        const { error } = await supabase.auth.signInWithPassword({ email, password: senha });
        if (error) throw error;
      } else if (modo === 'criar') {
        const { data, error } = await supabase.auth.signUp({ email, password: senha, options: { emailRedirectTo: urlRetorno() } });
        if (error) throw error;
        if (!data.session) setMsg({ tipo: 'ok', texto: 'Conta criada. Abra o link que enviamos para ' + email + ' para confirmar.' });
      } else {
        const { error } = await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: urlRetorno() } });
        if (error) throw error;
        setMsg({ tipo: 'ok', texto: 'Enviamos um link de acesso para ' + email + '. Abra neste mesmo navegador.' });
      }
    } catch (err) {
      setMsg({ tipo: 'erro', texto: msgErro(err) });
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="centro">
      <form className="caixa" onSubmit={enviar}>
        <img src="icon.svg" alt="" className="logo" />
        <h1 style={{ margin: '12px 0 4px' }}>Gestão de Line</h1>
        <p className="muted">Desempenho do contrato: prints, notas e gráficos.</p>
        {aviso && <div className="aviso" style={{ margin: '12px 0' }}>{aviso}</div>}
        <div className="seg" style={{ margin: '16px 0' }}>
          <button type="button" className={modo === 'senha' ? 'ativo' : ''} onClick={() => setModo('senha')}>Entrar</button>
          <button type="button" className={modo === 'link' ? 'ativo' : ''} onClick={() => setModo('link')}>Link mágico</button>
          <button type="button" className={modo === 'criar' ? 'ativo' : ''} onClick={() => setModo('criar')}>Criar conta</button>
        </div>
        <div className="campo">
          <label htmlFor="email">E-mail</label>
          <input id="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        {modo !== 'link' && (
          <div className="campo">
            <label htmlFor="senha">Senha</label>
            <input id="senha" type="password" minLength={6} autoComplete={modo === 'criar' ? 'new-password' : 'current-password'} required value={senha} onChange={(e) => setSenha(e.target.value)} />
          </div>
        )}
        {modo === 'criar' && <p className="small muted">Para criar uma equipe você vai precisar do código de acesso. Capitão e jogadores recebem o login do dono da equipe.</p>}
        <button className="btn-prim btn-bloco" disabled={enviando}>
          {enviando ? 'Aguarde…' : modo === 'senha' ? 'Entrar' : modo === 'criar' ? 'Criar conta' : 'Enviar link'}
        </button>
        {msg && <div className={msg.tipo} style={{ marginTop: 12 }}>{msg.texto}</div>}
      </form>
    </div>
  );
}
