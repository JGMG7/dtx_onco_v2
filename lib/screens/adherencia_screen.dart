import 'package:flutter/material.dart';
import '../models/resumen_participante.dart';
import '../services/registros_service.dart';

// ==========================================
// 📋 PANTALLA: ADHERENCIA DE PARTICIPANTES (Profesor)
// ==========================================
class AdherenciaScreen extends StatefulWidget {
  const AdherenciaScreen({super.key});

  @override
  State<AdherenciaScreen> createState() => _AdherenciaScreenState();
}

class _AdherenciaScreenState extends State<AdherenciaScreen> {
  final _registrosService = RegistrosService();
  late Future<List<ResumenParticipante>> _resumenFuture;

  @override
  void initState() {
    super.initState();
    _resumenFuture = _registrosService.obtenerResumenAdherencia();
  }

  ({Color color, String etiqueta}) _estadoDe(ResumenParticipante r) {
    if (r.diasSinRegistro == null) {
      return (color: Colors.red, etiqueta: '🔴 Nunca registró');
    }
    if (r.registroHoy) {
      return (color: Colors.green, etiqueta: '🟢 Registró hoy');
    }
    if (r.diasSinRegistro == 1) {
      return (color: Colors.amber.shade700, etiqueta: '🟡 1 día sin registro');
    }
    return (color: Colors.red, etiqueta: '🔴 ${r.diasSinRegistro} días sin registro');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherencia de Participantes'),
        backgroundColor: Colors.cyan.shade50,
      ),
      body: FutureBuilder<List<ResumenParticipante>>(
        future: _resumenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('❌ Error: ${snapshot.error}'));
          }

          final resumen = snapshot.data ?? [];
          if (resumen.isEmpty) {
            return const Center(child: Text('📭 Aún no hay participantes enrolados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resumen.length,
            itemBuilder: (context, index) {
              final r = resumen[index];
              final estado = _estadoDe(r);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estado.color,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text('ID: ${r.idParticipante}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${r.cohorte}${r.grupo != null ? ' · ${r.grupo}' : ''}\n'
                    '${estado.etiqueta}'
                    '${r.ultimoRegistro != null ? ' · Último: ${r.ultimoRegistro!.day}/${r.ultimoRegistro!.month}/${r.ultimoRegistro!.year}' : ''}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
