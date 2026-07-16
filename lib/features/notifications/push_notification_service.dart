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
    RemoteMessage message) async {
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

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _repository = const KaamNotificationRepository();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _firebaseAvailable = false;
  String? _lastToken;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[Notifications] Firebase unavailable: $error');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
        kaamFirebaseMessagingBackgroundHandler);
    await _configureLocalNotifications();
    await _createAndroidChannel();
    _listenForMessages();
    _listenForAuthChanges();
    await _handleInitialMessage();
  }

  Future<bool> requestPermissionAndRegister() async {
    if (!_firebaseAvailable || !SupabaseService.isEnabled) return false;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await registerCurrentDevice();
    return true;
  }

  Future<void> registerCurrentDevice() async {
    if (!_firebaseAvailable || !SupabaseService.isEnabled) return;
    if (SupabaseService.maybeClient?.auth.currentUser == null) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    _lastToken = token;
    await _repository.registerDeviceToken(fcmToken: token);
  }

  Future<void> deactivateCurrentDevice() async {
    if (!_firebaseAvailable || !SupabaseService.isEnabled) return;
    final token = _lastToken ?? await _messaging.getToken();
    await _repository.deactivateDeviceToken(token);
  }

  void _listenForAuthChanges() {
    final client = SupabaseService.maybeClient;
    if (client == null) return;
    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.initialSession) {
        await registerCurrentDevice();
      }
    });

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      _lastToken = token;
      if (SupabaseService.maybeClient?.auth.currentUser != null) {
        await _repository.registerDeviceToken(fcmToken: token);
      }
    });
  }

  void _listenForMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kaam_notifications',
            'Kaam notifications',
            channelDescription: 'Account, message, and verification updates.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['route'] as String?,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }

  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) _navigateFromMessage(message);
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
    const channel = AndroidNotificationChannel(
      'kaam_notifications',
      'Kaam notifications',
      description: 'Account, message, and verification updates.',
      importance: Importance.high,
    );
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  void _navigateFromMessage(RemoteMessage message) {
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
    if (navigator == null) return;
    final role = _roleFromCurrentRoute();
    final safeRoute = KaamNotificationDeepLinks.routeFor(
      role: role,
      type: '',
      actionRoute: route,
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
}
