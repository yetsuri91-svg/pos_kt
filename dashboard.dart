import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final db = DatabaseHelper();

  double _totalVentasHoy = 0;
  int _cantidadVentasHoy = 0;
  double _ticketPromedio = 0;
  double _totalFiados = 0;
  Map<String, double> _metodosPago = {};
  List<Map<String, dynamic>> _topProductos = [];
  List<Map<String, dynamic>> _topFieles = [];
  List<Map<String, dynamic>> _topMorosos = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final totalVentas = await db.obtenerTotalVentasHoy();
      final cantidadVentas = await db.obtenerCantidadVentasHoy();
      final ticketProm = await db.obtenerTicketPromedioHoy();
      final totalFiados = await db.obtenerTotalFiados();
      final metodos = await db.obtenerMetodosPagoHoy();
      final topProd = await db.obtenerTopProductos(5);
      final topFieles = await db.obtenerTopClientesFieles(3);
      final topMorosos = await db.obtenerTopClientesMorosos(3);

      if (mounted) {
        setState(() {
          _totalVentasHoy = totalVentas;
          _cantidadVentasHoy = cantidadVentas;
          _ticketPromedio = ticketProm;
          _totalFiados = totalFiados;
          _metodosPago = metodos;
          _topProductos = topProd;
          _topFieles = topFieles;
          _topMorosos = topMorosos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarError('Error al cargar datos: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF112240),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // SECCIÓN 1: TARJETAS DE MÉTRICAS (2x2)
            // ============================================================
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _TarjetaMetrica(
                  icon: Icons.attach_money,
                  titulo: 'Ventas hoy',
                  valor: '\$${_totalVentasHoy.toStringAsFixed(2)}',
                  color: Colors.blue,
                ),
                _TarjetaMetrica(
                  icon: Icons.shopping_cart,
                  titulo: 'Ventas realizadas',
                  valor: '$_cantidadVentasHoy',
                  color: Colors.cyan,
                ),
                _TarjetaMetrica(
                  icon: Icons.trending_up,
                  titulo: 'Ticket promedio',
                  valor: '\$${_ticketPromedio.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
                _TarjetaMetrica(
                  icon: Icons.people,
                  titulo: 'Fiados totales',
                  valor: '\$${_totalFiados.toStringAsFixed(2)}',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ============================================================
            // SECCIÓN 2: GRÁFICO DE BARRAS – MÉTODOS DE PAGO
            // ============================================================
            const Text(
              'Métodos de pago (hoy)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _metodosPago.isEmpty
                ? const Text(
              'No hay datos de métodos de pago',
              style: TextStyle(color: Colors.grey),
            )
                : SizedBox(
              height: 200,
              child: _GraficoBarras(metodos: _metodosPago),
            ),
            const SizedBox(height: 16),

            // ============================================================
            // SECCIÓN 3: GRÁFICO DE DONA – TOP 5 PRODUCTOS
            // ============================================================
            const Text(
              'Top 5 productos más vendidos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _topProductos.isEmpty
                ? const Text(
              'No hay productos vendidos',
              style: TextStyle(color: Colors.grey),
            )
                : SizedBox(
              height: 200,
              child: _GraficoDona(productos: _topProductos),
            ),
            const SizedBox(height: 16),

            // ============================================================
            // SECCIÓN 4: TOP CLIENTES FIELES
            // ============================================================
            const Text(
              'Top 3 clientes fieles',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _topFieles.isEmpty
                ? const Text(
              'No hay clientes fieles',
              style: TextStyle(color: Colors.grey),
            )
                : _ListaClientesFieles(clientes: _topFieles),
            const SizedBox(height: 16),

            // ============================================================
            // SECCIÓN 5: TOP CLIENTES MOROSOS
            // ============================================================
            const Text(
              'Top 3 clientes morosos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _topMorosos.isEmpty
                ? const Text(
              'No hay clientes morosos',
              style: TextStyle(color: Colors.grey),
            )
                : _ListaClientesMorosos(clientes: _topMorosos),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET: TARJETA DE MÉTRICA
// ============================================================
class _TarjetaMetrica extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;
  final Color color;

  const _TarjetaMetrica({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            titulo,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET: GRÁFICO DE BARRAS (fl_chart)
// ============================================================
class _GraficoBarras extends StatelessWidget {
  final Map<String, double> metodos;

  const _GraficoBarras({required this.metodos});

  @override
  Widget build(BuildContext context) {
    final keys = metodos.keys.toList();
    final values = metodos.values.toList();
    final maxY = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < keys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      keys[index],
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        barGroups: List.generate(keys.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: Colors.blue,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ============================================================
// WIDGET: GRÁFICO DE DONA (fl_chart)
// ============================================================
class _GraficoDona extends StatelessWidget {
  final List<Map<String, dynamic>> productos;

  const _GraficoDona({required this.productos});

  @override
  Widget build(BuildContext context) {
    final List<PieChartSectionData> sections = [];
    final colors = [Colors.blue, Colors.cyan, Colors.green, Colors.orange, Colors.purple];
    double total = 0;
    for (var p in productos) {
      total += (p['total_cantidad'] as num).toDouble();
    }

    for (int i = 0; i < productos.length; i++) {
      final p = productos[i];
      final valor = (p['total_cantidad'] as num).toDouble();
      final porcentaje = total > 0 ? (valor / total) * 100 : 0;
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: valor,
          title: '${porcentaje.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        pieTouchData: PieTouchData(enabled: true),
      ),
    );
  }
}

// ============================================================
// WIDGET: LISTA DE CLIENTES FIELES
// ============================================================
class _ListaClientesFieles extends StatelessWidget {
  final List<Map<String, dynamic>> clientes;

  const _ListaClientesFieles({required this.clientes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clientes.length,
      itemBuilder: (context, index) {
        final c = clientes[index];
        return Card(
          color: const Color(0xFF1A2A4A),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade800,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(c['nombre'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              'Compras: ${c['compras']}  |  Total: \$${(c['total_gastado'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.star, color: Colors.amber),
          ),
        );
      },
    );
  }
}

// ============================================================
// WIDGET: LISTA DE CLIENTES MOROSOS
// ============================================================
class _ListaClientesMorosos extends StatelessWidget {
  final List<Map<String, dynamic>> clientes;

  const _ListaClientesMorosos({required this.clientes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clientes.length,
      itemBuilder: (context, index) {
        final c = clientes[index];
        return Card(
          color: const Color(0xFF1A2A4A),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade800,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(c['nombre'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              'Deuda: \$${(c['deuda'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.redAccent),
            ),
            trailing: const Icon(Icons.warning, color: Colors.red),
          ),
        );
      },
    );
  }
}