import 'package:flutter/material.dart';
import '../logic/motor_clinico.dart';
import 'login_screen.dart';

// ==========================================
// 💊 PANTALLA 3: PRESCRIPCIÓN DEL EJERCICIO
// ==========================================
class PrescripcionScreen extends StatelessWidget {
  final String cohorte;
  final String semaforo;
  final DateTime fechaInicio;

  const PrescripcionScreen({
    super.key,
    required this.cohorte,
    required this.semaforo,
    required this.fechaInicio,
  });

  String _emojiParaTipo(TipoCarga tipo) {
    switch (tipo) {
      case TipoCarga.peso:
        return '🏋️';
      case TipoCarga.banda:
        return '🎗️';
      case TipoCarga.corporal:
        return '🤸';
    }
  }

  @override
  Widget build(BuildContext context) {
    final int diaSemana = DateTime.now().weekday;
    final int semanaPrograma = MotorClinico.calcularSemanaPrograma(fechaInicio, DateTime.now());
    final List<Ejercicio> ejercicios = MotorClinico.obtenerRutina(cohorte, diaSemana);
    final String intensidad = MotorClinico.obtenerIntensidad(semanaPrograma, diaSemana);
    final bool esDescarga = MotorClinico.esSemanaDescarga(semanaPrograma);

    Color colorFase = Colors.green;
    String tituloSemaforo = '🟢 Dosis Completa';
    String notaClinica = 'Realiza las series planificadas. Deja 2 a 3 repeticiones en recámara (RIR 2-3).';

    if (semaforo.contains('AMARILLO')) {
      colorFase = Colors.amber.shade700;
      tituloSemaforo = '🟡 Dosis Reducida (Down-Regulation)';
      notaClinica = 'Reducir volumen: Haz 1 serie menos por ejercicio y no llegues al fallo (RIR 4).';
    } else if (semaforo.contains('ROJO')) {
      colorFase = Colors.red;
      tituloSemaforo = '🔴 Carga Bloqueada';
      notaClinica = 'Aplica Protocolo Vagal (Respiración 4-7-8). Suspendemos el entrenamiento de fuerza de hoy.';
    } else if (esDescarga) {
      notaClinica = 'Semana de descarga: reduce el esfuerzo percibido y prioriza la técnica. Es parte del plan, no un retroceso.';
    }

    return Scaffold(
     appBar: AppBar(
        title: const Text('Tu Sesión de Entrenamiento'),
        backgroundColor: colorFase.withValues(alpha: 0.1),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                Icon(Icons.fitness_center, size: 64, color: colorFase),
                const SizedBox(height: 16),
                Text(tituloSemaforo, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorFase)),
                const SizedBox(height: 8),
                Text(notaClinica, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                const Divider(height: 48),

                if (!semaforo.contains('ROJO')) ...[
                  if (esDescarga) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.self_improvement, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text('Semana de Descarga', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('🎯 $intensidad', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        for (int i = 0; i < ejercicios.length; i++)
                          ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text('${_emojiParaTipo(ejercicios[i].tipoCarga)} ${ejercicios[i].nombre}'),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                  child: const Text('Entendido, cerrar sesión', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
