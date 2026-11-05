// Lê um print da tela de resultado do Free Fire e devolve, para cada jogador visível, os números da queda.
// O app comprime a imagem no celular (máx. 1600 px) e manda em base64; a imagem NÃO é guardada aqui.
// Nada é gravado nas tabelas do jogo: o capitão confere na tela "Conferir números" e só então salva.
// IA: Gemini (GEMINI_API_KEY, plano gratuito) ou Claude (ANTHROPIC_API_KEY), pelo _shared/ia.ts copiado do Battle Hub.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { iaLigada, perguntar, IaError } from '../_shared/ia.ts';
import { cors, env, json } from '../_shared/util.ts';
import { SYSTEM, TOOL, lerResultado } from '../_shared/leitura-print.ts';

const MAX_BYTES = 3 * 1024 * 1024;
const MAX_POR_DIA = Number(Deno.env.get('LEITURAS_POR_DIA') || 300); // por organização, para não estourar o plano gratuito

function deBase64(s: string) {
  const bin = atob(s.replace(/^data:[^,]+,/, ''));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    if (!iaLigada()) return json({ error: 'A leitura automática não está ligada. Digite os números à mão.' }, 501);
    const auth = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: u } = await auth.auth.getUser();
    if (!u?.user) return json({ error: 'Entre na sua conta de novo.' }, 401);

    const body = await req.json().catch(() => ({}));
    const orgId = String(body.org_id || '');
    const imagem = typeof body.imagem === 'string' ? body.imagem : '';
    if (!orgId || !imagem) return json({ error: 'Envie o print.' }, 400);
    const buf = deBase64(imagem);
    if (buf.byteLength > MAX_BYTES) return json({ error: 'Imagem grande demais.' }, 400);

    const { data: pode } = await auth.rpc('pode_lancar', { p_org: orgId });
    if (!pode) return json({ error: 'Só o capitão envia prints.' }, 403);

    const admin = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
    const desde = new Date(Date.now() - 24 * 3600e3).toISOString();
    const { count } = await admin.from('leituras_ia').select('id', { count: 'exact', head: true }).eq('org_id', orgId).gte('em', desde);
    if ((count || 0) >= MAX_POR_DIA) return json({ error: 'Limite de leituras automáticas de hoje. Digite os números à mão.' }, 429);

    const { data: elenco } = await auth.from('jogadores').select('nick, apelidos_leitura').eq('org_id', orgId).eq('ativo', true);
    const lista = (elenco || []).map((j) => [j.nick, ...(j.apelidos_leitura || [])].join(' / ')).join('\n');

    let resultado = null, erro = '';
    try {
      const r = await perguntar({ system: SYSTEM, tool: TOOL, image: buf, media: String(body.media || 'image/jpeg'), maxTokens: 2048,
        text: 'Jogadores da nossa equipe (nick e formas como já apareceu):\n' + (lista || '(sem cadastro)') });
      resultado = lerResultado(r);
      if (!resultado) erro = 'Este print não parece a tela de resultado.';
    } catch (e) {
      erro = (e instanceof IaError || e instanceof Error ? e.message : String(e)) + '. Digite os números à mão.';
    }
    await admin.from('leituras_ia').insert({ org_id: orgId, usuario_id: u.user.id, ok: !!resultado });
    if (!resultado) return json({ error: erro }, 422);
    return json(resultado);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
