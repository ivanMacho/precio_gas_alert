# Precio Gas Alert

**Precio Gas Alert** es una app Flutter para Android que te muestra las gasolineras más cercanas y te alerta si cumplen tus criterios de precio y distancia. Pensada para ahorrar en combustible y facilitar la vida al conductor.

---

## 🚀 ¿Qué hace la app?
- Muestra las 5 gasolineras más cercanas a tu ubicación actual.
- Permite configurar el tipo de combustible, la distancia máxima y el precio máximo.
- Te alerta (por consola/log) si alguna gasolinera cercana cumple tus criterios.
- Actualiza los datos automáticamente en segundo plano, incluso con la app cerrada.
- Guía al usuario para conceder los permisos necesarios de ubicación y background.

---

## 🛠️ Arquitectura y funcionamiento técnico

La app está desarrollada en **Flutter** y sigue una arquitectura modular, separando modelos, servicios, pantallas y utilidades para facilitar el mantenimiento y la escalabilidad.

### **Flujo general**
1. **SplashScreen**: Muestra el logo y navega a la pantalla principal.
2. **HomePage**: Obtiene la ubicación, descarga los datos de la API pública de gasolineras, muestra las más cercanas y comprueba condiciones de alerta periódicamente.
3. **ConfigPage**: Permite al usuario configurar sus criterios de alerta y guarda la configuración en preferencias.
4. **BackgroundService**: Usa el plugin `background_locator_2` para recibir ubicaciones en background y comprobar alertas aunque la app esté cerrada.

---

## 📁 Estructura de archivos

```
lib/
  main.dart                  # Arranque de la app y widget raíz
  combustibles.dart          # Lista de tipos de combustible
  models/
    gasolinera.dart          # Modelo de datos Gasolinera
  services/
    api_service.dart         # Lógica de llamada y parseo de la API
    location_service.dart    # Obtención de ubicación y permisos
    alert_service.dart       # Lógica de comprobación de alertas
    background_service.dart  # Inicialización y callback de background_locator_2
  screens/
    splash_screen.dart       # Pantalla de splash
    home_page.dart           # Pantalla principal
    config_page.dart         # Pantalla de configuración
```

---

## 🧩 Explicación de clases y servicios

### **Modelos**
- **Gasolinera**: Representa una gasolinera, con nombre, latitud, longitud y todos los datos originales del JSON de la API.

### **Servicios**
- **ApiService**: Llama a la API pública, parsea la respuesta y devuelve una lista de gasolineras y la fecha de los datos.
- **LocationService**: Gestiona la obtención de la ubicación actual y los permisos de localización (incluyendo background).
- **AlertService**: Comprueba si alguna gasolinera cumple los criterios de alerta (distancia y precio) y lanza prints de alerta.
- **BackgroundService**: Inicializa y gestiona el plugin `background_locator_2` para recibir ubicaciones en background y comprobar alertas aunque la app esté cerrada.

### **Pantallas**
- **SplashScreen**: Muestra el logo durante 2 segundos y navega a la pantalla principal.
- **HomePage**: Muestra la lista de gasolineras cercanas, permite refrescar y acceder a la configuración, y comprueba alertas periódicamente.
- **ConfigPage**: Permite seleccionar el tipo de combustible, la distancia máxima y el precio máximo, y guarda la configuración en preferencias.

### **Constantes**
- **combustibles.dart**: Lista de tipos de combustible disponibles para seleccionar en la configuración.

---

## ⚙️ Funcionamiento técnico detallado

- **Obtención de ubicación**: Usa el plugin `geolocator` para obtener la ubicación en foreground y gestionar permisos.
- **Llamada a la API**: Descarga los datos de todas las gasolineras de España desde la API pública del Ministerio.
- **Filtrado y ordenación**: Calcula la distancia a cada gasolinera y muestra las 5 más cercanas.
- **Comprobación de alertas**: Cada X segundos (configurable), compara la distancia y el precio de las gasolineras con los criterios del usuario y lanza una alerta por log si se cumple.
- **Background**: Usa `background_locator_2` para recibir ubicaciones en background real y comprobar alertas aunque la app esté cerrada (Android, permisos "Permitir siempre").
- **Persistencia**: Guarda la configuración y los datos descargados en `SharedPreferences` para mostrar datos aunque no haya conexión.

---

## 📝 Notas y recomendaciones
- La app está optimizada solo para Android.
- Para recibir alertas en background, es imprescindible conceder el permiso "Permitir siempre" y desactivar restricciones de batería para la app.
- El intervalo de comprobación en background depende de las políticas de Android y puede no ser exacto.
- El código está modularizado y documentado para facilitar la extensión y el mantenimiento.

---

## 👨‍💻 Autor y licencia
- Desarrollado por [Tu Nombre].
- Licencia MIT.

---

¿Dudas, sugerencias o mejoras? ¡Abre un issue o un pull request!
