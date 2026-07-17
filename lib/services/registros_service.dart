import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resumen_participante.dart';

enum ResultadoEnvio { enviado, guardadoLocalmente }

class RegistrosService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _prefijoPendiente = 'pendiente_registro_';

  Future<Map<String, dynamic>?> loginParticipante(String id, String pin) async {
    final respuesta = await _client.rpc('login_participante', params: {
      'p_id': id,
      'p_pin': pin,
    });

    if (respuesta == null) return null;
    return Map<String, dynamic>.from(respuesta as Map);
  }

  // Si falla por falta de conexión (el request nunca llega al servidor), el
  // registro se guarda en el dispositivo y se reintenta más tarde en vez de
  // perder lo que el paciente escribió. Si el servidor sí respondió con un
  // error real (PostgrestException/AuthException), no tiene sentido
  // reintentar solo: se relanza para que se muestre como error de verdad.
  Future<ResultadoEnvio> guardarRegistroDiario(
    String idParticipante,
    String pin,
    String fecha,
    Map<String, dynamic> datos,
  ) async {
    try {
      await _client.rpc('guardar_registro_diario', params: {
        'p_id': idParticipante,
        'p_pin': pin,
        'p_fecha': fecha,
        'p_datos': datos,
      });
      return ResultadoEnvio.enviado;
    } catch (e) {
      if (e is PostgrestException || e is AuthException) rethrow;
      await _guardarPendienteLocal(idParticipante, pin, fecha, datos);
      return ResultadoEnvio.guardadoLocalmente;
    }
  }

  Future<void> _guardarPendienteLocal(
    String idParticipante,
    String pin,
    String fecha,
    Map<String, dynamic> datos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'idParticipante': idParticipante,
      'pin': pin,
      'fecha': fecha,
      'datos': datos,
    });
    await prefs.setString('$_prefijoPendiente$idParticipante', payload);
  }

  // Reintenta cualquier registro guardado localmente por falta de conexión.
  // Pensado para llamarse "fire-and-forget" al iniciar la app y al entrar al
  // login de paciente — no bloquea la UI ni lanza errores hacia arriba.
  Future<void> sincronizarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final claves = prefs.getKeys().where((k) => k.startsWith(_prefijoPendiente)).toList();

    for (final clave in claves) {
      final raw = prefs.getString(clave);
      if (raw == null) continue;

      try {
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        await _client.rpc('guardar_registro_diario', params: {
          'p_id': payload['idParticipante'],
          'p_pin': payload['pin'],
          'p_fecha': payload['fecha'],
          'p_datos': payload['datos'],
        });
        await prefs.remove(clave);
      } catch (_) {
        // Sigue sin conexión (u otro error transitorio): se reintenta la próxima vez.
      }
    }
  }

  Future<void> crearParticipante({
    required String id,
    required String pin,
    required String grupo,
    required String cohorte,
    required bool verRutina,
    String? notasClinicas,
  }) async {
    await _client.rpc('crear_participante', params: {
      'p_id': id,
      'p_pin': pin,
      'p_grupo': grupo,
      'p_cohorte': cohorte,
      'p_ver_rutina': verRutina,
      'p_notas_clinicas': notasClinicas,
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

  Future<({String cohorte, DateTime fechaInicio, String? notasClinicas})> obtenerDatosParticipante(
      String idParticipante) async {
    final respuesta = await _client
        .from('participantes')
        .select('cohorte, fecha_inicio, notas_clinicas')
        .eq('id_participante', idParticipante);

    if (respuesta.isEmpty) {
      return (cohorte: 'MAMA', fechaInicio: DateTime.now(), notasClinicas: null);
    }

    final fila = respuesta.first;
    return (
      cohorte: (fila['cohorte'] as String?) ?? 'MAMA',
      fechaInicio: DateTime.tryParse((fila['fecha_inicio'] as String?) ?? '') ?? DateTime.now(),
      notasClinicas: fila['notas_clinicas'] as String?,
    );
  }

  // Sesión anterior más reciente del mismo día de la semana (mismos
  // ejercicios prescritos), para mostrarle al profesor la carga usada la
  // vez pasada y una referencia de progresión.
  Future<Map<String, dynamic>?> obtenerUltimaSesionMismoDia(
    String idParticipante,
    DateTime antesDe,
    int diaSemana,
  ) async {
    final historico = await obtenerHistorico(idParticipante);
    final anteriores = historico.where((r) {
      if (r['estado_sesion'] != 'Completado') return false;
      final fecha = DateTime.parse(r['fecha'] as String);
      return fecha.weekday == diaSemana && fecha.isBefore(antesDe);
    }).toList();

    if (anteriores.isEmpty) return null;
    anteriores.sort((a, b) => DateTime.parse(a['fecha'] as String).compareTo(DateTime.parse(b['fecha'] as String)));
    return anteriores.last;
  }

  // Cuenta cuántos de los últimos 7 días (relativo a fechaReferencia) el
  // participante estuvo en semáforo amarillo o rojo — señal de carga
  // alostática acumulada, más allá del estado puntual de hoy.
  Future<int> obtenerDiasAlertaUltimos7(String idParticipante, DateTime fechaReferencia) async {
    final historico = await obtenerHistorico(idParticipante);
    final desde = fechaReferencia.subtract(const Duration(days: 6));

    return historico.where((r) {
      final fecha = DateTime.parse(r['fecha'] as String);
      if (fecha.isBefore(desde) || fecha.isAfter(fechaReferencia)) return false;
      final semaforo = (r['semaforo'] as String?) ?? '';
      return semaforo.contains('ROJO') || semaforo.contains('AMARILLO');
    }).length;
  }

  Future<List<ResumenParticipante>> obtenerResumenAdherencia() async {
    final participantesResp = await _client.from('participantes').select('id_participante, grupo, cohorte');
    final registrosResp = await _client.from('registros_diarios').select('id_participante, fecha');

    final Map<String, DateTime> ultimoPorParticipante = {};
    for (final r in registrosResp) {
      final id = r['id_participante'] as String;
      final fecha = DateTime.parse(r['fecha'] as String);
      final actual = ultimoPorParticipante[id];
      if (actual == null || fecha.isAfter(actual)) {
        ultimoPorParticipante[id] = fecha;
      }
    }

    final hoy = DateTime.now();
    final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);

    final lista = participantesResp.map((p) {
      final id = p['id_participante'] as String;
      final ultimo = ultimoPorParticipante[id];
      final diasSinRegistro = ultimo == null
          ? null
          : hoyFecha.difference(DateTime(ultimo.year, ultimo.month, ultimo.day)).inDays;

      return ResumenParticipante(
        idParticipante: id,
        grupo: p['grupo'] as String?,
        cohorte: (p['cohorte'] as String?) ?? 'MAMA',
        ultimoRegistro: ultimo,
        diasSinRegistro: diasSinRegistro,
        registroHoy: diasSinRegistro == 0,
      );
    }).toList();

    lista.sort((a, b) => (b.diasSinRegistro ?? 9999).compareTo(a.diasSinRegistro ?? 9999));

    return lista;
  }
}
