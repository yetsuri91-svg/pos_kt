import 'package:flutter/material.dart';
import 'dart:async'; // Para Timer
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // Necesario para _obtenerRutaImagen
import '../database/database_helper.dart';
import '../modelos/producto.dart';
import '../widgets/factura_widget.dart' as factura;
import 'factura_preview.dart';
import 'escaner.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final db = DatabaseHelper();
  final TextEditingController _busquedaController = TextEditingController();
  final List<Map<String, dynamic>> _carrito = [];
  double _tasa = 1.0;
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _cargarTasa();
    _cargarProductos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarTasa() async {
    final tasa = await db.obtenerTasa();
    if (mounted) setState(() => _tasa = tasa);
  }

  Future<void> _cargarProductos() async {
    final productos = await db.obtenerProductos();
    if (mounted) {
      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
      });
    }
  }

  // ============================================================
  // 🔧 OBTENER RUTA COMPLETA DE LA IMAGEN (igual que en Inventario)
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

  void _mostrarDialogoCantidad(Producto producto) {
    final cantidadController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '📦 ${producto.nombre}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Precio: \$${producto.precio.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Stock disponible: ${producto.stock.toStringAsFixed(0)}',
                style: TextStyle(
                  color: producto.stock < 5 ? Colors.red : Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese una cantidad';
                  final cant = double.tryParse(value);
                  if (cant == null || cant <= 0) return 'Cantidad inválida';
                  if (cant > producto.stock) return 'Stock insuficiente (máx: ${producto.stock.toStringAsFixed(0)})';
                  return null;
                },
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cantidad = double.parse(cantidadController.text.trim());
                _agregarAlCarrito(producto, cantidad);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Agregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _agregarAlCarrito(Producto producto, double cantidad) {
    setState(() {
      final index = _carrito.indexWhere((item) => item['producto_id'] == producto.id);
      if (index != -1) {
        _carrito[index]['cantidad'] += cantidad;
      } else {
        _carrito.add({
          'producto_id': producto.id,
          'nombre': producto.nombre,
          'precio': producto.precio,
          'cantidad': cantidad,
          'stock': producto.stock,
        });
      }
    });
    _mostrarExito('${cantidad.toStringAsFixed(0)} x ${producto.nombre} agregado');
  }

  double _calcularTotal() {
    return _carrito.fold(0.0, (sum, item) => sum + (item['precio'] * item['cantidad']));
  }

  void _eliminarDelCarrito(String nombre) {
    setState(() => _carrito.removeWhere((item) => item['nombre'] == nombre));
  }

  void _limpiarCarrito() {
    setState(() => _carrito.clear());
  }

  void _abrirEscaner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EscanerScreen(
          onCodigoEscaneado: (codigo) async {
            final producto = await db.obtenerProductoPorCodigo(codigo);
            if (producto != null) {
              _mostrarDialogoCantidad(producto);
            } else {
              _mostrarError('Producto no encontrado');
            }
          },
        ),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  void _abrirPago() {
    if (_carrito.isEmpty) {
      _mostrarError('El carrito está vacío');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PagoDialog(
        carrito: _carrito,
        total: _calcularTotal(),
        tasa: _tasa,
        onPagoExitoso: () {
          if (mounted) {
            setState(() {
              _carrito.clear();
              _busquedaController.clear();
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      appBar: AppBar(
        title: const Text('Ventas', style: TextStyle(color: Colors.white)),
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
            onPressed: () {
              _cargarTasa();
              _cargarProductos();
            },
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
      body: _productos.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : isSmallScreen
              ? _buildVerticalLayout()
              : _buildHorizontalLayout(),
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        Expanded(child: _buildGridProductos()),
        _buildCarritoPanel(width: 320),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildGridProductos()),
        Container(
          height: 280,
          child: _buildCarritoPanel(width: double.infinity),
        ),
      ],
    );
  }

  // ============================================================
  // GRID DE PRODUCTOS CON IMÁGENES
  // ============================================================
  Widget _buildGridProductos() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: _productosFiltrados.length,
      itemBuilder: (context, index) {
        final p = _productosFiltrados[index];
        return _buildProductoCard(p);
      },
    );
  }

  // ============================================================
  // TARJETA DE PRODUCTO CON IMAGEN (usando FutureBuilder)
  // ============================================================
  Widget _buildProductoCard(Producto p) {
    return GestureDetector(
      onTap: () => _mostrarDialogoCantidad(p),
      child: Card(
        color: const Color(0xFF1A2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: FutureBuilder<String?>(
                future: _obtenerRutaImagen(p.imagenRuta ?? ''),
                builder: (context, snapshot) {
                  final rutaImagen = snapshot.data;
                  if (rutaImagen != null && rutaImagen.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.file(
                        File(rutaImagen),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Colors.grey, size: 40),
                      ),
                    );
                  }
                  return const Icon(Icons.inventory, color: Colors.grey, size: 40);
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${p.precio.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                    ),
                    Text(
                      'Stock: ${p.stock.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: p.stock < 5 ? Colors.red : Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANEL DEL CARRITO (sin cambios)
  // ============================================================
  Widget _buildCarritoPanel({required double width}) {
    return Container(
      width: width,
      color: const Color(0xFF112240),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '🛒 CARRITO',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A4A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tasa Bs/USD:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('${_tasa.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _carrito.length,
              itemBuilder: (context, index) {
                final item = _carrito[index];
                final subtotal = item['precio'] * item['cantidad'];
                return Card(
                  color: const Color(0xFF1A2A4A),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    leading: Text('${item['cantidad']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    title: Text(item['nombre'], style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 11)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                          onPressed: () => _eliminarDelCarrito(item['nombre']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A4A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Total: \$${_calcularTotal().toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bs ${(_calcularTotal() * _tasa).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _carrito.isEmpty ? null : _abrirPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('PAGAR'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 22),
                onPressed: _carrito.isEmpty ? null : _limpiarCarrito,
                tooltip: 'Vaciar carrito',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ============================================================
// DIÁLOGO DE PAGO (sin cambios – ya funciona bien)
// ============================================================
class _PagoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> carrito;
  final double total;
  final double tasa;
  final VoidCallback onPagoExitoso;

  const _PagoDialog({
    required this.carrito,
    required this.total,
    required this.tasa,
    required this.onPagoExitoso,
  });

  @override
  State<_PagoDialog> createState() => _PagoDialogState();
}

class _PagoDialogState extends State<_PagoDialog> {
  final db = DatabaseHelper();
  String _metodoPago = 'Efectivo';
  bool _esFiado = false;
  bool _cargando = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  bool _clienteExistente = false;
  String _mensajeCliente = '';
  String _clienteId = '';

  final TextEditingController _referenciaController = TextEditingController();
  bool _mostrarReferencia = false;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _referenciaController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _buscarClienteAutomatico() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _buscarCliente();
    });
  }

  Future<void> _buscarCliente() async {
    final cedula = _cedulaController.text.trim();
    if (cedula.isEmpty) {
      setState(() {
        _mensajeCliente = '';
        _clienteExistente = false;
        _clienteId = '';
        _nombreController.clear();
        _telefonoController.clear();
      });
      return;
    }

    final cliente = await db.obtenerClientePorCedula(cedula);
    if (cliente != null) {
      setState(() {
        _clienteExistente = true;
        _clienteId = cliente['id'].toString();
        _nombreController.text = cliente['nombre'];
        _telefonoController.text = cliente['telefono'] ?? '';
        _mensajeCliente = '✅ Cliente encontrado: ${cliente['nombre']}';
      });
    } else {
      setState(() {
        _clienteExistente = false;
        _clienteId = '';
        _mensajeCliente = '🆕 Cliente nuevo. Complete los datos.';
      });
    }
  }

  void _seleccionarMetodo(String metodo) {
    setState(() {
      _metodoPago = metodo;
      _esFiado = (metodo == 'Fiado');
      _mostrarReferencia = (metodo == 'Pago Móvil' || metodo == 'Biopago');
    });
  }

  Future<void> _confirmarPago() async {
    if (_nombreController.text.trim().isEmpty || _cedulaController.text.trim().isEmpty) {
      _mostrarError('Nombre y cédula son obligatorios');
      return;
    }

    setState(() => _cargando = true);

    try {
      int clienteId;
      if (_clienteExistente && _clienteId.isNotEmpty) {
        clienteId = int.parse(_clienteId);
      } else {
        clienteId = await db.obtenerOCrearCliente(
          _nombreController.text.trim(),
          _cedulaController.text.trim(),
          telefono: _telefonoController.text.trim(),
        );
      }
      final nombreCliente = _nombreController.text.trim();
      final cedulaCliente = _cedulaController.text.trim();

      final now = DateTime.now();
      final fecha = DateFormat('dd/MM/yyyy').format(now);
      final hora = DateFormat('HH:mm').format(now);
      final numeroFactura = await db.incrementarNumeroFactura();

      final referencia = _esFiado ? 'Fiado: $nombreCliente' : _referenciaController.text.trim();
      await db.registrarVenta(
        widget.carrito,
        widget.total,
        _metodoPago,
        referencia,
        clienteId,
        nombreCliente,
      );

      if (_esFiado) {
        final fiadoExistente = await db.obtenerFiadoPorCedula(cedulaCliente);
        if (fiadoExistente != null) {
          final nuevoTotal = (fiadoExistente['total'] as num).toDouble() + widget.total;
          await db.actualizarFiado(fiadoExistente['id'] as int, nuevoTotal);
          _mostrarExito('💰 Deuda actualizada: \$${nuevoTotal.toStringAsFixed(2)}');
        } else {
          await db.registrarFiado(
            nombreCliente,
            cedulaCliente,
            widget.total,
            nota: 'Factura N° $numeroFactura',
          );
          _mostrarExito('💰 Nuevo fiado registrado: \$${widget.total.toStringAsFixed(2)}');
        }

        if (_telefonoController.text.trim().isNotEmpty) {
          _enviarWhatsAppAbono(nombreCliente, widget.total, _telefonoController.text.trim());
        }
      }

      final config = await db.obtenerConfiguracion();
      final detalles = widget.carrito.map((item) => {
        'producto': item['nombre'],
        'cantidad': item['cantidad'],
        'precio': item['precio'],
      }).toList();

      final facturaWidget = factura.FacturaWidget(
        venta: {
          'fecha': fecha,
          'hora': hora,
          'metodo_pago': _metodoPago,
          'total': widget.total,
          'referencia_pago': referencia,
          'cliente_id': clienteId,
          'nombre_cliente': nombreCliente,
        },
        detalles: detalles,
        config: config,
        metodoPago: _metodoPago,
        esFiado: _esFiado,
        nombreCliente: nombreCliente,
        clienteCedula: cedulaCliente,
        tasa: widget.tasa,
        numeroFactura: numeroFactura,
        logoPath: config['ruta_logo'],
      );

      widget.onPagoExitoso();
      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FacturaPreviewScreen(
              facturaWidget: facturaWidget,
              titulo: 'Factura N° ${numeroFactura.toString().padLeft(4, '0')}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al procesar el pago: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _enviarWhatsAppAbono(String nombre, double monto, String telefono) {
    final numeroLimpio = telefono.replaceAll(RegExp(r'\D'), '');
    if (numeroLimpio.isEmpty) return;
    final mensaje = '✅ *ABONO REGISTRADO*\n\nCliente: $nombre\nMonto abonado: \$${monto.toStringAsFixed(2)}\nSaldo restante: Pendiente de actualizar\n\n¡Gracias por su pago!';
    Share.share(mensaje, subject: 'Abono registrado');
  }

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

  @override
  Widget build(BuildContext context) {
    final totalBs = widget.total * widget.tasa;

    return Dialog(
      backgroundColor: const Color(0xFF0A0F1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💳 PAGO', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF112240), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('\$${widget.total.toStringAsFixed(2)} USD', style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('Bs ${totalBs.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('🧑 CLIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cedulaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Cédula del cliente * (busca automático)',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _buscarClienteAutomatico(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _buscarCliente,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Buscar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              if (_mensajeCliente.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _mensajeCliente,
                  style: TextStyle(
                    color: _clienteExistente ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre completo *', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _telefonoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('💳 MÉTODO DE PAGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _botonMetodo('Efectivo', 'Efectivo'),
                  _botonMetodo('Divisa', 'Divisa'),
                  _botonMetodo('Punto', 'Punto'),
                  _botonMetodo('Pago Móvil', 'Pago Móvil'),
                  _botonMetodo('Biopago', 'Biopago'),
                  _botonMetodo('Fiado', 'Fiado'),
                ],
              ),
              const SizedBox(height: 8),
              if (_mostrarReferencia) ...[
                TextField(
                  controller: _referenciaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Últimos 4 dígitos de la referencia *', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: 8),
              ],
              _cargando
                  ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                  : ElevatedButton(
                      onPressed: _confirmarPago,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('CONFIRMAR PAGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonMetodo(String label, String valor) {
    final isSelected = _metodoPago == valor;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
      selected: isSelected,
      onSelected: (selected) => selected ? _seleccionarMetodo(valor) : null,
      selectedColor: Colors.blue,
      backgroundColor: const Color(0xFF1A2A4A),
      labelStyle: const TextStyle(fontSize: 12),
    );
  }
}