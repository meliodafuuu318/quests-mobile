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

// ─── COMMENT TILE ────────────────────────────────────────────────────────────
// Handles two modes:
//   • normal comment  — plain bubble
//   • verification submission — distinctive card with approve/flag voting
//     and a "COMPLETED" overlay when the quest creator has approved it.

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({super.key, required this.comment});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late int    _approveCount;
  late int    _flagCount;
  late String? _myVote;       // null | 'approved' | 'flagged'
  bool        _voting = false;

  @override
  void initState() {
    super.initState();
    _approveCount = _toInt(widget.comment['approve_count']);
    _flagCount    = _toInt(widget.comment['flag_count']);
    _myVote       = widget.comment['my_vote']?.toString();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _vote(bool approve) async {
    if (_voting || _myVote != null) return;
    final taskId = widget.comment['quest_participant_task_id']?.toString();
    if (taskId == null) return;

    setState(() => _voting = true);
    try {
      final res = approve
          ? await ApiService.verifyTask(taskId)
          : await ApiService.flagTask(taskId);
      if (res['error'] == false && mounted) {
        setState(() {
          _myVote = approve ? 'approved' : 'flagged';
          if (approve) _approveCount++;
          else         _flagCount++;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Vote failed'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _voting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isVerification = widget.comment['is_verification'] == true ||
        widget.comment['is_verification'] == 1;

    return isVerification
        ? _buildVerificationTile()
        : _buildNormalTile();
  }

  // ── Normal comment ───────────────────────────────────────────────────────
  Widget _buildNormalTile() {
    final media   = widget.comment['media'] as List? ?? [];
    final content = widget.comment['content']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatar(
          username:  widget.comment['username']?.toString() ?? 'u',
          avatarUrl: widget.comment['comment_avatar_url']?.toString(),
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.comment['username']?.toString() ?? '',
                style: AppTheme.label(color: AppTheme.textPrimary, size: 13, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(widget.comment['createdAt']?.toString() ?? '',
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
                Text(content, style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
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

  // ── Verification submission ───────────────────────────────────────────────
  Widget _buildVerificationTile() {
    final media             = widget.comment['media'] as List? ?? [];
    final content           = widget.comment['content']?.toString() ?? '';
    final status            = widget.comment['completion_status']?.toString();
    final isCompleted       = status == 'completed';
    final isCommunityVerified = status == 'community_verified';
    final isFlagged         = status == 'flagged';
    final username          = widget.comment['username']?.toString() ?? 'u';

    // Colour scheme changes by status
    final accentColor = isCompleted
        ? AppTheme.cyan
        : isCommunityVerified
            ? AppTheme.violet
            : isFlagged
                ? AppTheme.rose
                : AppTheme.gold;

    final bgColor = isCompleted
        ? AppTheme.cyan.withOpacity(0.06)
        : isCommunityVerified
            ? AppTheme.violet.withOpacity(0.06)
            : isFlagged
                ? AppTheme.rose.withOpacity(0.06)
                : AppTheme.gold.withOpacity(0.06);

    final statusLabel = isCompleted
        ? 'COMPLETED'
        : isCommunityVerified
            ? 'COMMUNITY VERIFIED'
            : isFlagged
                ? 'FLAGGED'
                : 'PENDING REVIEW';

    final statusIcon = isCompleted
        ? Icons.verified_outlined
        : isCommunityVerified
            ? Icons.people_outlined
            : isFlagged
                ? Icons.flag_outlined
                : Icons.hourglass_empty_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.10),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(children: [
              Icon(Icons.assignment_turned_in_outlined, color: accentColor, size: 13),
              const SizedBox(width: 6),
              Text('TASK SUBMISSION', style: AppTheme.mono(color: accentColor, size: 10)),
              const Spacer(),
              Icon(statusIcon, color: accentColor, size: 12),
              const SizedBox(width: 4),
              Text(statusLabel, style: AppTheme.label(color: accentColor, size: 10)),
            ]),
          ),

          // ── User + timestamp ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              UserAvatar(
                username:  username,
                avatarUrl: widget.comment['comment_avatar_url']?.toString(),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(username,
                    style: AppTheme.label(color: AppTheme.textPrimary, size: 13, weight: FontWeight.w600)),
                Text(widget.comment['createdAt']?.toString() ?? '',
                    style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
              ])),
              // Completed ribbon
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.cyan, size: 13),
                    const SizedBox(width: 4),
                    Text('APPROVED', style: AppTheme.mono(color: AppTheme.cyan, size: 10)),
                  ]),
                ),
            ]),
          ),

          // ── Comment content ─────────────────────────────────────────────
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(content, style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
            ),

          // ── Media proof ─────────────────────────────────────────────────
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaGallery(media: media),
              ),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.border),

          // ── Vote row (approve / flag) — hidden when already completed ───
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                // Approve button
                _VoteBtn(
                  icon:    Icons.thumb_up_alt_outlined,
                  label:   '$_approveCount',
                  color:   AppTheme.cyan,
                  active:  _myVote == 'approved',
                  enabled: _myVote == null && !_voting,
                  loading: _voting && _myVote == null,
                  onTap:   () => _vote(true),
                ),
                const SizedBox(width: 12),
                // Flag button
                _VoteBtn(
                  icon:    Icons.thumb_down_alt_outlined,
                  label:   '$_flagCount',
                  color:   AppTheme.rose,
                  active:  _myVote == 'flagged',
                  enabled: _myVote == null && !_voting,
                  loading: false,
                  onTap:   () => _vote(false),
                ),
                const Spacer(),
                Text(
                  _myVote == 'approved'
                      ? 'You approved'
                      : _myVote == 'flagged'
                          ? 'You flagged'
                          : 'Vote on this submission',
                  style: AppTheme.label(color: AppTheme.textMuted, size: 11),
                ),
              ]),
            ),

          // ── Completed footer ─────────────────────────────────────────────
          if (isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.star_outline, color: AppTheme.gold, size: 14),
                const SizedBox(width: 6),
                Text('Quest creator approved this submission',
                    style: AppTheme.label(color: AppTheme.gold, size: 12)),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ─── VOTE BUTTON ─────────────────────────────────────────────────────────────

class _VoteBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     active;
  final bool     enabled;
  final bool     loading;
  final VoidCallback onTap;

  const _VoteBtn({
    required this.icon, required this.label, required this.color,
    required this.active, required this.enabled,
    required this.loading, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:  active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color.withOpacity(0.5) : AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          loading
              ? SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon,
                  color:  active ? color : (enabled ? AppTheme.textMuted : AppTheme.border),
                  size: 15),
          const SizedBox(width: 5),
          Text(label,
              style: AppTheme.label(
                color: active ? color : (enabled ? AppTheme.textMuted : AppTheme.border),
                size: 13, weight: FontWeight.w600,
              )),
        ]),
      ),
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