import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/pusher_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/media_picker.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  final List<Map<String, dynamic>> _comments = [];
  bool   _loading    = true;
  int    _likeCount  = 0;
  bool   _liked      = false;
  bool   _submitting = false;

  final _commentCtrl    = TextEditingController();
  final _picker         = ImagePicker();
  final List<MediaFile> _commentMedia = [];

  @override
  void initState() {
    super.initState();
    _load();
    PusherService.instance.watchPost(widget.postId);
    PusherService.instance.onComment(widget.postId, _onNewComment);
    PusherService.instance.onReact(widget.postId, _onNewReact);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    PusherService.instance.unwatchPost(widget.postId);
    super.dispose();
  }

  void _onNewComment() => _loadComments();
  void _onNewReact(String postId, int count) {
    if (mounted) setState(() => _likeCount = count);
  }

  Future<void> _load() async {
    try {
      final postRes = await ApiService.getPost(widget.postId);
      if (postRes['error'] == false) {
        final r = postRes['results'] as Map<String, dynamic>;
        _post      = r;
        _likeCount = _toInt(r['likes_count']);
        _liked     = r['liked'] == true;
      }
      await _loadComments();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadComments() async {
    try {
      final res = await ApiService.getPostComments(widget.postId);
      if (res['error'] == false && mounted) {
        final raw  = res['results'];
        final list = (raw is Map ? raw['data'] : raw) as List? ?? [];
        setState(() {
          _comments.clear();
          _comments.addAll(list.cast<Map<String, dynamic>>());
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiService.react(widget.postId);
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

  Future<void> _pickCommentImage() async {
    if (_commentMedia.length >= 2) return;
    final res = await _picker.pickMultiImage(limit: 2 - _commentMedia.length);
    if (res.isNotEmpty) {
      setState(() {
        for (final f in res) {
          if (_commentMedia.length < 2) _commentMedia.add(MediaFile(file: f, isVideo: false));
        }
      });
    }
  }

  Future<void> _pickCommentVideo() async {
    if (_commentMedia.isNotEmpty) return;
    final f = await _picker.pickVideo(source: ImageSource.gallery);
    if (f != null) setState(() => _commentMedia.add(MediaFile(file: f, isVideo: true)));
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentMedia.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ApiService.createComment(
        target:     widget.postId,
        content:    text,
        mediaFiles: _commentMedia.map((m) => m.file).toList(),
      );
      _commentCtrl.clear();
      setState(() => _commentMedia.clear());
      await _loadComments();
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final mq             = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;
    final navBarHeight   = mq.padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('POST'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('LIVE', style: AppTheme.mono(color: AppTheme.cyan, size: 10)),
            ]),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _post == null
              ? Center(child: Text('Post not found',
                  style: AppTheme.label(color: AppTheme.textMuted)))
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildPostHeader(),
                        const SizedBox(height: 14),
                        _buildPostBody(),

                        if ((_post!['media'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: MediaGallery(media: _post!['media'] as List),
                          ),
                        ],

                        if (_post!['quest'] != null) ...[
                          const SizedBox(height: 20),
                          QuestCard(quest: _post!['quest']),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: GlowButton(
                              label: 'JOIN QUEST  (−25 Credits)',
                              color: AppTheme.cyan,
                              icon: Icons.play_arrow_outlined,
                              onPressed: () async {
                                final code = _post!['quest']['code'];
                                if (code == null) return;
                                final res = await ApiService.joinQuest(code);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(res['message'] ?? ''),
                                  backgroundColor: res['error'] == false
                                      ? AppTheme.cyan : AppTheme.rose,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ));
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        Row(children: [
                          GestureDetector(
                            onTap: _toggleLike,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _liked ? AppTheme.roseDim : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _liked
                                      ? AppTheme.rose.withOpacity(0.4)
                                      : AppTheme.border,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  _liked ? Icons.favorite : Icons.favorite_border,
                                  color: _liked ? AppTheme.rose : AppTheme.textMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text('$_likeCount', style: AppTheme.label(
                                  color: _liked ? AppTheme.rose : AppTheme.textMuted,
                                  size: 14, weight: FontWeight.w600,
                                )),
                              ]),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 24),
                        SectionHeader(title: 'Comments (${_comments.length})'),
                        const SizedBox(height: 14),

                        if (_comments.isEmpty)
                          Text('No comments yet. Be first!',
                              style: AppTheme.label(
                                  color: AppTheme.textMuted, size: 13))
                        else
                          ..._comments.map((c) => _CommentTile(comment: c)),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: keyboardHeight > 0 ? keyboardHeight : navBarHeight,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_commentMedia.isNotEmpty) ...[
                          MediaPickerBar.buildPreview(_commentMedia, (i) {
                            setState(() => _commentMedia.removeAt(i));
                          }),
                          const SizedBox(height: 8),
                        ],

                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _CommentMediaBtn(
                            icon: Icons.image_outlined,
                            color: AppTheme.cyan,
                            enabled: _commentMedia.length < 2,
                            onTap: _pickCommentImage,
                          ),
                          const SizedBox(width: 4),
                          _CommentMediaBtn(
                            icon: Icons.videocam_outlined,
                            color: AppTheme.violet,
                            enabled: _commentMedia.isEmpty,
                            onTap: _pickCommentVideo,
                          ),
                          const SizedBox(width: 8),

                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: TextField(
                                controller: _commentCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment...',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                style: AppTheme.label(
                                    color: AppTheme.textPrimary, size: 13),
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _commentCtrl,
                            builder: (_, val, __) {
                              final canSend = val.text.trim().isNotEmpty ||
                                  _commentMedia.isNotEmpty;
                              return GestureDetector(
                                onTap: canSend ? _submitComment : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: canSend
                                        ? AppTheme.gold
                                        : AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: canSend
                                        ? null
                                        : Border.all(color: AppTheme.border),
                                  ),
                                  child: _submitting
                                      ? const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.black),
                                        )
                                      : Icon(Icons.send_rounded,
                                          color: canSend ? Colors.black : AppTheme.textMuted,
                                          size: 18),
                                ),
                              );
                            },
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
    );
  }

  Widget _buildPostHeader() {
    final username  = _post!['creator_username']?.toString() ?? '';
    final fullName  = _post!['creator_full_name']?.toString() ?? '';
    // ShowPostRepository returns fields flat — no nested 'post' key
    final createdAt = _post!['created_at']?.toString() ?? '';
    // ── avatar from ShowPostRepository ───────────────────────────────────
    final avatarUrl = _post!['creator_avatar_url']?.toString();

    return Row(children: [
      UserAvatar(username: username, size: 44, avatarUrl: avatarUrl),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fullName.isNotEmpty ? fullName : username,
            style: AppTheme.label(
                color: AppTheme.textPrimary, size: 15, weight: FontWeight.w700)),
        Row(children: [
          Text('@$username',
              style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
          if (createdAt.isNotEmpty) ...[
            Text('  ·  ',
                style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
            Text(createdAt,
                style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
          ],
        ]),
      ])),
    ]);
  }

  Widget _buildPostBody() {
    // ShowPostRepository returns fields flat — no nested 'post' key
    final title   = _post!['title']?.toString() ?? '';
    final content = _post!['content']?.toString() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title.isNotEmpty)
        Text(title,
            style: AppTheme.label(
                color: AppTheme.textPrimary, size: 20, weight: FontWeight.w800)),
      if (content.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(content,
            style: AppTheme.label(color: AppTheme.textSecondary, size: 14)),
      ],
    ]);
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final media   = comment['media'] as List? ?? [];
    final content = comment['content']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatar(username: comment['username']?.toString() ?? 'u', size: 32),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(comment['username']?.toString() ?? '',
                style: AppTheme.label(
                    color: AppTheme.textPrimary, size: 13, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(comment['createdAt']?.toString() ?? '',
                style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
          ]),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: const BorderRadius.only(
                topRight:    Radius.circular(10),
                bottomLeft:  Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (content.isNotEmpty)
                Text(content,
                    style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
              if (media.isNotEmpty) ...[
                if (content.isNotEmpty) const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MediaGallery(media: media),
                ),
              ],
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _CommentMediaBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final bool     enabled;
  final VoidCallback onTap;
  const _CommentMediaBtn({
    required this.icon, required this.color,
    required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled ? color.withOpacity(0.3) : AppTheme.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: enabled ? color : AppTheme.textMuted, size: 16),
      ),
    );
  }
}