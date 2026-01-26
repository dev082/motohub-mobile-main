import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/theme.dart';
import 'package:provider/provider.dart';

/// App-wide navigation drawer (menu hambúrguer).
///
/// Uses go_router (`context.go`/`context.push`) to navigate.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.activeRoute});

  /// Current route path to highlight the active entry when possible.
  final String? activeRoute;

  bool _isActive(String route) => activeRoute == route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Icon(Icons.local_shipping, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hub Frete', style: theme.textTheme.titleMedium),
                        Text('Motorista', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Operação do dia',
                    selected: _isActive(AppRoutes.home) || activeRoute == null,
                    onTap: () {
                      context.pop();
                      context.go('${AppRoutes.home}?tab=operacao');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Entregas',
                    selected: false,
                    onTap: () {
                      context.pop();
                      context.go('${AppRoutes.home}?tab=entregas');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    selected: false,
                    onTap: () {
                      context.pop();
                      context.go('${AppRoutes.home}?tab=chat');
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                    child: Text('Outros', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  _DrawerItem(
                    icon: Icons.directions_car_outlined,
                    label: 'Veículos',
                    selected: _isActive(AppRoutes.veiculos),
                    onTap: () {
                      context.pop();
                      context.push(AppRoutes.veiculos);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.insights_outlined,
                    label: 'Relatórios',
                    selected: _isActive(AppRoutes.relatorios),
                    onTap: () {
                      context.pop();
                      context.push(AppRoutes.relatorios);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    selected: _isActive(AppRoutes.perfil),
                    onTap: () {
                      context.pop();
                      context.push(AppRoutes.perfil);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.explore_outlined,
                    label: 'Explorar',
                    selected: _isActive(AppRoutes.explorar),
                    onTap: () {
                      context.pop();
                      context.push(AppRoutes.explorar);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                    child: Text('Aparência', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const _ThemeModeSelector(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final mode = app.themeMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dark_mode_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tema',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                ],
                selected: {mode},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  context.read<AppProvider>().setThemeMode(value.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap, required this.selected});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
