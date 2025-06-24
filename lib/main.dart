import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Flutter Demo Home Page')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

class Gasolinera {
  final String rotulo;
  final double latitud;
  final double longitud;

  Gasolinera({required this.rotulo, required this.latitud, required this.longitud});

  factory Gasolinera.fromJson(Map<String, dynamic> json) {
    // La latitud y longitud pueden venir con coma decimal, hay que reemplazar por punto
    double parseCoord(String valor) => double.tryParse(valor.replaceAll(',', '.')) ?? 0.0;
    return Gasolinera(
      rotulo: json['Rótulo'] ?? '',
      latitud: parseCoord(json['Latitud'] ?? '0'),
      longitud: parseCoord(json['Longitud (WGS84)'] ?? '0'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Gasolinera> _todasGasolineras = [];
  List<Gasolinera> _cercanas = [];
  Position? _posicionUsuario;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      await _obtenerUbicacion();
      await _fetchGasStations();
      _filtrarCercanas();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _cargando = false; });
    }
  }

  Future<void> _obtenerUbicacion() async {
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      throw Exception('La ubicación está deshabilitada. Actívala en los ajustes.');
    }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }
    if (permiso == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente.');
    }
    _posicionUsuario = await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchGasStations() async {
    final url = Uri.parse('https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      _todasGasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener datos: ${response.statusCode}');
    }
  }

  void _filtrarCercanas() {
    if (_posicionUsuario == null) return;
    _cercanas = List.from(_todasGasolineras);
    _cercanas.sort((a, b) {
      double da = Geolocator.distanceBetween(
        _posicionUsuario!.latitude, _posicionUsuario!.longitude,
        a.latitud, a.longitud,
      );
      double db = Geolocator.distanceBetween(
        _posicionUsuario!.latitude, _posicionUsuario!.longitude,
        b.latitud, b.longitud,
      );
      return da.compareTo(db);
    });
    if (_cercanas.length > 5) {
      _cercanas = _cercanas.sublist(0, 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Gasolineras cercanas'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _cercanas.length,
                  itemBuilder: (context, index) {
                    final gas = _cercanas[index];
                    return ListTile(
                      leading: const Icon(Icons.local_gas_station),
                      title: Text(gas.rotulo),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí puedes navegar a la pantalla de ajustes
        },
        tooltip: 'Ajustes',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
