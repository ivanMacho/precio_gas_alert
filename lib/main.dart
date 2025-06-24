import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'combustibles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import 'package:app_settings/app_settings.dart';

const String tareaBackground = 'actualizarDatosGasolineras';

// Variables globales para controlar la frecuencia de comprobación
const Duration frecuenciaComprobacionForeground = Duration(
  seconds: 30,
); // Cambia aquí para foreground
const Duration frecuenciaComprobacionBackground = Duration(
  minutes: 10,
); // Cambia aquí para background (mínimo real en Android)

Future<void> comprobarAlertas(
  List<Gasolinera> gasolineras,
  Position? posicionUsuario,
  String combustible,
  double distanciaMax,
  double precioMax,
) async {
  if (posicionUsuario == null) return;
  for (final gas in gasolineras) {
    final campoPrecio = 'Precio $combustible';
    final precioStr = gas.datos[campoPrecio]?.toString() ?? '';
    if (precioStr.isEmpty) continue;
    final precio = double.tryParse(precioStr.replaceAll(',', '.'));
    if (precio == null) continue;
    final distancia =
        Geolocator.distanceBetween(
          posicionUsuario.latitude,
          posicionUsuario.longitude,
          gas.latitud,
          gas.longitud,
        ) /
        1000.0; // en km
    if (distancia <= distanciaMax && precio <= precioMax) {
      print(
        '[ALERTA] Gasolinera cerca: ${gas.rotulo}, distancia: ${distancia.toStringAsFixed(2)} km, precio: $precio €/L',
      );
    }
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[WM] Tarea background recibida: $task');
    if (task == tareaBackground) {
      try {
        print('[WM] Iniciando obtención de datos de la API en background...');
        final url = Uri.parse(
          'https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          print('[WM] Respuesta de la API correcta (OK)');
          final data = json.decode(utf8.decode(response.bodyBytes));
          final fecha = data['Fecha'] ?? '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('datos_api', utf8.decode(response.bodyBytes));
          await prefs.setString('fecha_api', fecha);
          final ahora = DateTime.now();
          await prefs.setString('fecha_actualizacion_local', ahora.toString());
          print('[WM] Datos guardados en preferencias.');
          // Comprobar alertas en background
          final lista = data['ListaEESSPrecio'] as List<dynamic>;
          final gasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
          final combustible =
              prefs.getString('combustible') ?? combustibles.first;
          final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
          final precioMax = prefs.getDouble('precio') ?? 2.0;
          // Obtener ubicación actual de forma robusta
          Position? posicionUsuario;
          try {
            bool servicioHabilitado =
                await Geolocator.isLocationServiceEnabled();
            LocationPermission permiso = await Geolocator.checkPermission();
            print('[WM] Servicio de ubicación habilitado: $servicioHabilitado');
            print('[WM] Permiso de ubicación actual: $permiso');
            if (servicioHabilitado && permiso == LocationPermission.always) {
              try {
                posicionUsuario = await Geolocator.getCurrentPosition(
                  timeLimit: Duration(seconds: 10),
                  desiredAccuracy: LocationAccuracy.high,
                  forceAndroidLocationManager:
                      true, // fuerza el uso del LocationManager nativo
                );
                print(
                  '[WM] Posición obtenida: ${posicionUsuario.latitude}, ${posicionUsuario.longitude}',
                );
              } catch (e) {
                print(
                  '[WM] Error al obtener la posición en background, intentando última conocida: $e',
                );
                posicionUsuario = await Geolocator.getLastKnownPosition();
                if (posicionUsuario != null) {
                  print(
                    '[WM] Última posición conocida: ${posicionUsuario.latitude}, ${posicionUsuario.longitude}',
                  );
                } else {
                  print('[WM] No hay última posición conocida disponible.');
                }
              }
            } else {
              print(
                '[WM][ADVERTENCIA] Permiso insuficiente o servicio deshabilitado para obtener ubicación en background.',
              );
            }
            if (posicionUsuario == null) {
              print(
                '[WM][ADVERTENCIA] No se pudo obtener la posición del usuario. No se comprobarán alertas.',
              );
            }
          } catch (e) {
            print('[WM] Error general al comprobar permisos/ubicación: $e');
          }
          await comprobarAlertas(
            gasolineras,
            posicionUsuario,
            combustible,
            distanciaMax,
            precioMax,
          );
          print('[WM] Comprobación de alertas en background completada.');
          print('[WM] Datos actualizados correctamente en background');
        } else {
          print(
            '[WM][ERROR] Error al obtener datos en background: ${response.statusCode}',
          );
        }
      } catch (e) {
        print('[WM][ERROR] Excepción en background: ${e.toString()}');
      }
    }
    print('[WM] Tarea background finalizada.');
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    '1',
    tareaBackground,
    frequency: frecuenciaComprobacionBackground, // Usar variable global
    initialDelay: const Duration(seconds: 60),
    constraints: Constraints(networkType: NetworkType.connected),
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
        MaterialPageRoute(
          builder: (context) =>
              const MyHomePage(title: 'Flutter Demo Home Page'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('assets/images/logo.png', width: 200, height: 200),
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

  Gasolinera({
    required this.rotulo,
    required this.latitud,
    required this.longitud,
    required this.datos,
  });

  factory Gasolinera.fromJson(Map<String, dynamic> json) {
    double parseCoord(String valor) =>
        double.tryParse(valor.replaceAll(',', '.')) ?? 0.0;
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  List<Gasolinera> _todasGasolineras = [];
  List<Gasolinera> _cercanas = [];
  Position? _posicionUsuario;
  bool _cargando = true;
  String? _error;
  String _combustibleSeleccionado = combustibles.first;
  String? _fechaDatos;
  String? _fechaActualizacionLocal;
  late AnimationController _animationController;
  Timer? _timerAlertas;

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
    _iniciarTimerAlertas();
    // Solicitar permiso de ubicación en background al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await solicitarPermisoUbicacionBackground(context);
      await comprobarPermisoUbicacionAlways(context);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timerAlertas?.cancel();
    super.dispose();
  }

  Future<void> _cargarCombustibleSeleccionado() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _combustibleSeleccionado =
          prefs.getString('combustible') ?? combustibles.first;
    });
  }

  Future<void> _cargarDatosPersistidos() async {
    print('[DEBUG] Intentando cargar datos persistidos...');
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('datos_api');
    final fecha = prefs.getString('fecha_api');
    final fechaLocal = prefs.getString('fecha_actualizacion_local');
    if (jsonString != null) {
      print('[DEBUG] Datos persistidos encontrados.');
      final data = json.decode(jsonString);
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      setState(() {
        _todasGasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
        _fechaDatos = fecha;
        _fechaActualizacionLocal = fechaLocal;
        _filtrarCercanas();
        _cargando = false;
      });
    } else {
      print('[DEBUG] No hay datos persistidos.');
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
    print('[DEBUG] Inicializando app (obteniendo ubicación y datos de API)...');
    setState(() {
      _cargando = true;
      _error = null;
    });
    _animationController.repeat();
    try {
      await _obtenerUbicacion();
      print('[DEBUG] Ubicación obtenida correctamente.');
      await _fetchGasStations();
      print('[DEBUG] Datos de gasolineras obtenidos correctamente.');
      _filtrarCercanas();
      print('[DEBUG] Gasolineras cercanas filtradas.');
      // Comprobar alertas tras actualizar datos
      final prefs = await SharedPreferences.getInstance();
      final combustible = prefs.getString('combustible') ?? combustibles.first;
      final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
      final precioMax = prefs.getDouble('precio') ?? 2.0;
      await comprobarAlertas(
        _todasGasolineras,
        _posicionUsuario,
        combustible,
        distanciaMax,
        precioMax,
      );
      print('[DEBUG] Comprobación de alertas tras inicialización completada.');
    } catch (e) {
      print('[ERROR] Error en inicialización: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _cargando = false;
      });
      _animationController.stop();
      print('[DEBUG] Inicialización finalizada.');
    }
  }

  Future<void> _obtenerUbicacion() async {
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      throw Exception(
        'La ubicación está deshabilitada. Actívala en los ajustes.',
      );
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
    print('[DEBUG] Iniciando llamada a la API de gasolineras...');
    final url = Uri.parse(
      'https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      print('[DEBUG] Respuesta de la API correcta (OK)');
      final data = json.decode(utf8.decode(response.bodyBytes));
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      setState(() {
        _todasGasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
        _fechaDatos = data['Fecha'] ?? '';
      });
      await _persistirDatosApi(
        utf8.decode(response.bodyBytes),
        _fechaDatos ?? '',
      );
      print('[DEBUG] Fin de la llamada a la API.');
    } else {
      print(
        '[ERROR] Respuesta de la API con error. Código: ${response.statusCode}',
      );
      print('[DEBUG] Fin de la llamada a la API.');
      throw Exception('Error al obtener datos:  ${response.statusCode}');
    }
  }

  void _filtrarCercanas() {
    if (_posicionUsuario == null) return;
    _cercanas = List.from(_todasGasolineras);
    _cercanas.sort((a, b) {
      double da = Geolocator.distanceBetween(
        _posicionUsuario!.latitude,
        _posicionUsuario!.longitude,
        a.latitud,
        a.longitud,
      );
      double db = Geolocator.distanceBetween(
        _posicionUsuario!.latitude,
        _posicionUsuario!.longitude,
        b.latitud,
        b.longitud,
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

  void _iniciarTimerAlertas() {
    _timerAlertas = Timer.periodic(frecuenciaComprobacionForeground, (_) async {
      await _comprobarAlertasPeriodicas();
    });
  }

  Future<void> _comprobarAlertasPeriodicas() async {
    print('[CHECK] Comprobando condiciones de alerta...');
    final prefs = await SharedPreferences.getInstance();
    final combustible = prefs.getString('combustible') ?? combustibles.first;
    final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
    final precioMax = prefs.getDouble('precio') ?? 2.0;
    try {
      Position? posicionUsuario;
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      LocationPermission permiso = await Geolocator.checkPermission();
      print(
        '[DEBUG] Servicio de ubicación habilitado: '
        '[33m$servicioHabilitado[0m',
      );
      print(
        '[DEBUG] Permiso de ubicación actual: '
        '[33m$permiso[0m',
      );
      if (servicioHabilitado) {
        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
          print(
            '[DEBUG] Permiso solicitado, nuevo estado: '
            '[33m$permiso[0m',
          );
        }
        if (permiso == LocationPermission.whileInUse ||
            permiso == LocationPermission.always) {
          try {
            posicionUsuario = await Geolocator.getCurrentPosition();
            print(
              '[DEBUG] Posición obtenida: '
              '[32m${posicionUsuario.latitude}, ${posicionUsuario.longitude}[0m',
            );
          } catch (e) {
            print('[DEBUG] Error al obtener la posición: $e');
            posicionUsuario = null;
          }
        } else {
          print(
            '[ADVERTENCIA] Permiso de ubicación insuficiente para comprobación (se requiere "always").',
          );
        }
      } else {
        print('[ADVERTENCIA] El servicio de ubicación está deshabilitado.');
      }
      if (posicionUsuario == null) {
        print(
          '[ADVERTENCIA] No se pudo obtener la posición del usuario. No se comprobarán alertas.',
        );
      }
      await comprobarAlertas(
        _todasGasolineras,
        posicionUsuario,
        combustible,
        distanciaMax,
        precioMax,
      );
    } catch (e) {
      print('[CHECK] Error al comprobar alertas: \\${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Precio Gas Alert'),
      ),
      body: _cargando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Actualizando datos...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _cercanas.isEmpty
          ? Center(child: Text('Sin datos para mostrar.'))
          : Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Gasolineras más cercanas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mostrando precios para: ${_cercanas.isNotEmpty && _cercanas.first.datos.containsKey('Precio ${_combustibleSeleccionado}') ? _combustibleSeleccionado : '-'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cercanas.length,
                    itemBuilder: (context, index) {
                      final gas = _cercanas[index];
                      final campoPrecio = 'Precio $_combustibleSeleccionado';
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
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Actualizado en el dispositivo: ${_formatearFechaLocal(_fechaActualizacionLocal)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
          print('[DEBUG] Navegando a la pantalla de configuración...');
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
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de combustible:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _combustible,
              isExpanded: true,
              items: combustibles
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _combustible = value);
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Distancia máxima (km):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            const Text(
              'Precio máximo por litro (€):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

Future<bool> solicitarPermisoUbicacionBackground(BuildContext context) async {
  LocationPermission permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.deniedForever) {
    return false;
  }
  if (permiso == LocationPermission.whileInUse) {
    // Mostrar diálogo explicativo
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación en segundo plano'),
        content: const Text(
          'Para poder avisarte aunque la app esté cerrada, necesitamos permiso de ubicación en segundo plano. ¿Quieres concederlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (aceptar == true) {
      permiso = await Geolocator.requestPermission();
    }
  }
  return permiso == LocationPermission.always;
}

Future<void> comprobarPermisoUbicacionAlways(BuildContext context) async {
  LocationPermission permiso = await Geolocator.checkPermission();
  if (permiso != LocationPermission.always) {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación necesario'),
        content: const Text(
          'Para que la app funcione correctamente en segundo plano, debes conceder el permiso de ubicación "Permitir siempre" (Allow all the time) en los ajustes de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Ir a ajustes'),
          ),
        ],
      ),
    );
  }
}
