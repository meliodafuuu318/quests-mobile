import '../auth/login_screen.dart';
import '../feed/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/pusher_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  List<dynamic> _posts = [];
  bool _loading = true;
  late TabController _tabs;

  bool get _isSelf => widget.username == null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    if (_isSelf) _syncNotificationCount();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _syncNotificationCount() async {
    try {
      final res = await ApiService.getNotifications();
      if (res['error'] == false) {
        final unread = res['results']?['unread_count'];
        if (unread != null && mounted) {
          PusherService.instance.setUnreadCount(_toInt(unread));
        }
      }
    } catch (_) {}
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _load() async {
    try {
      if (_isSelf) {
        final res = await ApiService.getAccountInfo();
        if (res['error'] == false) {
          _user = res['results'];
          final postsRes = await ApiService.getUserPosts(_user!['username']);
          _posts =
              postsRes['error'] == false ? (postsRes['results'] ?? []) : [];
        }
      } else {
        final res = await ApiService.showUser(widget.username!);
        if (res['error'] == false) {
          _user = res['results'];
          final postsRes = await ApiService.getUserPosts(widget.username!);
          _posts =
              postsRes['error'] == false ? (postsRes['results'] ?? []) : [];
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
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_isSelf) ...[
            const NotificationBell(),
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _user == null
              ? Center(
                  child: Text('User not found',
                      style: AppTheme.label(color: AppTheme.textMuted)))
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [
                    SliverToBoxAdapter(
                      child: _ProfileHeader(
                        user: _user!,
                        isSelf: _isSelf,
                        toDouble: _toDouble,
                        toInt: _toInt,
                        onSendRequest: () async {
                          final res = await ApiService.sendFriendRequest(
                              _user!['username']);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(res['message'] ?? ''),
                            backgroundColor: res['error'] == false
                                ? AppTheme.cyan
                                : AppTheme.rose,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ));
                        },
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabDelegate(
                        TabBar(
                          controller: _tabs,
                          labelColor: AppTheme.gold,
                          unselectedLabelColor: AppTheme.textMuted,
                          indicatorColor: AppTheme.gold,
                          indicatorWeight: 2,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          tabs: [
                            Tab(text: 'POSTS (${_posts.length})'),
                            Tab(
                              text:
                                  'QUESTS (${(_user!['quests'] as List? ?? []).length})',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabs,
                    children: [
                      _PostsTab(posts: _posts),
                      _QuestsTab(
                        quests: (_user!['quests'] as List? ?? [])
                            .cast<Map<String, dynamic>>(),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── TAB BAR DELEGATE ────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.bg,
      child: Column(children: [
        tabBar,
        const Divider(height: 1, color: AppTheme.border),
      ]),
    );
  }

  @override
  bool shouldRebuild(_TabDelegate old) => false;
}

// ─── PROFILE HEADER ──────────────────────────────────────────────────────────

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
    final username  = user['username']?.toString() ?? '';
    final firstName = user['first_name']?.toString() ?? '';
    final lastName  = user['last_name']?.toString() ?? '';
    final exp       = toDouble(user['exp']);
    final level     = toInt(user['level']);
    final bio       = user['bio']?.toString();
    final city      = user['city']?.toString();
    final country   = user['country']?.toString();
    final avatarUrl = user['avatar_url']?.toString();
    final maxExp    = (level * 1000).toDouble();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // ── Avatar — uses server image when available ──────────────────
          UserAvatar(username: username, size: 68, avatarUrl: avatarUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '$firstName $lastName'.trim().isEmpty
                    ? username
                    : '$firstName $lastName',
                style: AppTheme.label(
                    color: AppTheme.textPrimary,
                    size: 17,
                    weight: FontWeight.w700),
              ),
              Text('@$username',
                  style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
              if (city != null || country != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppTheme.textMuted, size: 12),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      [city, country]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(', '),
                      style: AppTheme.label(color: AppTheme.textMuted, size: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio,
              style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
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

// ─── POSTS TAB ───────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List<dynamic> posts;
  const _PostsTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
          child: Text('No posts yet.',
              style: AppTheme.label(color: AppTheme.textMuted, size: 13)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: posts.length,
      itemBuilder: (_, i) => _MiniPostCard(post: posts[i]),
    );
  }
}

// ─── QUESTS TAB ──────────────────────────────────────────────────────────────

class _QuestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> quests;
  const _QuestsTab({required this.quests});

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 40),
          const SizedBox(height: 12),
          Text('No quests joined yet.',
              style: AppTheme.label(color: AppTheme.textMuted)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: quests.length,
      itemBuilder: (_, i) => _QuestCard(quest: quests[i]),
    );
  }
}

// ─── QUEST CARD ──────────────────────────────────────────────────────────────

class _QuestCard extends StatefulWidget {
  final Map<String, dynamic> quest;
  const _QuestCard({required this.quest});

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard> {
  bool _expanded = false;

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed':        return AppTheme.cyan;
      case 'community_verified': return AppTheme.violet;
      case 'submitted':        return AppTheme.gold;
      case 'flagged':          return AppTheme.rose;
      default:                 return AppTheme.textMuted;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'completed':        return Icons.check_circle_outline;
      case 'community_verified': return Icons.verified_outlined;
      case 'submitted':        return Icons.upload_outlined;
      case 'flagged':          return Icons.flag_outlined;
      default:                 return Icons.radio_button_unchecked;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'completed':        return 'COMPLETED';
      case 'community_verified': return 'VERIFIED';
      case 'submitted':        return 'SUBMITTED';
      case 'flagged':          return 'FLAGGED';
      default:                 return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest       = widget.quest;
    final tasks       = (quest['quest_tasks'] as List? ?? []).cast<Map<String, dynamic>>();
    final completedAt = quest['completed_at'];
    final isCompleted = completedAt != null;
    final postId      = quest['post_id']?.toString(); // ← for navigation

    final completedTasks =
        tasks.where((t) => t['completion_status'] == 'completed').length;
    final totalTasks = tasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? AppTheme.cyan.withOpacity(0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header (tap to expand) ────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Quest code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    quest['code']?.toString() ?? '—',
                    style: AppTheme.label(color: AppTheme.textMuted, size: 10),
                  ),
                ),
                const Spacer(),
                if (isCompleted)
                  _StatusPill('QUEST DONE', AppTheme.cyan)
                else
                  Text('$completedTasks/$totalTasks tasks',
                      style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted, size: 18,
                ),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              if (totalTasks > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: completedTasks / totalTasks,
                    backgroundColor: AppTheme.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(children: [
                StatBadge(
                  label: 'EXP', value: '+${quest['reward_exp'] ?? 0}',
                  color: AppTheme.gold, icon: Icons.auto_awesome,
                ),
                const SizedBox(width: 8),
                StatBadge(
                  label: 'PTS', value: '+${quest['reward_points'] ?? 0}',
                  color: AppTheme.violet, icon: Icons.diamond_outlined,
                ),
                if (quest['joined_at'] != null) ...[
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(quest['joined_at'].toString()),
                      style: AppTheme.label(color: AppTheme.textMuted, size: 10),
                    ),
                  ]),
                ],
              ]),
            ]),
          ),
        ),

        // ── "View Post" button ─────────────────────────────────────────
        // Only shown when post_id is available.
        if (postId != null && postId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postId: postId)),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.violetDim,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.violet.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new_outlined,
                        color: AppTheme.violet, size: 14),
                    const SizedBox(width: 7),
                    Text('VIEW QUEST POST',
                        style: AppTheme.mono(color: AppTheme.violet, size: 11)),
                  ],
                ),
              ),
            ),
          ),

        // ── Task list (expandable) ────────────────────────────────────
        if (_expanded && tasks.isNotEmpty) ...[
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TASKS',
                  style: AppTheme.mono(color: AppTheme.textMuted, size: 10)),
              const SizedBox(height: 10),
              ...tasks.map((task) {
                final status = task['completion_status']?.toString();
                final color  = _statusColor(status);
                final icon   = _statusIcon(status);
                final label  = _statusLabel(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order badge
                      Container(
                        width: 22, height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text('${task['order']}',
                            style: AppTheme.label(
                                color: AppTheme.textMuted, size: 10)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task['title']?.toString() ?? '',
                                style: AppTheme.label(
                                    color: AppTheme.textPrimary,
                                    size: 13,
                                    weight: FontWeight.w600)),
                            if ((task['description'] ?? '').toString().isNotEmpty)
                              Text(
                                task['description'].toString(),
                                style: AppTheme.label(
                                    color: AppTheme.textSecondary, size: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(icon, color: color, size: 12),
                              const SizedBox(width: 4),
                              Text(label,
                                  style: AppTheme.label(color: color, size: 10)),
                              if (task['approved_at'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '· ${_formatDate(task['approved_at'].toString())}',
                                  style: AppTheme.label(
                                      color: AppTheme.textMuted, size: 10),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),
                      // Reward column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+${task['reward_exp']} EXP',
                              style: AppTheme.label(color: AppTheme.gold, size: 10)),
                          Text('+${task['reward_points']} PTS',
                              style: AppTheme.label(color: AppTheme.violet, size: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ]),
          ),
        ],
      ]),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: AppTheme.label(color: color, size: 10)),
      );
}

// ─── MINI POST CARD ───────────────────────────────────────────────────────────

class _MiniPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _MiniPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final postId = post['id']?.toString();
    return GestureDetector(
      onTap: postId != null
          ? () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: postId)))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                post['title']?.toString() ?? 'Untitled',
                style: AppTheme.label(
                    color: AppTheme.textPrimary,
                    size: 14,
                    weight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 16),
          ]),
          if (post['content'] != null &&
              post['content'].toString().isNotEmpty) ...[
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
            const Icon(Icons.access_time_outlined,
                size: 12, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              _formatTimestamp(post['datetime']?.toString() ?? ''),
              style: AppTheme.label(color: AppTheme.textMuted, size: 11),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$mi';
    } catch (_) {
      return raw;
    }
  }
}