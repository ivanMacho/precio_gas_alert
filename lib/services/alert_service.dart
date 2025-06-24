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
}
