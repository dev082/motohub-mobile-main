import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/models/relatorio_motorista.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/relatorio_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/app_drawer.dart';
import 'package:provider/provider.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final RelatorioService _service = RelatorioService();
  Future<RelatorioMotorista>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    final motoristaId = context.read<AppProvider>().currentMotorista?.id;
    if (motoristaId == null) return;
    _future ??= _service.buildMotoristaReport(motoristaId);
  }

  Future<void> _refresh() async {
    final motoristaId = context.read<AppProvider>().currentMotorista?.id;
    if (motoristaId == null) return;
    setState(() => _future = _service.buildMotoristaReport(motoristaId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final motorista = context.watch<AppProvider>().currentMotorista;

    if (motorista == null) {
      return Scaffold(
        drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
          ),
          title: const Text('Relatórios'),
          actions: [
            if (context.canPop())
              IconButton(onPressed: context.pop, icon: const Icon(Icons.close), tooltip: 'Fechar'),
          ],
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Text(
              'Faça login para ver seus relatórios.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          if (context.canPop())
            IconButton(onPressed: context.pop, icon: const Icon(Icons.close), tooltip: 'Fechar'),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: AppSpacing.paddingLg,
            children: [
              _HeaderCard(nome: motorista.nomeCompleto),
              const SizedBox(height: AppSpacing.lg),
              FutureBuilder<RelatorioMotorista>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _RelatoriosLoading();
                  }
                  if (snapshot.hasError) {
                    return _RelatoriosError(onRetry: _refresh);
                  }
                  final report = snapshot.data;
                  if (report == null) {
                    return _RelatoriosEmpty(onRetry: _refresh);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KpiGrid(report: report),
                      const SizedBox(height: AppSpacing.lg),
                      _StatusBreakdownCard(report: report),
                      const SizedBox(height: AppSpacing.lg),
                      _WeeklyTrendCard(report: report),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String nome;
  const _HeaderCard({required this.nome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.insights, color: cs.onPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumo do motorista', style: context.textStyles.labelLarge?.withColor(cs.onPrimary.withValues(alpha: 0.9))),
                const SizedBox(height: 6),
                Text(nome, style: context.textStyles.titleLarge?.withColor(cs.onPrimary).bold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final RelatorioMotorista report;
  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 520;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _KpiCard(
              width: isWide ? (c.maxWidth - AppSpacing.md) / 2 : c.maxWidth,
              title: 'Km rodados (estim.)',
              icon: Icons.route,
              valueText: NumberFormat('#,##0.0', 'pt_BR').format(report.kmEstimados),
              accentColorBuilder: (cs) => cs.primary,
            ),
            _KpiCard(
              width: isWide ? (c.maxWidth - AppSpacing.md) / 2 : c.maxWidth,
              title: 'Entregas entregues',
              icon: Icons.task_alt,
              valueText: report.entregues.toString(),
              accentColorBuilder: (_) => StatusColors.delivered,
            ),
            _KpiCard(
              width: isWide ? (c.maxWidth - AppSpacing.md) / 2 : c.maxWidth,
              title: 'Em andamento',
              icon: Icons.timelapse,
              valueText: report.emAndamento.toString(),
              accentColorBuilder: (_) => StatusColors.inTransit,
            ),
            _KpiCard(
              width: isWide ? (c.maxWidth - AppSpacing.md) / 2 : c.maxWidth,
              title: 'Canceladas',
              icon: Icons.cancel,
              valueText: report.canceladas.toString(),
              accentColorBuilder: (_) => StatusColors.cancelled,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final double width;
  final String title;
  final IconData icon;
  final String valueText;
  final Color Function(ColorScheme cs) accentColorBuilder;

  const _KpiCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.valueText,
    required this.accentColorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColorBuilder(cs);
    return SizedBox(
      width: width,
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: cs.surface,
          border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Text(
                      valueText,
                      key: ValueKey(valueText),
                      style: context.textStyles.headlineSmall?.withColor(cs.onSurface).bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  final RelatorioMotorista report;
  const _StatusBreakdownCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = max(1, report.totalEntregas);

    final sections = <PieChartSectionData>[];
    for (final entry in report.contagemPorStatus.entries) {
      if (entry.value <= 0) continue;
      sections.add(
        PieChartSectionData(
          color: _statusColor(entry.key),
          value: entry.value.toDouble(),
          radius: 62,
          title: '${((entry.value / total) * 100).round()}%',
          titleStyle: context.textStyles.labelLarge?.withColor(Colors.white).semiBold,
        ),
      );
    }

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Status das corridas', style: context.textStyles.titleMedium?.withColor(cs.onSurface).semiBold)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 560;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isWide ? 220 : 180,
                    height: isWide ? 220 : 180,
                    child: PieChart(
                      PieChartData(
                        sections: sections.isEmpty
                            ? [
                                PieChartSectionData(
                                  color: cs.surfaceContainerHighest,
                                  value: 1,
                                  radius: 62,
                                  title: '—',
                                  titleStyle: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant),
                                ),
                              ]
                            : sections,
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 350),
                      swapAnimationCurve: Curves.easeOutCubic,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: StatusEntrega.values
                          .where((s) => (report.contagemPorStatus[s] ?? 0) > 0)
                          .map((s) {
                        final count = report.contagemPorStatus[s] ?? 0;
                        final pct = (count / total) * 100;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _StatusRow(
                            color: _statusColor(s),
                            label: s.displayName,
                            value: '$count (${pct.toStringAsFixed(0)}%)',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  final RelatorioMotorista report;
  const _WeeklyTrendCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = report.ultimos7Dias;
    final maxY = max(2, days.map((d) => max(d.entregues, d.canceladas)).fold<int>(0, max)).toDouble();

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Últimos 7 dias', style: context.textStyles.titleMedium?.withColor(cs.onSurface).semiBold)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LegendDot(color: StatusColors.delivered, label: 'Entregues'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: StatusColors.cancelled, label: 'Canceladas'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: max(1, (maxY / 4).roundToDouble()),
                  getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withValues(alpha: 0.12), strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: max(1, (maxY / 4).roundToDouble()),
                      getTitlesWidget: (value, meta) {
                        if (value % meta.appliedInterval != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(value.toInt().toString(), style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        final d = days[i].date;
                        final label = DateFormat('E', 'pt_BR').format(d);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(days.length, (i) {
                  final d = days[i];
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: d.entregues.toDouble(),
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: StatusColors.delivered,
                      ),
                      BarChartRodData(
                        toY: d.canceladas.toDouble(),
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: StatusColors.cancelled,
                      ),
                    ],
                  );
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 350),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 8),
        Text(label, style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant)),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _StatusRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 240;
        final dot = Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)));

        if (isNarrow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 6), child: dot),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyMedium?.withColor(cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(value, style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            dot,
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyMedium?.withColor(cs.onSurface))),
            const SizedBox(width: AppSpacing.sm),
            Text(value, style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant)),
          ],
        );
      },
    );
  }
}

class _RelatoriosLoading extends StatelessWidget {
  const _RelatoriosLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 16),
          Text('Carregando relatórios…', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RelatoriosError extends StatelessWidget {
  final VoidCallback onRetry;
  const _RelatoriosError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 40, color: cs.error),
          const SizedBox(height: 12),
          Text('Não foi possível carregar os relatórios.', style: context.textStyles.titleMedium?.withColor(cs.onSurface).semiBold),
          const SizedBox(height: 6),
          Text('Puxe para atualizar ou tente novamente.', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _RelatoriosEmpty extends StatelessWidget {
  final VoidCallback onRetry;
  const _RelatoriosEmpty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Sem dados ainda', style: context.textStyles.titleMedium?.withColor(cs.onSurface).semiBold),
          const SizedBox(height: 6),
          Text('Quando você tiver entregas, elas vão aparecer aqui.', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: cs.primary, side: BorderSide(color: cs.primary.withValues(alpha: 0.6))),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(StatusEntrega status) {
  switch (status) {
    case StatusEntrega.aguardando:
    case StatusEntrega.saiuParaColeta:
      return StatusColors.waiting;
    case StatusEntrega.saiuParaEntrega:
      return StatusColors.inTransit;
    case StatusEntrega.entregue:
      return StatusColors.delivered;
    case StatusEntrega.problema:
      return StatusColors.problem;
    case StatusEntrega.cancelada:
      return StatusColors.cancelled;
  }
}
