// Copiado do Battle Hub (supabase/functions/_shared/util.ts), só com o que este app usa.
export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
}

export function env(name: string) {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Variável ${name} não configurada`);
  return v;
}
