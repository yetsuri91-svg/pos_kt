import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EscanerScreen extends StatefulWidget {
  final Function(String) onCodigoEscaneado;

  const EscanerScreen({
    super.key,
    required this.onCodigoEscaneado,
  });

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.upcA, BarcodeFormat.code128],
  );
  bool _estaEscaneando = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_estaEscaneando) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final codigo = barcode.rawValue;
    if (codigo == null || codigo.isEmpty) return;

    setState(() => _estaEscaneando = false);
    widget.onCodigoEscaneado(codigo);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Coloca el código de barras dentro del recuadro',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.flashlight_on, color: Colors.white),
              onPressed: () => _controller.toggleTorch(),
              iconSize: 30,
            ),
          ),
        ],
      ),
    );
  }
}