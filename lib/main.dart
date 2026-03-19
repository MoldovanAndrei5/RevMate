import 'package:car_maintenance_tracker/providers/auth_provider.dart';
import 'package:car_maintenance_tracker/providers/theme_provider.dart';
import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:car_maintenance_tracker/screens/other/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/car_provider.dart';
import 'providers/task_provider.dart';

void main() async {
  //ensure flutter engine is running
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  }
  catch (e) {
    AppLogger.error("Error loading.env file: $e");
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(CarMaintenanceApp());
  });
}

class CarMaintenanceApp extends StatelessWidget {
  const CarMaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(

      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadToken()),
        ChangeNotifierProvider(create: (_) => CarProvider()..fetchCars()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..fetchTasks()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Car Maintenance Tracker',
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: themeProvider.accentColor,
              brightness: Brightness.light,
            ),

            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: themeProvider.accentColor,
              brightness: Brightness.dark,
            ),

            home: const AuthGate(),
            debugShowCheckedModeBanner: false,
          );
        }
      ),
    );
  }
}
