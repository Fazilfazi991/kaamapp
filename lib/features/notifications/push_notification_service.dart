import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_service.dart';
import '../supabase_backend/kaam_backend.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

@pragma('vm:entry-point')
Future<void> kaamFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    return;
  }
}

class KaamPushNotificationService {
  KaamPushNotificationService._();

  static final instance = KaamPushNotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _repository = const KaamNotificationRepository();
  FirebaseMessaging? _messaging;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Future<void>? _initialization;
  bool _firebaseAvailable = false;
  String? _lastToken;
  String? _pendingRoute;
  String? _activeConversationId;
  KaamPushDiagnosticsSnapshot _diagnostics =
      const KaamPushDiagnosticsSnapshot();

  KaamPushDiagnosticsSnapshot get diagnostics => _diagnostics;

  /// Chat screens set this while visible to prevent a second system alert for
  /// a message the recipient is already reading.
  void setActiveConversation(String? conversationId) =>
      _activeConversationId = conversationId;

  Future<void> initialize() async {
    final existingInitialization = _initialization;
    if (existingInitialization != null) return existingInitialization;
    _initialization = _initialize();
    return _initialization;
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      _firebaseAvailable = true;
      _setDiagnostics(
        _diagnostics.copyWith(firebaseInitialized: true),
        log: 'Firebase initialized',
      );
    } on Object catch (error) {
      _setDiagnostics(
        _diagnostics.copyWith(
          firebaseInitialized: false,
          lastSafeErrorCategory: 'firebase_initialization_failed',
        ),
        log: 'Firebase initialization failed',
      );
      if (kDebugMode) {
        debugPrint('[Notifications] Firebase unavailable: $error');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      kaamFirebaseMessagingBackgroundHandler,
    );
    await _runOptionalStep(
      _configureLocalNotifications,
      category: 'local_notifications_initialization_failed',
      log: 'Local notifications initialization failed',
    );
    await _runOptionalStep(
      _createAndroidChannel,
      category: 'android_channel_creation_failed',
      log: 'Android notification channel creation failed',
    );
    _runOptionalSyncStep(
      _listenForMessages,
      category: 'message_listener_setup_failed',
      log: 'Message listener setup failed',
    );
    _runOptionalSyncStep(
      _listenForAuthChanges,
      category: 'auth_listener_setup_failed',
      log: 'Auth listener setup failed',
    );
    await _runOptionalStep(
      _handleInitialMessage,
      category: 'initial_message_handling_failed',
      log: 'Initial notification handling failed',
    );
  }

