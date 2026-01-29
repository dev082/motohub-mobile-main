import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/motorista.dart';
import 'package:hubfrete/services/auth_service.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/services/secure_storage_service.dart';
import 'package:hubfrete/services/storage_upload_service.dart';
import 'package:hubfrete/models/app_user_alert.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/models/tracking_state.dart';
import 'package:hubfrete/models/entrega.dart';

/// Main app provider for managing global state
class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final EntregaService _entregaService = EntregaService();
  final LocationTrackingService _trackingService = LocationTrackingService.instance;

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

  // Kept for potential future “notifications center”. Not currently used by overlay.
  final List<AppUserAlert> _userAlerts = [];

  ThemeMode _themeMode = ThemeMode.system;

  // UX: permite que a Home dispare uma busca e a aba Explorar já abra com texto preenchido.
  // Como Explorar fica em IndexedStack, precisamos de um estado global simples.
  String? _explorarPrefillQuery;

  String? _chatWallpaperUrl;
  double _chatWallpaperOpacity = 0.10;
  String? _chatWallpaperLoadedForUserId;

  AppProvider() {
    _initializeAuth();
    _setupAuthListener();
    _loadThemeMode();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      await _trackingService.initialize();
    } catch (e) {
      debugPrint('[AppProvider] Erro ao inicializar rastreamento: $e');
    }
  }

  static const String _lastAuthUserIdKey = 'last_auth_user_id';
  static String _cachedMotoristaKey(String userId) => 'cached_motorista_json:$userId';

  static const String _themeModeStorageKey = 'app_theme_mode';

  ThemeMode get themeMode => _themeMode;
  String? get chatWallpaperUrl => _chatWallpaperUrl;
  double get chatWallpaperOpacity => _chatWallpaperOpacity;

  String? get explorarPrefillQuery => _explorarPrefillQuery;

  /// Define uma busca para pré-preencher no Explorar.
  ///
  /// Observação: Explorar pode escolher limpar esse valor após consumir.
  void setExplorarPrefillQuery(String? query) {
    final normalized = query?.trim();
    final next = (normalized == null || normalized.isEmpty) ? null : normalized;
    if (next == _explorarPrefillQuery) return;
    _explorarPrefillQuery = next;
    notifyListeners();
  }

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

      // Se existir sessão (login persistido), tentamos carregar o motorista no servidor.
      // Se estiver sem internet, o select pode falhar/demorAR. Então:
      // 1) tentamos o servidor com timeout curto
      // 2) caímos para um cache local do motorista (se existir)
      final authUserId = user?.id ?? session?.user.id;
      if (authUserId != null) {
        await SecureStorageService.write(_lastAuthUserIdKey, authUserId);
      }

      try {
        await loadCurrentMotorista().timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('Auth bootstrap: loadCurrentMotorista failed/timeout, trying cached motorista. error=$e');
        await _restoreCachedMotoristaIfPossible();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  Future<void> _restoreCachedMotoristaIfPossible() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id ?? await SecureStorageService.read(_lastAuthUserIdKey);
      if (userId == null || userId.trim().isEmpty) return;

      final raw = await SecureStorageService.read(_cachedMotoristaKey(userId));
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final motorista = Motorista.fromJson(decoded);
      _currentMotorista = motorista;
      await _loadActiveEntregaId();
      notifyListeners();

      // Não iniciamos realtime aqui (pode estar offline). As telas podem funcionar com cache local.
      debugPrint('Auth bootstrap: restored cached motorista (${motorista.id}) for offline mode.');
    } catch (e) {
      debugPrint('Restore cached motorista error: $e');
    }
  }

  Future<void> _persistCachedMotorista(Motorista motorista) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id ?? motorista.userId;
      if (userId == null || userId.trim().isEmpty) return;
      await SecureStorageService.write(_lastAuthUserIdKey, userId);
      await SecureStorageService.write(_cachedMotoristaKey(userId), jsonEncode(motorista.toJson()));
    } catch (e) {
      debugPrint('Persist cached motorista error: $e');
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
  TrackingState get trackingState => _trackingService.currentState;
  bool get isLocationTrackingActive => _trackingService.isTracking && _trackingService.currentState != TrackingState.offline;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  AppUserAlert? get activeUserAlert => _userAlerts.isEmpty ? null : _userAlerts.first;
  bool get isAuthenticated => _currentMotorista != null;
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
        // Para rastreamento quando não há entrega ativa
        await _trackingService.updateTrackingState(TrackingState.onlineSemEntrega);
      } else {
        await SecureStorageService.write(key, entregaId);
        // Busca status da entrega para definir estado de rastreamento
        await _updateTrackingForEntrega();
      }
    } catch (e) {
      debugPrint('Persist activeEntregaId error: $e');
    }
  }

  Future<void> _updateTrackingForEntrega() async {
    try {
      final entregaId = _activeEntregaId;
      if (entregaId == null) return;

      final data = await SupabaseConfig.client.from('entregas').select('status').eq('id', entregaId).maybeSingle();
      if (data == null) return;

      final statusStr = data['status'] as String?;
      if (statusStr == null) return;

      final status = StatusEntrega.fromString(statusStr);
      final trackingState = switch (status) {
        StatusEntrega.aguardando => TrackingState.onlineSemEntrega,
        StatusEntrega.saiuParaColeta => TrackingState.emRotaColeta,
        StatusEntrega.saiuParaEntrega => TrackingState.emEntrega,
        StatusEntrega.entregue || StatusEntrega.cancelada => TrackingState.finalizado,
        StatusEntrega.problema => TrackingState.emEntrega,
      };

      await _trackingService.updateTrackingState(trackingState);
    } catch (e) {
      debugPrint('Update tracking for entrega error: $e');
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
      await _persistCachedMotorista(motorista);
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
      await _stopChatNotifications();
      await _stopEntregaAssignmentRealtime();
      
      // Para rastreamento ao fazer logout
      await _trackingService.stopTracking();
      
      await _authService.signOut();

      // Clear cached motorista for this user so the app doesn't restore offline after logout.
      try {
        final userId = await SecureStorageService.read(_lastAuthUserIdKey);
        if (userId != null && userId.trim().isNotEmpty) {
          await SecureStorageService.delete(_cachedMotoristaKey(userId));
        }
        await SecureStorageService.delete(_lastAuthUserIdKey);
      } catch (e) {
        debugPrint('Clear cached motorista on signOut error: $e');
      }

      _currentMotorista = null;
      _activeEntregaId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
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

        // Inicia rastreamento quando uma entrega é atribuída
        await _trackingService.startTracking(
          motoristaId: motorista.id,
          initialState: TrackingState.onlineSemEntrega,
        );
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
      Motorista? motorista;
      try {
        // Defensive timeout: without internet, Postgrest may take a long time.
        motorista = await _authService.getCurrentMotorista().timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('loadCurrentMotorista: remote fetch failed/timeout: $e');
      }

      // If remote fetch failed but we still have an auth session, try local cache.
      motorista ??= await _getCachedMotoristaForCurrentUser();
      _currentMotorista = motorista;
      await _loadActiveEntregaId();
      notifyListeners();

      if (motorista != null) {
        await _persistCachedMotorista(motorista);
        await _startChatNotifications();
        await _startEntregaAssignmentRealtime();
        
        // Inicia rastreamento online
        await _trackingService.startTracking(
          motoristaId: motorista.id,
          initialState: TrackingState.onlineSemEntrega,
        );
      }
    } catch (e) {
      debugPrint('Load current motorista error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Motorista?> _getCachedMotoristaForCurrentUser() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id ?? await SecureStorageService.read(_lastAuthUserIdKey);
      if (userId == null || userId.trim().isEmpty) return null;

      final raw = await SecureStorageService.read(_cachedMotoristaKey(userId));
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Motorista.fromJson(decoded);
    } catch (e) {
      debugPrint('Get cached motorista error: $e');
      return null;
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

  void pushUserAlert(AppUserAlert alert) {
    // Prevent spamming repeated identical alerts.
    final exists = _userAlerts.any((a) => a.code == alert.code && a.message == alert.message);
    if (exists) return;
    _userAlerts.insert(0, alert);
    if (_userAlerts.length > 5) _userAlerts.removeRange(5, _userAlerts.length);
    notifyListeners();
  }

  void dismissActiveUserAlert() {
    if (_userAlerts.isEmpty) return;
    _userAlerts.removeAt(0);
    notifyListeners();
  }
}
