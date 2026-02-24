import '../auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _posts = [];
  bool _loading = true;
  bool get _isSelf => widget.username == null;

  @override
  void initState() { super.initState(); _load(); }

  // Safely parse any numeric value from JSON (could be int, double, or String)
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 1;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 1;
  }

  Future<void> _load() async {
    try {
      if (_isSelf) {
        final res = await ApiService.getAccountInfo();
        if (res['error'] == false) {
          _user = res['results'];
          final postsRes = await ApiService.getUserPosts(_user!['username']);
          _posts = postsRes['error'] == false ? (postsRes['results'] ?? []) : [];
        }
      } else {
        final res = await ApiService.showUser(widget.username!);
        if (res['error'] == false) {
          _user = res['results'];
          final postsRes = await ApiService.getUserPosts(widget.username!);
          _posts = postsRes['error'] == false ? (postsRes['results'] ?? []) : [];
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelf ? 'PROFILE' : '@${widget.username ?? ''}'),
        leading: _isSelf
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isSelf)
            IconButton(
              icon: const Icon(Icons.logout_outlined, size: 20),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              color: AppTheme.rose,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _user == null
              ? Center(child: Text('User not found', style: AppTheme.label(color: AppTheme.textMuted)))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      user: _user!,
                      isSelf: _isSelf,
                      toDouble: _toDouble,
                      toInt: _toInt,
                      onSendRequest: () async {
                        final res = await ApiService.sendFriendRequest(_user!['username']);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(res['message'] ?? ''),
                          backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ));
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SectionHeader(title: 'Posts (${_posts.length})'),
                    ),
                  ),
                  if (_posts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('No posts yet.', style: AppTheme.label(color: AppTheme.textMuted, size: 13)),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _MiniPostCard(post: _posts[i]),
                        childCount: _posts.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ]),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelf;
  final VoidCallback onSendRequest;
  final double Function(dynamic) toDouble;
  final int Function(dynamic) toInt;

  const _ProfileHeader({
    required this.user,
    required this.isSelf,
    required this.onSendRequest,
    required this.toDouble,
    required this.toInt,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username']?.toString() ?? '';
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final exp = toDouble(user['exp']);
    final level = toInt(user['level']);
    final bio = user['bio']?.toString();
    final city = user['city']?.toString();
    final country = user['country']?.toString();
    final maxExp = (level * 1000).toDouble();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(username: username, size: 68),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName',
              style: AppTheme.label(color: AppTheme.textPrimary, size: 17, weight: FontWeight.w700),
            ),
            Text('@$username', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
            if (city != null || country != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: AppTheme.textMuted, size: 12),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    [city, country].where((e) => e != null && e.isNotEmpty).join(', '),
                    style: AppTheme.label(color: AppTheme.textMuted, size: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
          ])),
        ]),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio, style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
        ],
        const SizedBox(height: 20),
        XpBar(current: exp, max: maxExp, level: level),
        const SizedBox(height: 20),
        if (!isSelf) ...[
          SizedBox(
            width: double.infinity,
            child: GlowButton(
              label: 'SEND FRIEND REQUEST',
              onPressed: onSendRequest,
              outlined: true,
              color: AppTheme.cyan,
              icon: Icons.person_add_outlined,
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Divider(color: AppTheme.border),
      ]),
    );
  }
}

class _MiniPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _MiniPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          post['title']?.toString() ?? 'Untitled',
          style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600),
        ),
        if (post['content'] != null && post['content'].toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            post['content'].toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.label(color: AppTheme.textSecondary, size: 12),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.access_time_outlined, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(post['datetime']?.toString() ?? '', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
        ]),
      ]),
    );
  }
}