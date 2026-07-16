import 'package:flutter/material.dart';
import '../services/registros_service.dart';
import 'login_screen.dart';
import 'prescripcion_screen.dart';

// ==========================================
// 📱 PANTALLA 1: REGISTRO DIARIO DEL PACIENTE
// ==========================================
class RegistroDiarioScreen extends StatefulWidget {
  final String idParticipante;
  final String pin;
  final String? grupo;
  final String cohorte;
  final bool verRutina;
  final DateTime fechaInicio;

  const RegistroDiarioScreen({
    super.key,
    required this.idParticipante,
    required this.pin,
    this.grupo,
    required this.cohorte,
    required this.verRutina,
    required this.fechaInicio,
  });

  @override
  State<RegistroDiarioScreen> createState() => _RegistroDiarioScreenState();
}

class _RegistroDiarioScreenState extends State<RegistroDiarioScreen> {
  final _registrosService = RegistrosService();

  TimeOfDay _horaAcostar = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _horaDespertar = const TimeOfDay(hour: 6, minute: 30);

  final _latenciaController = TextEditingController(text: '15');
  final _despertaresController = TextEditingController(text: '0');

  String _calidadSueno = 'Bueno';
  final List<String> _opcionesCalidad = ['Malo', 'Regular', 'Bueno', 'Reparador'];

  double _animoValue = 3;
  final List<String> _etiquetasAnimo = ['Muy mal', 'Mal', 'Regular', 'Bien', 'Muy Bien', 'Excelente'];

  final _solHorasController = TextEditingController(text: '0');
  final _solMinutosController = TextEditingController(text: '15');

  double _fatigaValue = 2;
  double _estresValue = 2;

  final List<String> _opcionesZonas = ['Hombro Izq', 'Hombro Der', 'Lumbar', 'Rodillas', 'Hormigueo en Manos/Pies'];
  final Map<String, double> _doloresZonas = {};
  bool _isSubmitting = false;

