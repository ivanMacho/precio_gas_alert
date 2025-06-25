import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

/// Punto de entrada principal de la app
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Widget raíz de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Precio Gas Alert',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Color(0xFF00FF41), // Verde terminal
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF00FF41), // Verde terminal
          secondary: Color(0xFFFFC300), // Ámbar retro
          background: Colors.black,
          surface: Color(0xFF222222),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onBackground: Color(0xFF00FF41),
          onSurface: Color(0xFF00FF41),
        ),
        fontFamily: 'VT323',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF00FF41), fontSize: 24),
          bodyMedium: TextStyle(color: Color(0xFF00FF41), fontSize: 20),
          bodySmall: TextStyle(color: Color(0xFF00FF41), fontSize: 16),
          titleLarge: TextStyle(
            color: Color(0xFFFFC300),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF00FFF7),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Color(0xFF00FF41),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'VT323',
            color: Color(0xFFFFC300),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF222222),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF00FF41)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFFFFC300)),
          ),
          labelStyle: TextStyle(color: Color(0xFF00FF41)),
        ),
        buttonTheme: const ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          buttonColor: Color(0xFF00FF41),
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Color(0xFF00FF41)),
            foregroundColor: MaterialStatePropertyAll(Colors.black),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
