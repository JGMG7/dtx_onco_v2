import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'services/registros_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // No bloquea el arranque: si hay un registro diario pendiente por falta de
  // conexión, se reintenta en segundo plano.
  unawaited(RegistrosService().sincronizarPendientes());

  runApp(const DTxOncoApp());
}

class DTxOncoApp extends StatelessWidget {
  const DTxOncoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EFADAP Oncología',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan.shade700),
      ),
      home: const LoginScreen(),
    );
  }
}
