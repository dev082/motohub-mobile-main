import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/motorista.dart';
import 'package:hubfrete/services/auth_service.dart';
import 'package:hubfrete/services/location_service.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/services/secure_storage_service.dart';
import 'package:hubfrete/services/storage_upload_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Main app provider for managing global state
class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final EntregaService _entregaService = EntregaService();

  Timer? _ensureTrackingTimer;

  RealtimeChannel? _mensagensChannel;
  RealtimeChannel? _entregasAssignmentsChannel;
  String? _activeEntregaChatId;

  int _entregasRealtimeTick = 0;
  final Set<String> _notifiedEntregaAssignments = {};

  final Map<String, String> _cargaCodigoByChatId = {};
  final Map<String, String> _entregaIdByChatId = {};

  Motorista? _currentMotorista;
  String? _activeEntregaId;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  ThemeMode _themeMode = ThemeMode.system;

  String? _chatWallpaperUrl;
  double _chatWallpaperOpacity = 0.10;
  String? _chatWallpaperLoadedForUserId;

  AppProvider() {
    _initializeAuth();
    _setupAuthListener();
    _initializeTrackingService();
    _loadThemeMode();
  }

  static const String _themeModeStorageKey = 'app_theme_mode';

  ThemeMode get themeMode => _themeMode;
  String? get chatWallpaperUrl => _chatWallpaperUrl;
  double get chatWallpaperOpacity => _chatWallpaperOpacity;

  Future<void> _loadThemeMode() async {
    try {
      final value = await SecureStorageService.read(_themeModeStorageKey);
      final normalized = (value ?? '').trim().toLowerCase();
      final mode = switch (normalized) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' || '' => ThemeMode.system,
        _ => ThemeMode.system,
      };
      if (mode != _themeMode) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load themeMode error: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      await SecureStorageService.write(
        _themeModeStorageKey,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (e) {
      debugPrint('Persist themeMode error: $e');
    }
  }

  Future<void> _initializeTrackingService() async {
    try {
      await LocationTrackingService.instance.init();
    } catch (e) {
      debugPrint('Initialize tracking service error: $e');
    }
  }

  /// Verifica se há uma sessão salva ao inicializar o app
  Future<void> _initializeAuth() async {
    _setLoading(true);
    try {
      // Importante: não devemos “travar” o app esperando JWT/storage.
      // Se não existir sessão, finalizamos a inicialização e mostramos o login.
      final session = SupabaseConfig.auth.currentSession;
      final user = SupabaseConfig.auth.currentUser;

      if (session == null && user == null) {
        debugPrint('Auth bootstrap: no saved session found. Showing login.');
        return;
      }

      // Se existir sessão (login persistido), carregamos o motorista.
      // Colocamos timeout defensivo para evitar loading infinito.
      await loadCurrentMotorista().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  /// Configura listener para mudanças de autenticação
  void _setupAuthListener() {
    SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        // Sessão expirou ou usuário fez logout
        _currentMotorista = null;
        _chatWallpaperUrl = null;
        _chatWallpaperOpacity = 0.10;
        _chatWallpaperLoadedForUserId = null;
        await _stopChatNotifications();
        await _stopEntregaAssignmentRealtime();
        notifyListeners();
      } else if (_currentMotorista == null) {
        // Nova sessão foi criada (login ou recuperação automática)
        await loadCurrentMotorista();
        await loadChatWallpaperPrefs();
      }
    });
  }

  static String _chatWallpaperDataKey(String userId) => 'chat_wallpaper_data_$userId';
  static String _chatWallpaperOpacityKey(String userId) => 'chat_wallpaper_opacity_$userId';

  Future<void> loadChatWallpaperPrefs() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;
      if (_chatWallpaperLoadedForUserId == userId) return;

      final base64Data = await SecureStorageService.read(_chatWallpaperDataKey(userId));
      final opacityRaw = await SecureStorageService.read(_chatWallpaperOpacityKey(userId));
      final parsedOpacity = double.tryParse((opacityRaw ?? '').trim());

      // Store a data URI for local wallpaper
      _chatWallpaperUrl = (base64Data == null || base64Data.trim().isEmpty) ? null : base64Data.trim();
      _chatWallpaperOpacity = (parsedOpacity != null)
          ? parsedOpacity.clamp(0.0, 0.5)
          : 0.10;
      _chatWallpaperLoadedForUserId = userId;
      notifyListeners();
    } catch (e) {
      debugPrint('Load chat wallpaper prefs error: $e');
    }
  }

  Future<void> setChatWallpaperOpacity(double opacity) async {
    _chatWallpaperOpacity = opacity.clamp(0.0, 0.5);
    notifyListeners();
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;
      await SecureStorageService.write(
        _chatWallpaperOpacityKey(userId),
        _chatWallpaperOpacity.toStringAsFixed(3),
      );
    } catch (e) {
      debugPrint('Persist chat wallpaper opacity error: $e');
    }
  }

  Future<void> setChatWallpaperUrl(String? dataUri) async {
    _chatWallpaperUrl = (dataUri == null || dataUri.trim().isEmpty) ? null : dataUri.trim();
    notifyListeners();
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;
      if (_chatWallpaperUrl == null) {
        await SecureStorageService.delete(_chatWallpaperDataKey(userId));
      } else {
        await SecureStorageService.write(_chatWallpaperDataKey(userId), _chatWallpaperUrl!);
      }
    } catch (e) {
      debugPrint('Persist chat wallpaper data error: $e');
    }
  }

  /// Saves a wallpaper image locally (not on Supabase) and sets it as the chat wallpaper.
  /// The image is stored as a base64 data URI in secure storage.
  Future<String?> uploadAndSetChatWallpaper({required Uint8List bytes, required String contentType}) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return null;

      // Convert to base64 data URI for local storage
      final base64 = const Base64Encoder().convert(bytes);
      final dataUri = 'data:$contentType;base64,$base64';
      
      await setChatWallpaperUrl(dataUri);
      return dataUri;
    } catch (e) {
      debugPrint('Save chat wallpaper locally error: $e');
      return null;
    }
  }

  Motorista? get currentMotorista => _currentMotorista;
  String? get activeEntregaId => _activeEntregaId;
  int get entregasRealtimeTick => _entregasRealtimeTick;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentMotorista != null;
  LocationService get locationService => _locationService;

  static String _activeEntregaStorageKey(String motoristaId) => 'active_entrega_id:$motoristaId';

  Future<void> setActiveEntregaId(String? entregaId) async {
    final motorista = _currentMotorista;
    _activeEntregaId = entregaId;
    notifyListeners();

    if (motorista == null) return;
    final key = _activeEntregaStorageKey(motorista.id);
    try {
      if (entregaId == null || entregaId.isEmpty) {
        await SecureStorageService.delete(key);
      } else {
        await SecureStorageService.write(key, entregaId);
      }
    } catch (e) {
      // Não queremos travar a UI se storage falhar.
      debugPrint('Persist activeEntregaId error: $e');
    }
  }

  Future<void> _loadActiveEntregaId() async {
    final motorista = _currentMotorista;
    if (motorista == null) {
      _activeEntregaId = null;
      return;
    }

    try {
      final value = await SecureStorageService.read(_activeEntregaStorageKey(motorista.id));
      _activeEntregaId = (value == null || value.trim().isEmpty) ? null : value.trim();
      notifyListeners();
    } catch (e) {
      debugPrint('Load activeEntregaId error: $e');
    }
  }

  /// Sign in motorista
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final motorista = await _authService.signInMotorista(email, password);
      if (motorista == null) {
        _setError('Email ou senha inválidos');
        return false;
      }

      _currentMotorista = motorista;
      notifyListeners();

      // Start realtime notifications after login.
      await _startChatNotifications();
      await _startEntregaAssignmentRealtime();
      return true;
    } catch (e) {
      _setError('Erro ao fazer login: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Stop location tracking if active
      _locationService.stopTracking();
      await LocationTrackingService.instance.stopTracking();

      _ensureTrackingTimer?.cancel();
      _ensureTrackingTimer = null;

      await _stopChatNotifications();
      await _stopEntregaAssignmentRealtime();
      
      await _authService.signOut();
      _currentMotorista = null;
      _activeEntregaId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  void _startEnsureTrackingLoop() {
    _ensureTrackingTimer?.cancel();
    // Best-effort watchdog: guarantees tracking stays on while there is an active entrega.
    _ensureTrackingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await ensureTrackingForActiveEntrega();
    });
  }

  /// Ensures background tracking is running while the motorista has at least one active entrega.
  ///
  /// This is called:
  /// - after login/session restore
  /// - when an entrega is assigned via realtime
  /// - periodically (watchdog) while authenticated
  Future<void> ensureTrackingForActiveEntrega() async {
    final motorista = _currentMotorista;
    if (motorista == null) return;

    try {
      // Prefer the user-selected activeEntregaId.
      String? entregaId = _activeEntregaId;

      // If none selected, pick the most recent active entrega.
      if (entregaId == null || entregaId.isEmpty) {
        final active = await _entregaService.getMotoristaEntregas(motorista.id, activeOnly: true);
        if (active.isNotEmpty) {
          entregaId = active.first.id;
          // Persist selection so other screens stay consistent.
          await setActiveEntregaId(entregaId);
        }
      }

      // No active entrega -> stop tracking.
      if (entregaId == null || entregaId.isEmpty) {
        if (LocationTrackingService.instance.isTracking) {
          await LocationTrackingService.instance.stopTracking();
        }
        return;
      }

      // There is an active entrega -> ensure tracking is active for this entrega.
      if (!LocationTrackingService.instance.isTracking || LocationTrackingService.instance.currentEntregaId != entregaId) {
        final ok = await LocationTrackingService.instance.startTracking(entregaId, motorista.id);
        if (!ok) {
          debugPrint('⚠️ ensureTrackingForActiveEntrega: startTracking failed. lastError=${LocationTrackingService.instance.lastError}');
        }
      }
    } catch (e) {
      debugPrint('ensureTrackingForActiveEntrega error: $e');
    }
  }

  /// Used by ChatScreen to avoid notifying while the user is already in that chat.
  void setActiveChatEntregaId(String? entregaId) {
    _activeEntregaChatId = entregaId;
  }

  Future<void> _startChatNotifications() async {
    // Defensive: remove previous channel if any.
    await _stopChatNotifications();

    final motorista = _currentMotorista;
    final authUid = SupabaseConfig.client.auth.currentUser?.id;
    if (motorista == null || authUid == null) return;

    final channel = SupabaseConfig.client.channel('mensagens:notifications');
    _mensagensChannel = channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'mensagens',
      callback: (payload) async {
        try {
          final record = payload.newRecord;
          final chatId = record['chat_id'] as String?;
          final senderId = record['sender_id'] as String?;
          final senderNome = (record['sender_nome'] as String?)?.trim();
          final conteudo = (record['conteudo'] as String?)?.trim();

          if (chatId == null || senderId == null || conteudo == null || conteudo.isEmpty) return;
          // Don't notify for my own messages.
          if (senderId == authUid) return;

          final entregaId = await _resolveEntregaId(chatId);
          if (entregaId == null) return;

          // If user is currently viewing this chat, skip notification.
          if (_activeEntregaChatId != null && _activeEntregaChatId == entregaId) return;

          // Confirm this chat belongs to the motorista logged in.
          final belongs = await _entregaBelongsToMotorista(entregaId, motorista.id);
          if (!belongs) return;

          final cargaCodigo = await _resolveCargaCodigo(chatId);
          await NotificationService.instance.showChatMessage(
            cargaCodigo: cargaCodigo,
            senderNome: (senderNome == null || senderNome.isEmpty) ? 'Mensagem' : senderNome,
            message: conteudo,
          );
        } catch (e) {
          debugPrint('Chat notification callback error: $e');
        }
      },
    );

    channel.subscribe((status, error) {
      debugPrint('Notifications channel status=$status error=$error');
    });
  }

  Future<void> _startEntregaAssignmentRealtime() async {
    await _stopEntregaAssignmentRealtime();

    final motorista = _currentMotorista;
    if (motorista == null) return;

    final channel = SupabaseConfig.client.channel('entregas:assignments:${motorista.id}');
    _entregasAssignmentsChannel = channel;

    Future<void> handleRecord(Map<String, dynamic> record, {Map<String, dynamic>? oldRecord}) async {
      try {
        final entregaId = record['id'] as String?;
        final newMotoristaId = record['motorista_id'] as String?;
        final oldMotoristaId = oldRecord?['motorista_id'] as String?;

        if (entregaId == null) return;
        if (newMotoristaId != motorista.id) return;

        // Avoid duplicate notifications for the same entrega.
        if (_notifiedEntregaAssignments.contains(entregaId)) {
          // Still bump tick so UI can refresh if needed.
          _entregasRealtimeTick++;
          notifyListeners();
          return;
        }

        // If this is an UPDATE, only notify when the assignment just happened.
        if (oldRecord != null && oldMotoristaId == motorista.id) {
          // Already assigned before, skip notification.
          return;
        }

        _notifiedEntregaAssignments.add(entregaId);
        _entregasRealtimeTick++;
        notifyListeners();

        // Auto-select as active entrega if none selected.
        if ((_activeEntregaId == null || _activeEntregaId!.isEmpty)) {
          await setActiveEntregaId(entregaId);
        }

        await NotificationService.instance.showDeliveryEvent(
          title: '📦 Nova entrega designada',
          message: 'Uma entrega foi atribuída para você agora.',
          tipo: 'entrega_designada',
          entregaId: entregaId,
          motoristaId: motorista.id,
        );

        // Ensure tracking kicks in as soon as the driver receives an active entrega.
        await ensureTrackingForActiveEntrega();
      } catch (e) {
        debugPrint('Entrega assignment realtime callback error: $e');
      }
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'entregas',
          callback: (payload) async {
            final record = Map<String, dynamic>.from(payload.newRecord);
            await handleRecord(record);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'entregas',
          callback: (payload) async {
            final record = Map<String, dynamic>.from(payload.newRecord);
            final old = payload.oldRecord.isEmpty ? null : Map<String, dynamic>.from(payload.oldRecord);
            await handleRecord(record, oldRecord: old);
          },
        );

    channel.subscribe((status, error) {
      debugPrint('Entrega assignments channel status=$status error=$error');
    });
  }

  Future<void> _stopEntregaAssignmentRealtime() async {
    try {
      final ch = _entregasAssignmentsChannel;
      if (ch != null) await SupabaseConfig.client.removeChannel(ch);
    } catch (e) {
      debugPrint('Stop entrega assignment realtime error: $e');
    } finally {
      _entregasAssignmentsChannel = null;
      _notifiedEntregaAssignments.clear();
    }
  }

  Future<void> _stopChatNotifications() async {
    try {
      final ch = _mensagensChannel;
      if (ch != null) {
        await SupabaseConfig.client.removeChannel(ch);
      }
    } catch (e) {
      debugPrint('Stop chat notifications error: $e');
    } finally {
      _mensagensChannel = null;
      _cargaCodigoByChatId.clear();
      _entregaIdByChatId.clear();
      _activeEntregaChatId = null;
    }
  }

  Future<String?> _resolveEntregaId(String chatId) async {
    final cached = _entregaIdByChatId[chatId];
    if (cached != null) return cached;
    try {
      final data = await SupabaseConfig.client.from('chats').select('entrega_id').eq('id', chatId).maybeSingle();
      final entregaId = data?['entrega_id'] as String?;
      if (entregaId != null) _entregaIdByChatId[chatId] = entregaId;
      return entregaId;
    } catch (e) {
      debugPrint('Resolve entregaId error: $e');
      return null;
    }
  }

  Future<String> _resolveCargaCodigo(String chatId) async {
    final cached = _cargaCodigoByChatId[chatId];
    if (cached != null) return cached;
    try {
      final entregaId = await _resolveEntregaId(chatId);
      if (entregaId == null) return '—';

      final data = await SupabaseConfig.client
          .from('entregas')
          .select('codigo, carga:carga_id(codigo)')
          .eq('id', entregaId)
          .maybeSingle();

      final entregaCodigo = (data?['codigo'] as String?)?.trim();
      final carga = data?['carga'] as Map<String, dynamic>?;
      final cargaCodigo = (carga?['codigo'] as String?)?.trim();

      final result = (entregaCodigo != null && entregaCodigo.isNotEmpty)
          ? entregaCodigo
          : (cargaCodigo != null && cargaCodigo.isNotEmpty)
              ? cargaCodigo
              : '—';

      _cargaCodigoByChatId[chatId] = result;
      return result;
    } catch (e) {
      debugPrint('Resolve cargaCodigo error: $e');
      return '—';
    }
  }

  Future<bool> _entregaBelongsToMotorista(String entregaId, String motoristaId) async {
    try {
      final data = await SupabaseConfig.client.from('entregas').select('motorista_id').eq('id', entregaId).maybeSingle();
      return (data?['motorista_id'] as String?) == motoristaId;
    } catch (e) {
      debugPrint('Check entrega motorista error: $e');
      return false;
    }
  }

  /// Load current motorista
  Future<void> loadCurrentMotorista() async {
    _setLoading(true);
    try {
      final motorista = await _authService.getCurrentMotorista();
      _currentMotorista = motorista;
      await _loadActiveEntregaId();
      notifyListeners();

      if (motorista != null) {
        await _startChatNotifications();
        await _startEntregaAssignmentRealtime();

        _startEnsureTrackingLoop();
        await ensureTrackingForActiveEntrega();
      }
    } catch (e) {
      debugPrint('Load current motorista error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update motorista profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_currentMotorista == null) return false;

    _setLoading(true);
    _clearError();

    try {
      await _authService.updateMotorista(_currentMotorista!.id, updates);
      
      // Reload motorista data
      await loadCurrentMotorista();
      return true;
    } catch (e) {
      _setError('Erro ao atualizar perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
