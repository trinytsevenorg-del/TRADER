import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from './supabase';
import { regrasCompletas, type Jogador, type Meta, type Regras } from './nota';

export type Papel = 'dono' | 'capitao' | 'jogador';
export type Org = { id: string; nome: string; linha_nome: string; tag: string | null; dono_id: string; regras: Regras; papel: Papel };

type Ctx = {
  session: Session | null;
  carregando: boolean;
  orgs: Org[];
  org: Org | null;
  trocarOrg: (id: string) => void;
  recarregarOrgs: () => Promise<void>;
  jogadores: Jogador[];
  metas: Meta[];
  recarregar: () => Promise<void>;
  podeLancar: boolean;
  podeConfigurar: boolean;
  euJogador: Jogador | null;
};

const AppCtx = createContext<Ctx>(null as unknown as Ctx);
export const useApp = () => useContext(AppCtx);

const CHAVE_ORG = 'gestao-line:org';
const lerLocal = (k: string) => { try { return localStorage.getItem(k); } catch { return null; } };
const gravarLocal = (k: string, v: string) => { try { localStorage.setItem(k, v); } catch { /* aba anônima */ } };

export function AppProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [carregando, setCarregando] = useState(true);
  const [orgs, setOrgs] = useState<Org[]>([]);
  const [orgId, setOrgId] = useState<string | null>(lerLocal(CHAVE_ORG));
  const [jogadores, setJogadores] = useState<Jogador[]>([]);
  const [metas, setMetas] = useState<Meta[]>([]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); if (!data.session) setCarregando(false); });
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  const recarregarOrgs = useCallback(async () => {
    if (!session) { setOrgs([]); return; }
    const { data } = await supabase.from('membros').select('papel, organizacoes(id, nome, linha_nome, tag, dono_id, regras)').eq('usuario_id', session.user.id);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const lista: Org[] = (data || []).filter((m: any) => m.organizacoes).map((m: any) => ({ ...m.organizacoes, regras: regrasCompletas(m.organizacoes.regras), papel: m.papel }));
    lista.sort((a, b) => a.nome.localeCompare(b.nome));
    setOrgs(lista);
    setCarregando(false);
  }, [session]);

  useEffect(() => { recarregarOrgs(); }, [recarregarOrgs]);

  const org = orgs.find((o) => o.id === orgId) || orgs[0] || null;

  const recarregar = useCallback(async () => {
    if (!org) { setJogadores([]); setMetas([]); return; }
    const [j, m] = await Promise.all([
      supabase.from('jogadores').select('id, nick, ff_id, funcao, capitao, apelidos_leitura, ativo, usuario_id').eq('org_id', org.id).order('nick'),
      supabase.from('metas').select('funcao, criterio, base, meta, destaque, ordem').eq('org_id', org.id),
    ]);
    setJogadores((j.data as Jogador[]) || []);
    setMetas(((m.data || []) as Meta[]).map((x) => ({ ...x, base: Number(x.base), meta: Number(x.meta), destaque: Number(x.destaque) })));
  }, [org?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { recarregar(); }, [recarregar]);

  const trocarOrg = (id: string) => { setOrgId(id); gravarLocal(CHAVE_ORG, id); };
  const podeLancar = !!org && (org.papel === 'capitao' || (org.papel === 'dono' && org.regras.dono_pode_lancar));
  const podeConfigurar = org?.papel === 'dono';
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const euJogador = (org?.papel === 'jogador' && jogadores.find((j: any) => j.usuario_id === session?.user.id)) || null;

  return (
    <AppCtx.Provider value={{ session, carregando, orgs, org, trocarOrg, recarregarOrgs, jogadores, metas, recarregar, podeLancar, podeConfigurar, euJogador }}>
      {children}
    </AppCtx.Provider>
  );
}
