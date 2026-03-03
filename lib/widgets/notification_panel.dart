import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/pusher_service.dart';
import '../theme/app_theme.dart';

// ─── PUBLIC ENTRY POINT ──────────────────────────────────────────────────────

/// Open the notification inbox bottom sheet.
void showNotificationPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _NotificationPanel(),
  );
}

/// Lightweight router so the panel can push PostDetailScreen
/// without a circular import. Call [NotificationRouter.register] once
/// in app_shell.dart initState.
class NotificationRouter {
  static Widget Function(String postId)? _builder;
  static void register(Widget Function(String postId) builder) => _builder = builder;
}

// ─── PANEL ────────────────────────────────────────────────────────────────────

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel();
  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getNotifications();
      if (res['error'] == false && mounted) {
        final results = res['results'] as Map<String, dynamic>;
        final raw     = results['notifications'];
        final list    = (raw is Map ? raw['data'] : raw) as List? ?? [];
        setState(() {
          _items   = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
        // sync badge count
        final unread = results['unread_count'];
        if (unread != null) {
          PusherService.instance.setUnreadCount(_toInt(unread));
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    if (_marking) return;
    setState(() => _marking = true);
    try {
      await ApiService.markNotificationRead(all: true);
      setState(() {
        for (final n in _items) n['read'] = true;
      });
      PusherService.instance.setUnreadCount(0);
    } catch (_) {}
    if (mounted) setState(() => _marking = false);
  }

  Future<void> _markOne(int index) async {
    if (_items[index]['read'] == true) return;
    final id = _toInt(_items[index]['id']);
    try {
      await ApiService.markNotificationRead(notificationId: id);
      setState(() => _items[index]['read'] = true);
      PusherService.instance.decrementUnread();
    } catch (_) {}
  }

  int get _unreadCount => _items.where((n) => n['read'] != true).length;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(children: [
          // drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(children: [
              Text('NOTIFICATIONS', style: AppTheme.mono(color: AppTheme.textPrimary, size: 13)),
              if (_unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.roseDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.rose.withOpacity(0.4)),
                  ),
                  child: Text('$_unreadCount new', style: AppTheme.label(color: AppTheme.rose, size: 10)),
                ),
              ],
              const Spacer(),
              if (_unreadCount > 0)
                _marking
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                  : TextButton(
                      onPressed: _markAll,
                      child: Text('Mark all read', style: AppTheme.label(color: AppTheme.gold, size: 12)),
                    ),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // list
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
              : _items.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_none_outlined, color: AppTheme.textMuted, size: 40),
                    const SizedBox(height: 10),
                    Text('No notifications yet', style: AppTheme.label(color: AppTheme.textMuted)),
                  ]))
                : ListView.separated(
                    controller: ctrl,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) => _NoteTile(
                      note: _items[i],
                      onTap: () async {
                        await _markOne(i);
                        final postId = _items[i]['post_id'];
                        if (postId != null && NotificationRouter._builder != null && context.mounted) {
                          Navigator.pop(context);
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => NotificationRouter._builder!(postId.toString()),
                            ),
                          );
                        }
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ─── TILE ─────────────────────────────────────────────────────────────────────

class _NoteTile extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTap;
  const _NoteTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComment = note['type'] == 'new_comment';
    final isUnread  = note['read'] != true;
    final color     = isComment ? AppTheme.cyan : AppTheme.violet;
    final icon      = isComment ? Icons.chat_bubble_outline : Icons.shield_outlined;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isUnread ? AppTheme.bg.withOpacity(0.55) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // icon badge
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          // text
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              note['title']?.toString() ?? '',
              style: AppTheme.label(
                color: isUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                size: 13,
                weight: isUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if ((note['body'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                note['body'].toString(),
                style: AppTheme.label(color: AppTheme.textMuted, size: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            // Timestamp already formatted as "Y-m-d h:i" by the server
            Text(
              note['created_at']?.toString() ?? '',
              style: AppTheme.label(color: AppTheme.textMuted, size: 11),
            ),
          ])),
          // unread dot
          if (isUnread)
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 5, left: 8),
              decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}