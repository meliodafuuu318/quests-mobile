import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your Laravel backend URL
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─── AUTH ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String role = 'USER',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> logout() async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ─── POSTS / FEED ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeed() async {
    final res = await http.get(Uri.parse('$baseUrl/post'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    required String visibility,
    required int rewardExp,
    required int rewardPoints,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/post'),
      headers: _headers,
      body: jsonEncode({
        'type': 'post',
        'title': title,
        'content': content,
        'visibility': visibility,
        'rewardExp': rewardExp,
        'rewardPoints': rewardPoints,
        'tasks': tasks,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPost(String postId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/post/show?postId=$postId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deletePost(String postId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/post/delete'),
      headers: _headers,
      body: jsonEncode({'postId': postId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPostComments(String postId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/post/comments?postId=$postId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> react(String likeTarget) async {
    final res = await http.post(
      Uri.parse('$baseUrl/react'),
      headers: _headers,
      body: jsonEncode({'type': 'like', 'likeTarget': likeTarget}),
    );
    return jsonDecode(res.body);
  }

  // ─── COMMENTS ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createComment({
    required String commentTarget,
    required String content,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/comment/create'),
      headers: _headers,
      body: jsonEncode({
        'type': 'comment',
        'commentTarget': commentTarget,
        'content': content,
      }),
    );
    return jsonDecode(res.body);
  }

  // ─── QUESTS ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> joinQuest(String questCode) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quest/join'),
      headers: _headers,
      body: jsonEncode({'questCode': questCode}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> completeQuest(String questId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quest/complete'),
      headers: _headers,
      body: jsonEncode({'questId': questId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> completeTask(String taskId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quest/task/complete'),
      headers: _headers,
      body: jsonEncode({'taskId': taskId}),
    );
    return jsonDecode(res.body);
  }

  // ─── USER ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAccountInfo() async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/account-info'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getUserPosts(String username) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/posts?username=$username'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> showUser(String username) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/show?username=$username'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> searchUsers(String name) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/search?name=${Uri.encodeComponent(name)}'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> editAccountInfo(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/user/account-info'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  // ─── FRIENDS ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFriends() async {
    final res = await http.get(Uri.parse('$baseUrl/user/friend'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFriendRequests() async {
    final res = await http.get(Uri.parse('$baseUrl/user/friend/requests'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendFriendRequest(String username) async {
    final res = await http.post(
      Uri.parse('$baseUrl/user/friend/send'),
      headers: _headers,
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(String username) async {
    final res = await http.put(
      Uri.parse('$baseUrl/user/friend/accept'),
      headers: _headers,
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(res.body);
  }
}