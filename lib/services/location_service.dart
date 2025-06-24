import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

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
}
