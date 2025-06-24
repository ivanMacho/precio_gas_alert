import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'combustibles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

const String tareaBackground = 'actualizarDatosGasolineras';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == tareaBackground) {
      try {
        final url = Uri.parse('https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final fecha = data['Fecha'] ?? '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('datos_api', utf8.decode(response.bodyBytes));
          await prefs.setString('fecha_api', fecha);
          final ahora = DateTime.now();
          await prefs.setString('fecha_actualizacion_local', ahora.toString());
          print('[Workmanager] Datos actualizados correctamente en background');
        } else {
          print('[Workmanager] Error al obtener datos en background: \\${response.statusCode}');
        }
      } catch (e) {
        print('[Workmanager] Excepción en background: \\${e.toString()}');
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    '1',
    tareaBackground,
    frequency: const Duration(minutes: 15), // El mínimo real en Android es 15 min
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
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
  final Map<String, dynamic> datos;

  Gasolinera({required this.rotulo, required this.latitud, required this.longitud, required this.datos});

  factory Gasolinera.fromJson(Map<String, dynamic> json) {
    double parseCoord(String valor) => double.tryParse(valor.replaceAll(',', '.')) ?? 0.0;
    return Gasolinera(
      rotulo: json['Rótulo'] ?? '',
      latitud: parseCoord(json['Latitud'] ?? '0'),
      longitud: parseCoord(json['Longitud (WGS84)'] ?? '0'),
      datos: json,
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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Gasolinera> _todasGasolineras = [];
  List<Gasolinera> _cercanas = [];
  Position? _posicionUsuario;
  bool _cargando = true;
  String? _error;
  String _combustibleSeleccionado = combustibles.first;
  String? _fechaDatos;
  String? _fechaActualizacionLocal;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _cargarCombustibleSeleccionado();
    _cargarDatosPersistidos();
    _inicializar();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarCombustibleSeleccionado() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _combustibleSeleccionado = prefs.getString('combustible') ?? combustibles.first;
    });
  }

  Future<void> _cargarDatosPersistidos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('datos_api');
    final fecha = prefs.getString('fecha_api');
    final fechaLocal = prefs.getString('fecha_actualizacion_local');
    if (jsonString != null) {
      final data = json.decode(jsonString);
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      setState(() {
        _todasGasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
        _fechaDatos = fecha;
        _fechaActualizacionLocal = fechaLocal;
        _filtrarCercanas();
        _cargando = false;
      });
    }
  }

  Future<void> _persistirDatosApi(String jsonString, String fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('datos_api', jsonString);
    await prefs.setString('fecha_api', fecha);
    final ahora = DateTime.now();
    await prefs.setString('fecha_actualizacion_local', ahora.toString());
    setState(() {
      _fechaActualizacionLocal = ahora.toString();
    });
  }

  Future<void> _inicializar() async {
    setState(() { _cargando = true; _error = null; });
    _animationController.repeat();
    try {
      await _obtenerUbicacion();
      await _fetchGasStations();
      _filtrarCercanas();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _cargando = false; });
      _animationController.stop();
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
    print('Iniciando llamada a la API de gasolineras...');
    final url = Uri.parse('https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      print('Respuesta de la API correcta (OK)');
      final data = json.decode(utf8.decode(response.bodyBytes));
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      setState(() {
        _todasGasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
        _fechaDatos = data['Fecha'] ?? '';
      });
      await _persistirDatosApi(utf8.decode(response.bodyBytes), _fechaDatos ?? '');
      print('Fin de la llamada a la API.');
    } else {
      print('Respuesta de la API con error. Código: ${response.statusCode}');
      print('Fin de la llamada a la API.');
      throw Exception('Error al obtener datos:  {response.statusCode}');
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

  Future<void> _refrescarConfiguracion() async {
    await _cargarCombustibleSeleccionado();
    setState(() {}); // Refresca la pantalla con el nuevo combustible
  }

  String _formatearFechaLocal(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '-';
    try {
      final dt = DateTime.parse(fecha);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Precio Gas Alert'),
      ),
      body: _cargando && _cercanas.isEmpty
          ? ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const ListTile(
                leading: Icon(Icons.local_gas_station),
                title: Text('Cargando...'),
                subtitle: Text('Precio: ... €/L'),
              ),
            )
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Gasolineras más cercanas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mostrando precios para: ' +
                        (_cercanas.isNotEmpty && _cercanas.first.datos.containsKey('Precio ${_combustibleSeleccionado}')
                         ? _combustibleSeleccionado
                         : '-'),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cercanas.length,
                        itemBuilder: (context, index) {
                          final gas = _cercanas[index];
                          final campoPrecio = 'Precio ${_combustibleSeleccionado}';
                          String precio = gas.datos[campoPrecio]?.toString() ?? '';
                          if (precio.isEmpty) precio = 'N/D';
                          return ListTile(
                            leading: const Icon(Icons.local_gas_station),
                            title: Text(gas.rotulo),
                            subtitle: Text('Precio: $precio €/L'),
                          );
                        },
                      ),
                    ),
                    if (_fechaDatos != null && _fechaDatos!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 64.0, top: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RotationTransition(
                              turns: _animationController,
                              child: IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _cargando ? null : _inicializar,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha de los datos: ${_fechaDatos ?? '-'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Actualizado en el dispositivo: ${_formatearFechaLocal(_fechaActualizacionLocal)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ConfiguracionPage()),
          );
          await _refrescarConfiguracion();
        },
        tooltip: 'Ajustes',
        child: const Icon(Icons.settings),
      ),
    );
  }
}

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  String _combustible = combustibles.first;
  double _distancia = 5.0;
  double _precio = 2.0;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _combustible = prefs.getString('combustible') ?? combustibles.first;
      _distancia = prefs.getDouble('distancia') ?? 5.0;
      _precio = prefs.getDouble('precio') ?? 2.0;
    });
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('combustible', _combustible);
    await prefs.setDouble('distancia', _distancia);
    await prefs.setDouble('precio', _precio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de combustible:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _combustible,
              isExpanded: true,
              items: combustibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _combustible = value);
              },
            ),
            const SizedBox(height: 24),
            const Text('Distancia máxima (km):', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _distancia,
              min: 1,
              max: 100,
              divisions: 99,
              label: _distancia.toStringAsFixed(1),
              onChanged: (value) => setState(() => _distancia = value),
            ),
            Text('${_distancia.toStringAsFixed(1)} km'),
            const SizedBox(height: 24),
            const Text('Precio máximo por litro (€):', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _precio,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              label: _precio.toStringAsFixed(2),
              onChanged: (value) => setState(() => _precio = value),
            ),
            Text('${_precio.toStringAsFixed(2)} €/L'),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await _guardarPreferencias();
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
