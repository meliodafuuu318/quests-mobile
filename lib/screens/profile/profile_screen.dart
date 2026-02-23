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
        leading: _isSelf ? null : IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isSelf)
            IconButton(
              icon: const Icon(Icons.logout_outlined, size: 20),
              onPressed: () => context.read<AuthProvider>().logout(),
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
                    child: _ProfileHeader(user: _user!, isSelf: _isSelf, onSendRequest: () async {
                      final res = await ApiService.sendFriendRequest(_user!['username']);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? ''),
                        backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ));
                    }),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: SectionHeader(title: 'Posts (${_posts.length})')),
                  ),
                  if (_posts.isEmpty)
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('No posts yet.', style: AppTheme.label(color: AppTheme.textMuted, size: 13))))
                  else
                    SliverList(delegate: SliverChildBuilderDelegate((_, i) => _MiniPostCard(post: _posts[i]), childCount: _posts.length)),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ]),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelf;
  final VoidCallback onSendRequest;
  const _ProfileHeader({required this.user, required this.isSelf, required this.onSendRequest});

  @override
  Widget build(BuildContext context) {
    final username = user['username'] ?? '';
    final firstName = user['first_name'] ?? '';
    final lastName = user['last_name'] ?? '';
    final exp = (user['exp'] ?? 0).toDouble();
    final level = user['level'] ?? 1;
    final bio = user['bio'];
    final city = user['city'];
    final country = user['country'];
    final maxExp = (level * 1000).toDouble();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(username: username, size: 72),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firstName $lastName', style: AppTheme.label(color: AppTheme.textPrimary, size: 18, weight: FontWeight.w700)),
            Text('@$username', style: AppTheme.label(color: AppTheme.textMuted, size: 13)),
            if (city != null || country != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: AppTheme.textMuted, size: 13),
                const SizedBox(width: 3),
                Text([city, country].where((e) => e != null).join(', '), style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
              ]),
            ],
          ])),
        ]),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(bio, style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
        ],
        const SizedBox(height: 20),
        XpBar(current: exp, max: maxExp, level: level),
        const SizedBox(height: 20),
        if (!isSelf) ...[
          SizedBox(width: double.infinity, child: GlowButton(label: 'SEND FRIEND REQUEST', onPressed: onSendRequest, outlined: true, color: AppTheme.cyan, icon: Icons.person_add_outlined)),
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
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post['title'] ?? 'Untitled', style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
        if (post['content'] != null && post['content'].isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(post['content'], maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.label(color: AppTheme.textSecondary, size: 12)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.access_time_outlined, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(post['datetime'] ?? '', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
        ]),
      ]),
    );
  }
}