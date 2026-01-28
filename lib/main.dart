import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/cache_service.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:hubfrete/widgets/in_app_error_overlay.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'nav.dart';

/// Main entry point for the Hub Frete Driver App
///
/// This sets up:
/// - Supabase initialization
/// - Provider state management
/// - go_router navigation
/// - Material 3 theming with Hub Frete green branding
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  } catch (e) {
    debugPrint('Failed to initialize intl date formatting: $e');
  }
  
  // Inicializa Supabase com persistência automática de sessão
  await SupabaseConfig.initialize();

  // Initialize Hive cache for offline-first tracking
  await CacheService.init();

  // Best-effort init for local notifications (Android/iOS). On web it's a no-op.
  await NotificationService.instance.init();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Builder(
        builder: (context) {
          _router ??= AppRouter.createRouter(context.read<AppProvider>());
          final themeMode = context.watch<AppProvider>().themeMode;
          return MaterialApp.router(
            title: 'HubFrete Motoristas',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            builder: (context, child) => InAppErrorOverlay(child: child ?? const SizedBox.shrink()),
            routerConfig: _router!,
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppBarTheme.of(context).backgroundColor,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
