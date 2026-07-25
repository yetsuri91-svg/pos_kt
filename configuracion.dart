import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';
import '../database/database_helper.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final db = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _rifController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _bancoController = TextEditingController();
  final _telefonoPagoController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _tasaController = TextEditingController();

  String? _logoPath; // SOLO EL NOMBRE DEL ARCHIVO
  bool _cargando = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rifController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _bancoController.dispose();
    _telefonoPagoController.dispose();
    _cedulaController.dispose();
    _tasaController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _cargando = true);
    try {
      final config = await db.obtenerConfiguracion();
      final tasa = await db.obtenerTasa();

      _nombreController.text = config['nombre_negocio'] ?? '';
      _rifController.text = config['rif'] ?? '';
      _telefonoController.text = config['telefono_negocio'] ?? '';
      _direccionController.text = config['direccion'] ?? '';
      _bancoController.text = config['banco'] ?? '';
      _telefonoPagoController.text = config['telefono_pago'] ?? '';
      _cedulaController.text = config['cedula'] ?? '';
      _tasaController.text = tasa.toString();

      final rutaLogo = config['ruta_logo'];
      // ✅ Verificar que el archivo exista en la carpeta config/
      if (rutaLogo != null && rutaLogo.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final fullPath = '${appDir.path}/config/$rutaLogo';
        if (File(fullPath).existsSync()) {
          _logoPath = rutaLogo; // Solo el nombre
        } else {
          _logoPath = null;
        }
      } else {
        _logoPath = null;
      }

      setState(() => _cargando = false);
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarError('Error al cargar configuración: $e');
    }
  }

  Future<void> _seleccionarLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final configDir = Directory('${appDir.path}/config');
        if (!await configDir.exists()) {
          await configDir.create(recursive: true);
        }

        // ✅ Guardar con nombre único y sin ruta
        final nombreArchivo = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
        final destino = File('${configDir.path}/$nombreArchivo');
        await File(image.path).copy(destino.path);

        setState(() => _logoPath = nombreArchivo); // Solo el nombre
        _mostrarExito('Logo seleccionado correctamente');

        final config = await db.obtenerConfiguracion();
        config['ruta_logo'] = nombreArchivo; // Guardar solo el nombre
        await db.guardarConfiguracion(config);
      }
    } catch (e) {
      _mostrarError('Error al seleccionar logo: $e');
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final config = {
        'nombre_negocio': _nombreController.text.trim(),
        'rif': _rifController.text.trim(),
        'telefono_negocio': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'banco': _bancoController.text.trim(),
        'telefono_pago': _telefonoPagoController.text.trim(),
        'cedula': _cedulaController.text.trim(),
        'ruta_logo': _logoPath ?? '',
      };

      await db.guardarConfiguracion(config);

      final tasa = double.tryParse(_tasaController.text.trim()) ?? 1.0;
      await db.guardarTasa(tasa);

      _mostrarExito('Configuración guardada correctamente');
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    }
  }

  // ============================================================
  // EXPORTAR/IMPORTAR ZIP (respaldo completo)
  // ============================================================
  Future<File> _crearZipBackup() async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/pos_backup.zip';

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final dbPath = await db.getDatabasePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      encoder.addFile(dbFile, 'pos.db');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/imagenes_productos');
    if (await imagesDir.exists()) {
      final files = imagesDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          final relativePath = file.path.replaceFirst('${appDir.path}/', '');
          encoder.addFile(file, relativePath);
        }
      }
    }

    // También agregar la carpeta config (donde está el logo)
    final configDir = Directory('${appDir.path}/config');
    if (await configDir.exists()) {
      final files = configDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          final relativePath = file.path.replaceFirst('${appDir.path}/', '');
          encoder.addFile(file, relativePath);
        }
      }
    }

    encoder.close();
    return File(zipPath);
  }

  Future<void> _exportarBD() async {
    try {
      final zipFile = await _crearZipBackup();
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        text: '📦 Respaldo completo de la base de datos e imágenes POS',
      );
      _mostrarExito('Respaldo completo exportado correctamente');
    } catch (e) {
      _mostrarError('Error al exportar: $e');
    }
  }

  Future<void> _restaurarDesdeZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final appDir = await getApplicationDocumentsDirectory();

    for (var file in archive) {
      if (file.isFile) {
        final fileName = file.name;
        final destPath = '${appDir.path}/$fileName';
        final destFile = File(destPath);
        await destFile.parent.create(recursive: true);
        await destFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  Future<void> _importarBD() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return;

      final path = result.files.single.path;
      if (path == null) {
        _mostrarError('No se pudo obtener la ruta del archivo');
        return;
      }

      await _restaurarDesdeZip(path);
      _mostrarExito('✅ Restauración completa exitosa. Reinicia la app.');
    } catch (e) {
      _mostrarError('Error al importar: ${e.toString()}');
    }
  }

  // ============================================================
  // ADMINISTRAR BASE DE DATOS
  // ============================================================
  Future<void> _borrarTabla(String tabla, String mensaje) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('⚠️ Confirmar borrado', style: TextStyle(color: Colors.white)),
        content: Text(mensaje, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final db = await DatabaseHelper().database;
        await db.delete(tabla);
        _mostrarExito('$tabla borrada correctamente');
      } catch (e) {
        _mostrarError('Error al borrar $tabla: $e');
      }
    }
  }

  Future<void> _reiniciarTodo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('⚠️ PELIGRO', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Esto borrará TODOS los datos (ventas, productos, clientes, fiados, egresos).\n\n'
          'La configuración (logo, nombre, RIF) y la clave de acceso NO se borran.\n\n'
          '¿Estás seguro?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, borrar todo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final db = await DatabaseHelper().database;
        await db.delete('ventas');
        await db.delete('ventas_detalle');
        await db.delete('fiados');
        await db.delete('egresos');
        await db.delete('inventario');
        _mostrarExito('Todos los datos transaccionales borrados correctamente');
      } catch (e) {
        _mostrarError('Error al reiniciar: $e');
      }
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================
  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _guardar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ================= DATOS DEL NEGOCIO =================
                    const Text('Datos del negocio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildTextField(_nombreController, 'Nombre del negocio'),
                    _buildTextField(_rifController, 'RIF'),
                    _buildTextField(_telefonoController, 'Teléfono'),
                    _buildTextField(_direccionController, 'Dirección', maxLines: 2),

                    // ================= LOGO =================
                    const SizedBox(height: 16),
                    const Text('Logo del negocio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1A2A4A), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logoPath != null ? 'Logo seleccionado ✅' : 'Sin logo',
                                  style: TextStyle(color: _logoPath != null ? Colors.green : Colors.grey),
                                ),
                                if (_logoPath != null)
                                  Text(_logoPath!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _seleccionarLogo,
                            icon: const Icon(Icons.image),
                            label: const Text('Seleccionar logo'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                          if (_logoPath != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () => setState(() => _logoPath = null),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('El logo se guarda permanentemente en la app.', style: TextStyle(color: Colors.grey, fontSize: 11)),

                    // ================= PAGO MÓVIL =================
                    const SizedBox(height: 16),
                    const Text('Pago Móvil (para QR en factura)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildTextField(_bancoController, 'Banco'),
                    _buildTextField(_telefonoPagoController, 'Teléfono asociado'),
                    _buildTextField(_cedulaController, 'Cédula del titular'),

                    // ================= TASA DE CAMBIO =================
                    const SizedBox(height: 16),
                    const Text('Tasa de cambio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildTextField(_tasaController, 'Bs/USD', keyboardType: TextInputType.number),

                    const SizedBox(height: 24),

                    // ================= RESPALDO COMPLETO (ZIP) =================
                    const Divider(color: Colors.grey, thickness: 2),
                    const Text('📦 RESPALDO COMPLETO (BASE DE DATOS + IMÁGENES + LOGO)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Exporta un archivo ZIP que contiene la base de datos y todas las imágenes.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _exportarBD,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('📤 Exportar respaldo completo (ZIP)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      onPressed: _importarBD,
                      icon: const Icon(Icons.download),
                      label: const Text('📥 Importar respaldo completo (ZIP)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),

                    const SizedBox(height: 24),

                    // ================= ADMINISTRAR BASE DE DATOS =================
                    const Divider(color: Colors.grey, thickness: 2),
                    const Text('🗑️ ADMINISTRAR BASE DE DATOS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Borra datos por tabla. Esta acción no se puede deshacer.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () => _borrarTabla('ventas', '¿Borrar TODAS las ventas?'),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Borrar todas las ventas'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      onPressed: () => _borrarTabla('fiados', '¿Borrar TODOS los fiados?'),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Borrar todos los fiados'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      onPressed: () => _borrarTabla('egresos', '¿Borrar TODOS los egresos?'),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Borrar todos los egresos'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      onPressed: () => _borrarTabla('inventario', '¿Borrar TODOS los productos?'),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Borrar todos los productos'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _reiniciarTodo,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('⚠️ REINICIAR TODO (ventas, fiados, egresos, productos)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _guardar,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        ),
        validator: (value) => (value == null || value.isEmpty) ? 'Este campo es obligatorio' : null,
      ),
    );
  }
}