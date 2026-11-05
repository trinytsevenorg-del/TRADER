-- Gestão de Line: esquema inicial.
-- Projeto Supabase separado do BATTLEHUB. Cada pessoa só enxerga a organização da qual é membro (RLS).
-- Papéis: dono (lê tudo, ajusta metas e regras, convida), capitao (lança tudo), jogador (fase 2: só o próprio).

-- gen_random_uuid() é nativo do Postgres 13+ (sem pgcrypto)

create type papel_t as enum ('dono', 'capitao', 'jogador');
create type funcao_t as enum ('rush', 'suporte', 'granadeiro');
create type evento_t as enum ('treino', 'campeonato');
create type presenca_t as enum ('presente', 'atrasado', 'falta_avisada', 'falta_sem_aviso');

-- Regras de cálculo iniciais (seção "Regras de cálculo" da especificação). Editáveis em Configurações.
create or replace function regras_padrao() returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'pesos', jsonb_build_object('desempenho', 50, 'presenca', 20, 'divulgacao', 15, 'postura', 15),
    'niveis', jsonb_build_object('destaque', 100, 'meta', 80, 'base', 50),
    'tolerancia_capitao', jsonb_build_object('ativa', true, 'fracao_base', 0.7),
    'presenca_faixas', jsonb_build_array(
      jsonb_build_object('min', 80, 'pontos', 20),
      jsonb_build_object('min', 70, 'pontos', 12),
      jsonb_build_object('min', 60, 'pontos', 6)),
    'atrasos_por_falta', 3,
    'falta_avisada_conta', true,
    'resultado_faixas', jsonb_build_object('destaque', 85, 'meta', 70, 'base', 55),
    'inclui_treinos_no_desempenho', true,
    'divulgacao_em', jsonb_build_array('campeonato'),
    'dono_pode_lancar', false
  )
$$;

create table organizacoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(trim(nome)) between 1 and 80),
  linha_nome text not null default 'Line principal' check (length(trim(linha_nome)) between 1 and 80),
  tag text check (tag is null or length(tag) <= 12),
  dono_id uuid not null references auth.users (id),
  regras jsonb not null default regras_padrao(),
  criado_em timestamptz not null default now()
);

create table membros (
  org_id uuid not null references organizacoes (id) on delete cascade,
  usuario_id uuid not null references auth.users (id) on delete cascade,
  papel papel_t not null,
  email text,
  criado_em timestamptz not null default now(),
  primary key (org_id, usuario_id)
);
create index membros_usuario on membros (usuario_id);

create table jogadores (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes (id) on delete cascade,
  nick text not null check (length(trim(nick)) between 1 and 40),
  ff_id text check (ff_id is null or ff_id ~ '^[0-9]{5,15}$'),
  funcao funcao_t not null,
  capitao boolean not null default false,
  apelidos_leitura text[] not null default '{}',
  ativo boolean not null default true,
  usuario_id uuid references auth.users (id) on delete set null, -- fase 2: conta do próprio jogador
  criado_em timestamptz not null default now()
);
create index jogadores_org on jogadores (org_id);

create table convites (
  token text primary key default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  org_id uuid not null references organizacoes (id) on delete cascade,
  papel papel_t not null check (papel <> 'dono'),
  jogador_id uuid references jogadores (id) on delete cascade, -- convite de jogador já ligado ao cadastro
  criado_por uuid not null default auth.uid() references auth.users (id),
  expira_em timestamptz not null default now() + interval '7 days',
  usado_por uuid references auth.users (id),
  usado_em timestamptz,
  criado_em timestamptz not null default now()
);

create table eventos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes (id) on delete cascade,
  tipo evento_t not null,
  nome text not null check (length(trim(nome)) between 1 and 80),
  data date not null,
  quedas_previstas smallint check (quedas_previstas is null or quedas_previstas between 1 and 30),
  criado_em timestamptz not null default now()
);
create index eventos_org_data on eventos (org_id, data);

