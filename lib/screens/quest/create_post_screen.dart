import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _rewardExpCtrl = TextEditingController(text: '100');
  final _rewardPtsCtrl = TextEditingController(text: '10');
  String _visibility = 'public';
  bool _submitting = false;
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void dispose() {
    for (final c in [_titleCtrl, _contentCtrl, _rewardExpCtrl, _rewardPtsCtrl]) c.dispose();
    for (final t in _tasks) {
      (t['titleCtrl'] as TextEditingController).dispose();
      (t['descCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addTask() {
    setState(() => _tasks.add({
      'title': '', 'description': '', 'rewardExp': 10, 'rewardPoints': 1,
      'order': _tasks.length + 1,
      'titleCtrl': TextEditingController(),
      'descCtrl': TextEditingController(),
    }));
  }

  void _removeTask(int i) {
    (_tasks[i]['titleCtrl'] as TextEditingController).dispose();
    (_tasks[i]['descCtrl'] as TextEditingController).dispose();
    setState(() {
      _tasks.removeAt(i);
      for (int j = 0; j < _tasks.length; j++) _tasks[j]['order'] = j + 1;
    });
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required'), backgroundColor: AppTheme.rose));
      return;
    }
    if (_tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one quest task'), backgroundColor: AppTheme.rose));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiService.createPost(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        visibility: _visibility,
        rewardExp: int.tryParse(_rewardExpCtrl.text) ?? 100,
        rewardPoints: int.tryParse(_rewardPtsCtrl.text) ?? 10,
        tasks: _tasks.map((t) => {
          'title': (t['titleCtrl'] as TextEditingController).text.trim(),
          'description': (t['descCtrl'] as TextEditingController).text.trim(),
          'rewardExp': t['rewardExp'], 'rewardPoints': t['rewardPoints'], 'order': t['order'],
        }).toList(),
      );
      if (!mounted) return;
      if (res['error'] == false) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: AppTheme.rose));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error'), backgroundColor: AppTheme.rose));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW QUEST POST'),
        leading: IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GlowButton(label: 'PUBLISH', onPressed: _submit, isLoading: _submitting),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionHeader(title: 'Post Details'),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Quest Title *'),
            style: AppTheme.label(color: AppTheme.textPrimary, size: 15, weight: FontWeight.w600),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contentCtrl,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
            maxLines: 4,
            style: AppTheme.label(color: AppTheme.textPrimary, size: 14),
          ),
          const SizedBox(height: 14),
          // Visibility
          Row(children: [
            Text('Visibility:', style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
            const SizedBox(width: 12),
            ...([('public', Icons.public), ('friends', Icons.people_outline), ('private', Icons.lock_outline)].map((v) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _visibility = v.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _visibility == v.$1 ? AppTheme.goldDim : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _visibility == v.$1 ? AppTheme.gold : AppTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(v.$2, size: 13, color: _visibility == v.$1 ? AppTheme.gold : AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(v.$1, style: AppTheme.label(color: _visibility == v.$1 ? AppTheme.gold : AppTheme.textMuted, size: 12)),
                    ]),
                  ),
                ),
              )
            )),
          ]),
          const SizedBox(height: 28),
          SectionHeader(title: 'Quest Rewards'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EXP Reward', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardExpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_awesome, color: AppTheme.gold, size: 16), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                style: AppTheme.mono(color: AppTheme.gold, size: 14),
              ),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Points Reward', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardPtsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.diamond_outlined, color: AppTheme.violet, size: 16), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                style: AppTheme.mono(color: AppTheme.violet, size: 14),
              ),
            ])),
          ]),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Quest Tasks',
            trailing: GestureDetector(
              onTap: _addTask,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.goldDim, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.gold.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, color: AppTheme.gold, size: 14),
                  const SizedBox(width: 4),
                  Text('ADD TASK', style: AppTheme.mono(color: AppTheme.gold, size: 10)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                const Icon(Icons.add_task, color: AppTheme.textMuted, size: 32),
                const SizedBox(height: 8),
                Text('No tasks yet. Add at least one task.', textAlign: TextAlign.center, style: AppTheme.label(color: AppTheme.textMuted, size: 13)),
              ]),
            )
          else
            ..._tasks.asMap().entries.map((e) => _TaskEditor(
              index: e.key, task: e.value,
              onRemove: () => _removeTask(e.key),
              onChanged: () => setState(() {}),
            )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _TaskEditor extends StatelessWidget {
  final int index;
  final Map<String, dynamic> task;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _TaskEditor({required this.index, required this.task, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppTheme.goldDim, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppTheme.gold.withOpacity(0.4))),
              child: Text('${index + 1}', style: AppTheme.mono(color: AppTheme.gold, size: 10)),
            ),
            const SizedBox(width: 10),
            Text('TASK ${index + 1}', style: AppTheme.label(color: AppTheme.textSecondary, size: 11)),
            const Spacer(),
            GestureDetector(onTap: onRemove, child: const Icon(Icons.delete_outline, color: AppTheme.rose, size: 18)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
              controller: task['titleCtrl'],
              decoration: const InputDecoration(labelText: 'Task Title'),
              style: AppTheme.label(color: AppTheme.textPrimary, size: 14),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: task['descCtrl'],
              decoration: const InputDecoration(labelText: 'Description'),
              style: AppTheme.label(color: AppTheme.textPrimary, size: 13),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(children: [
              _Counter(label: 'EXP', value: task['rewardExp'], color: AppTheme.gold,
                onDec: () { if (task['rewardExp'] > 1) { task['rewardExp']--; onChanged(); } },
                onInc: () { task['rewardExp']++; onChanged(); }),
              const SizedBox(width: 10),
              _Counter(label: 'PTS', value: task['rewardPoints'], color: AppTheme.violet,
                onDec: () { if (task['rewardPoints'] > 1) { task['rewardPoints']--; onChanged(); } },
                onInc: () { task['rewardPoints']++; onChanged(); }),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _Counter({required this.label, required this.value, required this.color, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: onDec, color: AppTheme.textMuted, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          Expanded(child: Text('$value', textAlign: TextAlign.center, style: AppTheme.mono(color: color, size: 12))),
          IconButton(icon: const Icon(Icons.add, size: 14), onPressed: onInc, color: AppTheme.textMuted, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ]),
      ),
    ]));
  }
}