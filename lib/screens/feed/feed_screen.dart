import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../quest/create_post_screen.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadFeed(); }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getFeed();
      if (res['error'] == false) {
        setState(() { _posts = res['results']['data'] ?? res['results'] ?? []; _loading = false; });
      } else {
        setState(() { _error = res['message']; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Could not load feed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bg,
            title: Text('QUESTIFY', style: AppTheme.mono(color: AppTheme.gold, size: 18)),
            actions: [
              IconButton(icon: const Icon(Icons.refresh_outlined, size: 20), onPressed: _loadFeed, color: AppTheme.textSecondary),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.border),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SectionHeader(title: 'Live Feed'),
            ),
          ),
          if (_loading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: _PostSkeleton()),
                childCount: 4,
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_outlined, color: AppTheme.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTheme.label(color: AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  GlowButton(label: 'Retry', onPressed: _loadFeed, outlined: true),
                ]),
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.explore_outlined, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('No posts yet.\nBe the first to post a quest!', textAlign: TextAlign.center, style: AppTheme.label(color: AppTheme.textMuted)),
                ]),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: _PostCard(post: _posts[i], onRefresh: _loadFeed)),
                childCount: _posts.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
          if (created == true) _loadFeed();
        },
        backgroundColor: AppTheme.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: Text('NEW QUEST', style: AppTheme.mono(color: Colors.black, size: 11)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  const _PostCard({required this.post, required this.onRefresh});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() { super.initState(); _likeCount = widget.post['likes_count'] ?? 0; }

  Future<void> _toggleLike() async {
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try { await ApiService.react(widget.post['id'].toString()); } catch (_) {
      setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final username = post['creator_username'] ?? post['user']?['username'] ?? 'Unknown';
    final title = post['post']?['title'] ?? post['title'] ?? 'Untitled';
    final content = post['post']?['content'] ?? post['content'];
    final quest = post['quest'];
    final commentsCount = post['comments_count'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post['id'].toString()))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(username: username),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(username, style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
                      Text(post['post']?['created_at'] ?? post['created_at'] ?? '', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.border)),
                    child: Text((post['visibility'] ?? 'public').toUpperCase(), style: AppTheme.label(color: AppTheme.textMuted, size: 10)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title.isNotEmpty) Text(title, style: AppTheme.label(color: AppTheme.textPrimary, size: 16, weight: FontWeight.w700)),
                if (content != null && content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(content, style: AppTheme.label(color: AppTheme.textSecondary, size: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            if (quest != null)
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: QuestCard(quest: quest)),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _ActionBtn(icon: _liked ? Icons.favorite : Icons.favorite_border, label: '$_likeCount', color: _liked ? AppTheme.rose : AppTheme.textMuted, onTap: _toggleLike),
                  const SizedBox(width: 20),
                  _ActionBtn(icon: Icons.chat_bubble_outline, label: '$commentsCount', color: AppTheme.textMuted,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post['id'].toString())))),
                  const Spacer(),
                  if (quest != null)
                    GestureDetector(
                      onTap: () async {
                        try {
                          final res = await ApiService.joinQuest(quest['code']);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res['message'] ?? 'Done'),
                            backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ));
                        } catch (_) {}
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanDim,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cyan.withOpacity(0.4)),
                        ),
                        child: Text('JOIN QUEST', style: AppTheme.mono(color: AppTheme.cyan, size: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.label(color: color, size: 13, weight: FontWeight.w600)),
      ]),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ShimmerBox(width: 36, height: 36, radius: 18),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerBox(width: 100, height: 12),
            const SizedBox(height: 4),
            ShimmerBox(width: 60, height: 10),
          ]),
        ]),
        const SizedBox(height: 16),
        ShimmerBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        ShimmerBox(width: 200, height: 12),
        const SizedBox(height: 16),
        ShimmerBox(width: double.infinity, height: 70),
      ]),
    );
  }
}