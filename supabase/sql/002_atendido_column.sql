-- ============================================================
-- EFADAP Oncología — Migración: separar "atendido" del semáforo clínico
-- Ejecutar completo en: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- Antes, marcar una alerta como "atendida" sobrescribía el semáforo a verde,
-- perdiendo el color real (🔴/🟡) que tuvo ese día. Esta columna separa ambos
-- conceptos: `semaforo` conserva siempre la severidad clínica real del día;
-- `atendido` indica si el profesor ya dio seguimiento a esa alerta.
alter table public.registros_diarios add column if not exists atendido boolean not null default false;
