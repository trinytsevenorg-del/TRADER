// Estatísticas de perfil do Free Fire (opcional, só informativo: NÃO entram na nota do contrato).
// Consulta a free-ff-api (não oficial, github.com/jinix6/free-ff-api; código-fonte em github.com/0xMe/FreeFire-Api),
// endpoints /api/v1/account e /api/v1/playerstats, região BR. Guarda no máximo uma "foto" por semana por jogador.
// Se a API cair, devolve { indisponivel: true } com a última foto guardada e o app segue normalmente.
// FF_API_BASE: troque pela sua cópia hospedada quando tiver uma.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { cors, env, json } from '../_shared/util.ts';

const BASE = (Deno.env.get('FF_API_BASE') || 'https://free-ff-api-src-5plp.onrender.com').replace(/\/$/, '');
const SEMANA_MS = 7 * 24 * 3600e3;

async function buscar(path: string, uid: string) {
  const res = await fetch(`${BASE}${path}?region=BR&uid=${encodeURIComponent(uid)}`, { signal: AbortSignal.timeout(25000) });
  if (!res.ok) throw new Error('API ' + res.status);
  return await res.json();
}

// só os números de carreira que o app mostra (evita guardar o JSON inteiro, que é grande e muda de formato)
// deno-lint-ignore no-explicit-any
export function resumir(conta: any, stats: any) {
  const b = conta?.basicInfo || {};
  // deno-lint-ignore no-explicit-any
  const modo = (s: any) => {
    if (!s || !s.gamesPlayed) return null;
    const d = s.detailedStats || {};
    const mortes = Number(d.deaths) || 0;
    return {
      partidas: Number(s.gamesPlayed) || 0, vitorias: Number(s.wins) || 0, abates: Number(s.kills) || 0,
      kd: mortes ? Math.round(((Number(s.kills) || 0) / mortes) * 100) / 100 : null,
      dano: Number(d.damage) || null, derrubados: Number(d.knockDown) || null, revividos: Number(d.revives) || null,
    };
  };
  return {
    nickname: typeof b.nickname === 'string' ? b.nickname : null,
    nivel: Number(b.level) || null,
    rank_pontos: Number(b.rankingPoints) || null,
    squad: modo(stats?.quadStats), duo: modo(stats?.duoStats), solo: modo(stats?.soloStats),
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: u } = await auth.auth.getUser();
    if (!u?.user) return json({ error: 'Entre na sua conta de novo.' }, 401);
    const body = await req.json().catch(() => ({}));

    // conferir um ID no cadastro, antes de salvar o jogador: só devolve o nick e o nível
    if (body.ff_id && body.org_id) {
      const { data: staff } = await auth.rpc('e_staff', { p_org: String(body.org_id) });
      if (!staff) return json({ error: 'Sem permissão.' }, 403);
      if (!/^[0-9]{5,15}$/.test(String(body.ff_id))) return json({ error: 'ID inválido.' }, 400);
      try {
        const conta = await buscar('/api/v1/account', String(body.ff_id));
        return json({ resumo: resumir(conta, null) });
      } catch (_) {
        return json({ indisponivel: true });
      }
    }

    // a ficha do jogador: RLS garante que quem chamou pode ver este jogador
    const { data: jog } = await auth.from('jogadores').select('id, ff_id').eq('id', String(body.jogador_id || '')).maybeSingle();
    if (!jog) return json({ error: 'Jogador não encontrado.' }, 404);
    const { data: fotos } = await auth.from('snapshots_perfil').select('data, dados_json').eq('jogador_id', jog.id).order('data', { ascending: true }).limit(60);
    const ultima = fotos?.[fotos.length - 1];
    if (!jog.ff_id) return json({ fotos: fotos || [], sem_id: true });
    if (ultima && Date.now() - new Date(ultima.data + 'T12:00:00Z').getTime() < SEMANA_MS) return json({ fotos });

    try {
      const [conta, stats] = await Promise.all([buscar('/api/v1/account', jog.ff_id), buscar('/api/v1/playerstats', jog.ff_id)]);
      const dados = resumir(conta, stats);
      const admin = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
      const hoje = new Date().toISOString().slice(0, 10);
      // org_id é preenchido pelo gatilho do banco a partir do jogador (o valor enviado é ignorado)
      await admin.from('snapshots_perfil').upsert({ jogador_id: jog.id, org_id: '00000000-0000-0000-0000-000000000000', data: hoje, dados_json: dados }, { onConflict: 'jogador_id,data' });
      return json({ fotos: [...(fotos || []), { data: hoje, dados_json: dados }] });
    } catch (e) {
      console.log('free-ff-api falhou:', e instanceof Error ? e.message : e);
      return json({ fotos: fotos || [], indisponivel: true });
    }
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
