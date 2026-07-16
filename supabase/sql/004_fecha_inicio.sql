-- ============================================================
-- EFADAP Oncología — Migración: fecha de inicio del programa por participante
-- Ejecutar completo en: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- Necesaria para calcular en qué semana del programa de 12 semanas está cada
-- participante. Los participantes existentes quedan con la fecha de hoy
-- (arrancan en semana 1); cada participante nuevo enrolado por el profesor
-- toma automáticamente la fecha real de enrolamiento vía este mismo default.
alter table public.participantes add column if not exists fecha_inicio date not null default current_date;

-- login_participante ahora también devuelve fecha_inicio, para que la app
-- pueda calcular la semana del programa sin una consulta adicional.
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
    'ver_rutina', fila.ver_rutina,
    'fecha_inicio', fila.fecha_inicio
  );
end;
$$;

revoke all on function public.login_participante(text, text) from public;
grant execute on function public.login_participante(text, text) to anon, authenticated;
