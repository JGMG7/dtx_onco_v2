// TODO(seguridad): mover a --dart-define / variables de entorno antes de producción.
class SupabaseConfig {
  static const String url = 'https://mxjihlciggfuxznqunpr.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14amlobGNpZ2dmdXh6bnF1bnByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NTAwNDMsImV4cCI6MjA5NTEyNjA0M30.rWBDLNeNZJlmTEHQE_IRhKqlf9Wtc5Zv8RVJeh5ULoM';

  // Cuenta técnica compartida del equipo docente en Supabase Auth.
  // Debe crearse manualmente en Dashboard -> Authentication -> Users.
  static const String professorAuthEmail = 'equipo.efadap@auth.local';
}
