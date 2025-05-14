import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'database/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializar formato de fechas en catalán
  await initializeDateFormatting('ca', null);
  
  // Inicializar timezone data y zona local
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
  
  // Modo sistema UI (solo dev)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual, 
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]
  );
  
  // Inicializar ReminderService (crea canal, timezone, etc.)
  final reminderService = ReminderService();
  await reminderService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplicació TFG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ca'), // Català
        Locale('es'), // Español
        Locale('en'), // English
      ],
      home: const SplashScreen(),
    );
  }
}
