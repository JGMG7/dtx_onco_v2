-- ============================================================
-- EFADAP Oncología — Migración: Auth + RLS + PIN hasheado
-- Ejecutar completo en: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1. Extensión necesaria para hashear PINs (bcrypt vía pgcrypto).
--    Supabase la instala en el esquema `extensions`, por eso las funciones de abajo
--    incluyen `extensions` en su search_path (si no, crypt()/gen_salt() no se encuentran).
create extension if not exists pgcrypto;

-- 2. Columna nueva para el PIN hasheado (no reemplaza aún la columna vieja `pin`)
alter table public.participantes add column if not exists pin_hash text;

-- 3. Migra automáticamente los PIN existentes en texto plano al nuevo hash.
--    Así el/los participante(s) de prueba actuales siguen funcionando con el mismo PIN.
update public.participantes
set pin_hash = crypt(pin, gen_salt('bf'))
where pin_hash is null and pin is not null;

-- 4. Activa Row Level Security en ambas tablas.
--    A partir de aquí, sin una policy explícita, el acceso queda bloqueado por defecto.
alter table public.participantes enable row level security;
alter table public.registros_diarios enable row level security;

-- 5. Policies para el profesor (rol `authenticated`, sesión real de Supabase Auth).
--    El rol `anon` (paciente) NO tiene ninguna policy: queda bloqueado para acceso
--    directo a las tablas. Todo el acceso del paciente pasa por las funciones RPC de abajo.

drop policy if exists "profesores_select_participantes" on public.participantes;
create policy "profesores_select_participantes"
  on public.participantes
  for select
  to authenticated
  using (true);

drop policy if exists "profesores_select_registros" on public.registros_diarios;
create policy "profesores_select_registros"
  on public.registros_diarios
  for select
  to authenticated
  using (true);

drop policy if exists "profesores_update_registros" on public.registros_diarios;
create policy "profesores_update_registros"
  on public.registros_diarios
  for update
  to authenticated
  using (true)
  with check (true);

-- 6. RPC: login de paciente (reemplaza el SELECT directo con PIN en texto plano)
create or replace function public.login_participante(p_id text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  fila public.participantes%rowtype;
begin
  select * into fila
  from public.participantes
  where id_participante = p_id
    and pin_hash is not null
    and pin_hash = crypt(p_pin, pin_hash);

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id_participante', fila.id_participante,
    'grupo', fila.grupo,
    'cohorte', fila.cohorte,
    'ver_rutina', fila.ver_rutina
  );
end;
$$;

revoke all on function public.login_participante(text, text) from public;
grant execute on function public.login_participante(text, text) to anon, authenticated;

-- 7. RPC: guardar registro diario del paciente (revalida PIN en cada llamada,
--    porque el paciente no tiene sesión persistente que RLS pueda verificar).
--    Reproduce la lógica actual: si ya existe un registro para esa fecha, actualiza; si no, inserta.
create or replace function public.guardar_registro_diario(
  p_id text,
  p_pin text,
  p_fecha date,
  p_datos jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_existe_id uuid; -- registros_diarios.id es uuid
begin
  if not exists (
    select 1 from public.participantes
    where id_participante = p_id
      and pin_hash is not null
      and pin_hash = crypt(p_pin, pin_hash)
  ) then
    raise exception 'Credenciales inválidas';
  end if;

  select id into v_existe_id
  from public.registros_diarios
  where id_participante = p_id and fecha = p_fecha;

  if v_existe_id is not null then
    update public.registros_diarios
    set
      estado_triage       = coalesce(p_datos->>'estado_triage', estado_triage),
      semaforo             = coalesce(p_datos->>'semaforo', semaforo),
      eficiencia_sueno     = coalesce((p_datos->>'eficiencia_sueno')::numeric, eficiencia_sueno),
      latencia_min         = coalesce((p_datos->>'latencia_min')::int, latencia_min),
      despertares_veces    = coalesce((p_datos->>'despertares_veces')::int, despertares_veces),
      calidad_sueno        = coalesce(p_datos->>'calidad_sueno', calidad_sueno),
      estado_animo         = coalesce(p_datos->>'estado_animo', estado_animo),
      exposicion_sol_min   = coalesce((p_datos->>'exposicion_sol_min')::int, exposicion_sol_min),
      fatiga_bfi           = coalesce((p_datos->>'fatiga_bfi')::int, fatiga_bfi),
      estres_nccn          = coalesce((p_datos->>'estres_nccn')::int, estres_nccn),
      dolor_maximo         = coalesce((p_datos->>'dolor_maximo')::int, dolor_maximo),
      zonas_dolor          = coalesce(p_datos->>'zonas_dolor', zonas_dolor)
    where id = v_existe_id;
  else
    insert into public.registros_diarios (
      id_participante, fecha, estado_triage, semaforo, eficiencia_sueno,
      latencia_min, despertares_veces, calidad_sueno, estado_animo,
      exposicion_sol_min, fatiga_bfi, estres_nccn, dolor_maximo, zonas_dolor
    ) values (
      p_id, p_fecha,
      p_datos->>'estado_triage',
      p_datos->>'semaforo',
      (p_datos->>'eficiencia_sueno')::numeric,
      (p_datos->>'latencia_min')::int,
      (p_datos->>'despertares_veces')::int,
      p_datos->>'calidad_sueno',
      p_datos->>'estado_animo',
      (p_datos->>'exposicion_sol_min')::int,
      (p_datos->>'fatiga_bfi')::int,
      (p_datos->>'estres_nccn')::int,
      (p_datos->>'dolor_maximo')::int,
      p_datos->>'zonas_dolor'
    );
  end if;
end;
$$;

revoke all on function public.guardar_registro_diario(text, text, date, jsonb) from public;
grant execute on function public.guardar_registro_diario(text, text, date, jsonb) to anon;

-- 8. RPC: crear participante (solo el profesor autenticado puede enrolar).
--    Hashea el PIN server-side; el cliente nunca envía ni calcula el hash.
create or replace function public.crear_participante(
  p_id text,
  p_pin text,
  p_grupo text,
  p_cohorte text,
  p_ver_rutina boolean
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.participantes (id_participante, pin_hash, grupo, cohorte, ver_rutina)
  values (upper(p_id), crypt(p_pin, gen_salt('bf')), p_grupo, p_cohorte, p_ver_rutina);
end;
$$;

revoke all on function public.crear_participante(text, text, text, text, boolean) from public;
grant execute on function public.crear_participante(text, text, text, text, boolean) to authenticated;

-- ============================================================
-- PASO OPCIONAL — ejecutar aparte, solo después de confirmar que
-- el login y el registro diario funcionan correctamente en la app.
-- Es DESTRUCTIVO: borra el PIN en texto plano permanentemente.
-- ============================================================
-- alter table public.participantes drop column pin;
