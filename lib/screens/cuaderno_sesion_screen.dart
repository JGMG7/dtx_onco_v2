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

class _CuadernoSesionScreenState extends State<CuadernoSesionScreen> {
  final _registrosService = RegistrosService();

  static const List<String> _nivelesDisponibles = ['Media', 'Alta', 'Fuerte'];
  static const Map<String, double> _nivelANumero = {'Media': 1.0, 'Alta': 2.0, 'Fuerte': 3.0};

  final List<TextEditingController> _kilosControllers = [
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
  ];
  final List<String> _nivelesBanda = List.generate(4, (_) => 'Media');
  double _rpeSesion = 6;
  bool _isSaving = false;
  late final Future<({String cohorte, DateTime fechaInicio})> _datosParticipanteFuture;

  @override
  void initState() {
    super.initState();
    _datosParticipanteFuture = _registrosService.obtenerDatosParticipante(widget.reporte['id_participante']);
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

  Widget _campoParaEjercicio(int i, Ejercicio ejercicio) {
    switch (ejercicio.tipoCarga) {
      case TipoCarga.peso:
        return TextFormField(
          controller: _kilosControllers[i],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '${i + 1}. ${ejercicio.nombre} (Kg)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.fitness_center),
          ),
        );
      case TipoCarga.banda:
        return DropdownButtonFormField<String>(
          initialValue: _nivelesBanda[i],
          decoration: InputDecoration(
            labelText: '${i + 1}. ${ejercicio.nombre} (Nivel de Banda)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.circle_outlined),
          ),
          items: _nivelesDisponibles.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (valor) => setState(() => _nivelesBanda[i] = valor!),
        );
      case TipoCarga.corporal:
        return ListTile(
          tileColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          leading: const Icon(Icons.accessibility_new),
          title: Text('${i + 1}. ${ejercicio.nombre}'),
          subtitle: const Text('Peso corporal — sin carga que registrar'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime fechaReporte = DateTime.parse(widget.reporte['fecha']);
    final int diaSemana = fechaReporte.weekday;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuaderno de Sesión: ${widget.reporte['id_participante']}'),
        backgroundColor: Colors.blueGrey.shade100,
      ),
      body: FutureBuilder<({String cohorte, DateTime fechaInicio})>(
        future: _datosParticipanteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final String cohorte = snapshot.data?.cohorte ?? 'MAMA';
          final DateTime fechaInicio = snapshot.data?.fechaInicio ?? fechaReporte;
          final int semanaPrograma = MotorClinico.calcularSemanaPrograma(fechaInicio, fechaReporte);
          final List<Ejercicio> rutina = MotorClinico.obtenerRutina(cohorte, diaSemana);
          final String intensidad = MotorClinico.obtenerIntensidad(semanaPrograma, diaSemana);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎯 Periodización: $intensidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Divider(height: 32),
                    const Text('📋 Registro de Carga de la Sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    ...List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _campoParaEjercicio(i, rutina[i]),
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
