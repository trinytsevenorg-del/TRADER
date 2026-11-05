// O dono cria o login do capitão (ou de um jogador, fase 2): e-mail + senha provisória, já confirmado.
// A pessoa entra direto com esses dados e troca a senha depois em "Conta". Se o e-mail já tem conta,
// só coloca a pessoa na organização (a senha dela não muda).
import { createClient } from 'npm:@supabase/supabase-js@2';
import { cors, env, json } from '../_shared/util.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: u } = await auth.auth.getUser();
    if (!u?.user) return json({ error: 'Entre na sua conta de novo.' }, 401);

    const body = await req.json().catch(() => ({}));
    const orgId = String(body.org_id || '');
    const papel = body.papel === 'jogador' ? 'jogador' : 'capitao';
    const email = String(body.email || '').trim().toLowerCase();
    const senha = String(body.senha || '');
    const jogadorId = body.jogador_id ? String(body.jogador_id) : null;
    if (!orgId || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: 'Informe um e-mail válido.' }, 400);

    // capitão: só o dono cria. jogador: dono ou capitão.
    const [{ data: dono }, { data: lanca }] = await Promise.all([
      auth.rpc('pode_configurar', { p_org: orgId }),
      auth.rpc('pode_lancar', { p_org: orgId }),
    ]);
    if (!dono && !(papel === 'jogador' && lanca)) return json({ error: 'Só o dono da equipe cria o login do capitão.' }, 403);

    const admin = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
    let { data: id } = await admin.rpc('svc_usuario_por_email', { p_email: email });
    let criada = false;
    if (!id) {
      if (senha.length < 8) return json({ error: 'A senha provisória precisa ter 8 caracteres ou mais.' }, 400);
      const { data: novo, error } = await admin.auth.admin.createUser({ email, password: senha, email_confirm: true });
      if (error || !novo.user) return json({ error: error?.message || 'Não deu para criar a conta.' }, 400);
      id = novo.user.id;
      criada = true;
    }
    const { data: ja } = await admin.from('membros').select('papel').eq('org_id', orgId).eq('usuario_id', id).maybeSingle();
    if (ja) return json({ error: 'Esta pessoa já faz parte da organização (' + ja.papel + ').' }, 400);
    const { error: eM } = await admin.from('membros').insert({ org_id: orgId, usuario_id: id, papel, email });
    if (eM) return json({ error: eM.message }, 400);
    if (papel === 'jogador' && jogadorId) {
      // o gatilho só deixa ligar a conta ao jogador pelo convite; aqui a chave de serviço faz o mesmo papel
      await admin.rpc('svc_ligar_jogador', { p_jogador: jogadorId, p_org: orgId, p_usuario: id });
    }
    return json({ ok: true, conta_nova: criada });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
