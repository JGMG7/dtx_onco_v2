-- ============================================================
-- EFADAP Oncología — Migración: notas clínicas por participante
-- Ejecutar completo en: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- Contraindicaciones/observaciones individuales (ej. "evitar carga unilateral
-- en brazo derecho por linfedema"), visibles para el profesor en el
-- Cuaderno de Sesión y en el detalle del Dashboard.
alter table public.participantes add column if not exists notas_clinicas text;

-- crear_participante ahora acepta notas clínicas opcionales al enrolar.
-- Se elimina la firma anterior (5 parámetros): al agregar un parámetro nuevo,
-- Postgres lo trataría como una sobrecarga distinta en vez de reemplazarla.
drop function if exists public.crear_participante(text, text, text, text, boolean);

create or replace function public.crear_participante(
  p_id text,
  p_pin text,
  p_grupo text,
  p_cohorte text,
  p_ver_rutina boolean,
  p_notas_clinicas text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.participantes (id_participante, pin_hash, grupo, cohorte, ver_rutina, notas_clinicas)
  values (upper(p_id), crypt(p_pin, gen_salt('bf')), p_grupo, p_cohorte, p_ver_rutina, p_notas_clinicas);
end;
$$;

revoke all on function public.crear_participante(text, text, text, text, boolean, text) from public;
grant execute on function public.crear_participante(text, text, text, text, boolean, text) to authenticated;
