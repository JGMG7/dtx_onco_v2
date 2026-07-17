import 'package:flutter/material.dart';
import '../logic/motor_clinico.dart';
import '../services/registros_service.dart';

// ==========================================
// 📝 PANTALLA 4: CUADERNO DE SESIÓN (Profesor)
// ==========================================
class CuadernoSesionScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const CuadernoSesionScreen({super.key, required this.reporte});

  @override
  State<CuadernoSesionScreen> createState() => _CuadernoSesionScreenState();
}

typedef _Contexto = ({
  String cohorte,
  DateTime fechaInicio,
  String? notasClinicas,
  Map<String, dynamic>? ultimaSesion,
  int diasAlerta,
});

class _CuadernoSesionScreenState extends State<CuadernoSesionScreen> {
  final _registrosService = RegistrosService();

  // Escala ordinal 1-6 que traza a los materiales reales del kit EFADAP
  // (ver "ENTREGA DE MATERIALES PARA PLAN PILOTO"). Se guarda como número en
  // la misma columna kilos_ejercicio_N (no es Kg, es un nivel de resistencia).
  static const List<String> _nivelesDisponibles = [
    'Mini Band Media',
    'Mini Band Alta',
    'Banda Tubular Media',
    'Banda Tubular Alta',
    'Banda Tubular Fuerte',
    'Banda Elástica Fuerte (2m)',
  ];
  static const Map<String, double> _nivelANumero = {
    'Mini Band Media': 1.0,
    'Mini Band Alta': 2.0,
    'Banda Tubular Media': 3.0,
    'Banda Tubular Alta': 4.0,
    'Banda Tubular Fuerte': 5.0,
    'Banda Elástica Fuerte (2m)': 6.0,
  };

  final List<TextEditingController> _kilosControllers = [
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
  ];
  final List<String> _nivelesBanda = List.generate(4, (_) => _nivelesDisponibles.first);
  double _rpeSesion = 6;
  bool _isSaving = false;
  late final Future<_Contexto> _contextoFuture;

  @override
  void initState() {
    super.initState();
    _contextoFuture = _cargarContexto();
  }

  Future<_Contexto> _cargarContexto() async {
    final fechaReporte = DateTime.parse(widget.reporte['fecha']);
    final diaSemana = fechaReporte.weekday;
    final idParticipante = widget.reporte['id_participante'] as String;

    final datosParticipante = await _registrosService.obtenerDatosParticipante(idParticipante);
    final ultimaSesion = await _registrosService.obtenerUltimaSesionMismoDia(idParticipante, fechaReporte, diaSemana);
    final diasAlerta = await _registrosService.obtenerDiasAlertaUltimos7(idParticipante, fechaReporte);

    return (
      cohorte: datosParticipante.cohorte,
      fechaInicio: datosParticipante.fechaInicio,
      notasClinicas: datosParticipante.notasClinicas,
      ultimaSesion: ultimaSesion,
      diasAlerta: diasAlerta,
    );
  }

