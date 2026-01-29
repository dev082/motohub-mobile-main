import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/screens/operacao_dia_screen.dart';
import 'package:hubfrete/screens/entregas_screen.dart';
import 'package:hubfrete/screens/chat_list_screen.dart';
import 'package:hubfrete/screens/explorar_screen.dart';
import 'package:hubfrete/screens/perfil_screen.dart';

/// Main screen with bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialTab});

  /// Optional query param (`/home?tab=inicio|explorar|entregas|chat|menu`).
  final String? initialTab;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    OperacaoDiaScreen(),
    ExplorarScreen(),
    EntregasScreen(),
    ChatListScreen(),
    PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromQuery();
  }

  void _syncFromQuery() {
    // If router provided `initialTab`, honor it once.
    final tab = widget.initialTab ?? GoRouterState.of(context).uri.queryParameters['tab'];
    final mapped = _indexFromTab(tab);
    if (mapped != null && mapped != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = mapped);
      });
    }
  }

  int? _indexFromTab(String? tab) {
    switch (tab) {
      case 'operacao': // backward compat
      case 'inicio':
      case null:
      case '':
        return 0;
      case 'explorar':
        return 1;
      case 'entregas':
        return 2;
      case 'chat':
        return 3;
      case 'menu':
      case 'perfil':
        return 4;
    }
    return null;
  }

  String _tabFromIndex(int index) {
    switch (index) {
      case 0:
        return 'inicio';
      case 1:
        return 'explorar';
      case 2:
        return 'entregas';
      case 3:
        return 'chat';
      case 4:
        return 'menu';
      default:
        return 'inicio';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        animationDuration: const Duration(milliseconds: 360),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          context.go('${AppRoutes.home}?tab=${_tabFromIndex(index)}');
        },
        destinations: const [
          // Ícones sempre "outline"; estado selecionado é apenas pela cor (verde sutil), sem indicador.
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_outlined), label: 'Explorar'),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_outlined),
            label: 'Entregas',
          ),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          // Menu não troca ícone quando selecionado.
          NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }
}
