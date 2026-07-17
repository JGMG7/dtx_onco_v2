import 'package:flutter/material.dart';
import '../services/registros_service.dart';

// ==========================================
// 🧑‍⚕️ PANTALLA: ENROLAR PARTICIPANTE (Profesor)
// ==========================================
class EnrolarParticipanteScreen extends StatefulWidget {
  const EnrolarParticipanteScreen({super.key});

  @override
  State<EnrolarParticipanteScreen> createState() => _EnrolarParticipanteScreenState();
}

class _EnrolarParticipanteScreenState extends State<EnrolarParticipanteScreen> {
  final _registrosService = RegistrosService();
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  final _notasController = TextEditingController();

  String _cohorte = 'MAMA';
  String _grupo = 'CONTROL';
  bool _verRutina = true;
  bool _isSaving = false;

  Future<void> _enrolar() async {
    if (_idController.text.trim().isEmpty || _pinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Completa el ID y el PIN del participante.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _registrosService.crearParticipante(
        id: _idController.text.trim().toUpperCase(),
        pin: _pinController.text.trim(),
        grupo: _grupo,
        cohorte: _cohorte,
        verRutina: _verRutina,
        notasClinicas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Participante enrolado con éxito'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al enrolar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrolar Participante'),
        backgroundColor: Colors.cyan.shade50,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alta de nuevo participante', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'ID de Participante', hintText: 'Ej. SUBJ_042', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(labelText: 'PIN inicial', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _cohorte,
                  decoration: const InputDecoration(labelText: 'Cohorte', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                  items: const [
                    DropdownMenuItem(value: 'MAMA', child: Text('Mama')),
                    DropdownMenuItem(value: 'PROSTATA', child: Text('Próstata')),
                  ],
                  onChanged: (valor) => setState(() => _cohorte = valor!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _grupo,
                  decoration: const InputDecoration(labelText: 'Grupo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups)),
                  items: const [
                    DropdownMenuItem(value: 'CONTROL', child: Text('Control')),
                    DropdownMenuItem(value: 'INTERVENCION', child: Text('Intervención')),
                  ],
                  onChanged: (valor) => setState(() => _grupo = valor!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recibe rutina de ejercicio'),
                  value: _verRutina,
                  onChanged: (valor) => setState(() => _verRutina = valor),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notasController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas clínicas / contraindicaciones (opcional)',
                    hintText: 'Ej. evitar carga unilateral en brazo derecho por linfedema',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_amber),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: _isSaving
                      ? const FilledButton(onPressed: null, child: CircularProgressIndicator())
                      : FilledButton(onPressed: _enrolar, child: const Text('Enrolar', style: TextStyle(fontSize: 18))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
