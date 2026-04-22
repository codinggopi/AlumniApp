import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AlumniLeaderboardScreen extends StatefulWidget {
  const AlumniLeaderboardScreen({super.key});
  @override
  State<AlumniLeaderboardScreen> createState() => _AlumniLeaderboardScreenState();
}

class _AlumniLeaderboardScreenState extends State<AlumniLeaderboardScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/alumni/leaderboard');
      if (res.statusCode == 200 && mounted) {
        setState(() { _rows = jsonDecode(res.body); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏅 Leaderboard'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
          ? const Center(child: Text('No data yet. Start contributing!'))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = _rows[i];
                  final rank = r['rank'] as int;
                  final badges = (r['badges'] as List?) ?? [];
                  final rankColor = rank == 1 ? const Color(0xFFFFD700)
                      : rank == 2 ? const Color(0xFFC0C0C0)
                      : rank == 3 ? const Color(0xFFCD7F32)
                      : const Color(0xFF9E9E9E);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: rank <= 3 ? rankColor.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: rank <= 3 ? Border.all(color: rankColor.withValues(alpha: 0.4)) : null,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Center(child: Text(
                          rank <= 3 ? ['🥇','🥈','🥉'][rank-1] : '#$rank',
                          style: TextStyle(fontSize: rank <= 3 ? 18 : 13, fontWeight: FontWeight.w800),
                        )),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE3F2FD),
                        backgroundImage: (r['profile_picture_url'] != null && r['profile_picture_url'].toString().isNotEmpty)
                            ? NetworkImage(r['profile_picture_url'].toString().startsWith('http')
                                ? r['profile_picture_url'] : '${ApiService.baseUrl}${r['profile_picture_url']}')
                            : null,
                        child: (r['profile_picture_url'] == null || r['profile_picture_url'].toString().isEmpty)
                            ? const Icon(Icons.person, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (badges.isNotEmpty)
                          Text(badges.map((b) => '${b['icon']} ${b['name']}').join('  '),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${r['points']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF57C00))),
                        const Text('pts', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                      ]),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}
