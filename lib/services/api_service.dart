import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 10.0.2.2 = localhost from Android emulator
  // Change to your PC's local IP (e.g. 192.168.1.x) for physical device
  static const String baseUrl = 'http://10.54.172.9:8000/api';

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

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> _safePost(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _safeGet(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _safePut(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _safeDelete(String path, Map<String, dynamic> body) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String username, required String email, required String password,
    required String firstName, required String lastName, String role = 'USER',
  }) => _safePost('/auth/register', {
    'username': username, 'email': email, 'password': password,
    'firstName': firstName, 'lastName': lastName, 'role': role,
  });

  static Future<Map<String, dynamic>> login({required String username, required String password}) =>
      _safePost('/auth/login', {'username': username, 'password': password});

  static Future<Map<String, dynamic>> logout() =>
      _safePost('/auth/logout', {});

  // ─── FEED ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeed() => _safeGet('/post');

  static Future<Map<String, dynamic>> getPost(String postId) => _safeGet('/post/show?postId=$postId');

  static Future<Map<String, dynamic>> createPost({
    required String title, required String content, required String visibility,
    required int rewardExp, required int rewardPoints, required List<Map<String, dynamic>> tasks,
  }) => _safePost('/post', {
    'type': 'post', 'title': title, 'content': content, 'visibility': visibility,
    'rewardExp': rewardExp, 'rewardPoints': rewardPoints, 'tasks': tasks,
  });

  static Future<Map<String, dynamic>> deletePost(String postId) =>
      _safeDelete('/post/delete', {'postId': postId});

  static Future<Map<String, dynamic>> getPostComments(String postId) =>
      _safeGet('/post/comments?postId=$postId');

  static Future<Map<String, dynamic>> getPostReacts(String postId) =>
      _safeGet('/post/reacts?postId=$postId');

  static Future<Map<String, dynamic>> react(String likeTarget) =>
      _safePost('/react', {'type': 'like', 'likeTarget': likeTarget});

  // ─── COMMENTS ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createComment({required String commentTarget, required String content}) =>
      _safePost('/comment/create', {'type': 'comment', 'commentTarget': commentTarget, 'content': content});

  // ─── QUESTS ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> joinQuest(String questCode) =>
      _safePost('/quest/join', {'questCode': questCode});

  static Future<Map<String, dynamic>> completeQuest(String questId) =>
      _safePost('/quest/complete', {'questId': questId});

  static Future<Map<String, dynamic>> completeTask(String taskId) =>
      _safePost('/quest/task/complete', {'taskId': taskId});

  // ─── USER ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAccountInfo() => _safeGet('/user/account-info');

  static Future<Map<String, dynamic>> getUserPosts(String username) =>
      _safeGet('/user/posts?username=$username');

  static Future<Map<String, dynamic>> showUser(String username) =>
      _safeGet('/user/show?username=$username');

  static Future<Map<String, dynamic>> searchUsers(String name) =>
      _safeGet('/user/search?name=${Uri.encodeComponent(name)}');

  static Future<Map<String, dynamic>> editAccountInfo(Map<String, dynamic> data) =>
      _safePut('/user/account-info', data);

  // ─── FRIENDS ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFriends() => _safeGet('/user/friend');

  static Future<Map<String, dynamic>> getFriendRequests() => _safeGet('/user/friend/requests');

  static Future<Map<String, dynamic>> sendFriendRequest(String username) =>
      _safePost('/user/friend/send', {'username': username});

  static Future<Map<String, dynamic>> acceptFriendRequest(String username) =>
      _safePut('/user/friend/accept', {'username': username});
}