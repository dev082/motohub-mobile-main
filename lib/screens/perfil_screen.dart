import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/motorista.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/pull_to_refresh.dart';
import 'package:provider/provider.dart';

/// Profile screen - shows motorista information
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final motorista = context.watch<AppProvider>().currentMotorista;

    if (motorista == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _showLogoutDialog(context)),
        ],
      ),
      body: PullToRefresh(
        onRefresh: () => context.read<AppProvider>().loadCurrentMotorista(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.paddingLg,
          children: [
            _ProfileHeader(motoristaNome: motorista.nomeCompleto, isAutonomo: motorista.isAutonomo, fotoUrl: motorista.fotoUrl),
            const SizedBox(height: AppSpacing.lg),

            Text('Conta', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const SizedBox(height: AppSpacing.sm),
            _MenuSection(
              children: [
                _MenuTile(icon: Icons.person_outline, title: 'Dados do motorista', subtitle: 'Email, telefone, documentos', onTap: () => _showDriverDetailsSheet(context, motorista)),
                _MenuTile(icon: Icons.directions_car_outlined, title: 'Veículos', subtitle: 'Gerencie seus veículos', onTap: () => context.push(AppRoutes.veiculos)),
                _MenuTile(icon: Icons.insights_outlined, title: 'Relatórios', subtitle: 'KPIs e histórico', onTap: () => context.push(AppRoutes.relatorios)),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Aparência', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const SizedBox(height: AppSpacing.sm),
            const _ThemeModeCard(),

            const SizedBox(height: AppSpacing.lg),
            Text('Sobre', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const SizedBox(height: AppSpacing.sm),
            _MenuSection(
              children: [
                _MenuTile(icon: Icons.local_shipping_outlined, title: 'Hub Frete Driver', subtitle: 'Versão 1.0.0', onTap: () {}),
                _MenuTile(icon: Icons.logout, title: 'Sair', subtitle: 'Encerrar sessão', onTap: () => _showLogoutDialog(context), destructive: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showDriverDetailsSheet(BuildContext context, Motorista motorista) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dados do motorista', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(label: 'Nome', value: motorista.nomeCompleto),
                _InfoRow(label: 'Email', value: motorista.email ?? 'Não informado'),
                _InfoRow(label: 'Telefone', value: motorista.telefone ?? 'Não informado'),
                _InfoRow(label: 'CPF', value: motorista.cpf),
                if (motorista.cnh != null) _InfoRow(label: 'CNH', value: '${motorista.cnh} - ${motorista.categoriaCnh ?? ""}'),
                if (motorista.uf != null) _InfoRow(label: 'UF', value: motorista.uf!),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: context.pop,
                    style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              context.read<AppProvider>().signOut();
              context.go('/login');
            },
            child: Text(
              'Sair',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.motoristaNome, required this.isAutonomo, required this.fotoUrl});
  final String motoristaNome;
  final bool isAutonomo;
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badgeColor = isAutonomo ? StatusColors.delivered : StatusColors.collected;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primaryContainer,
                backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl!) : null,
                child: fotoUrl == null ? Icon(Icons.person, color: cs.onPrimaryContainer) : null,
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Icon(isAutonomo ? Icons.person : Icons.business, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(motoristaNome, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  isAutonomo ? 'Motorista autônomo' : 'Motorista de frota',
                  style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.destructive = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconBg = destructive ? cs.errorContainer : cs.primaryContainer;
    final iconFg = destructive ? cs.onErrorContainer : cs.onPrimaryContainer;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconFg),
          ),
          title: Text(title, style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: destructive ? cs.error : cs.onSurface)),
          subtitle: Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ),
        Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.10)),
      ],
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.watch<AppProvider>();
    final mode = app.themeMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Tema', style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(value, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
