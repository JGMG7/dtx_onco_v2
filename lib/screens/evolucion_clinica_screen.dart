import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/registros_service.dart';

// ==========================================
// 📈 PANTALLA 5: EVOLUCIÓN CLÍNICA (Gráficos)
// ==========================================
class EvolucionClinicaScreen extends StatefulWidget {
  final String idParticipante;

  const EvolucionClinicaScreen({super.key, required this.idParticipante});

  @override
  State<EvolucionClinicaScreen> createState() => _EvolucionClinicaScreenState();
}

class _EvolucionClinicaScreenState extends State<EvolucionClinicaScreen> {
  final _registrosService = RegistrosService();

  Future<List<Map<String, dynamic>>> _obtenerHistorico() {
    return _registrosService.obtenerHistorico(widget.idParticipante);
  }

  Widget _construirGrafico(List<Map<String, dynamic>> datos, String titulo, String clave1, String clave2, Color color1, Color color2, [double? maxY]) {
    if (datos.length < 2) return const SizedBox.shrink();

    List<FlSpot> puntosLinea1 = [];
    List<FlSpot> puntosLinea2 = [];

    for (int i = 0; i < datos.length; i++) {
      double val1 = (datos[i][clave1] is num) ? (datos[i][clave1] as num).toDouble() : 0.0;
      double val2 = (datos[i][clave2] is num) ? (datos[i][clave2] as num).toDouble() : 0.0;
      puntosLinea1.add(FlSpot(i.toDouble(), val1));
      puntosLinea2.add(FlSpot(i.toDouble(), val2));
    }

    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: color1, size: 12), const SizedBox(width: 4), Text(clave1),
            const SizedBox(width: 16),
            Icon(Icons.circle, color: color2, size: 12), const SizedBox(width: 4), Text(clave2),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
              minX: 0,
              maxX: (datos.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(spots: puntosLinea1, isCurved: true, color: color1, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: true)),
                LineChartBarData(spots: puntosLinea2, isCurved: true, color: color2, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: true)),
              ],
            ),
          ),
        ),
        const Divider(height: 48),
      ],
    );
  }

  Widget _construirGraficoUnico(List<Map<String, dynamic>> datos, String titulo, String clave, Color color, [double? maxY]) {
    if (datos.length < 2) return const SizedBox.shrink();

    List<FlSpot> puntosLinea = [];
    for (int i = 0; i < datos.length; i++) {
      double val = (datos[i][clave] is num) ? (datos[i][clave] as num).toDouble() : 0.0;
      puntosLinea.add(FlSpot(i.toDouble(), val));
    }

    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.circle, color: color, size: 12), const SizedBox(width: 4), Text(clave)],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
              minX: 0,
              maxX: (datos.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(spots: puntosLinea, isCurved: true, color: color, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: true)),
              ],
            ),
          ),
        ),
        const Divider(height: 48),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico: ${widget.idParticipante}'),
        backgroundColor: Colors.cyan.shade50,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _obtenerHistorico(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('❌ Error al cargar histórico: ${snapshot.error}'));

          final datos = snapshot.data ?? [];

          for (var row in datos) {
            String animo = row['estado_animo'] ?? '';
            row['animo_num'] = animo == 'Muy mal' ? 1.0 : animo == 'Mal' ? 2.0 : animo == 'Regular' ? 3.0 : animo == 'Bien' ? 4.0 : animo == 'Muy Bien' ? 5.0 : animo == 'Excelente' ? 6.0 : 0.0;

            String sueno = row['calidad_sueno'] ?? '';
            row['calidad_sueno_num'] = sueno == 'Malo' ? 1.0 : sueno == 'Regular' ? 2.0 : sueno == 'Bueno' ? 3.0 : sueno == 'Reparador' ? 4.0 : 0.0;
          }

          if (datos.length < 2) {
            return const Center(child: Text('⚠️ Se necesitan al menos 2 días de reportes para ver las curvas.', style: TextStyle(fontSize: 16)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Registros Totales del Paciente: ${datos.length}', style: const TextStyle(fontSize: 18, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),

                    _construirGrafico(datos, '1. Respuesta Somática', 'fatiga_bfi', 'dolor_maximo', Colors.redAccent, Colors.orangeAccent, 10),
                    _construirGrafico(datos, '2. Psico-Oncología (Estrés vs Ánimo 1-6)', 'estres_nccn', 'animo_num', Colors.purple, Colors.blue, 10),
                    _construirGrafico(datos, '3. Cronobiología (Eficiencia % vs Calidad 1-4)', 'eficiencia_sueno', 'calidad_sueno_num', Colors.teal, Colors.cyan, 100),
                    _construirGraficoUnico(datos, '4. Exposición Solar Directa (Minutos)', 'exposicion_sol_min', Colors.amber),
                    _construirGrafico(datos, '5. Carga Externa e Interna', 'rpe_sesion', 'kilos_ejercicio_1', Colors.deepPurple, Colors.green),
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
