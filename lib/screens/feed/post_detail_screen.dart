import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<dynamic> _comments = [];
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final postRes = await ApiService.getPost(widget.postId);
      final commentRes = await ApiService.getPostComments(widget.postId);
      setState(() {
        _post = postRes['error'] == false ? postRes['results'] : null;
        _comments = commentRes['error'] == false ? (commentRes['results'] ?? commentRes['results'] ?? []) : [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _comment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createComment(commentTarget: widget.postId, content: _commentCtrl.text.trim());
      _commentCtrl.clear();
      _load();
    } catch (_) {}
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POST'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _post == null
              ? Center(child: Text('Post not found', style: AppTheme.label(color: AppTheme.textMuted)))
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(children: [
                          UserAvatar(username: _post!['creator_username'] ?? 'u'),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_post!['creator_full_name'] ?? '', style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
                            Text('@${_post!['creator_username'] ?? ''}', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
                          ]),
                        ]),
                        const SizedBox(height: 16),
                        if (_post!['post']?['title'] != null)
                          Text(_post!['post']['title'], style: AppTheme.label(color: AppTheme.textPrimary, size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (_post!['post']?['content'] != null)
                          Text(_post!['post']['content'], style: AppTheme.label(color: AppTheme.textSecondary, size: 14)),
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
                                  backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ));
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SectionHeader(title: 'Comments (${_comments.length})'),
                        const SizedBox(height: 16),
                        if (_comments.isEmpty)
                          Text('No comments yet.', style: AppTheme.label(color: AppTheme.textMuted, size: 13))
                        else
                          ..._comments.map((c) => _CommentTile(comment: c)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(hintText: 'Write a comment...', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                          style: AppTheme.label(color: AppTheme.textPrimary, size: 13),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _comment(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _comment,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(8)),
                          child: _submitting
                              ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatar(username: comment['username'] ?? 'u', size: 30),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(comment['username'] ?? '', style: AppTheme.label(color: AppTheme.textPrimary, size: 13, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(comment['createdAt'] ?? '', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
          ]),
          const SizedBox(height: 4),
          Text(comment['content'] ?? '', style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
        ])),
      ]),
    );
  }
}