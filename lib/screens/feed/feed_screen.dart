import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/pusher_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/media_picker.dart';
import '../quest/create_post_screen.dart';
import 'post_detail_screen.dart';

// ─── ALGORITHM CONFIG ─────────────────────────────────────────────────────────
const int _injectEvery  = 3;   // insert 1 discovery post every N related posts
const int _newPostDelay = 30;  // seconds before showing "new posts" banner
// ─────────────────────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _posts     = [];
  final List<Map<String, dynamic>> _discovery = [];
  final Set<String>                _seenIds   = {};

  int  _feedPage        = 1;
  int  _discoveryPage   = 1;
  bool _hasMoreFeed     = true;
  bool _hasMoreDiscovery = true;
  int  _relatedSinceInject = 0;

  bool _initialLoading = true;
  bool _loadingMore    = false;
  bool _newPostsBanner = false;
  bool _allExhausted   = false;
  String? _error;

  Timer? _newPostTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PusherService.instance.onNewPostAvailable = _onNewPostSignal;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _newPostTimer?.cancel();
    PusherService.instance.onNewPostAvailable = null;
    super.dispose();
  }

  void _onNewPostSignal() {
    _newPostTimer?.cancel();
    _newPostTimer = Timer(const Duration(seconds: _newPostDelay), () {
      if (mounted) setState(() => _newPostsBanner = true);
    });
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ── Initial load ──────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    setState(() { _initialLoading = true; _error = null; });
    _posts.clear(); _discovery.clear(); _seenIds.clear();
    _feedPage = _discoveryPage = 1;
    _hasMoreFeed = _hasMoreDiscovery = true;
    _relatedSinceInject = 0;
    _allExhausted = false;

    await Future.wait([_fetchFeedPage(), _fetchDiscoveryPage()]);
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _refresh() async {
    setState(() => _newPostsBanner = false);
    await _loadInitial();
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Future<void> _fetchFeedPage() async {
    try {
      final res = await ApiService.getFeed(page: _feedPage);
      if (res['error'] == false) {
        final results = res['results'];
        final List raw = (results is Map ? results['data'] : results) ?? [];
        _mergePosts(raw.cast<Map<String, dynamic>>(), isDiscovery: false);
        _hasMoreFeed = results is Map && results['next_page_url'] != null;
        _feedPage++;
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load feed');
    }
  }

  Future<void> _fetchDiscoveryPage() async {
    try {
      final res = await ApiService.getDiscoveryPosts(page: _discoveryPage);
      if (res['error'] == false) {
        final results = res['results'];
        final List raw = (results is Map ? results['data'] : results) ?? [];
        for (final p in raw.cast<Map<String, dynamic>>()) {
          if (!_seenIds.contains(_postId(p))) _discovery.add(p);
        }
        _hasMoreDiscovery = results is Map && results['next_page_url'] != null;
        _discoveryPage++;
      }
    } catch (_) {}
  }

  void _mergePosts(List<Map<String, dynamic>> related, {required bool isDiscovery}) {
    for (final post in related) {
      final id = _postId(post);
      if (_seenIds.contains(id) && !isDiscovery) continue;
      _seenIds.add(id);

      final tagged = Map<String, dynamic>.from(post);
      tagged['_is_discovery'] = isDiscovery;
      _posts.add(tagged);

      if (!isDiscovery) {
        _relatedSinceInject++;
        if (_relatedSinceInject >= _injectEvery && _discovery.isNotEmpty) {
          final d = Map<String, dynamic>.from(_discovery.removeAt(0));
          d['_is_discovery'] = true;
          final did = _postId(d);
          if (!_seenIds.contains(did)) {
            _seenIds.add(did);
            _posts.add(d);
          }
          _relatedSinceInject = 0;
        }
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    if (_hasMoreFeed) {
      await _fetchFeedPage();
      if (_discovery.isEmpty && _hasMoreDiscovery) await _fetchDiscoveryPage();
    } else if (_hasMoreDiscovery) {
      await _fetchDiscoveryPage();
      if (_discovery.isNotEmpty) {
        final batch = _discovery.take(5).toList();
        _discovery.removeRange(0, batch.length);
        _mergePosts(batch, isDiscovery: true);
      }
    } else {
      _recycleSeenPosts();
    }

    if (mounted) setState(() => _loadingMore = false);
  }

  void _recycleSeenPosts() {
    if (_posts.isEmpty) return;
    final recycled = List<Map<String, dynamic>>.from(_posts)..shuffle();
    for (final p in recycled.take(5)) {
      final copy = Map<String, dynamic>.from(p);
      copy['_recycled'] = true;
      _posts.add(copy);
    }
    if (mounted) setState(() => _allExhausted = true);
  }

  String _postId(Map<String, dynamic> p) =>
      p['id']?.toString() ?? UniqueKey().toString();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            _buildAppBar(),
            if (_initialLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 14), child: _PostSkeleton()),
                  childCount: 4,
                ),
              )
            else if (_error != null && _posts.isEmpty)
              SliverFillRemaining(child: _buildError())
            else if (_posts.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildItem(i),
                    childCount: _posts.length,
                  ),
                ),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))),
                )),
              if (_allExhausted && !_loadingMore)
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(
                    "You've seen it all — showing highlights",
                    style: AppTheme.label(color: AppTheme.textMuted, size: 12),
                  )),
                )),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),

        // ── "New posts" banner ────────────────────────────────────────────
        if (_newPostsBanner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _refresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.violet,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppTheme.violet.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 15),
                    const SizedBox(width: 7),
                    Text('New posts — tap to refresh',
                        style: AppTheme.label(color: Colors.white, size: 13, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
          if (created == true && mounted) _loadInitial();
        },
        backgroundColor: AppTheme.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: Text('NEW QUEST', style: AppTheme.mono(color: Colors.black, size: 11)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  SliverAppBar _buildAppBar() => SliverAppBar(
    pinned: true,
    backgroundColor: AppTheme.bg,
    title: Text('QUESTS', style: AppTheme.mono(color: AppTheme.gold, size: 18)),
    actions: [
      const NotificationBell(),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.refresh_outlined, size: 20, color: AppTheme.textSecondary),
        onPressed: _refresh,
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppTheme.border),
    ),
  );

  Widget _buildItem(int i) {
    final post        = _posts[i];
    final isDiscovery = post['_is_discovery'] == true;
    final isRecycled  = post['_recycled']     == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isDiscovery && (i == 0 || _posts[i - 1]['_is_discovery'] != true))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            const Icon(Icons.explore_outlined, color: AppTheme.violet, size: 13),
            const SizedBox(width: 5),
            Text('SUGGESTED FOR YOU', style: AppTheme.mono(color: AppTheme.violet, size: 10)),
          ])),
        if (isRecycled && (i == 0 || _posts[i - 1]['_recycled'] != true))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            const Icon(Icons.history_outlined, color: AppTheme.textMuted, size: 13),
            const SizedBox(width: 5),
            Text('IN CASE YOU MISSED IT', style: AppTheme.mono(color: AppTheme.textMuted, size: 10)),
          ])),
        _PostCard(post: post, isDiscovery: isDiscovery),
      ]),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_outlined, color: AppTheme.textMuted, size: 40),
    const SizedBox(height: 12),
    Text(_error!, style: AppTheme.label(color: AppTheme.textMuted), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    GlowButton(label: 'Retry', onPressed: _loadInitial, outlined: true),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.explore_outlined, color: AppTheme.textMuted, size: 48),
    const SizedBox(height: 12),
    Text('No posts yet.', style: AppTheme.label(color: AppTheme.textMuted)),
  ]));
}

