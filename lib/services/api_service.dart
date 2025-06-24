import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gasolinera.dart';

/// Resultado de la consulta a la API: lista de gasolineras y fecha
class GasolinerasResult {
  final List<Gasolinera> gasolineras;
  final String fecha;
  GasolinerasResult(this.gasolineras, this.fecha);
}

/// Servicio para obtener y parsear los datos de la API de gasolineras
class ApiService {
  static const String apiUrl =
      'https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/';

  /// Llama a la API y devuelve la lista de gasolineras y la fecha
  static Future<GasolinerasResult> fetchGasolineras() async {
    final url = Uri.parse(apiUrl);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final lista = data['ListaEESSPrecio'] as List<dynamic>;
      final fecha = data['Fecha'] ?? '';
      final gasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
      return GasolinerasResult(gasolineras, fecha);
    } else {
      throw Exception('Error al obtener datos: ${response.statusCode}');
    }
  }
}
