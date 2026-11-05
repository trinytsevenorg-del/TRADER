import { supabase } from './supabase';
import { somarMes, type Dados, type Divulgacao, type Estatistica, type Evento, type Jogador, type Meta, type NotaCapitao, type Presenca, type Queda, type Regras } from './nota';

// Carrega tudo o que o cálculo precisa de um intervalo de meses (o volume de uma line é pequeno).
export async function carregarDados(orgId: string, deMes: string, ateMes: string, jogadores: Jogador[], metas: Meta[], regras: Regras): Promise<Dados> {
  const ini = deMes + '-01';
  const fim = somarMes(ateMes, 1) + '-01';
  const { data: ev, error } = await supabase.from('eventos').select('id, tipo, nome, data, quedas_previstas').eq('org_id', orgId).gte('data', ini).lt('data', fim).order('data');
  if (error) throw error;
  const eventos = (ev || []) as Evento[];
  const ids = eventos.map((e) => e.id);
  const meses: string[] = [];
  for (let m = deMes; m <= ateMes; m = somarMes(m, 1)) meses.push(m);

  const vazio = { data: [] as never[] };
  const [q, p, d, n] = await Promise.all([
    ids.length ? supabase.from('quedas').select('id, evento_id, numero, colocacao, hash_print').in('evento_id', ids) : vazio,
    ids.length ? supabase.from('presencas').select('evento_id, jogador_id, status').in('evento_id', ids) : vazio,
    ids.length ? supabase.from('divulgacoes').select('evento_id, jogador_id, story_antes, resultado_24h').in('evento_id', ids) : vazio,
    supabase.from('notas_capitao').select('jogador_id, mes, postura, utilitario').eq('org_id', orgId).in('mes', meses),
  ]);
  const quedas = (q.data || []) as Queda[];
  const qids = quedas.map((x) => x.id);
  const est = qids.length
    ? await supabase.from('estatisticas_queda').select('queda_id, jogador_id, abates, derrubados, dano, assistencias, revividos, print_enviado, corrigido, confianca').in('queda_id', qids)
    : vazio;
  return {
    jogadores, metas, regras, eventos, quedas,
    estatisticas: (est.data || []) as Estatistica[],
    presencas: (p.data || []) as Presenca[],
    divulgacoes: (d.data || []) as Divulgacao[],
    notas: (n.data || []) as NotaCapitao[],
  };
}
