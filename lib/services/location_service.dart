import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

/// Servicio para gestionar la ubicación y los permisos
class LocationService {
  /// Obtiene la posición actual del usuario (o null si no es posible)
  static Future<Position?> getCurrentPosition() async {
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) return null;
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return null;
    }
    if (permiso == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition();
  }

  /// Comprueba y solicita el permiso de ubicación en background
  /// Devuelve true si se obtiene el permiso "always"
  static Future<bool> solicitarPermisoUbicacionBackground(
    BuildContext context,
  ) async {
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
            'Para que la app funcione correctamente en segundo plano, debes conceder el permiso de ubicación "Permitir siempre" (always) en la configuración de la app.\n\nAdemás, desactiva cualquier restricción de ahorro de batería para esta app en tu dispositivo Android.\n\n¿Quieres ir a la configuración ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
                AppSettings.openAppSettings();
              },
              child: const Text('Sí'),
            ),
          ],
        ),
      );
      // No se solicita el permiso automáticamente, el usuario debe hacerlo manualmente
    }
    return permiso == LocationPermission.always;
  }
}
