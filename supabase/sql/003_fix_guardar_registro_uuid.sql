-- ============================================================
-- EFADAP Oncología — Fix: registros_diarios.id es uuid, no bigint
-- Ejecutar completo en: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- La función guardar_registro_diario asumía que `id` era bigint. En realidad
-- es uuid, así que al intentar actualizar un registro existente (mismo
-- participante + misma fecha) Postgres fallaba con "invalid input syntax
-- for type bigint" (22P02) al convertir el uuid. Se corrige el tipo de la
-- variable interna.
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
  v_existe_id uuid;
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
