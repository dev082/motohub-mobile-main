import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/theme.dart';
import 'package:provider/provider.dart';

/// Login screen for motoristas
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    // Triggers a subtle entrance animation without requiring an AnimationController.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    final success = await provider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Erro ao fazer login'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.primary.withValues(alpha: 0.92),
                    scheme.surface,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _entered ? 1 : 0),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - t) * 18),
                      child: Opacity(opacity: t, child: child),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LoginBrandHeader(
                          title: 'Hub Frete Driver',
                          subtitle: 'Gerencie suas entregas',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          onSubmit: _handleLogin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBg = scheme.onSurface;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.primary.withValues(alpha: 0.18),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
          ),
          child: Icon(Icons.local_shipping_rounded,
              color: scheme.primary, size: 28),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "HubFrete Motorista",
          textAlign: TextAlign.center,
          style: context.textStyles.headlineMedium
              ?.copyWith(color: onBg, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium
              ?.copyWith(color: onBg.withValues(alpha: 0.70), height: 1.5),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBg = scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(text: 'E-MAIL'),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: context.textStyles.bodyMedium?.copyWith(color: onBg),
              decoration: InputDecoration(
                hintText: 'seuemail@exemplo.com',
                prefixIcon: Icon(Icons.email_outlined,
                    color: onBg.withValues(alpha: 0.70)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Digite seu email';
                if (!value.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel(text: 'SENHA'),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              style: context.textStyles.bodyMedium?.copyWith(color: onBg),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline,
                    color: onBg.withValues(alpha: 0.70)),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: onBg.withValues(alpha: 0.70),
                  ),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Digite sua senha' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                return FilledButton(
                  onPressed: provider.isLoading ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: provider.isLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: scheme.onPrimary),
                          )
                        : Row(
                            key: const ValueKey('cta'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Entrar',
                                  style: context.textStyles.labelLarge
                                      ?.copyWith(
                                          color: scheme.onPrimary,
                                          fontWeight: FontWeight.w700)),
                              const SizedBox(width: AppSpacing.sm),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: scheme.onPrimary),
                            ],
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Fale com o suporte para recuperar sua senha.'),
                    backgroundColor: scheme.surfaceContainerHighest,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                  foregroundColor: onBg.withValues(alpha: 0.70)),
              child: Text('Esqueci minha senha',
                  style: context.textStyles.labelMedium
                      ?.copyWith(color: onBg.withValues(alpha: 0.70))),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: context.textStyles.labelSmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.72),
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
