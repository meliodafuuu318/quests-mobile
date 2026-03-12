import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

// ─── CHANGE THESE to match your Pusher dashboard ────────────────────────────
const String kPusherKey     = 'YOUR_PUSHER_APP_KEY';
const String kPusherCluster = 'YOUR_PUSHER_CLUSTER'; // e.g. 'ap1', 'us2'
const String kPusherAuthUrl = 'http://192.168.10.252:8000/broadcasting/auth';
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String type;   // 'new_post' | 'new_comment'
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  bool read;
  final DateTime time;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    this.read = false,
    required this.time,
  });
}

class PusherService extends ChangeNotifier {
  PusherService._();
  static final PusherService instance = PusherService._();

  PusherChannelsFlutter? _pusher;
  bool _connected = false;
  String? _userId;
  String? _authToken;

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // Server-driven unread count (synced from DB on panel open).
  int _serverUnread = 0;
  int get unreadCount => _serverUnread + _notifications.where((n) => !n.read).length;

  void setUnreadCount(int count) { _serverUnread = count; notifyListeners(); }
  void decrementUnread() { if (_serverUnread > 0) { _serverUnread--; notifyListeners(); } }
  void clearAllRead() { _serverUnread = 0; for (final n in _notifications) n.read = true; notifyListeners(); }

  // Feed callback — called when a new public/friends post arrives
  VoidCallback? onNewPostAvailable;

  // Post-level callbacks — keyed by postId, set by PostDetailScreen
  final Map<String, VoidCallback> _commentListeners = {};
  final Map<String, void Function(String, int)> _reactListeners = {};

  // Profile callback — keyed by username
  final Map<String, VoidCallback> _profileListeners = {};

  // ── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect({required String userId, required String authToken}) async {
    if (_connected) return;
    _userId   = userId;
    _authToken = authToken;

    try {
      _pusher = PusherChannelsFlutter.getInstance();
      await _pusher!.init(
        apiKey: kPusherKey,
        cluster: kPusherCluster,
        authEndpoint: kPusherAuthUrl,
        onConnectionStateChange: (curr, prev) {
          _connected = curr == 'CONNECTED';
          debugPrint('[Pusher] $prev → $curr');
        },
        onError: (msg, code, err) => debugPrint('[Pusher] err $code: $msg'),
        onAuthorizer: (channelName, socketId, options) async {
          // Return auth headers — Laravel Echo will handle the rest
          return {'Authorization': 'Bearer $authToken'};
        },
      );

      await _pusher!.connect();

      // Public feed channel
      await _subscribe('feed');

      // Private user channel for personal notifications
      await _subscribe('private-user.$userId');

    } catch (e) {
      debugPrint('[Pusher] connect error: $e');
    }
  }

  // ── Subscribe to a post channel (called by PostDetailScreen) ─────────────

  Future<void> watchPost(String postId) async {
    await _subscribe('post.$postId');
  }

  Future<void> unwatchPost(String postId) async {
    try { await _pusher?.unsubscribe(channelName: 'post.$postId'); } catch (_) {}
    _commentListeners.remove(postId);
    _reactListeners.remove(postId);
  }

  void onComment(String postId, VoidCallback cb) => _commentListeners[postId] = cb;
  void onReact(String postId, void Function(String postId, int count) cb) => _reactListeners[postId] = cb;

  // ── Subscribe to a user profile channel ──────────────────────────────────

  Future<void> watchProfile(String username) async {
    await _subscribe('profile.$username');
    // store listener slot — caller will register via onProfileUpdate
  }

  Future<void> unwatchProfile(String username) async {
    try { await _pusher?.unsubscribe(channelName: 'profile.$username'); } catch (_) {}
    _profileListeners.remove(username);
  }

  void onProfileUpdate(String username, VoidCallback cb) => _profileListeners[username] = cb;

  // ── Internal subscribe ────────────────────────────────────────────────────

  Future<void> _subscribe(String channel) async {
    if (_pusher == null) return;
    try {
      await _pusher!.subscribe(channelName: channel, onEvent: _onEvent);
    } catch (e) {
      debugPrint('[Pusher] subscribe $channel error: $e');
    }
  }

  void _onEvent(PusherEvent event) {
    debugPrint('[Pusher] ${event.channelName} → ${event.eventName}');
    Map<String, dynamic> data = {};
    try { data = jsonDecode(event.data ?? '{}') as Map<String, dynamic>; } catch (_) {}

    final eventName = event.eventName;
    final channel   = event.channelName ?? '';

    // ── New post on the public feed ─────────────────────────────────────
    if (eventName == 'App\\Events\\NewPost' || eventName == 'new-post') {
      onNewPostAvailable?.call();

      // Notify if friend posted with friends visibility
      final isFriend     = data['is_friend'] == true;
      final visibility   = data['visibility']?.toString() ?? 'public';
      if (isFriend && visibility == 'friends') {
        _addNotification(AppNotification(
          id:      _uid(),
          type:    'new_post',
          title:   '${data['username'] ?? 'A friend'} posted a new quest',
          body:    data['title']?.toString() ?? '',
          payload: data,
          time:    DateTime.now(),
        ));
      }
      return;
    }

    // ── New comment on a post ───────────────────────────────────────────
    if (eventName == 'App\\Events\\NewComment' || eventName == 'new-comment') {
      final postId = data['post_id']?.toString() ?? '';
      _commentListeners[postId]?.call();

      // Notify the post owner
      final ownerId = data['post_owner_id']?.toString() ?? '';
      if (ownerId == _userId) {
        _addNotification(AppNotification(
          id:      _uid(),
          type:    'new_comment',
          title:   '${data['username'] ?? 'Someone'} commented on your post',
          body:    data['content']?.toString() ?? '',
          payload: data,
          time:    DateTime.now(),
        ));
      }
      return;
    }

    // ── React updated ───────────────────────────────────────────────────
    if (eventName == 'App\\Events\\NewReact' || eventName == 'new-react') {
      final postId = data['post_id']?.toString() ?? '';
      final count  = _toInt(data['likes_count']);
      _reactListeners[postId]?.call(postId, count);
      return;
    }

    // ── Profile updated ─────────────────────────────────────────────────
    if (eventName == 'App\\Events\\ProfileUpdated' || eventName == 'profile-updated') {
      final username = data['username']?.toString() ?? '';
      _profileListeners[username]?.call();
      return;
    }
  }

  void _addNotification(AppNotification n) {
    _notifications.insert(0, n);
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) { _notifications[idx].read = true; notifyListeners(); }
  }

  void markAllRead() {
    for (final n in _notifications) n.read = true;
    notifyListeners();
  }

  Future<void> disconnect() async {
    try { await _pusher?.disconnect(); } catch (_) {}
    _connected = false;
    _pusher    = null;
    _commentListeners.clear();
    _reactListeners.clear();
    _profileListeners.clear();
  }

  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}