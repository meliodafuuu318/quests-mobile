import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../profile/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _friends = [], _incoming = [], _sent = [], _searchResults = [];
  bool _loading = true, _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }

  @override
  void dispose() { _tabs.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fr = await ApiService.getFriends();
      final rr = await ApiService.getFriendRequests();
      if (fr['error'] == false) _friends = fr['results']['friends'] ?? [];
      if (rr['error'] == false) { _incoming = rr['results']['incomingRequests'] ?? []; _sent = rr['results']['sentRequests'] ?? []; }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final res = await ApiService.searchUsers(q);
      setState(() => _searchResults = res['error'] == false ? (res['results'] ?? []) : []);
    } catch (_) {}
    setState(() => _searching = false);
  }

  Future<void> _accept(String username) async {
    final res = await ApiService.acceptFriendRequest(username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? ''),
      backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COMPANIONS'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace'),
          tabs: [
            Tab(text: 'Friends (${_friends.length})'),
            Tab(text: 'Requests (${_incoming.length})'),
            const Tab(text: 'Search'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : TabBarView(controller: _tabs, children: [
              _buildFriends(),
              _buildRequests(),
              _buildSearch(),
            ]),
    );
  }

  Widget _buildFriends() {
    if (_friends.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.group_outlined, color: AppTheme.textMuted, size: 48),
      const SizedBox(height: 12),
      Text('No companions yet.\nSearch to add friends!', textAlign: TextAlign.center, style: AppTheme.label(color: AppTheme.textMuted)),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _friends.length,
      itemBuilder: (_, i) {
        final f = _friends[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: f['username']))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              UserAvatar(username: f['username'] ?? 'u'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['username'] ?? '', style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
                Text('Since ${f['friendsSince'] ?? ''}', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
              ])),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRequests() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_incoming.isNotEmpty) ...[
          SectionHeader(title: 'Incoming (${_incoming.length})'),
          const SizedBox(height: 12),
          ..._incoming.map((r) => _RequestTile(
            username: r['sender'] ?? '',
            subtitle: 'Sent ${r['sentOn'] ?? ''}',
            trailing: GlowButton(label: 'ACCEPT', color: AppTheme.cyan, onPressed: () => _accept(r['sender'])),
          )),
          const SizedBox(height: 24),
        ],
        if (_sent.isNotEmpty) ...[
          SectionHeader(title: 'Sent (${_sent.length})'),
          const SizedBox(height: 12),
          ..._sent.map((r) => _RequestTile(
            username: r['sentTo'] ?? '',
            subtitle: 'Sent ${r['sentOn'] ?? ''}',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
              child: Text('PENDING', style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
            ),
          )),
        ],
        if (_incoming.isEmpty && _sent.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.only(top: 60), child: Column(children: [
            const Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 40),
            const SizedBox(height: 12),
            Text('No friend requests', style: AppTheme.label(color: AppTheme.textMuted)),
          ]))),
      ],
    );
  }

  Widget _buildSearch() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by username or name...',
            prefixIcon: const Icon(Icons.search_outlined, size: 18),
            suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))) : null,
          ),
          onChanged: _search,
          style: AppTheme.label(color: AppTheme.textPrimary),
        ),
      ),
      Expanded(
        child: _searchResults.isEmpty
            ? Center(child: Text(_searchCtrl.text.isEmpty ? 'Start typing to search' : 'No users found', style: AppTheme.label(color: AppTheme.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final u = _searchResults[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      UserAvatar(username: u['username'] ?? 'u'),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${u['firstName'] ?? ''} ${u['lastName'] ?? ''}', style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
                        Text('@${u['username'] ?? ''}', style: AppTheme.label(color: AppTheme.textMuted, size: 12)),
                      ])),
                      GestureDetector(
                        onTap: () async {
                          final res = await ApiService.sendFriendRequest(u['username']);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res['message'] ?? ''),
                            backgroundColor: res['error'] == false ? AppTheme.cyan : AppTheme.rose,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.cyanDim, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.cyan.withOpacity(0.3))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.person_add_outlined, color: AppTheme.cyan, size: 14),
                            const SizedBox(width: 4),
                            Text('ADD', style: AppTheme.mono(color: AppTheme.cyan, size: 10)),
                          ]),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

class _RequestTile extends StatelessWidget {
  final String username, subtitle;
  final Widget trailing;
  const _RequestTile({required this.username, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        UserAvatar(username: username),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(username, style: AppTheme.label(color: AppTheme.textPrimary, size: 14, weight: FontWeight.w600)),
          Text(subtitle, style: AppTheme.label(color: AppTheme.textMuted, size: 11)),
        ])),
        trailing,
      ]),
    );
  }
}