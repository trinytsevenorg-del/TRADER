// O dono cria o login (e-mail + senha provisória) de quem vai acessar a equipe. Nada de cadastro aberto:
// só entra quem o dono colocou ou convidou.
import { useState } from 'react';
import { useApp } from '../lib/app';
import { chamarFuncao, msgErro, urlRetorno } from '../lib/supabase';
import { Modal } from './ui';

function senhaAleatoria() {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const b = crypto.getRandomValues(new Uint8Array(10));
  return [...b].map((x) => letras[x % letras.length]).join('');
}

export function CriarLogin({ aberto, fechar, papel, jogadorId, nome, aoCriar }: {
  aberto: boolean; fechar: () => void; papel: 'capitao' | 'jogador'; jogadorId?: string; nome?: string; aoCriar?: () => void;
}) {
  const { org } = useApp();
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState(senhaAleatoria);
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState('');
  const [pronto, setPronto] = useState<{ email: string; senha: string; nova: boolean } | null>(null);

  const sair = () => { setEmail(''); setSenha(senhaAleatoria()); setErro(''); setPronto(null); fechar(); };

  async function criar(e: React.FormEvent) {
    e.preventDefault();
    setEnviando(true); setErro('');
    try {
      const r = await chamarFuncao<{ ok: boolean; conta_nova: boolean }>('criar-acesso', { org_id: org!.id, papel, email, senha, jogador_id: jogadorId || null });
      setPronto({ email: email.trim().toLowerCase(), senha, nova: r.conta_nova });
      aoCriar?.();
    } catch (err) {
      setErro(msgErro(err));
    } finally {
      setEnviando(false);
    }
  }

  const texto = pronto && (pronto.nova
    ? `Acesso à equipe ${org?.nome} (${org?.linha_nome})\nLink: ${urlRetorno()}\nE-mail: ${pronto.email}\nSenha provisória: ${pronto.senha}\nTroque a senha em Conta depois de entrar.`
    : `Você foi colocado na equipe ${org?.nome}. Entre em ${urlRetorno()} com sua conta de sempre (${pronto.email}).`);

  return (
    <Modal aberto={aberto} fechar={sair} titulo={papel === 'capitao' ? 'Criar login do capitão' : 'Criar login de ' + (nome || 'jogador')}>
      {pronto ? (
        <>
          <div className="ok" style={{ marginBottom: 12 }}>{pronto.nova ? 'Login criado.' : 'Esta pessoa já tinha conta: foi colocada na equipe (a senha dela não mudou).'}</div>
          <label htmlFor="msg">Mande para a pessoa</label>
          <textarea id="msg" readOnly rows={5} value={texto || ''} onFocus={(e) => e.target.select()} />
          <div className="linha" style={{ marginTop: 10 }}>
            <button onClick={() => navigator.clipboard.writeText(texto || '').catch(() => {})}>Copiar</button>
            <div className="cresce" />
            <button className="btn-prim" onClick={sair}>Pronto</button>
          </div>
        </>
      ) : (
        <form onSubmit={criar}>
          <p className="small sec">{papel === 'capitao' ? 'O capitão cadastra jogadores, cria eventos, envia os prints e lança presença e notas.' : 'O jogador vê só a própria nota, o gráfico e o histórico.'}</p>
          <div className="campo"><label htmlFor="cl-email">E-mail da pessoa</label><input id="cl-email" type="email" required autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} /></div>
          <div className="campo">
            <label htmlFor="cl-senha">Senha provisória</label>
            <div className="linha">
              <input id="cl-senha" required minLength={8} autoComplete="off" value={senha} onChange={(e) => setSenha(e.target.value)} />
              <button type="button" onClick={() => setSenha(senhaAleatoria())}>Outra</button>
            </div>
            <div className="small muted">A pessoa entra com ela e troca depois. Se o e-mail já tiver conta, ela só é colocada na equipe.</div>
          </div>
          {erro && <div className="erro" style={{ marginBottom: 10 }}>{erro}</div>}
          <button className="btn-prim btn-bloco" disabled={enviando}>{enviando ? 'Criando…' : 'Criar login'}</button>
        </form>
      )}
    </Modal>
  );
}
