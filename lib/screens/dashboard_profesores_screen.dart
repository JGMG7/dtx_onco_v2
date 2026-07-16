import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para el portapapeles (CSV)
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/registros_service.dart';
import 'login_screen.dart';
import 'evolucion_clinica_screen.dart';
import 'cuaderno_sesion_screen.dart';
import 'enrolar_participante_screen.dart';

// ==========================================
// 💻 PANTALLA 2: DASHBOARD DEL PROFESOR
// ==========================================
class DashboardProfesoresScreen extends StatefulWidget {
  const DashboardProfesoresScreen({super.key});

  @override
  State<DashboardProfesoresScreen> createState() => _DashboardProfesoresScreenState();
}

class _DashboardProfesoresScreenState extends State<DashboardProfesoresScreen> {
  final _registrosService = RegistrosService();
  String _filtroSemaforo = 'Todos';

  Future<List<Map<String, dynamic>>> _obtenerReportes() {
    return _registrosService.obtenerReportes();
  }

  Future<void> _marcarComoResuelto(String idReporte, BuildContext dialogContext) async {
    try {
      await _registrosService.marcarComoResuelto(idReporte);

      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();

      if (!context.mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Paciente atendido. Alerta resuelta.'), backgroundColor: Colors.green));

    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al actualizar: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarBaseDatosCSV() async {
    try {
      final respuesta = await _registrosService.obtenerReportes();

      if (respuesta.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📭 No hay datos registrados para exportar.'), backgroundColor: Colors.orange));
        return;
      }

      StringBuffer csvResultado = StringBuffer();
      csvResultado.writeln('id_registro,id_participante,fecha,estado_triage,semaforo,atendido,eficiencia_sueno,'
        'latencia_min,despertares_veces,calidad_sueno,estado_animo,exposicion_sol_min,'
        'fatiga_bfi,estres_nccn,dolor_maximo,zonas_dolor,estado_sesion,rpe_sesion,'
        'ejercicio_1,kilos_e1,ejercicio_2,kilos_e2,ejercicio_3,kilos_e3,ejercicio_4,kilos_e4');

      for (var fila in respuesta) {
        csvResultado.writeln(
          '${fila['id'] ?? ''},${fila['id_participante'] ?? ''},${fila['fecha'] ?? ''},${fila['estado_triage'] ?? ''},'
          '${fila['semaforo'] ?? ''},${fila['atendido'] == true ? 'SI' : 'NO'},${(fila['eficiencia_sueno'] ?? 0).toStringAsFixed(1)},${fila['latencia_min'] ?? 0},'
          '${fila['despertares_veces'] ?? 0},${fila['calidad_sueno'] ?? ''},${fila['estado_animo'] ?? ''},'
          '${fila['exposicion_sol_min'] ?? 0},${fila['fatiga_bfi'] ?? 0},${fila['estres_nccn'] ?? 0},'
          '${fila['dolor_maximo'] ?? 0},"${fila['zonas_dolor'] ?? 'Ninguna'}",${fila['estado_sesion'] ?? 'Pendiente'},'
          '${fila['rpe_sesion'] ?? 0},${fila['ejercicio_1'] ?? 'Ninguno'},${fila['kilos_ejercicio_1'] ?? 0.0},'
          '${fila['ejercicio_2'] ?? 'Ninguno'},${fila['kilos_ejercicio_2'] ?? 0.0},${fila['ejercicio_3'] ?? 'Ninguno'},'
          '${fila['kilos_ejercicio_3'] ?? 0.0},${fila['ejercicio_4'] ?? 'Ninguno'},${fila['kilos_ejercicio_4'] ?? 0.0}'
        );
      }

      await Clipboard.setData(ClipboardData(text: csvResultado.toString()));

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.analytics, color: Colors.green), SizedBox(width: 8), Text('¡Base Exportada!')]),
          content: const Text('Toda la base de datos ha sido convertida a CSV y copiada a tu portapapeles.\n\n🚀 Abre Excel y presiona pegar (Ctrl + V).'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('Excelente'))],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al exportar: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarDetalles(BuildContext context, Map<String, dynamic> rep) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [const Icon(Icons.analytics, color: Colors.blueGrey), const SizedBox(width: 8), Text('ID: ${rep['id_participante']}')]),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rep['semaforo'].contains('ROJO') ? Colors.red.shade100 : rep['semaforo'].contains('AMARILLO') ? Colors.amber.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Estado: ${rep['semaforo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rep['atendido'] == true ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rep['atendido'] == true ? '✅ Atendido por el equipo docente' : '⏳ Pendiente de atención',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 24),
                const Text('💤 Sueño', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('Eficiencia: ${rep['eficiencia_sueno'].toStringAsFixed(1)}%'),
                Text('Calidad: ${rep['calidad_sueno']}'),
                Text('Latencia: ${rep['latencia_min']} min | Despertares: ${rep['despertares_veces']}'),
                const SizedBox(height: 12),
                const Text('🧠 Ánimo y Entorno', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Text('Estado de Ánimo: ${rep['estado_animo']}'),
                Text('Exposición Solar: ${rep['exposicion_sol_min']} min'),
                const SizedBox(height: 12),
                const Text('🔋 Energía Mental/Física', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                Text('Fatiga (BFI): ${rep['fatiga_bfi']} / 10'),
                Text('Estrés (NCCN): ${rep['estres_nccn']} / 10'),
                const SizedBox(height: 12),
                const Text('🦴 Dolor Musculoesquelético', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                Text('Intensidad Máxima: ${rep['dolor_maximo']} / 10'),
                Text('Zonas Afectadas: ${rep['zonas_dolor']}'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
            if (rep['atendido'] != true && (rep['semaforo'].contains('ROJO') || rep['semaforo'].contains('AMARILLO')))
              FilledButton.icon(
                icon: const Icon(Icons.check_circle), label: const Text('Atender'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _marcarComoResuelto(rep['id'], context),
              ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.show_chart), label: const Text('Histórico'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => EvolucionClinicaScreen(idParticipante: rep['id_participante'])));
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.edit_document), label: const Text('Cuaderno'),
              style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => CuadernoSesionScreen(reporte: rep)))
                  .then((_) { if (context.mounted) setState(() {}); });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte - EFADAP', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.teal),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EnrolarParticipanteScreen()))
                  .then((_) { if (context.mounted) setState(() {}); });
            },
            tooltip: 'Enrolar Participante',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.teal),
            onPressed: _exportarBaseDatosCSV,
            tooltip: 'Exportar Base de Datos (CSV)',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.blueGrey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  ChoiceChip(label: const Text('Todos'), selected: _filtroSemaforo == 'Todos', onSelected: (val) => setState(() => _filtroSemaforo = 'Todos')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('🔴 Alertas Rojas'), selected: _filtroSemaforo == 'ROJO', selectedColor: Colors.red.shade100, onSelected: (val) => setState(() => _filtroSemaforo = 'ROJO')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('🟡 Amarillos'), selected: _filtroSemaforo == 'AMARILLO', selectedColor: Colors.amber.shade100, onSelected: (val) => setState(() => _filtroSemaforo = 'AMARILLO')),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _obtenerReportes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('❌ Error: ${snapshot.error}'));

                final reportes = snapshot.data ?? [];
                final reportesFiltrados = _filtroSemaforo == 'Todos' ? reportes : reportes.where((rep) => rep['semaforo'].toString().contains(_filtroSemaforo)).toList();

                if (reportesFiltrados.isEmpty) {
                  return Center(
                    child: Text(_filtroSemaforo == 'Todos' ? '📭 Aún no hay registros.' : '🎉 ¡Excelente! No hay pacientes en semáforo $_filtroSemaforo hoy.', style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reportesFiltrados.length,
                  itemBuilder: (context, index) {
                    final rep = reportesFiltrados[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: rep['semaforo'].contains('ROJO') ? Colors.red : rep['semaforo'].contains('AMARILLO') ? Colors.amber : Colors.green,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text('ID: ${rep['id_participante']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Fecha: ${rep['fecha']} | Fatiga: ${rep['fatiga_bfi']} | Sueño: ${rep['eficiencia_sueno']}%'
                          '${rep['atendido'] == true ? ' | ✅ Atendido' : ''}',
                        ),
                        trailing: const Icon(Icons.zoom_in, color: Colors.blueGrey),
                        onTap: () => _mostrarDetalles(context, rep),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
