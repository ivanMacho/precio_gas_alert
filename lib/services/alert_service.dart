import 'package:geolocator/geolocator.dart';
import '../models/gasolinera.dart';

/// Servicio para comprobar condiciones de alerta
class AlertService {
  /// Comprueba si alguna gasolinera cumple los criterios y lanza prints de alerta
  static Future<void> comprobarAlertas(
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
          1000.0;
      if (distancia <= distanciaMax && precio <= precioMax) {
        print(
          '[ALERTA] Gasolinera cerca: ${gas.rotulo}, distancia: ${distancia.toStringAsFixed(2)} km, precio: $precio €/L',
        );
      }
    }
  }

  /// Obtiene las gasolineras que cumplen las condiciones de alerta
  static Future<List<Gasolinera>> obtenerGasolinerasConAlerta(
    List<Gasolinera> gasolineras,
    Position? posicionUsuario,
    String combustible,
    double distanciaMax,
    double precioMax,
  ) async {
    if (posicionUsuario == null) return [];

    List<Gasolinera> gasolinerasConAlerta = [];

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
          1000.0;
      if (distancia <= distanciaMax && precio <= precioMax) {
        gasolinerasConAlerta.add(gas);
      }
    }

    // Ordenar por distancia (más cercanas primero)
    gasolinerasConAlerta.sort((a, b) {
      double da = Geolocator.distanceBetween(
        posicionUsuario.latitude,
        posicionUsuario.longitude,
        a.latitud,
        a.longitud,
      );
      double db = Geolocator.distanceBetween(
        posicionUsuario.latitude,
        posicionUsuario.longitude,
        b.latitud,
        b.longitud,
      );
      return da.compareTo(db);
    });

    return gasolinerasConAlerta;
  }
}
