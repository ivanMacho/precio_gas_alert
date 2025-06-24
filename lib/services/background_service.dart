import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart' as bl2;
import 'package:background_locator_2/settings/locator_settings.dart' as bl2;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gasolinera.dart';
import 'alert_service.dart';
import '../combustibles.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Servicio para gestionar la localización en background
class BackgroundService {
  static Position? ultimaPosicionBackground;

  /// Callback que se ejecuta en background cuando llega una nueva ubicación
  static void backgroundLocationCallback(LocationDto locationDto) async {
    print(
      '[BL2] Nueva ubicación recibida en background: ${locationDto.latitude}, ${locationDto.longitude}',
    );
    ultimaPosicionBackground = Position(
      latitude: locationDto.latitude,
      longitude: locationDto.longitude,
      timestamp: DateTime.now(),
      accuracy: locationDto.accuracy,
      altitude: locationDto.altitude,
      heading: locationDto.heading,
      speed: locationDto.speed,
      speedAccuracy: locationDto.speedAccuracy,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    // Cargar datos persistidos y preferencias
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('datos_api');
    if (jsonString == null) {
      print('[BL2] No hay datos de gasolineras persistidos.');
      return;
    }
    final data = json.decode(jsonString);
    final lista = data['ListaEESSPrecio'] as List<dynamic>;
    final gasolineras = lista.map((e) => Gasolinera.fromJson(e)).toList();
    final combustible = prefs.getString('combustible') ?? combustibles.first;
    final distanciaMax = prefs.getDouble('distancia') ?? 5.0;
    final precioMax = prefs.getDouble('precio') ?? 2.0;
    await AlertService.comprobarAlertas(
      gasolineras,
      ultimaPosicionBackground,
      combustible,
      distanciaMax,
      precioMax,
    );
  }

  /// Inicializa y registra el servicio de localización en background
  static Future<void> startBackgroundLocation({
    required Duration frecuenciaComprobacionBackground,
  }) async {
    print('[BL2] Inicializando background_locator_2...');
    try {
      final permiso = await Geolocator.checkPermission();
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      print('[BL2] Permiso de ubicación antes de registrar: $permiso');
      print('[BL2] Servicio de ubicación habilitado: $servicioHabilitado');
      if (permiso != LocationPermission.always) {
        print(
          '[BL2][ADVERTENCIA] El permiso NO es "always". El servicio puede no funcionar en background.',
        );
      }
      if (!servicioHabilitado) {
        print(
          '[BL2][ADVERTENCIA] El servicio de ubicación está deshabilitado.',
        );
      }
      await BackgroundLocator.initialize();
      print('[BL2] BackgroundLocator inicializado. Registrando callback...');
      await BackgroundLocator.registerLocationUpdate(
        backgroundLocationCallback,
        androidSettings: bl2.AndroidSettings(
          accuracy: bl2.LocationAccuracy.NAVIGATION,
          interval: frecuenciaComprobacionBackground.inMilliseconds,
          distanceFilter: 0,
          client: bl2.LocationClient.google,
          androidNotificationSettings: bl2.AndroidNotificationSettings(
            notificationChannelName: 'Ubicación en background',
            notificationTitle: 'La app está usando tu ubicación',
            notificationMsg:
                'Precio Gas Alert está comprobando gasolineras cercanas',
            notificationBigMsg:
                'Precio Gas Alert está comprobando gasolineras cercanas en segundo plano.',
            notificationIcon: '',
            notificationIconColor: Colors.blue,
          ),
        ),
        autoStop: false,
      );
      print(
        '[BL2] Servicio de localización en background registrado correctamente.',
      );
    } catch (e, st) {
      print(
        '[BL2][ERROR] Error al registrar el servicio de localización en background: $e',
      );
      print(st);
    }
  }
}
