-- Acesso fechado: só cria organização quem recebeu um código do administrador da plataforma.
-- Fluxo: administrador gera o código -> entrega ao dono da equipe -> o dono cria a conta e a organização com o código
-- -> o dono cria o login do capitão (ou manda um convite). Sem código nem convite, a conta não vê nada.
-- Os administradores ficam na tabela admins_plataforma (por e-mail), preenchida direto no banco:
--   insert into admins_plataforma (email) values ('seu-email@exemplo.com');

create table admins_plataforma (
  email text primary key check (email = lower(email))
);
alter table admins_plataforma enable row level security; -- ninguém lê pela API

create table codigos_acesso (
  codigo text primary key,
  para text check (para is null or length(para) <= 80), -- anotação: para quem é o código
  criado_por uuid not null references auth.users (id),
  expira_em timestamptz not null default now() + interval '30 days',
  usado_por uuid references auth.users (id),
  usado_em timestamptz,
  org_id uuid references organizacoes (id) on delete set null,
  criado_em timestamptz not null default now()
);
alter table codigos_acesso enable row level security;

create or replace function sou_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from admins_plataforma a join auth.users u on lower(u.email) = a.email
    where u.id = auth.uid()
  )
$$;

create policy codigos_ler on codigos_acesso for select using (sou_admin());
create policy codigos_apagar on codigos_acesso for delete using (sou_admin() and usado_por is null);

-- código legível: LINE-XXXX-XXXX-XXXX (48 bits aleatórios)
create or replace function gerar_codigo_acesso(p_para text default null, p_dias int default 30) returns text
language plpgsql security definer set search_path = public as $$
declare v text; h text;
begin
  if not sou_admin() then raise exception 'Só o administrador gera códigos'; end if;
  h := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  v := 'LINE-' || substr(h, 1, 4) || '-' || substr(h, 5, 4) || '-' || substr(h, 9, 4);
  insert into codigos_acesso (codigo, para, criado_por, expira_em)
    values (v, nullif(trim(p_para), ''), auth.uid(), now() + make_interval(days => greatest(1, least(coalesce(p_dias, 30), 365))));
  return v;
end $$;

-- tentativas erradas de código (contra força bruta)
create table tentativas_codigo (usuario_id uuid not null, em timestamptz not null default now());
alter table tentativas_codigo enable row level security;
create index tentativas_codigo_usuario on tentativas_codigo (usuario_id, em);

-- criar_organizacao agora exige um código válido (o administrador não precisa)
drop function criar_organizacao(text, text, text);
create or replace function criar_organizacao(p_nome text, p_linha text default 'Line principal', p_tag text default null, p_codigo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_email text; v_cod codigos_acesso; v_admin boolean := sou_admin();
begin
  if auth.uid() is null then raise exception 'Entre na sua conta'; end if;
  if not v_admin then
    if (select count(*) from tentativas_codigo where usuario_id = auth.uid() and em > now() - interval '1 hour') >= 10 then
      raise exception 'Muitas tentativas. Tente de novo em uma hora.';
    end if;
    select * into v_cod from codigos_acesso where codigo = upper(trim(coalesce(p_codigo, ''))) for update;
    if v_cod.codigo is null or v_cod.usado_por is not null or v_cod.expira_em < now() then
      insert into tentativas_codigo (usuario_id) values (auth.uid());
      -- a tentativa precisa ficar gravada: devolve erro sem desfazer a transação
      return null;
    end if;
  end if;
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
  if v_cod.codigo is not null then
    update codigos_acesso set usado_por = auth.uid(), usado_em = now(), org_id = v_org where codigo = v_cod.codigo;
  end if;
  return v_org;
end $$;

-- lista para a tela do administrador (com o nome da organização criada e o e-mail de quem usou)
create or replace function listar_codigos() returns table (codigo text, para text, expira_em timestamptz, usado_em timestamptz, usado_por_email text, org_nome text, criado_em timestamptz)
language sql stable security definer set search_path = public as $$
  select c.codigo, c.para, c.expira_em, c.usado_em, u.email::text, o.nome, c.criado_em
  from codigos_acesso c left join auth.users u on u.id = c.usado_por left join organizacoes o on o.id = c.org_id
  where sou_admin() order by c.criado_em desc limit 200
$$;

revoke execute on function criar_organizacao(text, text, text, text) from public, anon;
revoke execute on function gerar_codigo_acesso(text, int) from public, anon;
revoke execute on function listar_codigos() from public, anon;
grant execute on function criar_organizacao(text, text, text, text) to authenticated;
grant execute on function gerar_codigo_acesso(text, int) to authenticated;
grant execute on function listar_codigos() to authenticated;
grant execute on function sou_admin() to authenticated;

-- usada só pela Edge Function criar-acesso (chave de serviço): acha a conta pelo e-mail
create or replace function svc_usuario_por_email(p_email text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from auth.users where lower(email) = lower(trim(p_email)) limit 1
$$;
revoke execute on function svc_usuario_por_email(text) from public, anon, authenticated;
grant execute on function svc_usuario_por_email(text) to service_role;

-- usada só pela Edge Function criar-acesso: liga a conta ao cadastro do jogador (fase 2)
create or replace function svc_ligar_jogador(p_jogador uuid, p_org uuid, p_usuario uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('gestao.aceitando_convite', 'sim', true);
  update jogadores set usuario_id = p_usuario where id = p_jogador and org_id = p_org;
  perform set_config('gestao.aceitando_convite', '', true);
end $$;
revoke execute on function svc_ligar_jogador(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function svc_ligar_jogador(uuid, uuid, uuid) to service_role;
