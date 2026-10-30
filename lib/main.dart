import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/componentes_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verificar_correo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PromedioApp());
}

/// Widget raíz de la aplicación PromedioApp.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PromedioApp extends StatelessWidget {
  const PromedioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ComponentesProvider(),
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'Pondera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Mientras se determina el estado, podramos mostrar un loader, pero authStateChanges es casi instantneo.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user != null) {
              // La cuenta solo entra si confirmo su correo.
              if (!user.emailVerified) {
                return const VerificarCorreoScreen();
              }
              return const HomeScreen(); // Usuario logueado y verificado
            }
            return const WelcomeScreen(); // No hay usuario
          },
        ),
      ),
    );
  }
}
