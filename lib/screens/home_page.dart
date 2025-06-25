import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gasolinera.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/alert_service.dart';
import '../combustibles.dart';
import 'config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';

/// Pantalla principal que muestra la lista de gasolineras que cumplen los criterios de alerta y permite refrescar/configurar
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Gasolinera> _todasGasolineras = [];
  List<Gasolinera> _gasolinerasConAlerta = [];
  Position? _posicionUsuario;
  bool _cargando = true;
  String? _error;
  String _combustibleSeleccionado = combustibles.first;
  String? _fechaDatos;
  late AnimationController _animationController;
  Timer? _timerAlertas;
  double _distanciaMax = 5.0;
  double _precioMax = 2.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocationService.solicitarPermisoUbicacionBackground(context);
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
      _distanciaMax = prefs.getDouble('distancia') ?? 5.0;
      _precioMax = prefs.getDouble('precio') ?? 2.0;
    });
  }

  Future<void> _cargarDatosPersistidos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('datos_api');
    final fecha = prefs.getString('fecha_api');
    if (jsonString != null) {
      final data = ApiService
          .apiUrl; // dummy para evitar warning, reemplazar por parseo real si se desea
      // Aquí deberías parsear el jsonString si quieres mostrar datos persistidos
      setState(() {
        _fechaDatos = fecha;
        _cargando = false;
      });
    }
  }

  Future<void> _persistirDatosApi(String jsonString, String fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('datos_api', jsonString);
    await prefs.setString('fecha_api', fecha);
    setState(() {
      _fechaDatos = fecha;
    });
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    _animationController.repeat();
    try {
      _posicionUsuario = await LocationService.getCurrentPosition();
      final result = await ApiService.fetchGasolineras();
      setState(() {
        _todasGasolineras = result.gasolineras;
        _fechaDatos = result.fecha;
      });
      await _filtrarGasolinerasConAlerta();
      final prefs = await SharedPreferences.getInstance();
      final combustible = prefs.getString('combustible') ?? combustibles.first;
      final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
      final precioMax = prefs.getDouble('precio') ?? 2.0;
      await AlertService.comprobarAlertas(
        _todasGasolineras,
        _posicionUsuario,
        combustible,
        distanciaMax,
        precioMax,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _cargando = false;
      });
      _animationController.stop();
    }
  }

  Future<void> _filtrarGasolinerasConAlerta() async {
    if (_posicionUsuario == null) return;

    final gasolinerasConAlerta = await AlertService.obtenerGasolinerasConAlerta(
      _todasGasolineras,
      _posicionUsuario,
      _combustibleSeleccionado,
      _distanciaMax,
      _precioMax,
    );

    setState(() {
      _gasolinerasConAlerta = gasolinerasConAlerta;
    });
  }

  Future<void> _refrescarConfiguracion() async {
    await _cargarCombustibleSeleccionado();
    await _filtrarGasolinerasConAlerta();
    setState(() {});
  }

  void _iniciarTimerAlertas() {
    _timerAlertas = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _comprobarAlertasPeriodicas();
    });
  }

  Future<void> _comprobarAlertasPeriodicas() async {
    final prefs = await SharedPreferences.getInstance();
    final combustible = prefs.getString('combustible') ?? combustibles.first;
    final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
    final precioMax = prefs.getDouble('precio') ?? 2.0;
    try {
      Position? posicionUsuario = await LocationService.getCurrentPosition();
      await AlertService.comprobarAlertas(
        _todasGasolineras,
        posicionUsuario,
        combustible,
        distanciaMax,
        precioMax,
      );
    } catch (e) {
      // Ignorar errores en comprobación periódica
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
          : _gasolinerasConAlerta.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_gas_station_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay gasolineras que cumplan los criterios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Combustible: $_combustibleSeleccionado\nPrecio máximo: $_precioMax €/L\nDistancia máxima: $_distanciaMax km',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Tus gasolineras filtradas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_combustibleSeleccionado ≤ $_precioMax €/L • ≤ $_distanciaMax km',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_gasolinerasConAlerta.length} gasolinera${_gasolinerasConAlerta.length == 1 ? '' : 's'} encontrada${_gasolinerasConAlerta.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _gasolinerasConAlerta.length,
                    itemBuilder: (context, index) {
                      final gas = _gasolinerasConAlerta[index];
                      final campoPrecio = 'Precio $_combustibleSeleccionado';
                      String precio = gas.datos[campoPrecio]?.toString() ?? '';
                      if (precio.isEmpty) precio = 'N/D';

                      // Calcular distancia
                      double distancia = 0.0;
                      if (_posicionUsuario != null) {
                        distancia =
                            Geolocator.distanceBetween(
                              _posicionUsuario!.latitude,
                              _posicionUsuario!.longitude,
                              gas.latitud,
                              gas.longitud,
                            ) /
                            1000.0;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_gas_station,
                            color: Colors.green,
                          ),
                          title: Text(
                            gas.rotulo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Precio: $precio €/L'),
                              Text(
                                'Distancia: ${distancia.toStringAsFixed(2)} km',
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final cambiosGuardados = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (context) => const ConfigPage()),
          );

          // Solo actualizar si se guardaron cambios
          if (cambiosGuardados == true) {
            await _refrescarConfiguracion();
          }
        },
        tooltip: 'Ajustes',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
