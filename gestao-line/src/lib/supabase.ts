import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
export const configurado = !!(url && key);
export const supabase = createClient(url || 'http://localhost:54321', key || 'sem-chave', {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
});

// mensagem de erro amigável a partir do que o Supabase/Edge Function devolve
export function msgErro(e: unknown): string {
  if (!e) return 'Erro desconhecido';
  if (typeof e === 'string') return e;
  const x = e as { message?: string; error?: string };
  const m = x.message || x.error || String(e);
  if (/quedas_hash_unico/.test(m)) return 'Este print já foi enviado antes.';
  if (/Invalid login credentials/i.test(m)) return 'E-mail ou senha incorretos.';
  if (/Email not confirmed/i.test(m)) return 'Confirme o e-mail pelo link que enviamos.';
  return m;
}

// chama uma Edge Function e devolve o JSON (o erro vem no campo "error")
export async function chamarFuncao<T>(nome: string, body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke(nome, { body });
  if (error) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const ctx = (error as any).context as Response | undefined;
    if (ctx && typeof ctx.json === 'function') {
      const j = await ctx.json().catch(() => null);
      if (j?.error) throw new Error(j.error);
    }
    throw new Error(error.message);
  }
  return data as T;
}

// endereço para onde o link mágico/confirmação de e-mail volta (sem o "#/rota": o Supabase acrescenta ?code=)
export const urlRetorno = () => window.location.origin + window.location.pathname;

// convite aberto antes do login: guardado para continuar depois de entrar
const CHAVE_CONVITE = 'gestao-line:convite';
export const guardarConvite = (t: string) => { try { localStorage.setItem(CHAVE_CONVITE, t); } catch { /* */ } };
export const conviteGuardado = () => { try { return localStorage.getItem(CHAVE_CONVITE); } catch { return null; } };
export const esquecerConvite = () => { try { localStorage.removeItem(CHAVE_CONVITE); } catch { /* */ } };
