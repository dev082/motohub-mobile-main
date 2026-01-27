import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/app_drawer.dart';
import 'package:motohub/widgets/pull_to_refresh.dart';
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
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
          if (context.canPop())
            IconButton(onPressed: context.pop, icon: const Icon(Icons.close), tooltip: 'Fechar'),
        ],
      ),
      body: PullToRefresh(
        onRefresh: () => context.read<AppProvider>().loadCurrentMotorista(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.paddingLg,
          children: [
            // Profile picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: motorista.fotoUrl != null
                        ? NetworkImage(motorista.fotoUrl!)
                        : null,
                    child: motorista.fotoUrl == null
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: motorista.isAutonomo
                            ? StatusColors.delivered
                            : StatusColors.collected,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 3,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        motorista.isAutonomo ? Icons.person : Icons.business,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Name and type
            Text(
              motorista.nomeCompleto,
              style: context.textStyles.headlineSmall?.semiBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: motorista.isAutonomo
                    ? StatusColors.delivered.withValues(alpha: 0.1)
                    : StatusColors.collected.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                motorista.isAutonomo ? 'Motorista Autônomo' : 'Motorista de Frota',
                style: context.textStyles.labelLarge?.copyWith(
                  color: motorista.isAutonomo ? StatusColors.delivered : StatusColors.collected,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Information cards
            _buildInfoCard(
              context,
              icon: Icons.email_outlined,
              title: 'Email',
              value: motorista.email ?? 'Não informado',
            ),
            _buildInfoCard(
              context,
              icon: Icons.phone_outlined,
              title: 'Telefone',
              value: motorista.telefone ?? 'Não informado',
            ),
            _buildInfoCard(
              context,
              icon: Icons.badge_outlined,
              title: 'CPF',
              value: motorista.cpf,
            ),
            if (motorista.cnh != null)
              _buildInfoCard(
                context,
                icon: Icons.credit_card_outlined,
                title: 'CNH',
                value: '${motorista.cnh} - ${motorista.categoriaCnh ?? ""}',
              ),
            if (motorista.uf != null)
              _buildInfoCard(
                context,
                icon: Icons.location_city_outlined,
                title: 'UF',
                value: motorista.uf!,
              ),

            const SizedBox(height: AppSpacing.xxl),

            // About section
            Text(
              'Hub Frete Driver App',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Versão 1.0.0',
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: context.textStyles.bodyMedium?.semiBold,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
