import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/screens/operacao_dia_screen.dart';
import 'package:motohub/screens/entregas_screen.dart';
import 'package:motohub/screens/chat_list_screen.dart';

/// Main screen with bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialTab});

  /// Optional query param (`/home?tab=operacao|entregas|chat`).
  final String? initialTab;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    OperacaoDiaScreen(),
    EntregasScreen(),
    ChatListScreen(),
  ];

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
      case 'operacao':
      case null:
      case '':
        return 0;
      case 'entregas':
        return 1;
      case 'chat':
        return 2;
    }
    return null;
  }

  String _tabFromIndex(int index) {
    switch (index) {
      case 0:
        return 'operacao';
      case 1:
        return 'entregas';
      case 2:
        return 'chat';
      default:
        return 'operacao';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        animationDuration: const Duration(milliseconds: 360),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          context.go('${AppRoutes.home}?tab=${_tabFromIndex(index)}');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Operação',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Entregas',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