create table quedas (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references eventos (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  numero smallint not null check (numero between 1 and 30),
  colocacao smallint check (colocacao is null or colocacao between 1 and 60),
  hash_print text check (hash_print is null or hash_print ~ '^[0-9a-f]{64}$'),
  criado_em timestamptz not null default now(),
  unique (evento_id, numero)
);
create unique index quedas_hash_unico on quedas (org_id, hash_print) where hash_print is not null;

create table estatisticas_queda (
  queda_id uuid not null references quedas (id) on delete cascade,
  jogador_id uuid not null references jogadores (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  abates smallint not null default 0 check (abates between 0 and 60),
  derrubados smallint not null default 0 check (derrubados between 0 and 80),
  dano integer not null default 0 check (dano between 0 and 20000),
  assistencias smallint not null default 0 check (assistencias between 0 and 60),
  revividos smallint not null default 0 check (revividos between 0 and 40),
  print_enviado boolean not null default true,
  confianca jsonb not null default '{}', -- {campo: "baixa"} nos campos em que a leitura teve dúvida
  corrigido boolean not null default false, -- o capitão mudou algum número lido pela IA (mede a taxa de acerto)
  primary key (queda_id, jogador_id)
);
create index estatisticas_jogador on estatisticas_queda (jogador_id);

create table presencas (
  evento_id uuid not null references eventos (id) on delete cascade,
  jogador_id uuid not null references jogadores (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  status presenca_t not null,
  primary key (evento_id, jogador_id)
);

create table divulgacoes (
  evento_id uuid not null references eventos (id) on delete cascade,
  jogador_id uuid not null references jogadores (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  story_antes boolean not null default false,
  resultado_24h boolean not null default false,
  primary key (evento_id, jogador_id)
);

create table notas_capitao (
  jogador_id uuid not null references jogadores (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  mes text not null check (mes ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  postura smallint check (postura is null or postura between 1 and 5),
  utilitario smallint check (utilitario is null or utilitario between 1 and 5),
  primary key (jogador_id, mes)
);

create table metas (
  org_id uuid not null references organizacoes (id) on delete cascade,
  funcao funcao_t not null,
  criterio text not null check (criterio in ('abates', 'derrubados', 'dano', 'assistencias', 'revividos', 'utilitario')),
  base numeric not null check (base >= 0),
  meta numeric not null,
  destaque numeric not null,
  ordem smallint not null default 0,
  primary key (org_id, funcao, criterio),
  check (meta >= base and destaque >= meta)
);

create table snapshots_perfil (
  id uuid primary key default gen_random_uuid(),
  jogador_id uuid not null references jogadores (id) on delete cascade,
  org_id uuid not null references organizacoes (id) on delete cascade,
  data date not null default current_date,
  dados_json jsonb not null,
  unique (jogador_id, data)
);

-- registro das leituras por IA (controle do limite gratuito e taxa de acerto)
create table leituras_ia (
  id bigint generated always as identity primary key,
  org_id uuid not null references organizacoes (id) on delete cascade,
  usuario_id uuid not null references auth.users (id) on delete cascade,
  ok boolean not null,
  em timestamptz not null default now()
);
create index leituras_ia_org_em on leituras_ia (org_id, em);

-- ---------------------------------------------------------------- funções de acesso

create or replace function meu_papel(p_org uuid) returns papel_t
language sql stable security definer set search_path = public as $$
  select papel from membros where org_id = p_org and usuario_id = auth.uid()
$$;

create or replace function e_membro(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where org_id = p_org and usuario_id = auth.uid())
$$;

-- dono e capitão veem tudo da organização
create or replace function e_staff(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where org_id = p_org and usuario_id = auth.uid() and papel in ('dono', 'capitao'))
$$;

create or replace function pode_configurar(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where org_id = p_org and usuario_id = auth.uid() and papel = 'dono')
$$;

-- quem lança números: o capitão (e o dono, só se ele ligar isso em Configurações)
create or replace function pode_lancar(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from membros m join organizacoes o on o.id = m.org_id
    where m.org_id = p_org and m.usuario_id = auth.uid()
      and (m.papel = 'capitao' or (m.papel = 'dono' and coalesce((o.regras ->> 'dono_pode_lancar')::boolean, false)))
  )
$$;

-- fase 2: o jogador ligado à conta
create or replace function e_o_jogador(p_jogador uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from jogadores where id = p_jogador and usuario_id = auth.uid() and auth.uid() is not null)
$$;

-- ---------------------------------------------------------------- org_id coerente
-- As tabelas filhas guardam org_id para a RLS ficar simples. O valor nunca vem do cliente:
-- é copiado do evento/queda e o jogador precisa ser da mesma organização.

create or replace function trg_org_do_evento() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select org_id into new.org_id from eventos where id = new.evento_id;
  if new.org_id is null then raise exception 'Evento não encontrado'; end if;
  if not exists (select 1 from jogadores where id = new.jogador_id and org_id = new.org_id) then
    raise exception 'Jogador de outra organização';
  end if;
  return new;
end $$;

create or replace function trg_org_da_queda_evento() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select org_id into new.org_id from eventos where id = new.evento_id;
  if new.org_id is null then raise exception 'Evento não encontrado'; end if;
  return new;
end $$;

create or replace function trg_org_da_queda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select org_id into new.org_id from quedas where id = new.queda_id;
  if new.org_id is null then raise exception 'Queda não encontrada'; end if;
  if not exists (select 1 from jogadores where id = new.jogador_id and org_id = new.org_id) then
    raise exception 'Jogador de outra organização';
  end if;
  return new;
end $$;

create or replace function trg_org_do_jogador() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select org_id into new.org_id from jogadores where id = new.jogador_id;
  if new.org_id is null then raise exception 'Jogador não encontrado'; end if;
  return new;
end $$;

create trigger quedas_org before insert or update on quedas for each row execute function trg_org_da_queda_evento();
create trigger presencas_org before insert or update on presencas for each row execute function trg_org_do_evento();
create trigger divulgacoes_org before insert or update on divulgacoes for each row execute function trg_org_do_evento();
create trigger estatisticas_org before insert or update on estatisticas_queda for each row execute function trg_org_da_queda();
create trigger notas_org before insert or update on notas_capitao for each row execute function trg_org_do_jogador();
create trigger snapshots_org before insert or update on snapshots_perfil for each row execute function trg_org_do_jogador();

-- jogador não muda de organização; dono_id não muda
create or replace function trg_fixa_org() returns trigger language plpgsql as $$
begin
  if new.org_id <> old.org_id then raise exception 'Não é possível mudar a organização'; end if;
  return new;
end $$;
create trigger jogadores_fixa_org before update on jogadores for each row execute function trg_fixa_org();
create trigger eventos_fixa_org before update on eventos for each row execute function trg_fixa_org();

create or replace function trg_fixa_dono() returns trigger language plpgsql as $$
begin
  if new.dono_id <> old.dono_id then raise exception 'Não é possível mudar o dono'; end if;
  return new;
end $$;
create trigger organizacoes_fixa_dono before update on organizacoes for each row execute function trg_fixa_dono();

-- usuario_id do jogador só é preenchido pelo convite (aceitar_convite), nunca pelo cliente
create or replace function trg_jogador_usuario() returns trigger language plpgsql as $$
begin
  if current_setting('gestao.aceitando_convite', true) is distinct from 'sim' then
    if tg_op = 'INSERT' then new.usuario_id := null;
    else new.usuario_id := old.usuario_id; end if;
  end if;
  return new;
end $$;
create trigger jogadores_usuario before insert or update on jogadores for each row execute function trg_jogador_usuario();

-- ---------------------------------------------------------------- RPCs

-- cria a organização (com a line), coloca quem chamou como dono e as metas iniciais
create or replace function criar_organizacao(p_nome text, p_linha text default 'Line principal', p_tag text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_email text;
begin
  if auth.uid() is null then raise exception 'Entre na sua conta'; end if;
  if (select count(*) from organizacoes where dono_id = auth.uid()) >= 5 then raise exception 'Limite de organizações'; end if;
  insert into organizacoes (nome, linha_nome, tag, dono_id)
    values (trim(p_nome), coalesce(nullif(trim(p_linha), ''), 'Line principal'), nullif(trim(p_tag), ''), auth.uid())
    returning id into v_org;
  select email into v_email from auth.users where id = auth.uid();
  insert into membros (org_id, usuario_id, papel, email) values (v_org, auth.uid(), 'dono', v_email);
  insert into metas (org_id, funcao, criterio, base, meta, destaque, ordem) values
    (v_org, 'rush', 'abates', 1.5, 2.5, 3.5, 1),
    (v_org, 'rush', 'derrubados', 2, 3, 4, 2),
    (v_org, 'rush', 'dano', 600, 900, 1300, 3),
    (v_org, 'suporte', 'revividos', 0.5, 1, 2, 1),
    (v_org, 'suporte', 'assistencias', 1, 1.5, 2, 2),
    (v_org, 'suporte', 'dano', 400, 650, 900, 3),
    (v_org, 'granadeiro', 'dano', 500, 800, 1100, 1),
    (v_org, 'granadeiro', 'assistencias', 1, 1.5, 2, 2),
    (v_org, 'granadeiro', 'utilitario', 3, 4, 5, 3);
  return v_org;
end $$;

-- mostra para quem abriu o link o que o convite é, antes de aceitar
create or replace function ver_convite(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('org', o.nome, 'linha', o.linha_nome, 'papel', c.papel,
    'valido', c.usado_por is null and c.expira_em > now(),
    'jogador', (select nick from jogadores where id = c.jogador_id))
  from convites c join organizacoes o on o.id = c.org_id where c.token = p_token
$$;

create or replace function aceitar_convite(p_token text) returns uuid
language plpgsql security definer set search_path = public as $$
declare c convites; v_email text;
begin
  if auth.uid() is null then raise exception 'Entre na sua conta'; end if;
  select * into c from convites where token = p_token for update;
  if c.token is null then raise exception 'Convite não encontrado'; end if;
  if c.usado_por is not null then
    if c.usado_por = auth.uid() then return c.org_id; end if;
    raise exception 'Este convite já foi usado';
  end if;
  if c.expira_em < now() then raise exception 'Convite expirado. Peça um novo link.'; end if;
  if exists (select 1 from membros where org_id = c.org_id and usuario_id = auth.uid()) then
    raise exception 'Você já faz parte desta organização';
  end if;
  select email into v_email from auth.users where id = auth.uid();
  insert into membros (org_id, usuario_id, papel, email) values (c.org_id, auth.uid(), c.papel, v_email);
  if c.jogador_id is not null then
    perform set_config('gestao.aceitando_convite', 'sim', true);
    update jogadores set usuario_id = auth.uid() where id = c.jogador_id;
    perform set_config('gestao.aceitando_convite', '', true);
  end if;
  update convites set usado_por = auth.uid(), usado_em = now() where token = p_token;
  return c.org_id;
end $$;

-- capitão salva a resposta de "Quem é este?" sem precisar reescrever o cadastro inteiro
create or replace function adicionar_apelido(p_jogador uuid, p_apelido text) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select org_id into v_org from jogadores where id = p_jogador;
  if v_org is null or not pode_lancar(v_org) then raise exception 'Sem permissão'; end if;
  if length(trim(p_apelido)) = 0 or length(p_apelido) > 60 then return; end if;
  update jogadores set apelidos_leitura = array_append(apelidos_leitura, trim(p_apelido))
    where id = p_jogador and not (trim(p_apelido) = any (apelidos_leitura)) and cardinality(apelidos_leitura) < 30;
end $$;

-- grava uma queda inteira (colocação + números de cada jogador) de uma vez, numa transação
create or replace function salvar_queda(p_evento uuid, p_queda uuid, p_numero int, p_colocacao int, p_hash text, p_linhas jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_id uuid; l jsonb;
begin
  select org_id into v_org from eventos where id = p_evento;
  if v_org is null or not pode_lancar(v_org) then raise exception 'Sem permissão'; end if;
  if p_queda is null then
    insert into quedas (evento_id, org_id, numero, colocacao, hash_print)
      values (p_evento, v_org, p_numero, p_colocacao, nullif(p_hash, '')) returning id into v_id;
  else
    update quedas set numero = p_numero, colocacao = p_colocacao, hash_print = coalesce(nullif(p_hash, ''), hash_print)
      where id = p_queda and evento_id = p_evento returning id into v_id;
    if v_id is null then raise exception 'Queda não encontrada'; end if;
    delete from estatisticas_queda where queda_id = v_id;
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_linhas, '[]'::jsonb)) loop
    insert into estatisticas_queda (queda_id, jogador_id, org_id, abates, derrubados, dano, assistencias, revividos, print_enviado, confianca, corrigido)
    values (v_id, (l ->> 'jogador_id')::uuid, v_org,
      coalesce((l ->> 'abates')::int, 0), coalesce((l ->> 'derrubados')::int, 0), coalesce((l ->> 'dano')::int, 0),
      coalesce((l ->> 'assistencias')::int, 0), coalesce((l ->> 'revividos')::int, 0),
      coalesce((l ->> 'print_enviado')::boolean, true), coalesce(l -> 'confianca', '{}'::jsonb),
      coalesce((l ->> 'corrigido')::boolean, false));
  end loop;
  return v_id;
end $$;

-- ---------------------------------------------------------------- RLS

alter table organizacoes enable row level security;
alter table membros enable row level security;
alter table convites enable row level security;
alter table jogadores enable row level security;
alter table eventos enable row level security;
alter table quedas enable row level security;
alter table estatisticas_queda enable row level security;
alter table presencas enable row level security;
alter table divulgacoes enable row level security;
alter table notas_capitao enable row level security;
alter table metas enable row level security;
alter table snapshots_perfil enable row level security;
alter table leituras_ia enable row level security;

create policy org_ler on organizacoes for select using (e_membro(id));
create policy org_editar on organizacoes for update using (pode_configurar(id)) with check (pode_configurar(id));
create policy org_apagar on organizacoes for delete using (dono_id = auth.uid());

create policy membros_ler on membros for select using (e_staff(org_id) or usuario_id = auth.uid());
create policy membros_editar on membros for update using (pode_configurar(org_id) and papel <> 'dono') with check (pode_configurar(org_id) and papel <> 'dono');
create policy membros_remover on membros for delete using ((pode_configurar(org_id) and papel <> 'dono') or (usuario_id = auth.uid() and papel <> 'dono'));

-- o dono convida capitão e jogadores; o capitão convida jogadores (fase 2)
create policy convites_ler on convites for select using (e_staff(org_id));
create policy convites_criar on convites for insert with check (
  criado_por = auth.uid() and usado_por is null and (pode_configurar(org_id) or (papel = 'jogador' and pode_lancar(org_id))));
create policy convites_apagar on convites for delete using (pode_configurar(org_id) or (papel = 'jogador' and pode_lancar(org_id)));

create policy jogadores_ler on jogadores for select using (e_staff(org_id) or usuario_id = auth.uid());
create policy jogadores_criar on jogadores for insert with check (pode_lancar(org_id));
create policy jogadores_editar on jogadores for update using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy jogadores_apagar on jogadores for delete using (pode_lancar(org_id));

create policy eventos_ler on eventos for select using (e_membro(org_id));
create policy eventos_criar on eventos for insert with check (pode_lancar(org_id));
create policy eventos_editar on eventos for update using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy eventos_apagar on eventos for delete using (pode_lancar(org_id));

create policy quedas_ler on quedas for select using (e_membro(org_id));
create policy quedas_criar on quedas for insert with check (pode_lancar(org_id));
create policy quedas_editar on quedas for update using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy quedas_apagar on quedas for delete using (pode_lancar(org_id));

-- tabelas por jogador: staff vê tudo, o jogador (fase 2) vê só as linhas dele, só o capitão escreve
create policy est_ler on estatisticas_queda for select using (e_staff(org_id) or e_o_jogador(jogador_id));
create policy est_escrever on estatisticas_queda for all using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy pres_ler on presencas for select using (e_staff(org_id) or e_o_jogador(jogador_id));
create policy pres_escrever on presencas for all using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy div_ler on divulgacoes for select using (e_staff(org_id) or e_o_jogador(jogador_id));
create policy div_escrever on divulgacoes for all using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy notas_ler on notas_capitao for select using (e_staff(org_id) or e_o_jogador(jogador_id));
create policy notas_escrever on notas_capitao for all using (pode_lancar(org_id)) with check (pode_lancar(org_id));
create policy snap_ler on snapshots_perfil for select using (e_staff(org_id) or e_o_jogador(jogador_id));

create policy metas_ler on metas for select using (e_membro(org_id));
create policy metas_escrever on metas for all using (pode_configurar(org_id)) with check (pode_configurar(org_id));

create policy leituras_ler on leituras_ia for select using (e_staff(org_id));

-- RPCs só para quem está logado
revoke execute on function criar_organizacao(text, text, text) from public, anon;
revoke execute on function aceitar_convite(text) from public, anon;
revoke execute on function adicionar_apelido(uuid, text) from public, anon;
revoke execute on function salvar_queda(uuid, uuid, int, int, text, jsonb) from public, anon;
grant execute on function criar_organizacao(text, text, text) to authenticated;
grant execute on function aceitar_convite(text) to authenticated;
grant execute on function adicionar_apelido(uuid, text) to authenticated;
grant execute on function salvar_queda(uuid, uuid, int, int, text, jsonb) to authenticated;
grant execute on function ver_convite(text) to anon, authenticated;