  Future<void> _enviarReporte() async {
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      DateTime dtAcostar = DateTime(now.year, now.month, now.day, _horaAcostar.hour, _horaAcostar.minute);
      DateTime dtDespertar = DateTime(now.year, now.month, now.day, _horaDespertar.hour, _horaDespertar.minute);

      if (dtDespertar.isBefore(dtAcostar) || dtDespertar.isAtSameMomentAs(dtAcostar)) {
        dtDespertar = dtDespertar.add(const Duration(days: 1));
      }

      final double tCama = dtDespertar.difference(dtAcostar).inMinutes.toDouble();
      final int latencia = int.tryParse(_latenciaController.text) ?? 15;
      final int despertares = int.tryParse(_despertaresController.text) ?? 0;

      final double tDormido = (tCama - latencia - (despertares * 10)).clamp(0, tCama);
      final double eficiencia = tCama > 0 ? (tDormido / tCama) * 100 : 0.0;

      double dolorMax = 0;
      if (_doloresZonas.isNotEmpty) dolorMax = _doloresZonas.values.reduce((a, b) => a > b ? a : b);

      final String zonasDolorTxt = _doloresZonas.isNotEmpty ? _doloresZonas.keys.join(", ") : "Ninguna";
      final String estadoAnimoTxt = _etiquetasAnimo[_animoValue.toInt()];

      int solHoras = int.tryParse(_solHorasController.text) ?? 0;
      int solMinutos = int.tryParse(_solMinutosController.text) ?? 0;
      int exposicionSolMin = (solHoras * 60) + solMinutos;

      String semaforo = "🟢 VERDE";

      if (_fatigaValue >= 8 || dolorMax >= 7 || estadoAnimoTxt == "Muy mal" || estadoAnimoTxt == "Mal") {
        semaforo = "🔴 ROJO";
      } else if (eficiencia < 85.0 || latencia > 45 || _fatigaValue >= 5 || _estresValue >= 6 || estadoAnimoTxt == "Regular") {
        semaforo = "🟡 AMARILLO";
      }

      String hoyStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final Map<String, dynamic> datosTriage = {
        "id_participante": widget.idParticipante,
        "fecha": hoyStr,
        "estado_triage": "Completado",
        "semaforo": semaforo,
        "eficiencia_sueno": eficiencia,
        "latencia_min": latencia,
        "despertares_veces": despertares,
        "calidad_sueno": _calidadSueno,
        "estado_animo": estadoAnimoTxt,
        "exposicion_sol_min": exposicionSolMin,
        "fatiga_bfi": _fatigaValue.toInt(),
        "estres_nccn": _estresValue.toInt(),
        "dolor_maximo": dolorMax.toInt(),
        "zonas_dolor": zonasDolorTxt
      };

      await _registrosService.guardarRegistroDiario(widget.idParticipante, widget.pin, hoyStr, datosTriage);

      if (!context.mounted) return;
      if (widget.verRutina && widget.grupo != 'CONTROL' && (now.weekday == 1 || now.weekday == 3 || now.weekday == 5)) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PrescripcionScreen(cohorte: widget.cohorte, semaforo: semaforo, fechaInicio: widget.fechaInicio)),
          );
      } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Registro guardado con éxito!'), backgroundColor: Colors.green));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📡 Error al enviar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _latenciaController.dispose();
    _despertaresController.dispose();
    _solHorasController.dispose();
    _solMinutosController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarHora(BuildContext context, bool esAcostar) async {
    final TimeOfDay? seleccionada = await showTimePicker(context: context, initialTime: esAcostar ? _horaAcostar : _horaDespertar);
    if (seleccionada != null) {
      setState(() {
        if (esAcostar) _horaAcostar = seleccionada;
        else _horaDespertar = seleccionada;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro Diario', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Hola, ${widget.idParticipante}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    widget.grupo == 'CONTROL' ? 'Tu reporte diario es vital para comprender la evolución.' : 'Tu reporte ajustará la dosis de tu entrenamiento.',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.bedtime, color: Colors.teal), SizedBox(width: 8), Text('1. Arquitectura y Calidad del Sueño', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(child: ListTile(title: const Text('🛌 Acostarse', style: TextStyle(fontSize: 12)), subtitle: Text(_horaAcostar.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)), onTap: () => _seleccionarHora(context, true))),
                              Expanded(child: ListTile(title: const Text('🌅 Despertarse', style: TextStyle(fontSize: 12)), subtitle: Text(_horaDespertar.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)), onTap: () => _seleccionarHora(context, false))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _latenciaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '⏱️ Min. para dormir', border: OutlineInputBorder()))),
                              const SizedBox(width: 12),
                              Expanded(child: TextFormField(controller: _despertaresController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '🔄 N° despertares', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _calidadSueno,
                            decoration: const InputDecoration(labelText: '⭐ Calidad global del sueño', border: OutlineInputBorder(), prefixIcon: Icon(Icons.star, color: Colors.amber)),
                            items: _opcionesCalidad.map((String valor) { return DropdownMenuItem<String>(value: valor, child: Text(valor)); }).toList(),
                            onChanged: (nuevoValor) => setState(() => _calidadSueno = nuevoValor!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.psychology, color: Colors.blue), SizedBox(width: 8), Text('2. Estado de Ánimo y Sol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                          const Divider(height: 24),
                          Text('¿Cómo te sientes hoy?: ${_etiquetasAnimo[_animoValue.toInt()]}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Slider(value: _animoValue, min: 0, max: 5, divisions: 5, activeColor: Colors.blue, label: _etiquetasAnimo[_animoValue.toInt()], onChanged: (valor) => setState(() => _animoValue = valor)),
                          const SizedBox(height: 16),
                          const Text('Exposición directa al sol ayer:', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _solHorasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas', border: OutlineInputBorder()))),
                              const SizedBox(width: 12),
                              Expanded(child: TextFormField(controller: _solMinutosController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos', border: OutlineInputBorder()))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.battery_charging_full, color: Colors.orange), SizedBox(width: 8), Text('3. Fatiga y Estrés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                          const Divider(height: 24),
                          Text('Fatiga física: ${_fatigaValue.toInt()} (0=Energía | 10=Agotamiento)'),
                          Slider(value: _fatigaValue, min: 0, max: 10, divisions: 10, activeColor: Colors.orange, label: _fatigaValue.toInt().toString(), onChanged: (valor) => setState(() => _fatigaValue = valor)),
                          const SizedBox(height: 16),
                          Text('Estrés/Ansiedad: ${_estresValue.toInt()} (0=Paz | 10=Angustia)'),
                          Slider(value: _estresValue, min: 0, max: 10, divisions: 10, activeColor: Colors.deepOrange, label: _estresValue.toInt().toString(), onChanged: (valor) => setState(() => _estresValue = valor)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.accessibility_new, color: Colors.red), SizedBox(width: 8), Text('4. Dolor Corporal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                          const Divider(height: 24),
                          const Text('📍 Toca las zonas afectadas (si las hay):', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0, runSpacing: 4.0,
                            children: _opcionesZonas.map((zona) {
                              final isSelected = _doloresZonas.containsKey(zona);
                              return FilterChip(
                                label: Text(zona), selected: isSelected, selectedColor: Colors.red.shade100, checkmarkColor: Colors.red,
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) _doloresZonas[zona] = 5.0;
                                    else _doloresZonas.remove(zona);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          if (_doloresZonas.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Intensidad del dolor por zona (1 a 10):', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            ..._doloresZonas.keys.map((zona) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$zona: ${_doloresZonas[zona]!.toInt()}'),
                                  Slider(value: _doloresZonas[zona]!, min: 1, max: 10, divisions: 9, activeColor: Colors.redAccent, label: _doloresZonas[zona]!.toInt().toString(), onChanged: (valor) => setState(() => _doloresZonas[zona] = valor)),
                                ],
                              );
                            }),
                          ] else ...[
                            const SizedBox(height: 16),
                            const Text('✅ Ninguna zona con dolor reportada.', style: TextStyle(color: Colors.green)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity, height: 55,
                    child: _isSubmitting
                        ? const FilledButton(onPressed: null, child: CircularProgressIndicator())
                        : FilledButton(
                            onPressed: _enviarReporte,
                            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                            child: Text(widget.grupo == 'CONTROL' ? 'Enviar Registro Diario 🚀' : 'Enviar Reporte 🚀', style: const TextStyle(fontSize: 18)),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
