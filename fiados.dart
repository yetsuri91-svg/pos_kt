import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class FiadosScreen extends StatefulWidget {
  const FiadosScreen({super.key});

  @override
  State<FiadosScreen> createState() => _FiadosScreenState();
}

class _FiadosScreenState extends State<FiadosScreen> {
  final db = DatabaseHelper();
  List<Map<String, dynamic>> _fiados = [];
  bool _cargando = true;

  // Controlador para el diálogo de abono
  final TextEditingController _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarFiados();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR FIADOS
  // ============================================================
  Future<void> _cargarFiados() async {
    setState(() => _cargando = true);
    try {
      final fiados = await db.obtenerFiados();
      if (mounted) {
        setState(() {
          _fiados = fiados;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarError('Error al cargar fiados: $e');
      }
    }
  }

  // ============================================================
  // ABRIR DIÁLOGO PARA REGISTRAR ABONO
  // ============================================================
  void _abrirDialogoAbono(Map<String, dynamic> fiado) {
    _montoController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Abonar a ${fiado['nombre'] ?? 'Cliente'}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deuda actual: \$${(fiado['total'] as num?)?.toStringAsFixed(2) ?? '0.00'} USD',
              style: const TextStyle(color: Colors.orange, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Monto a abonar (USD)',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Se enviará un mensaje de WhatsApp al cliente (si tiene teléfono)',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _registrarAbono(fiado),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Abonar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REGISTRAR ABONO (con envío de WhatsApp)
  // ============================================================
  Future<void> _registrarAbono(Map<String, dynamic> fiado) async {
    final montoTexto = _montoController.text.trim();
    if (montoTexto.isEmpty) {
      _mostrarError('Ingrese un monto');
      return;
    }

    final monto = double.tryParse(montoTexto);
    if (monto == null || monto <= 0) {
      _mostrarError('Monto inválido');
      return;
    }

    final deudaActual = fiado['total'] as num? ?? 0;
    if (monto > deudaActual) {
      _mostrarError('El abono no puede ser mayor a la deuda');
      return;
    }

    // Cerrar el diálogo
    if (mounted) Navigator.pop(context);

    final fiadoId = fiado['id'] as int;
    final nuevoSaldo = deudaActual - monto;

    try {
      // 1. Actualizar la deuda en fiados
      await db.actualizarFiado(fiadoId, nuevoSaldo);

      // 2. Registrar el abono como una venta (para el historial)
      final fecha = DateTime.now();
      final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
      final horaStr = DateFormat('HH:mm').format(fecha);

      // Obtener o crear cliente (si existe, usar su ID, si no, null)
      int? clienteId;
      final nombreCliente = fiado['nombre'] ?? 'Cliente';
      final telefono = fiado['telefono'] ?? '';

      // Si tiene cédula (usamos teléfono como cédula en la tabla fiados), intentar obtener cliente
      if (telefono.isNotEmpty) {
        final cliente = await db.obtenerClientePorCedula(telefono);
        if (cliente != null) {
          clienteId = cliente['id'] as int;
        } else {
          // Crear cliente si no existe (usamos teléfono como cédula)
          clienteId = await db.obtenerOCrearCliente(
            nombreCliente,
            telefono,
            telefono: telefono,
          );
        }
      }

      // Registrar venta (sin afectar stock porque es abono)
      await db.registrarVenta(
        [], // carrito vacío (no consume stock)
        monto,
        'Divisa',
        'Abono: $nombreCliente',
        clienteId,
        nombreCliente,
      );

      // 3. Enviar WhatsApp al cliente (si tiene teléfono)
      if (telefono.isNotEmpty) {
        _enviarWhatsAppAbono(nombreCliente, monto, nuevoSaldo, telefono);
      }

      // 4. Mostrar mensaje de éxito
      if (mounted) {
        _mostrarExito(
          'Abono de \$${monto.toStringAsFixed(2)} registrado.\n'
              'Nuevo saldo: \$${nuevoSaldo.toStringAsFixed(2)}',
        );
        _cargarFiados(); // Recargar lista
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al registrar abono: $e');
      }
    }
  }

  // ============================================================
  // ENVIAR WHATSAPP (ABONO)
  // ============================================================
  void _enviarWhatsAppAbono(String nombre, double monto, double saldo, String telefono) {
    // Limpiar número (solo dígitos)
    final numeroLimpio = telefono.replaceAll(RegExp(r'\D'), '');
    if (numeroLimpio.isEmpty) return;

    final mensaje = '✅ *ABONO REGISTRADO*\n\n'
        'Cliente: $nombre\n'
        'Monto abonado: \$${monto.toStringAsFixed(2)}\n'
        'Saldo restante: \$${saldo.toStringAsFixed(2)}\n\n'
        '¡Gracias por su pago!';

    // Abrir WhatsApp o compartir
    final url = 'https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(mensaje)}';
    Share.share(mensaje, subject: 'Abono registrado');
    // Nota: para abrir directamente el chat de WhatsApp, se necesita url_launcher.
    // Si tienes url_launcher, puedes usar: await launchUrl(Uri.parse(url));
    // Por ahora usamos share_plus para que el usuario elija la app.
  }

  // ============================================================
  // ELIMINAR FIADO
  // ============================================================
  Future<void> _eliminarFiado(Map<String, dynamic> fiado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('Eliminar fiado', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar la deuda de ${fiado['nombre'] ?? 'cliente'}?',
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
        await db.eliminarFiado(fiado['id'] as int);
        if (mounted) {
          _mostrarExito('Fiado eliminado');
          _cargarFiados();
        }
      } catch (e) {
        if (mounted) {
          _mostrarError('Error al eliminar: $e');
        }
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
  // BUILD PRINCIPAL
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      appBar: AppBar(
        title: const Text('Fiados / Morosos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarFiados,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _fiados.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 12),
            Text(
              '✅ No hay fiados registrados',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _fiados.length,
        itemBuilder: (context, index) {
          final f = _fiados[index];
          return Card(
            color: const Color(0xFF1A2A4A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade800,
                child: Text(
                  (f['nombre'] ?? 'C')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                f['nombre'] ?? 'Cliente sin nombre',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f['telefono'] != null && f['telefono']!.isNotEmpty)
                    Text('Teléfono: ${f['telefono']}', style: const TextStyle(color: Colors.white70)),
                  Text(
                    'Deuda: \$${(f['total'] as num?)?.toStringAsFixed(2) ?? '0.00'} USD',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  if (f['fecha'] != null)
                    Text('Fecha: ${f['fecha']}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.payment, color: Colors.green),
                    onPressed: () => _abrirDialogoAbono(f),
                    tooltip: 'Abonar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _eliminarFiado(f),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}