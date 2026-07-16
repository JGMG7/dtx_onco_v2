import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrosService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> loginParticipante(String id, String pin) async {
    final respuesta = await _client.rpc('login_participante', params: {
      'p_id': id,
      'p_pin': pin,
    });

    if (respuesta == null) return null;
    return Map<String, dynamic>.from(respuesta as Map);
  }

  Future<void> guardarRegistroDiario(
    String idParticipante,
    String pin,
    String fecha,
    Map<String, dynamic> datos,
  ) async {
    await _client.rpc('guardar_registro_diario', params: {
      'p_id': idParticipante,
      'p_pin': pin,
      'p_fecha': fecha,
      'p_datos': datos,
    });
  }

  Future<void> crearParticipante({
    required String id,
    required String pin,
    required String grupo,
    required String cohorte,
    required bool verRutina,
  }) async {
    await _client.rpc('crear_participante', params: {
      'p_id': id,
      'p_pin': pin,
      'p_grupo': grupo,
      'p_cohorte': cohorte,
      'p_ver_rutina': verRutina,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerReportes() async {
    final respuesta = await _client.from('registros_diarios').select().order('fecha', ascending: false);
    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorico(String idParticipante) async {
    final respuesta = await _client
        .from('registros_diarios')
        .select()
        .eq('id_participante', idParticipante)
        .order('fecha', ascending: true);
    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<void> marcarComoResuelto(String idReporte) async {
    await _client.from('registros_diarios').update({'atendido': true}).eq('id', idReporte);
  }

  Future<void> guardarSesion(String idReporte, Map<String, dynamic> datos) async {
    await _client.from('registros_diarios').update(datos).eq('id', idReporte);
  }

  Future<({String cohorte, DateTime fechaInicio})> obtenerDatosParticipante(String idParticipante) async {
    final respuesta = await _client
        .from('participantes')
        .select('cohorte, fecha_inicio')
        .eq('id_participante', idParticipante);

    if (respuesta.isEmpty) {
      return (cohorte: 'MAMA', fechaInicio: DateTime.now());
    }

    final fila = respuesta.first;
    return (
      cohorte: (fila['cohorte'] as String?) ?? 'MAMA',
      fechaInicio: DateTime.tryParse((fila['fecha_inicio'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}
