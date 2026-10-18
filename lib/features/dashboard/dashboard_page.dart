import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../connection/connection_page.dart';
import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/health_score.dart';

/// Tela principal. Lê o telemetryStore (alimentado pelo telemetryBus).
/// Sem dados, mostra "--". O botão de play liga a simulação.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  void _toggleSimulation() {
    setState(() {
      if (telemetrySimulator.running) {
        telemetrySimulator.stop();
      } else {
        telemetrySimulator.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final store = telemetryStore;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            store.latest,
            store.live,
            store.instantKmL,
            store.avgKmL,
            store.dtcCount,
          ]),
          builder: (context, _) {
            final telemetry = store.latest.value;
            final coolant = telemetry?.coolantTempC;
            final report = buildHealthReport(
              coolantTempC: coolant,
              errorCount: store.dtcCount.value,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, motorista',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Veja como está seu carro hoje',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                                        IconButton.filledTonal(
                      tooltip: 'Conexão OBD2',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConnectionPage(),
                        ),
                      ),
                      icon: const Icon(Icons.bluetooth_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: telemetrySimulator.running
                          ? 'Parar simulação'
                          : 'Simular dados',
                      onPressed: _toggleSimulation,
                      icon: Icon(
                        telemetrySimulator.running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Alternar tema',
                      onPressed: () {
                        AppTheme.themeMode.value =
                            isDark ? ThemeMode.light : ThemeMode.dark;
                      },
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _HealthCard(report: report, live: store.live.value),
                const SizedBox(height: 24),

                Text(
                  'Indicadores',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.thermostat,
                        label: 'Temperatura',
                        value: _fmt(coolant),
                        unit: '°C',
                        progress: _ratio(coolant, 120),
                        color: const Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.speed,
                        label: 'Velocidade',
                        value: _fmt(telemetry?.speedKmh),
                        unit: 'km/h',
                        progress: _ratio(telemetry?.speedKmh, 200),
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.local_gas_station,
                        label: 'Consumo atual',
                        value: _fmt(store.instantKmL.value, casas: 1),
                        unit: 'km/l',
                        progress: _ratio(store.instantKmL.value, 20),
                        color: const Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.show_chart,
                        label: 'Consumo médio',
                        value: _fmt(store.avgKmL.value, casas: 1),
                        unit: 'km/l',
                        progress: _ratio(store.avgKmL.value, 20),
                        color: const Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text(
                  'Diagnóstico',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _ErrorsTile(errorCount: store.dtcCount.value),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Formata número no padrão brasileiro. Sem dado, mostra "--".
String _fmt(double? value, {int casas = 0}) {
  if (value == null) return '--';
  return value.toStringAsFixed(casas).replaceAll('.', ',');
}

/// Proporção de 0 a 1 para as barras. Sem dado, fica vazia.
double _ratio(double? value, double max) {
  if (value == null) return 0;
  return (value / max).clamp(0.0, 1.0);
}

/// Cartão de saúde geral. Recebe report nulo quando ainda não há dados.
class _HealthCard extends StatelessWidget {
  final HealthReport? report;
  final bool live;

  const _HealthCard({required this.report, required this.live});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final decoration = isDark
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF164E63), Color(0xFF0C4A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF164E63).withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          )
        : AppTheme.cardDecoration(context).copyWith(
            borderRadius: BorderRadius.circular(28),
          );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: decoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saúde geral',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : muted,
                    fontSize: 15,
                  ),
                ),
              ),
              _LiveDot(active: live),
            ],
          ),
          const SizedBox(height: 20),
          _Gauge(score: report?.overall, isDark: isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              // Ordem fixa definida em computeHealth: 0 = Motor, 1 = Eletrônica.
              Expanded(
                child: _SystemChip(
                  name: 'Motor',
                  score: report?.systems[0].score,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _SystemChip(
                  name: 'Eletrônica',
                  score: report?.systems[1].score,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Medidor circular animado. A cor acompanha a nota (healthColor).
/// Sem dado, mostra "--" e o arco fica vazio.
class _Gauge extends StatelessWidget {
  final int? score;
  final bool isDark;

  const _Gauge({required this.score, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score?.toDouble() ?? 0.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final arcColor =
            score == null ? Colors.grey : healthColor(value.round());

        return SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(
            painter: _GaugePainter(
              progress: value / 100,
              color: arcColor,
              isDark: isDark,
            ),
            child: Center(
              child: Text(
                score == null ? '--' : '${value.round()}%',
                style: TextStyle(
                  color: textColor,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desenha o arco de fundo e o arco de progresso.
class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 a 1.0
  final Color color;
  final bool isDark;

  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    // O arco vai de 135° a 405° (270 graus), deixando a parte de baixo aberta.
    const startAngle = 3 * math.pi / 4;
    const fullSweep = 3 * math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.2)
          : color.withValues(alpha: 0.15);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, startAngle, fullSweep, false, track);
    canvas.drawArc(
        rect, startAngle, fullSweep * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

/// Chip com a nota de um sistema. A bolinha usa a mesma cor da nota.
class _SystemChip extends StatelessWidget {
  final String name;
  final int? score;
  final bool isDark;

  const _SystemChip({
    required this.name,
    required this.score,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final chipColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : colors.surfaceContainerHighest.withValues(alpha: 0.6);
    final dotColor = score == null ? Colors.grey : healthColor(score!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score == null ? '--' : '$score%',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Cartão de indicador: ícone, valor, unidade e barra de progresso.
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final double progress; // 0.0 a 1.0
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de diagnóstico. Sem leitura de DTC ainda, mostra "não lido".
class _ErrorsTile extends StatelessWidget {
  final int? errorCount;

  const _ErrorsTile({required this.errorCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unknown = errorCount == null;
    final ok = errorCount == 0;

    final color = unknown
        ? Colors.grey
        : ok
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);
    final icon = unknown
        ? Icons.help_outline_rounded
        : ok
            ? Icons.check_circle_rounded
            : Icons.warning_rounded;
    final title = unknown
        ? 'Erros ainda não lidos'
        : ok
            ? 'Nenhum erro na ECU'
            : '$errorCount erro(s) na ECU';
    final subtitle = unknown
        ? 'A leitura de códigos entra na próxima etapa'
        : 'Lido da ECU';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Bolinha "ao vivo" que pulsa enquanto chegam leituras. Com active = false, fica cinza.
class _LiveDot extends StatefulWidget {
  final bool active;

  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = widget.active ? const Color(0xFF22C55E) : Colors.grey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    return Container(
                      width: 16 * (0.5 + t * 0.5),
                      height: 16 * (0.5 + t * 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.5 * (1 - t)),
                      ),
                    );
                  },
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          widget.active ? 'Ao vivo' : 'Offline',
          style: TextStyle(
            color: widget.active ? muted : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
