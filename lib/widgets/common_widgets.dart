import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pusher_service.dart';
import '../theme/app_theme.dart';

// ─── STAT BADGE ──────────────────────────────────────────────────────────────

class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const StatBadge({super.key, required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTheme.mono(color: color, size: 12)),
              Text(label, style: AppTheme.label(color: AppTheme.textMuted, size: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── GLOW BUTTON ─────────────────────────────────────────────────────────────

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final IconData? icon;
  final bool isLoading;

  const GlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppTheme.gold,
    this.outlined = false,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: outlined ? 1.5 : 0),
          boxShadow: outlined ? null : [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.black),
              )
            else ...[
              if (icon != null) ...[Icon(icon, color: outlined ? color : Colors.black, size: 15), const SizedBox(width: 7)],
              Text(label, style: AppTheme.mono(color: outlined ? color : Colors.black, size: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── XP BAR ──────────────────────────────────────────────────────────────────

class XpBar extends StatelessWidget {
  final double current;
  final double max;
  final int level;

  const XpBar({super.key, required this.current, required this.max, required this.level});

  @override
  Widget build(BuildContext context) {
    final progress = (current / max.clamp(1, double.infinity)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LVL $level', style: AppTheme.mono(color: AppTheme.gold, size: 11)),
            Text('${current.toInt()} / ${max.toInt()} XP', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.gold, AppTheme.cyan]),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: AppTheme.gold.withOpacity(0.4), blurRadius: 6)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── QUEST CARD ──────────────────────────────────────────────────────────────

class QuestCard extends StatelessWidget {
  final Map<String, dynamic> quest;
  const QuestCard({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    final tasks = quest['quest_tasks'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cyanDim.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.cyan, size: 13),
              const SizedBox(width: 5),
              Text('QUEST', style: AppTheme.mono(color: AppTheme.cyan, size: 10)),
              const Spacer(),
              if (quest['code'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4)),
                  child: Text(quest['code'], style: AppTheme.label(color: AppTheme.textMuted, size: 10)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatBadge(label: 'EXP', value: '+${quest['reward_exp'] ?? 0}', color: AppTheme.gold, icon: Icons.auto_awesome),
              const SizedBox(width: 8),
              StatBadge(label: 'PTS', value: '+${quest['reward_points'] ?? 0}', color: AppTheme.violet, icon: Icons.diamond_outlined),
              const Spacer(),
              const Icon(Icons.people_outline, color: AppTheme.textMuted, size: 13),
              const SizedBox(width: 3),
              Text('${quest['participants'] ?? 0}', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 10),
            ...tasks.take(3).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 18, height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(4)),
                    child: Text('${t['order']}', style: AppTheme.label(color: AppTheme.textMuted, size: 9)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(t['title'] ?? '', style: AppTheme.label(color: AppTheme.textSecondary, size: 12), overflow: TextOverflow.ellipsis)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3, height: 15,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: AppTheme.gold.withOpacity(0.5), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 9),
        Text(title.toUpperCase(), style: AppTheme.mono(color: AppTheme.textPrimary, size: 12)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ─── SHIMMER BOX ─────────────────────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, required this.width, required this.height, this.radius = 8});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: [AppTheme.border, AppTheme.borderBright, AppTheme.border],
          ),
        ),
      ),
    );
  }
}

// ─── USER AVATAR ─────────────────────────────────────────────────────────────
// Renders a server image when [avatarUrl] is provided; falls back to a
// coloured initials circle on error or when the URL is absent.

class UserAvatar extends StatelessWidget {
  final String username;
  final double size;
  final Color? color;
  /// Relative ("/storage/…") or absolute URL from the API.
  /// Relative paths are prefixed with [_base] automatically.
  final String? avatarUrl;

  static const String _base = 'http://10.54.172.88:8000';

  const UserAvatar({
    super.key,
    required this.username,
    this.size = 36,
    this.color,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      final url =
          avatarUrl!.startsWith('http') ? avatarUrl! : '$_base$avatarUrl';
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final colors = [AppTheme.gold, AppTheme.cyan, AppTheme.violet, AppTheme.rose];
    final c = color ??
        (username.isNotEmpty
            ? colors[username.codeUnitAt(0) % colors.length]
            : AppTheme.gold);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: TextStyle(
          color: c,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─── NOTIFICATION BELL ───────────────────────────────────────────────────────

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<PusherService>().unreadCount;
    return GestureDetector(
      onTap: () => NotificationBellRouter._show?.call(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(
            count > 0 ? Icons.notifications : Icons.notifications_outlined,
            color: count > 0 ? AppTheme.gold : AppTheme.textSecondary,
            size: 22,
          ),
          if (count > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppTheme.rose, shape: BoxShape.circle),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 8,
                    fontWeight: FontWeight.w700, fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class NotificationBellRouter {
  static void Function(BuildContext)? _show;
  static void register(void Function(BuildContext) fn) => _show = fn;
}