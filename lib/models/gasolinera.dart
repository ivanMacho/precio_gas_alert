/// Modelo de datos para una gasolinera
class Gasolinera {
  /// Nombre comercial de la gasolinera
  final String rotulo;

  /// Latitud en WGS84
  final double latitud;

  /// Longitud en WGS84
  final double longitud;

  /// Mapa con todos los datos originales del JSON
  final Map<String, dynamic> datos;

  Gasolinera({
    required this.rotulo,
    required this.latitud,
    required this.longitud,
    required this.datos,
  });

  /// Crea una instancia de Gasolinera a partir de un JSON
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
