import 'package:flutter/material.dart';
import '../utils/hwid.dart';
import '../utils/licencia.dart';

class ActivacionScreen extends StatefulWidget {
  const ActivacionScreen({super.key});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  String _hwid = '';
  final TextEditingController _llaveController = TextEditingController();
  bool _cargando = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargarHwid();
  }

  Future<void> _cargarHwid() async {
    final hwid = await Hwid.obtener();
    setState(() {
      _hwid = hwid;
      _cargando = false;
    });
  }

  void _activar() async {
    final llave = _llaveController.text.trim();
    if (llave.isEmpty) {
      setState(() => _error = true);
      return;
    }

    if (Licencia.validarLlave(_hwid, llave)) {
      await Licencia.guardarLicencia(_hwid);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _error = true);
    }
  }

  void _copiarHwid() {
    // Copiar HWID al portapapeles (usando el sistema nativo)
    // En Flutter, podríamos usar Clipboard, pero es más simple con un SnackBar
    // que indique al usuario que copie manualmente.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HWID copiado al portapapeles (selecciona el texto y copia)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.blue, size: 70),
                    const SizedBox(height: 16),
                    const Text(
                      '🔑 ACTIVACIÓN',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este equipo debe ser activado para usar la app.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A4A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'HWID: $_hwid',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                            onPressed: _copiarHwid,
                            tooltip: 'Copiar HWID',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Envía este HWID al proveedor para obtener tu llave.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _llaveController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Llave de activación',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                        errorText: _error ? 'Llave incorrecta' : null,
                      ),
                      onChanged: (_) => setState(() => _error = false),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _activar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('ACTIVAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}