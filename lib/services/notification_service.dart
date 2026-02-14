import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

/// Service for handling push notifications
class NotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  NotificationService(this._ref);

  /// Initialize Firebase Messaging and request permissions
  Future<void> initialize(String? userId) async {
    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen((token) {
          _saveToken(token);
        });

        // Get and store FCM token
        await _getAndStoreToken();

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Get FCM token and store it in Firestore
  Future<String?> _getAndStoreToken() async {
    try {
      debugPrint('Fetching FCM token...');
      // VAPID key is required for Web FCM - using a generic placeholder or actual if available
      // For Production, this should be the webPush certificate key from Firebase Console
      const vapidKey = 'BPlK6cM97uK4jS_R5Z9W_m_M_P_Y_V_M_P_W_P_K_P_S_P_W_P_M'; 
      
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? vapidKey : null,
      );
      
      if (token != null) {
        debugPrint('FCM Token obtained successfully');
        await _saveToken(token);
      } else {
        debugPrint('FCM Token is null - this usually means user denied permission or service worker missing');
      }
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      await _ref.read(firebaseServiceProvider).updateUserDeviceToken(token);
      debugPrint('FCM Token stored in Firestore');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');
    // Logic to show local notification or update UI
  }

  /// Subscribe to a topic (e.g., 'announcements')
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}
