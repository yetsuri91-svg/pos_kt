import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FacturaPreviewScreen extends StatefulWidget {
  final Widget facturaWidget;
  final String titulo;

  const FacturaPreviewScreen({
    super.key,
    required this.facturaWidget,
    required this.titulo,
  });

  @override
  State<FacturaPreviewScreen> createState() => _FacturaPreviewScreenState();
}

class _FacturaPreviewScreenState extends State<FacturaPreviewScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _generando = false;

  Future<Uint8List?> _capturarImagen() async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _compartirImagen(String mensaje) async {
    if (!mounted) return;
    setState(() => _generando = true);
    final bytes = await _capturarImagen();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar la imagen'), backgroundColor: Colors.red),
        );
      }
      setState(() => _generando = false);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/factura_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: mensaje,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _generando = false);
  }

  Future<void> _guardarEnDescargas() async {
    if (!mounted) return;
    setState(() => _generando = true);
    final bytes = await _capturarImagen();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar la imagen'), backgroundColor: Colors.red),
        );
      }
      setState(() => _generando = false);
      return;
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) throw Exception('No se pudo acceder a Descargas');

      final fileName = 'factura_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factura guardada en Descargas: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _generando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.titulo, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          if (_generando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: RepaintBoundary(
                  key: _captureKey,
                  child: widget.facturaWidget,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Compartir',
                  onPressed: () => _compartirImagen('📄 Factura de venta'),
                ),
                _buildActionButton(
                  icon: Icons.save_alt,
                  label: 'Guardar',
                  onPressed: _guardarEnDescargas,
                ),
                _buildActionButton(
                  icon: Icons.print,
                  label: 'Imprimir',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Función de impresión disponible pronto'), backgroundColor: Colors.blue),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.close,
                  label: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.blue,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 30),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}