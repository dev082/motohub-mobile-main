import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/carroceria.dart';
import 'package:hubfrete/models/veiculo.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/screens/chat_history_screen.dart';
import 'package:hubfrete/screens/chat_screen.dart';
import 'package:hubfrete/screens/carga_detalhes_screen.dart';
import 'package:hubfrete/screens/carroceria_form_screen.dart';
import 'package:hubfrete/screens/entrega_route_map_screen.dart';
import 'package:hubfrete/screens/entrega_detalhes_screen.dart';
import 'package:hubfrete/screens/login_screen.dart';
import 'package:hubfrete/screens/main_screen.dart';
import 'package:hubfrete/screens/veiculos_screen.dart';
import 'package:hubfrete/screens/relatorios_screen.dart';
import 'package:hubfrete/screens/perfil_screen.dart';
import 'package:hubfrete/screens/explorar_screen.dart';
import 'package:hubfrete/screens/veiculo_form_screen.dart';
import 'package:hubfrete/theme.dart';
import 'package:provider/provider.dart';

/// GoRouter configuration for Hub Frete Driver App navigation
///
/// This uses go_router for declarative routing with:
/// - Authentication guards and redirects
/// - Deep linking support
/// - Type-safe navigation
class AppRouter {
  static GoRouter createRouter(AppProvider appProvider) => GoRouter(
    initialLocation: AppRoutes.login,
    // This is critical: it makes go_router re-run redirect/pageBuilder when the
    // provider changes (e.g., when initialization finishes or auth state updates).
    refreshListenable: appProvider,
    redirect: (context, state) {
      final isAuthenticated = appProvider.isAuthenticated;
      final isInitialized = appProvider.isInitialized;
      final isLoginPage = state.matchedLocation == AppRoutes.login;

      // While bootstrapping auth, stay on the current location.
      if (!isInitialized) return null;

      if (isAuthenticated && isLoginPage) return AppRoutes.home;
      if (!isAuthenticated && !isLoginPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) {
          if (!appProvider.isInitialized) {
            return const NoTransitionPage(child: AuthLoadingScreen());
          }
          return const NoTransitionPage(child: LoginScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return NoTransitionPage(child: MainScreen(initialTab: tab));
        },
      ),
      GoRoute(
        path: AppRoutes.veiculos,
        name: 'veiculos',
        pageBuilder: (context, state) => const MaterialPage(child: VeiculosScreen()),
      ),
      GoRoute(
        path: AppRoutes.relatorios,
        name: 'relatorios',
        pageBuilder: (context, state) => const MaterialPage(child: RelatoriosScreen()),
      ),
      GoRoute(
        path: AppRoutes.perfil,
        name: 'perfil',
        pageBuilder: (context, state) => const MaterialPage(child: PerfilScreen()),
      ),
      GoRoute(
        path: AppRoutes.explorar,
        name: 'explorar',
        pageBuilder: (context, state) => const MaterialPage(child: ExplorarScreen()),
      ),
      GoRoute(
        path: AppRoutes.chatHistory,
        name: 'chatHistory',
        pageBuilder: (context, state) => const MaterialPage(child: ChatHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) {
          final entregaId = state.pathParameters['entregaId']!;
          return MaterialPage(child: ChatScreen(entregaId: entregaId));
        },
      ),
      GoRoute(
        path: AppRoutes.entregaMapa,
        name: 'entregaMapa',
        pageBuilder: (context, state) {
          final entregaId = state.pathParameters['id']!;
          return MaterialPage(child: EntregaRouteMapScreen(entregaId: entregaId));
        },
      ),
      GoRoute(
        path: AppRoutes.veiculoForm,
        name: 'veiculoForm',
        pageBuilder: (context, state) {
          final veiculo = state.extra is Veiculo ? state.extra as Veiculo : null;
          return MaterialPage(child: VeiculoFormScreen(veiculo: veiculo));
        },
      ),
      GoRoute(
        path: AppRoutes.carroceriaForm,
        name: 'carroceriaForm',
        pageBuilder: (context, state) {
          final carroceria = state.extra is Carroceria ? state.extra as Carroceria : null;
          return MaterialPage(child: CarroceriaFormScreen(carroceria: carroceria));
        },
      ),
      GoRoute(
        path: AppRoutes.entregaDetails,
        name: 'entregaDetails',
        pageBuilder: (context, state) {
          final entregaId = state.pathParameters['id']!;
          return MaterialPage(child: EntregaDetalhesScreen(entregaId: entregaId));
        },
      ),
      GoRoute(
        path: AppRoutes.cargaDetails,
        name: 'cargaDetails',
        pageBuilder: (context, state) {
          final cargaId = state.pathParameters['id']!;
          return MaterialPage(child: CargaDetalhesScreen(cargaId: cargaId));
        },
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String veiculos = '/veiculos';
  static const String relatorios = '/relatorios';
  static const String perfil = '/perfil';
  static const String explorar = '/explorar';
  static const String cargaDetails = '/carga/:id';
  static const String entregaDetails = '/entrega/:id';
  static const String entregaMapa = '/entrega/:id/mapa';
  static const String chatHistory = '/chat/historico';
  static const String chat = '/chat/:entregaId';
  static const String veiculoForm = '/veiculos/veiculo';
  static const String carroceriaForm = '/veiculos/carroceria';

  /// Helpers to build concrete paths for parameterized routes.
  /// Prefer these over manual string concatenation to avoid `Page Not Found`.
  static String entregaDetailsPath(String entregaId) => '/entrega/$entregaId';
  static String entregaMapaPath(String entregaId) => '/entrega/$entregaId/mapa';
  static String chatPath(String entregaId) => '/chat/$entregaId';
  static String cargaDetailsPath(String cargaId) => '/carga/$cargaId';
}

/// Tela de loading mostrada durante verifica\u00e7\u00e3o de sess\u00e3o
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LightModeColors.lightPrimary,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Hub Frete',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          CircularProgressIndicator(color: Colors.white),
        ],
      ),
    ),
  );
}