  Future<void> _guardarSesion(List<Ejercicio> rutina) async {
    setState(() => _isSaving = true);
    try {
      final List<double> cargas = List.generate(4, (i) {
        switch (rutina[i].tipoCarga) {
          case TipoCarga.peso:
            return double.tryParse(_kilosControllers[i].text) ?? 0.0;
          case TipoCarga.banda:
            return _nivelANumero[_nivelesBanda[i]] ?? 1.0;
          case TipoCarga.corporal:
            return 0.0;
        }
      });

      final datosSesion = {
        "estado_sesion": "Completado",
        "rpe_sesion": _rpeSesion.toInt(),
        "ejercicio_1": rutina[0].nombre, "kilos_ejercicio_1": cargas[0],
        "ejercicio_2": rutina[1].nombre, "kilos_ejercicio_2": cargas[1],
        "ejercicio_3": rutina[2].nombre, "kilos_ejercicio_3": cargas[2],
        "ejercicio_4": rutina[3].nombre, "kilos_ejercicio_4": cargas[3],
        "atendido": true,
      };

      await _registrosService.guardarSesion(widget.reporte['id'], datosSesion);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Sesión L-M-V guardada con éxito'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (var c in _kilosControllers) { c.dispose(); }
    super.dispose();
  }

  String _formatearCarga(dynamic valor, TipoCarga tipo) {
    final numero = (valor as num?)?.toDouble() ?? 0.0;
    switch (tipo) {
      case TipoCarga.peso:
        return '${numero.toStringAsFixed(1)}kg';
      case TipoCarga.banda:
        return _nivelANumero.entries
            .firstWhere((e) => e.value == numero, orElse: () => const MapEntry('nivel desconocido', 0))
            .key;
      case TipoCarga.corporal:
        return 'peso corporal';
    }
  }

  String? _sugerenciaPara(int i, TipoCarga tipo, Map<String, dynamic>? ultimaSesion) {
    if (ultimaSesion == null || tipo == TipoCarga.corporal) return null;
    final rpeSesionRaw = ultimaSesion['rpe_sesion'];
    if (rpeSesionRaw == null) return null;

    final rpe = (rpeSesionRaw as num).toInt();
    final String direccion;
    if (rpe <= 5) {
      direccion = '🔼 Considera subir';
    } else if (rpe <= 7) {
      direccion = '➡️ Mantener';
    } else {
      direccion = '🔽 Mantener o bajar';
    }

    final cargaAnterior = _formatearCarga(ultimaSesion['kilos_ejercicio_${i + 1}'], tipo);
    final fechaAnterior = DateTime.parse(ultimaSesion['fecha'] as String);
    return 'Última vez (${fechaAnterior.day}/${fechaAnterior.month}): $cargaAnterior · RPE sesión $rpe → $direccion';
  }

  Widget _campoParaEjercicio(int i, Ejercicio ejercicio, Map<String, dynamic>? ultimaSesion) {
    final sugerencia = _sugerenciaPara(i, ejercicio.tipoCarga, ultimaSesion);

    Widget campo;
    switch (ejercicio.tipoCarga) {
      case TipoCarga.peso:
        campo = TextFormField(
          controller: _kilosControllers[i],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '${i + 1}. ${ejercicio.nombre} (Kg)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.fitness_center),
          ),
        );
        break;
      case TipoCarga.banda:
        campo = DropdownButtonFormField<String>(
          initialValue: _nivelesBanda[i],
          decoration: InputDecoration(
            labelText: '${i + 1}. ${ejercicio.nombre} (Banda)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.circle_outlined),
          ),
          items: _nivelesDisponibles.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (valor) => setState(() => _nivelesBanda[i] = valor!),
        );
        break;
      case TipoCarga.corporal:
        campo = ListTile(
          tileColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          leading: const Icon(Icons.accessibility_new),
          title: Text('${i + 1}. ${ejercicio.nombre}'),
          subtitle: const Text('Peso corporal — sin carga que registrar'),
        );
        break;
    }

    if (sugerencia == null) return campo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        campo,
        Padding(
          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
          child: Text(sugerencia, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime fechaReporte = DateTime.parse(widget.reporte['fecha']);
    final int diaSemana = fechaReporte.weekday;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuaderno de Sesión: ${widget.reporte['id_participante']}'),
        backgroundColor: Colors.cyan.shade100,
      ),
      body: FutureBuilder<_Contexto>(
        future: _contextoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contexto = snapshot.data;
          final String cohorte = contexto?.cohorte ?? 'MAMA';
          final DateTime fechaInicio = contexto?.fechaInicio ?? fechaReporte;
          final int semanaPrograma = MotorClinico.calcularSemanaPrograma(fechaInicio, fechaReporte);
          final List<Ejercicio> rutina = MotorClinico.obtenerRutina(cohorte, diaSemana);
          final String intensidad = MotorClinico.obtenerIntensidad(semanaPrograma, diaSemana);
          final bool esExploracion = MotorClinico.esFaseExploracion(semanaPrograma);
          final int diasAlerta = contexto?.diasAlerta ?? 0;
          final String? notasClinicas = contexto?.notasClinicas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notasClinicas != null && notasClinicas.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Notas clínicas: $notasClinicas', style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (diasAlerta >= 3) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                        child: Text(
                          '⚠️ Carga alostática elevada: $diasAlerta de los últimos 7 días en alerta (🟡/🔴). Considera no progresar el bloque esta sesión.',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (esExploracion) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          '🔍 Fase de Exploración: hoy el objetivo es encontrar la carga de referencia (ramp-up dentro de la sesión), no aplicarla.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('🎯 Periodización: $intensidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Divider(height: 32),
                    const Text('📋 Registro de Carga de la Sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    ...List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _campoParaEjercicio(i, rutina[i], contexto?.ultimaSesion),
                      );
                    }),

                    const Divider(height: 32),
                    const Text('Escala de Borg CR10 (Carga Interna de la Sesión):', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _rpeSesion, min: 0, max: 10, divisions: 10,
                      activeColor: Colors.purple,
                      label: _rpeSesion.toInt().toString(),
                      onChanged: (val) => setState(() => _rpeSesion = val),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: _isSaving
                          ? const FilledButton(onPressed: null, child: CircularProgressIndicator())
                          : FilledButton.icon(
                              onPressed: () => _guardarSesion(rutina),
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar Sesión L-M-V 💾', style: TextStyle(fontSize: 18)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
