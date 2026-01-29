import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/screens/operacao_dia_screen.dart';
import 'package:hubfrete/screens/entregas_screen.dart';
import 'package:hubfrete/screens/chat_list_screen.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/widgets/tracking_permission_blocker.dart';

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
  bool _permissionsGranted = false;
  bool _isCheckingPermissions = true;

  final List<Widget> _screens = const [
    OperacaoDiaScreen(),
    EntregasScreen(),
    ChatListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromQuery();
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await LocationTrackingService.instance.checkPermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = hasPermissions;
        _isCheckingPermissions = false;
      });
    }
  }

  void _onPermissionsGranted() {
    setState(() => _permissionsGranted = true);
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
    if (_isCheckingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_permissionsGranted) {
      return TrackingPermissionBlocker(onPermissionsGranted: _onPermissionsGranted);
    }

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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Operação'),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Entregas',
          ),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
        ],
      ),
    );
  }
}