// ─── POST CARD ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDiscovery;
  const _PostCard({required this.post, this.isDiscovery = false});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked     = false;
  int  _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _liked     = widget.post['liked'] == true;  // ← from API
    _likeCount = _toInt(widget.post['likes_count']);

    final id = widget.post['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      PusherService.instance.onReact(id, (_, count) {
        if (mounted) setState(() => _likeCount = count);
      });
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _toggleLike() async {
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiService.react(widget.post['id'].toString());
      if (res['error'] == false && mounted) {
        final r = res['results'] as Map<String, dynamic>? ?? {};
        setState(() {
          _likeCount = _toInt(r['likes_count'] ?? _likeCount);
          _liked     = r['liked'] == true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post       = widget.post;
    final postData   = post['post'] is Map ? post['post'] as Map : null;
    final username   = post['creator_username']?.toString() ?? post['user']?['username']?.toString() ?? 'Unknown';
    final title      = postData?['title']?.toString() ?? post['title']?.toString() ?? '';
    final content    = postData?['content']?.toString() ?? post['content']?.toString() ?? '';
    final createdAt  = postData?['created_at']?.toString() ?? post['created_at']?.toString() ?? '';
    final quest      = post['quest'] is Map ? post['quest'] as Map<String, dynamic> : null;
    final comments   = _toInt(post['comments_count']);
    final vis        = post['visibility']?.toString() ?? 'public';
    final media      = post['media'] as List? ?? [];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post['id'].toString()),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDiscovery ? AppTheme.violet.withOpacity(0.3) : AppTheme.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              UserAvatar(username: username),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(username, style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
                Text(createdAt, style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
              ])),
              widget.isDiscovery
                  ? _badge('SUGGESTED', AppTheme.violet, AppTheme.violetDim)
                  : _badge(vis.toUpperCase(), AppTheme.textMuted, AppTheme.surfaceElevated),
            ]),
          ),

          // ── Body ──────────────────────────────────────────────────────
          if (title.isNotEmpty || content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title.isNotEmpty)
                  Text(title, style: AppTheme.label(color: AppTheme.textPrimary, size: 15, weight: FontWeight.w700)),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(content, style: AppTheme.label(color: AppTheme.textSecondary, size: 13),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),

          // ── Media ─────────────────────────────────────────────────────
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MediaGallery(media: media),
              ),
            ),

          // ── Quest card ────────────────────────────────────────────────
          if (quest != null)
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: QuestCard(quest: quest)),

          // ── Footer ────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              _ActionBtn(
                icon:  _liked ? Icons.favorite : Icons.favorite_border,
                label: '$_likeCount',
                color: _liked ? AppTheme.rose : AppTheme.textMuted,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 18),
              _ActionBtn(
                icon:  Icons.chat_bubble_outline,
                label: '$comments',
                color: AppTheme.textMuted,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: post['id'].toString()),
                )),
              ),
              const Spacer(),
              if (quest != null && quest['code'] != null)
                GestureDetector(
                  onTap: () async {
                    final res = await ApiService.joinQuest(quest['code']);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['message'] ?? ''),
                      backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ));
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
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: AppTheme.label(color: color, size: 9)),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 5),
      Text(label, style: AppTheme.label(color: color, size: 13, weight: FontWeight.w600)),
    ]),
  );
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ShimmerBox(width: 36, height: 36, radius: 18),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShimmerBox(width: 110, height: 11), const SizedBox(height: 5), ShimmerBox(width: 70, height: 9),
        ]),
      ]),
      const SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 13),
      const SizedBox(height: 7),
      ShimmerBox(width: 180, height: 11),
      const SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 60),
    ]),
  );
}