  Future<bool> requestPermissionAndRegister() async {
    final messaging = _messaging;
    if (!_firebaseAvailable ||
        messaging == null ||
        !SupabaseService.isEnabled) {
      return false;
    }
    _setDiagnostics(
      _diagnostics.copyWith(lastSafeErrorCategory: 'none'),
      log: 'Notification permission requested',
    );
    late final NotificationSettings settings;
    try {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } on Object {
      _setDiagnostics(
        _diagnostics.copyWith(
          notificationPermission: 'Failed',
          lastSafeErrorCategory: 'notification_permission_failed',
        ),
        log: 'Notification permission request failed',
      );
      return false;
    }
    final permission = _permissionLabel(settings.authorizationStatus);
    _setDiagnostics(
      _diagnostics.copyWith(notificationPermission: permission),
      log: 'Notification permission result: $permission',
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await registerCurrentDevice();
    return true;
  }

  Future<void> registerCurrentDevice() async {
    final messaging = _messaging;
    if (!_firebaseAvailable ||
        messaging == null ||
        !SupabaseService.isEnabled) {
      return;
    }
    if (KaamAuthSessionCoordinator.blocksSessionRestore) return;
    if (SupabaseService.maybeClient?.auth.currentUser == null) return;
    try {
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _setDiagnostics(
          _diagnostics.copyWith(
            fcmRegistration: 'Not registered',
            supabaseDeviceRegistration: 'Inactive',
            lastSafeErrorCategory: 'fcm_token_missing',
          ),
          log: 'FCM token unavailable',
        );
        return;
      }
      _lastToken = token;
      _setDiagnostics(
        _diagnostics.copyWith(fcmRegistration: 'Registered'),
        log: 'FCM registration succeeded',
      );
      await _repository.registerDeviceToken(
        fcmToken: token,
        platform:
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      _setDiagnostics(
        _diagnostics.copyWith(
          supabaseDeviceRegistration: 'Active',
          lastSafeErrorCategory: 'none',
        ),
        log: 'Supabase device registration succeeded',
      );
    } on Object {
      _setDiagnostics(
        _diagnostics.copyWith(
          fcmRegistration: 'Failed',
          supabaseDeviceRegistration: 'Failed',
          lastSafeErrorCategory: 'device_registration_failed',
        ),
        log: 'Device registration failed',
      );
    }
  }

  Future<void> deactivateCurrentDevice() async {
    final messaging = _messaging;
    if (!_firebaseAvailable ||
        messaging == null ||
        !SupabaseService.isEnabled) {
      return;
    }
    try {
      final token = _lastToken ?? await messaging.getToken();
      await _repository.deactivateDeviceToken(token);
      _setDiagnostics(
        _diagnostics.copyWith(supabaseDeviceRegistration: 'Inactive'),
        log: 'Logout device deactivation requested',
      );
    } on Object {
      _setDiagnostics(
        _diagnostics.copyWith(
          lastSafeErrorCategory: 'device_deactivation_failed',
        ),
        log: 'Device deactivation failed',
      );
    }
  }

  Future<KaamPushDiagnosticsSnapshot> refreshDiagnostics() async {
    final messaging = _messaging;
    if (_firebaseAvailable && messaging != null) {
      try {
        final settings = await messaging.getNotificationSettings();
        _diagnostics = _diagnostics.copyWith(
          firebaseInitialized: true,
          notificationPermission: _permissionLabel(
            settings.authorizationStatus,
          ),
        );
      } on Object {
        _diagnostics = _diagnostics.copyWith(
          lastSafeErrorCategory: 'notification_settings_failed',
        );
      }
    }
    if (_firebaseAvailable && messaging != null && SupabaseService.isEnabled) {
      try {
        final token = _lastToken ?? await messaging.getToken();
        _lastToken = token;
        _diagnostics = _diagnostics.copyWith(
          fcmRegistration:
              token == null || token.isEmpty ? 'Not registered' : 'Registered',
        );
        final active = await _repository.currentDeviceActive(token);
        _diagnostics = _diagnostics.copyWith(
          supabaseDeviceRegistration: active == true
              ? 'Active'
              : active == false
                  ? 'Inactive'
                  : 'Inactive',
        );
      } on Object {
        _diagnostics = _diagnostics.copyWith(
          supabaseDeviceRegistration: 'Failed',
          lastSafeErrorCategory: 'diagnostics_refresh_failed',
        );
      }
    }
    return _diagnostics;
  }

  void _listenForAuthChanges() {
    final client = SupabaseService.maybeClient;
    final messaging = _messaging;
    if (client == null) return;
    if (messaging == null) return;
    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((state) async {
      _debugAuthEvent(state);
      if (KaamAuthSessionCoordinator.blocksSessionRestore) return;
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.initialSession) {
        await registerCurrentDevice();
        final pending = _pendingRoute;
        if (pending != null) {
          _pendingRoute = null;
          _navigateToSafeRoute(pending);
        }
      }
    });

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
      _lastToken = token;
      _setDiagnostics(
        _diagnostics.copyWith(fcmRegistration: 'Registered'),
        log: 'FCM token refresh received',
      );
      if (!KaamAuthSessionCoordinator.blocksSessionRestore &&
          SupabaseService.maybeClient?.auth.currentUser != null) {
        try {
          await _repository.registerDeviceToken(fcmToken: token);
          _setDiagnostics(
            _diagnostics.copyWith(supabaseDeviceRegistration: 'Active'),
            log: 'Supabase device registration updated',
          );
        } on Object {
          _setDiagnostics(
            _diagnostics.copyWith(
              supabaseDeviceRegistration: 'Failed',
              lastSafeErrorCategory: 'token_refresh_registration_failed',
            ),
            log: 'Token refresh device registration failed',
          );
        }
      }
    });
  }

  void _debugAuthEvent(AuthState state) {
    if (!kDebugMode) return;
    final user = state.session?.user;
    debugPrint(
      '[AuthState] event=${state.event.name} '
      'userIdPresent=${user?.id.isNotEmpty == true} '
      'email=${_maskedEmail(user?.email)}',
    );
  }

  String _maskedEmail(String? email) {
    final value = (email ?? '').trim();
    final at = value.indexOf('@');
    if (value.isEmpty || at <= 0) return 'none';
    final name = value.substring(0, at);
    final domain = value.substring(at + 1);
    final visible = name.length <= 2 ? name[0] : name.substring(0, 2);
    return '$visible***@$domain';
  }

  void _listenForMessages() {
    final messaging = _messaging;
    if (messaging == null) return;
    FirebaseMessaging.onMessage.listen((message) async {
      _setDiagnostics(
        _diagnostics.copyWith(lastPushReceived: 'Foreground'),
        log: 'Foreground push received',
      );
      final notification = message.notification;
      if (notification == null) return;
      final conversationId = message.data['conversation_id'] as String?;
      if (conversationId != null && conversationId == _activeConversationId) {
        return;
      }
      try {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelFor(message.data['type'] as String?),
              'KAAM notifications',
              channelDescription: 'Account, message, and verification updates.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: message.data['route'] as String?,
        );
      } on Object {
        _setDiagnostics(
          _diagnostics.copyWith(
            lastSafeErrorCategory: 'foreground_notification_failed',
          ),
          log: 'Foreground notification display failed',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }

  Future<void> _handleInitialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return;
    final message = await messaging.getInitialMessage();
    if (message != null) {
      _setDiagnostics(
        _diagnostics.copyWith(lastPushReceived: 'Terminated/opened'),
        log: 'Terminated notification tap received',
      );
      _navigateFromMessage(message);
    }
  }

  Future<void> _configureLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null) _navigateToSafeRoute(route);
      },
    );
  }

  Future<void> _createAndroidChannel() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in const [
      AndroidNotificationChannel('kaam_messages', 'Messages',
          description: 'Chat messages', importance: Importance.high),
      AndroidNotificationChannel('kaam_matches', 'Matches and interests',
          description: 'Matches and interests', importance: Importance.high),
      AndroidNotificationChannel('kaam_account', 'Account and documents',
          description: 'Account and document updates',
          importance: Importance.defaultImportance),
      AndroidNotificationChannel('kaam_announcements', 'Announcements',
          description: 'KAAM announcements',
          importance: Importance.defaultImportance),
    ]) {
      await android?.createNotificationChannel(channel);
    }
  }

  Future<void> _runOptionalStep(
    Future<void> Function() action, {
    required String category,
    required String log,
  }) async {
    try {
      await action();
    } on Object {
      _setDiagnostics(
        _diagnostics.copyWith(lastSafeErrorCategory: category),
        log: log,
      );
    }
  }

  void _runOptionalSyncStep(
    void Function() action, {
    required String category,
    required String log,
  }) {
    try {
      action();
    } on Object {
      _setDiagnostics(
        _diagnostics.copyWith(lastSafeErrorCategory: category),
        log: log,
      );
    }
  }

  void _navigateFromMessage(RemoteMessage message) {
    _setDiagnostics(
      _diagnostics.copyWith(lastPushReceived: 'Background/opened'),
      log: 'Notification tap received',
    );
    if (SupabaseService.maybeClient?.auth.currentUser == null) {
      _pendingRoute = message.data['route'] as String?;
      return;
    }
    final role = _roleFromCurrentRoute();
    final type = message.data['type'] as String? ?? '';
    final route = KaamNotificationDeepLinks.routeFor(
      role: role,
      type: type,
      actionRoute: message.data['route'] as String?,
    );
    _navigateToSafeRoute(route);
  }

  void _navigateToSafeRoute(String route) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _setDiagnostics(
        _diagnostics.copyWith(
          deepLinkResult: 'Failed',
          lastSafeErrorCategory: 'navigator_unavailable',
        ),
        log: 'Safe deep-link failed',
      );
      return;
    }
    final role = _roleFromCurrentRoute();
    final safeRoute = KaamNotificationDeepLinks.routeFor(
      role: role,
      type: '',
      actionRoute: route,
    );
    _setDiagnostics(
      _diagnostics.copyWith(
        deepLinkResult: safeRoute == route ? 'Opened' : 'Fallback',
        lastSafeErrorCategory: 'none',
      ),
      log:
          'Safe deep-link result: ${safeRoute == route ? 'Opened' : 'Fallback'}',
    );
    navigator.pushNamed(safeRoute);
  }

  KaamRole _roleFromCurrentRoute() {
    final context = navigatorKey.currentContext;
    if (context == null) return KaamRole.candidate;
    final name = ModalRoute.of(context)?.settings.name;
    if (name?.startsWith('/employer') == true) return KaamRole.employer;
    return KaamRole.candidate;
  }

  String _permissionLabel(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => 'Allowed',
      AuthorizationStatus.provisional => 'Allowed',
      AuthorizationStatus.denied => 'Denied',
      AuthorizationStatus.notDetermined => 'Not requested',
    };
  }

  String _channelFor(String? type) {
    if (type == 'new_message') return 'kaam_messages';
    if (type?.contains('match') == true || type?.contains('interest') == true) {
      return 'kaam_matches';
    }
    if (type?.contains('document') == true ||
        type?.contains('company') == true) {
      return 'kaam_account';
    }
    return 'kaam_announcements';
  }

  void _setDiagnostics(KaamPushDiagnosticsSnapshot snapshot, {String? log}) {
    _diagnostics = snapshot;
    if (kDebugMode && log != null) debugPrint('[Notifications][QA] $log');
  }
}

