import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/registros_service.dart';
import 'registro_diario_screen.dart';
import 'dashboard_profesores_screen.dart';

// ==========================================
// 🔐 PANTALLA DE LOGIN
// ==========================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('EFADAP Oncología', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.smartphone), text: 'Participantes'),
              Tab(icon: Icon(Icons.science), text: 'Profesores'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FormularioParticipante(),
            _FormularioInvestigador(),
          ],
        ),
      ),
    );
  }
}

// --- FORMULARIO 1: PARTICIPANTES ---
class _FormularioParticipante extends StatefulWidget {
  const _FormularioParticipante();

  @override
  State<_FormularioParticipante> createState() => _FormularioParticipanteState();
}

class _FormularioParticipanteState extends State<_FormularioParticipante> {
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  final _registrosService = RegistrosService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // No bloquea la UI: si quedó un registro pendiente por falta de conexión
    // de una visita anterior, se reintenta al volver a abrir este login.
    unawaited(_registrosService.sincronizarPendientes());
  }

  Future<void> _iniciarSesion() async {
    if (_idController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Por favor, completa todos los campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final datosParticipante = await _registrosService.loginParticipante(
        _idController.text.trim().toUpperCase(),
        _pinController.text.trim(),
      );

      if (datosParticipante != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroDiarioScreen(
                idParticipante: datosParticipante['id_participante'],
                pin: _pinController.text.trim(),
                grupo: datosParticipante['grupo'],
                cohorte: datosParticipante['cohorte'] ?? 'MAMA',
                verRutina: datosParticipante['ver_rutina'] ?? false,
                fechaInicio: DateTime.tryParse(datosParticipante['fecha_inicio'] ?? '') ?? DateTime.now(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Error en credenciales. Verifica tu ID o PIN.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📡 Error de conexión: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Acceso a Registro Diario', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'ID de Participante', hintText: 'Ej. SUBJ_042', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN Secreto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 50,
                child: _isLoading
                    ? const FilledButton(onPressed: null, child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                    : FilledButton(onPressed: _iniciarSesion, child: const Text('Ingresar 🚀', style: TextStyle(fontSize: 18))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FORMULARIO 2: EQUIPO DOCENTE ---
class _FormularioInvestigador extends StatefulWidget {
  const _FormularioInvestigador();

  @override
  State<_FormularioInvestigador> createState() => _FormularioInvestigadorState();
}

class _FormularioInvestigadorState extends State<_FormularioInvestigador> {
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _desbloquearRadar() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: SupabaseConfig.professorAuthEmail,
        password: _passController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardProfesoresScreen()));
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Contraseña denegada. Acceso restringido.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📡 Error de conexión: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Panel del Profesor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña Maestra', border: OutlineInputBorder(), prefixIcon: Icon(Icons.admin_panel_settings)),
                onSubmitted: (_) => _desbloquearRadar(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 50,
                child: _isLoading
                    ? const FilledButton.tonal(onPressed: null, child: CircularProgressIndicator())
                    : FilledButton.tonal(onPressed: _desbloquearRadar, child: const Text('Desbloquear 🔐', style: TextStyle(fontSize: 18))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
