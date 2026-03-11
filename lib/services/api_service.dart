import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.54.172.88:8000/api';

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static bool    get isLoggedIn => _token != null && _token!.isNotEmpty;
  static String? get token      => _token;

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Map<String, String> get _authHeaders => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _post(String p, Map<String, dynamic> b) async {
    final r = await http.post(Uri.parse('$baseUrl$p'), headers: _jsonHeaders, body: jsonEncode(b));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _get(String p) async {
    final r = await http.get(Uri.parse('$baseUrl$p'), headers: _jsonHeaders);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(String p, Map<String, dynamic> b) async {
    final r = await http.put(Uri.parse('$baseUrl$p'), headers: _jsonHeaders, body: jsonEncode(b));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _delete(String p, Map<String, dynamic> b) async {
    final r = await http.delete(Uri.parse('$baseUrl$p'), headers: _jsonHeaders, body: jsonEncode(b));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Multipart POST — for endpoints that accept files alongside fields.
  static Future<Map<String, dynamic>> _multipartPost(
    String path,
    Map<String, String> fields,
    List<XFile> mediaFiles,
  ) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    req.headers.addAll(_authHeaders);
    req.fields.addAll(fields);

    for (int i = 0; i < mediaFiles.length; i++) {
      final f    = mediaFiles[i];
      final file = File(f.path);
      final mime = f.mimeType ?? _guessMime(f.path);
      req.files.add(await http.MultipartFile.fromPath(
        'media[]',  // Laravel expects media[]
        file.path,
        contentType: _parseMediaType(mime),
      ));
    }

    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _guessMime(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'mov') return 'video/quicktime';
    return 'application/octet-stream';
  }

  static http.MediaType _parseMediaType(String mime) {
    final parts = mime.split('/');
    return http.MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream');
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String username, required String email, required String password,
    required String firstName, required String lastName,
  }) => _post('/auth/register', {
    'username': username, 'email': email, 'password': password,
    'firstName': firstName, 'lastName': lastName, 'role': 'USER',
  });

  static Future<Map<String, dynamic>> login({required String username, required String password}) =>
      _post('/auth/login', {'username': username, 'password': password});

  static Future<Map<String, dynamic>> logout() => _post('/auth/logout', {});

  // ─── FEED (page-based pagination) ────────────────────────────────────────
  static Future<Map<String, dynamic>> getFeed({int page = 1, int perPage = 10}) =>
      _get('/post?page=$page&per_page=$perPage');

  static Future<Map<String, dynamic>> getDiscoveryPosts({int page = 1, int perPage = 5}) =>
      _get('/post?discovery=1&page=$page&per_page=$perPage');

  static Future<Map<String, dynamic>> getPost(String id) => _get('/post/show?postId=$id');

  // Creates a post — sends as multipart when media files are attached
  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    required String visibility,
    required int rewardExp,
    required int rewardPoints,
    required List<Map<String, dynamic>> tasks,
    List<XFile> mediaFiles = const [],
  }) async {
    final fields = {
      'type': 'post',
      'title': title,
      'content': content,
      'visibility': visibility,
      'rewardExp': rewardExp.toString(),
      'rewardPoints': rewardPoints.toString(),
    };

    // Serialize tasks as indexed form fields (Laravel array parsing)
    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      fields['tasks[$i][title]']        = t['title'].toString();
      fields['tasks[$i][description]']  = t['description'].toString();
      fields['tasks[$i][rewardExp]']    = t['rewardExp'].toString();
      fields['tasks[$i][rewardPoints]'] = t['rewardPoints'].toString();
      fields['tasks[$i][order]']        = t['order'].toString();
    }

    if (mediaFiles.isEmpty) {
      // Pure JSON path (no media)
      return _post('/post', {
        'type': 'post', 'title': title, 'content': content,
        'visibility': visibility, 'rewardExp': rewardExp, 'rewardPoints': rewardPoints,
        'tasks': tasks,
      });
    }

    return _multipartPost('/post', fields, mediaFiles);
  }

  static Future<Map<String, dynamic>> deletePost(String id) =>
      _delete('/post/delete', {'postId': id});

  static Future<Map<String, dynamic>> getPostComments(String id) =>
      _get('/post/comments?postId=$id');

  /// React returns {error, results: {likes_count, liked}}
  static Future<Map<String, dynamic>> react(String likeTarget) =>
      _post('/react', {'type': 'like', 'likeTarget': likeTarget});

  // ─── COMMENTS ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createComment({
    required String target,
    required String content,
    List<XFile> mediaFiles = const [],
  }) {
    if (mediaFiles.isEmpty) {
      return _post('/comment/create', {
        'type': 'comment',
        'commentTarget': target,
        'content': content,
      });
    }
    return _multipartPost('/comment/create', {
      'type': 'comment',
      'commentTarget': target,
      'content': content,
    }, mediaFiles);
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────
  /// Fetch paginated notifications. Returns {notifications: {data:[...]}, unread_count: N}
  static Future<Map<String, dynamic>> getNotifications() =>
      _get('/notifications');

  /// Mark read: pass notificationId for single, or all=true for all.
  static Future<Map<String, dynamic>> markNotificationRead({
    int? notificationId,
    bool all = false,
  }) => _post('/notifications/read', {
    if (all) 'all': true,
    if (notificationId != null) 'notificationId': notificationId,
  });

  // ─── QUESTS ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> joinQuest(String code)     => _post('/quest/join',         {'questCode': code});
  static Future<Map<String, dynamic>> completeQuest(String id)   => _post('/quest/complete',      {'questId': id});
  static Future<Map<String, dynamic>> completeTask(String id)    => _post('/quest/task/complete', {'taskId': id});

  // ─── USER ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAccountInfo()              => _get('/user/account-info');
  static Future<Map<String, dynamic>> getUserPosts(String username) => _get('/user/posts?username=$username');
  static Future<Map<String, dynamic>> showUser(String username)     => _get('/user/show?username=$username');
  static Future<Map<String, dynamic>> searchUsers(String q)        => _get('/user/search?name=${Uri.encodeComponent(q)}');
  static Future<Map<String, dynamic>> editAccountInfo(Map<String, dynamic> d) => _put('/user/account-info', d);

  // ─── FRIENDS ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getFriends()                  => _get('/user/friend');
  static Future<Map<String, dynamic>> getFriendRequests()           => _get('/user/friend/requests');
  static Future<Map<String, dynamic>> sendFriendRequest(String u)   => _post('/user/friend/send',  {'username': u});
  static Future<Map<String, dynamic>> acceptFriendRequest(String u) => _put('/user/friend/accept', {'username': u});
}