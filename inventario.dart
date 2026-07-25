import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../modelos/producto.dart';
import 'escaner.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final db = DatabaseHelper();
  final TextEditingController _busquedaController = TextEditingController();
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);
    try {
      final productos = await db.obtenerProductos();
      if (mounted) {
        setState(() {
          _productos = productos;
          _productosFiltrados = productos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarError('Error al cargar productos: $e');
      }
    }
  }

  // ============================================================
  // OBTENER RUTA COMPLETA DE LA IMAGEN (con el nombre guardado)
  // ============================================================
  Future<String?> _obtenerRutaImagen(String nombreArchivo) async {
    if (nombreArchivo.isEmpty) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final ruta = '${appDir.path}/imagenes_productos/$nombreArchivo';
    if (await File(ruta).exists()) {
      return ruta;
    }
    return null;
  }

  // ============================================================
  // ESCÁNER
  // ============================================================
  void _abrirEscaner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EscanerScreen(
          onCodigoEscaneado: (codigo) {
            _procesarCodigoInventario(codigo);
          },
        ),
      ),
    );
  }

  Future<void> _procesarCodigoInventario(String codigo) async {
    try {
      final producto = await db.obtenerProductoPorCodigo(codigo);
      if (mounted) {
        if (producto != null) {
          setState(() {
            _productosFiltrados = [producto];
            _busquedaController.text = producto.nombre;
          });
          _mostrarExito('Producto encontrado: ${producto.nombre}');
        } else {
          setState(() {
            _productosFiltrados = [];
            _busquedaController.clear();
          });
          _mostrarError('Producto no encontrado');
        }
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al buscar: $e');
    }
  }

  // ============================================================
  // FORMULARIO (CREAR / EDITAR)
  // ============================================================
  void _abrirFormulario({Producto? producto}) {
    final isEdit = producto != null;
    final formKey = GlobalKey<FormState>();

    final nombreController = TextEditingController(text: producto?.nombre ?? '');
    final precioController = TextEditingController(text: producto?.precio.toString() ?? '');
    final stockController = TextEditingController(text: producto?.stock.toString() ?? '');
    final categoriaController = TextEditingController(text: producto?.categoria ?? '');
    final unidadController = TextEditingController(text: producto?.unidadMedida ?? '');
    final codigoController = TextEditingController(text: producto?.codigoBarra ?? '');
    final precioCompraController = TextEditingController(
      text: producto?.precioCompraUsd?.toString() ?? '',
    );
    final unidadesPacaController = TextEditingController(
      text: producto?.unidadesPorPaca.toString() ?? '1',
    );
    String? imagenRuta = producto?.imagenRuta;
    final ImagePicker picker = ImagePicker();

    bool modoPaca = (producto?.unidadesPorPaca ?? 1) > 1;
    TextEditingController stockControllerEdit = stockController;
    TextEditingController pacasController = TextEditingController();
    TextEditingController unidadesPorPacaController = TextEditingController();

    if (modoPaca && producto != null) {
      final unidades = producto.unidadesPorPaca;
      final stock = producto.stock;
      final pacas = (stock / unidades).floor();
      pacasController.text = pacas.toString();
      unidadesPorPacaController.text = unidades.toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF112240),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEdit ? 'Editar producto' : 'Nuevo producto',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCampo(nombreController, 'Nombre *', esObligatorio: true),
                    _buildCampo(precioController, 'Precio USD *', esObligatorio: true, keyboard: TextInputType.number),
                    _buildCampo(categoriaController, 'Categoría'),
                    _buildCampo(unidadController, 'Unidad de medida *', esObligatorio: true),
                    _buildCampo(codigoController, 'Código de barras'),
                    _buildCampo(precioCompraController, 'Precio compra USD', keyboard: TextInputType.number),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Modo Paca:', style: TextStyle(color: Colors.white)),
                        const SizedBox(width: 8),
                        Switch(
                          value: modoPaca,
                          onChanged: (value) {
                            setStateDialog(() {
                              modoPaca = value;
                              if (!modoPaca) {
                                pacasController.clear();
                                unidadesPorPacaController.clear();
                              }
                            });
                          },
                          activeThumbColor: Colors.blue,
                          inactiveThumbColor: Colors.grey,
                        ),
                      ],
                    ),

                    if (!modoPaca) ...[
                      _buildCampo(stockControllerEdit, 'Stock *', esObligatorio: true, keyboard: TextInputType.number),
                    ] else ...[
                      _buildCampo(pacasController, 'Cantidad de pacas *', esObligatorio: true, keyboard: TextInputType.number),
                      _buildCampo(unidadesPorPacaController, 'Unidades por paca *', esObligatorio: true, keyboard: TextInputType.number),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imagenRuta != null ? 'Imagen seleccionada' : 'Sin imagen',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final appDir = await getApplicationDocumentsDirectory();
                              final imagesDir = Directory('${appDir.path}/imagenes_productos');
                              if (!await imagesDir.exists()) {
                                await imagesDir.create(recursive: true);
                              }
                              final destino = File('${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}.png');
                              await File(image.path).copy(destino.path);
                              // ✅ Guarda solo el nombre del archivo
                              setStateDialog(() {
                                imagenRuta = destino.path.split('/').last;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          child: const Text('Seleccionar imagen'),
                        ),
                        if (imagenRuta != null)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () => setStateDialog(() => imagenRuta = null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final nombre = nombreController.text.trim();
                  final precio = double.tryParse(precioController.text.trim()) ?? 0;
                  final categoria = categoriaController.text.trim();
                  final unidad = unidadController.text.trim();
                  final codigo = codigoController.text.trim();
                  final precioCompra = double.tryParse(precioCompraController.text.trim()) ?? 0;

                  double stock;
                  int unidadesPaca;
                  if (modoPaca) {
                    final pacas = int.tryParse(pacasController.text.trim()) ?? 0;
                    final unidadesPorPaca = int.tryParse(unidadesPorPacaController.text.trim()) ?? 1;
                    stock = (pacas * unidadesPorPaca).toDouble();
                    unidadesPaca = unidadesPorPaca;
                  } else {
                    stock = double.tryParse(stockControllerEdit.text.trim()) ?? 0;
                    unidadesPaca = 1;
                  }

                  final nuevoProducto = Producto(
                    id: isEdit ? producto!.id : null,
                    nombre: nombre,
                    precio: precio,
                    stock: stock,
                    categoria: categoria,
                    unidadMedida: unidad,
                    codigoBarra: codigo.isNotEmpty ? codigo : null,
                    precioCompraUsd: precioCompra > 0 ? precioCompra : null,
                    unidadesPorPaca: unidadesPaca,
                    imagenRuta: imagenRuta, // Esto se guarda como solo el nombre (gracias a toMap)
                  );

                  try {
                    if (isEdit) {
                      await db.actualizarProducto(nuevoProducto);
                    } else {
                      await db.insertarProducto(nuevoProducto);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      _cargarProductos();
                      _mostrarExito(isEdit ? 'Producto actualizado' : 'Producto creado');
                    }
                  } catch (e) {
                    if (mounted) _mostrarError('Error al guardar: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(isEdit ? 'Actualizar' : 'Crear', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampo(
    TextEditingController controller,
    String label, {
    bool esObligatorio = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        ),
        validator: (value) {
          if (esObligatorio && (value == null || value.isEmpty)) {
            return 'Campo obligatorio';
          }
          return null;
        },
      ),
    );
  }

  // ============================================================
  // ELIMINAR PRODUCTO
  // ============================================================
  Future<void> _eliminarProducto(Producto producto) async {
    if (producto.id == null) {
      _mostrarError('ID de producto inválido');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('Eliminar producto', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${producto.nombre}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await db.eliminarProducto(producto.id!);
        if (mounted) {
          _cargarProductos();
          _mostrarExito('Producto eliminado');
        }
      } catch (e) {
        if (mounted) _mostrarError('Error al eliminar: $e');
      }
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================
  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
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
        title: const Text('Inventario', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _abrirEscaner,
            tooltip: 'Escanear código de barras',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarProductos,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _busquedaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '🔍 Buscar por nombre o código...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A2A4A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _busquedaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _productosFiltrados = _productos);
                        },
                      )
                    : null,
              ),
              onChanged: (query) {
                setState(() {
                  if (query.isEmpty) {
                    _productosFiltrados = _productos;
                  } else {
                    _productosFiltrados = _productos.where((p) {
                      final nombre = p.nombre.toLowerCase();
                      final codigo = p.codigoBarra?.toLowerCase() ?? '';
                      final search = query.toLowerCase();
                      return nombre.contains(search) || codigo.contains(search);
                    }).toList();
                  }
                });
              },
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _productosFiltrados.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final p = _productosFiltrados[index];
                    final ganancia = p.precio - (p.precioCompraUsd ?? 0);
                    return Card(
                      color: const Color(0xFF1A2A4A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: FutureBuilder<String?>(
                        future: _obtenerRutaImagen(p.imagenRuta ?? ''),
                        builder: (context, snapshot) {
                          final rutaImagen = snapshot.data;
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: rutaImagen != null && rutaImagen.isNotEmpty
                                  ? Image.file(
                                      File(rutaImagen),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Colors.grey, size: 40),
                                    )
                                  : const Icon(Icons.inventory, color: Colors.grey, size: 40),
                            ),
                            title: Text(
                              p.nombre,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stock: ${p.stock.toStringAsFixed(0)}  |  Precio: \$${p.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white70)),
                                if (p.codigoBarra != null && p.codigoBarra!.isNotEmpty)
                                  Text('Código: ${p.codigoBarra}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                Text('Ganancia: \$${ganancia.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.lightBlueAccent)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _abrirFormulario(producto: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _eliminarProducto(p),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}