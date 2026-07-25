import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/database_helper.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final db = DatabaseHelper();
  final TextEditingController _fechaController = TextEditingController();
  String _modo = 'Día';
  DateTime _fechaSeleccionada = DateTime.now();
  bool _cargando = false;
  Map<String, dynamic>? _reporteData;

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
    _generarReporte();
  }

  // ============================================================
  // FILTROS Y GENERACIÓN DE REPORTE
  // ============================================================
  void _cambiarModo(String? modo) {
    if (modo != null) {
      setState(() => _modo = modo);
      _generarReporte();
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blue,
            onPrimary: Colors.white,
            surface: Color(0xFF112240),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
        _fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _generarReporte();
    }
  }

  Future<void> _generarReporte() async {
    setState(() => _cargando = true);
    try {
      final fechaStr = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
      Map<String, dynamic> data;

      if (_modo == 'Día') {
        data = await db.obtenerResumenCierre(fechaStr);
        data['titulo'] = '📊 Reporte del Día: $fechaStr';
      } else {
        data = await db.obtenerResumenPorRango('01/01/2000', fechaStr);
        data['titulo'] = '📊 Resumen Acumulado (hasta: $fechaStr)';
        try {
          final ventas = await db.obtenerVentasRango('01/01/2000', fechaStr);
          if (ventas.isNotEmpty) {
            data['primera_fecha'] = ventas.last['fecha'];
          } else {
            data['primera_fecha'] = fechaStr;
          }
        } catch (e) {
          data['primera_fecha'] = fechaStr;
        }
      }

      if (mounted) {
        setState(() {
          _reporteData = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarError('Error al generar reporte: $e');
      }
    }
  }

  // ============================================================
  // EXPORTAR REPORTE A PDF
  // ============================================================
  Future<void> _exportarPDF() async {
    if (_reporteData == null) return;

    final data = _reporteData!;
    final totalVentas = data['total_ventas_usd'] ?? 0.0;
    final totalAbonos = data['total_abonos_usd'] ?? 0.0;
    final totalIngresos = data['total_ingresos_usd'] ?? 0.0;
    final costo = data['costo_ventas'] ?? 0.0;
    final ganancia = data['ganancia_bruta'] ?? 0.0;
    final margen = data['margen_porcentaje'] ?? 0.0;
    final egresos = data['total_egresos'] ?? 0.0;
    final neto = data['neto'] ?? 0.0;
    final metodos = data['totales_por_metodo'] as Map<String, double>? ?? {};

    final pdf = pw.Document();
    final fechaStr = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Container(
              padding: pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Título
                  pw.Text(
                    data['titulo'] ?? 'Reporte',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  if (data['primera_fecha'] != null && _modo == 'Acumulado')
                    pw.Text('Desde: ${data['primera_fecha']}', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 16),
                  // Tarjetas
                  _buildPdfCard('💵 TOTAL VENTAS', '\$${totalVentas.toStringAsFixed(2)}', PdfColors.blue),
                  pw.SizedBox(height: 8),
                  _buildPdfCard('💰 ABONOS', '\$${totalAbonos.toStringAsFixed(2)}', PdfColors.green),
                  pw.SizedBox(height: 8),
                  _buildPdfCard(
                    '📊 COSTO Y GANANCIA',
                    'Costo: \$${costo.toStringAsFixed(2)}\nGanancia: \$${ganancia.toStringAsFixed(2)} (${margen.toStringAsFixed(1)}%)',
                    PdfColors.purple,
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfCard('💸 EGRESOS', '\$${egresos.toStringAsFixed(2)}', PdfColors.red),
                  pw.SizedBox(height: 16),
                  // Resumen final
                  pw.Container(
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('🧾 RESUMEN FINAL',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Ingresos totales'),
                            pw.Text('\$${totalIngresos.toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('(-) Costo de ventas', style: pw.TextStyle(color: PdfColors.red)),
                            pw.Text('-\$${costo.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red)),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('(-) Gastos', style: pw.TextStyle(color: PdfColors.red)),
                            pw.Text('-\$${egresos.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red)),
                          ],
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('NETO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('\$${neto.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  // Métodos de pago
                  if (metodos.isNotEmpty) ...[
                    pw.Text('💳 MÉTODOS DE PAGO',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    ...metodos.entries
                        .where((e) => e.value > 0)
                        .map((e) => pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(e.key),
                        pw.Text('\$${e.value.toStringAsFixed(2)}'),
                      ],
                    ))
                        .toList(),
                  ],
                  pw.SizedBox(height: 20),
                  pw.Text('Reporte generado desde POS Móvil',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.Text('Fecha: ${DateTime.now().toString()}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    try {
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/reporte_${fechaStr.replaceAll('/', '_')}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📊 Reporte de ventas del $fechaStr',
      );
    } catch (e) {
      _mostrarError('Error al exportar PDF: $e');
    }
  }

  pw.Widget _buildPdfCard(String titulo, String contenido, PdfColor color) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 4),
          pw.Text(contenido, style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ============================================================
  // DIÁLOGO PARA REGISTRAR EGRESO
  // ============================================================
  void _mostrarDialogoEgreso() {
    final formKey = GlobalKey<FormState>();
    final tipoController = TextEditingController();
    final beneficiarioController = TextEditingController();
    final montoController = TextEditingController();
    final metodoController = TextEditingController();
    final referenciaController = TextEditingController();
    final notaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Egreso', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCampo(tipoController, 'Tipo (ej: Compra, Servicio, Otro)', esObligatorio: true),
                _buildCampo(beneficiarioController, 'Beneficiario', esObligatorio: true),
                _buildCampo(montoController, 'Monto en USD', esObligatorio: true, keyboard: TextInputType.number),
                _buildCampo(metodoController, 'Método de pago (Efectivo, Divisa, Punto...)', esObligatorio: true),
                _buildCampo(referenciaController, 'Referencia (opcional)'),
                _buildCampo(notaController, 'Nota (opcional)'),
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
              final tipo = tipoController.text.trim();
              final beneficiario = beneficiarioController.text.trim();
              final monto = double.tryParse(montoController.text.trim()) ?? 0;
              if (monto <= 0) {
                _mostrarError('Monto debe ser mayor a 0');
                return;
              }
              final metodo = metodoController.text.trim();
              final referencia = referenciaController.text.trim();
              final nota = notaController.text.trim();

              await db.registrarEgreso(
                tipo,
                beneficiario,
                monto,
                metodo,
                referencia,
                nota,
              );
              Navigator.pop(context);
              _mostrarExito('Egreso registrado correctamente');
              _generarReporte();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          if (esObligatorio && (value == null || value.isEmpty)) return 'Campo obligatorio';
          return null;
        },
      ),
    );
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
        title: const Text('Reportes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _mostrarDialogoEgreso,
            tooltip: 'Registrar egreso',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _reporteData != null ? _exportarPDF : null,
            tooltip: 'Exportar a PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _generarReporte,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF112240),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _modo,
                  dropdownColor: const Color(0xFF1A2A4A),
                  style: const TextStyle(color: Colors.white),
                  underline: Container(height: 1, color: Colors.grey),
                  items: const [
                    DropdownMenuItem(value: 'Día', child: Text('Día')),
                    DropdownMenuItem(value: 'Acumulado', child: Text('Acumulado')),
                  ],
                  onChanged: _cambiarModo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _fechaController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Fecha',
                      labelStyle: const TextStyle(color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                        onPressed: _seleccionarFecha,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _generarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Generar'),
                ),
              ],
            ),
          ),
          // Reporte
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : _reporteData == null
                ? const Center(
              child: Text(
                'Genera un reporte para ver los datos',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
                : _buildReporte(_reporteData!),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONSTRUIR REPORTE EN PANTALLA
  // ============================================================
  Widget _buildReporte(Map<String, dynamic> data) {
    final totalVentas = data['total_ventas_usd'] ?? 0.0;
    final totalAbonos = data['total_abonos_usd'] ?? 0.0;
    final totalIngresos = data['total_ingresos_usd'] ?? 0.0;
    final costo = data['costo_ventas'] ?? 0.0;
    final ganancia = data['ganancia_bruta'] ?? 0.0;
    final margen = data['margen_porcentaje'] ?? 0.0;
    final egresos = data['total_egresos'] ?? 0.0;
    final neto = data['neto'] ?? 0.0;
    final metodos = data['totales_por_metodo'] as Map<String, double>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['titulo'] ?? 'Reporte',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (data['primera_fecha'] != null && _modo == 'Acumulado')
            Text(
              'Desde: ${data['primera_fecha']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          const SizedBox(height: 12),
          _buildCard('💵 TOTAL VENTAS', '\$${totalVentas.toStringAsFixed(2)}', Colors.blue),
          const SizedBox(height: 12),
          _buildCard('💰 ABONOS', '\$${totalAbonos.toStringAsFixed(2)}', Colors.green),
          const SizedBox(height: 12),
          _buildCard(
            '📊 COSTO Y GANANCIA',
            'Costo: \$${costo.toStringAsFixed(2)}\nGanancia: \$${ganancia.toStringAsFixed(2)} (${margen.toStringAsFixed(1)}%)',
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildCard('💸 EGRESOS', '\$${egresos.toStringAsFixed(2)}', Colors.red),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🧾 RESUMEN FINAL',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.grey),
                _buildResumenItem('Ingresos totales', '\$${totalIngresos.toStringAsFixed(2)}', Colors.white),
                _buildResumenItem('(-) Costo de ventas', '-\$${costo.toStringAsFixed(2)}', Colors.red),
                _buildResumenItem('(-) Gastos', '-\$${egresos.toStringAsFixed(2)}', Colors.red),
                const Divider(color: Colors.grey),
                _buildResumenItem('NETO', '\$${neto.toStringAsFixed(2)}', Colors.green, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (metodos.isNotEmpty) ...[
            const Text(
              '💳 MÉTODOS DE PAGO',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...metodos.entries.map((entry) {
              if (entry.value <= 0) return const SizedBox.shrink();
              return Card(
                color: const Color(0xFF1A2A4A),
                child: ListTile(
                  title: Text(entry.key, style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    '\$${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.blueAccent),
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(String titulo, String contenido, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(contenido, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}