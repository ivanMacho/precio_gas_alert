import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../combustibles.dart';

/// Pantalla de configuración para seleccionar combustible, distancia y precio
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
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