class KaamPushDiagnosticsSnapshot {
  const KaamPushDiagnosticsSnapshot({
    this.firebaseInitialized = false,
    this.notificationPermission = 'Not requested',
    this.fcmRegistration = 'Not registered',
    this.supabaseDeviceRegistration = 'Inactive',
    this.lastPushReceived = 'Not received',
    this.deepLinkResult = 'Not opened',
    this.lastSafeErrorCategory = 'none',
  });

  final bool firebaseInitialized;
  final String notificationPermission;
  final String fcmRegistration;
  final String supabaseDeviceRegistration;
  final String lastPushReceived;
  final String deepLinkResult;
  final String lastSafeErrorCategory;

  KaamPushDiagnosticsSnapshot copyWith({
    bool? firebaseInitialized,
    String? notificationPermission,
    String? fcmRegistration,
    String? supabaseDeviceRegistration,
    String? lastPushReceived,
    String? deepLinkResult,
    String? lastSafeErrorCategory,
  }) {
    return KaamPushDiagnosticsSnapshot(
      firebaseInitialized: firebaseInitialized ?? this.firebaseInitialized,
      notificationPermission:
          notificationPermission ?? this.notificationPermission,
      fcmRegistration: fcmRegistration ?? this.fcmRegistration,
      supabaseDeviceRegistration:
          supabaseDeviceRegistration ?? this.supabaseDeviceRegistration,
      lastPushReceived: lastPushReceived ?? this.lastPushReceived,
      deepLinkResult: deepLinkResult ?? this.deepLinkResult,
      lastSafeErrorCategory:
          lastSafeErrorCategory ?? this.lastSafeErrorCategory,
    );
  }

  String toSafeSummary() {
    return [
      'Firebase initialized: ${firebaseInitialized ? 'Yes' : 'No'}',
      'Notification permission: $notificationPermission',
      'FCM registration: $fcmRegistration',
      'Supabase device registration: $supabaseDeviceRegistration',
      'Last push received: $lastPushReceived',
      'Deep-link result: $deepLinkResult',
      'Last safe error category: $lastSafeErrorCategory',
    ].join('\n');
  }
}
