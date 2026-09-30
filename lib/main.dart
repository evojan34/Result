import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

// -------------------------------------------------------------
// نماذج البيانات
// -------------------------------------------------------------
class GameRound {
  int s1, s2;
  GameRound(this.s1, this.s2);

  Map<String, dynamic> toJson() => {'s1': s1, 's2': s2};
  factory GameRound.fromJson(Map<String, dynamic> j) =>
      GameRound(j['s1'] ?? 0, j['s2'] ?? 0);
}

class GameMatch {
  final String id;
  String t1p1, t1p2, t2p1, t2p2;
  List<GameRound> rounds;
  String current1, current2, status;
  int winner;
  int durationSeconds;

  GameMatch({
    required this.id,
    required this.t1p1,
    required this.t1p2,
    required this.t2p1,
    required this.t2p2,
    required this.rounds,
    this.current1 = '',
    this.current2 = '',
    required this.status,
    this.winner = 0,
    this.durationSeconds = 0,
  });

  int get total1 => rounds.fold(0, (a, b) => a + b.s1) + (int.tryParse(current1) ?? 0);
  int get total2 => rounds.fold(0, (a, b) => a + b.s2) + (int.tryParse(current2) ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        't1p1': t1p1,
        't1p2': t1p2,
        't2p1': t2p1,
        't2p2': t2p2,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'current1': current1,
        'current2': current2,
        'status': status,
        'winner': winner,
        'durationSeconds': durationSeconds,
      };

  factory GameMatch.fromJson(Map<String, dynamic> j) => GameMatch(
        id: j['id'] ?? '',
        t1p1: j['t1p1'] ?? '',
        t1p2: j['t1p2'] ?? '',
        t2p1: j['t2p1'] ?? '',
        t2p2: j['t2p2'] ?? '',
        rounds: (j['rounds'] as List? ?? [])
            .map((r) => GameRound.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        current1: j['current1'] ?? '',
        current2: j['current2'] ?? '',
        status: j['status'] ?? 'مؤجلة',
        winner: j['winner'] ?? 0,
        durationSeconds: j['durationSeconds'] ?? 0,
      );
}

List<GameMatch> soloMatchesList = [];

class GroupData {
  String code;
  String name;
  String adminPin;
  List<GameMatch> matches = [];
  GroupData({required this.code, required this.name, this.adminPin = '1234'});

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'adminPin': adminPin,
        'matches': matches.map((m) => m.toJson()).toList(),
      };

  factory GroupData.fromJson(Map<String, dynamic> j) {
    var g = GroupData(
      code: j['code'] ?? '',
      name: j['name'] ?? 'كروب',
      adminPin: j['adminPin'] ?? '1234',
    );
    if (j['matches'] != null) {
      g.matches = (j['matches'] as List)
          .map((m) => GameMatch.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return g;
  }
}

// -------------------------------------------------------------
// محرك السحابة
// -------------------------------------------------------------
class CloudStorage {
  static const String host = 'https://games-242da-default-rtdb.firebaseio.com';

  static String _formatKey(String code) {
    return base64Url.encode(utf8.encode(code.trim().toLowerCase())).replaceAll('=', '');
  }

  static Future<bool> saveGroup(GroupData group) async {
    try {
      final key = _formatKey(group.code);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.putUrl(Uri.parse('$host/groups/$key.json'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(group.toJson()));
      final res = await req.close();
      await res.drain();
      client.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<GroupData?> fetchGroup(String code) async {
    try {
      final key = _formatKey(code);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse('$host/groups/$key.json'));
      final res = await req.close();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        if (body != 'null' && body.trim().isNotEmpty) {
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            client.close();
            return GroupData.fromJson(data);
          }
        }
      }
      client.close();
    } catch (_) {}
    return null;
  }

  static Future<void> deleteGroup(String code) async {
    try {
      final key = _formatKey(code);
      final client = HttpClient();
      final req = await client.deleteUrl(Uri.parse('$host/groups/$key.json'));
      final res = await req.close();
      await res.drain();
      client.close();
    } catch (_) {}
  }
}

class GroupManager {
  static GroupData? activeGroup;

  static Future<bool> createGroup(String name, String code, String pin) async {
    String cleanName = name.trim();
    String cleanCode = code.trim();
    String cleanPin = pin.trim().isEmpty ? '1234' : pin.trim();
    if (cleanName.isEmpty || cleanCode.isEmpty) return false;

    var newGroup = GroupData(code: cleanCode, name: cleanName, adminPin: cleanPin);
    activeGroup = newGroup;
    await CloudStorage.saveGroup(newGroup);
    return true;
  }

  static Future<void> updateActiveGroup() async {
    if (activeGroup != null) {
      await CloudStorage.saveGroup(activeGroup!);
    }
  }

  static Future<void> deleteActiveGroup() async {
    if (activeGroup != null) {
      await CloudStorage.deleteGroup(activeGroup!.code);
      activeGroup = null;
    }
  }
}

// -------------------------------------------------------------
// التطبيق الرئيسي
// -------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Natija',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B1E22)),
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});
  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final String bgImageUrl = 'https://images.pexels.com/photos/262333/pexels-photo-262333.jpeg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Natija', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(bgImageUrl), fit: BoxFit.cover)),
        child: Container(
          color: Colors.black.withOpacity(0.65),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.add_circle, color: Color(0xFFD4AF37)),
                    label: const Text('لعبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: false))).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24))),
                    icon: const Icon(Icons.history, color: Colors.amber),
                    label: Text('الألعاب السابقة (${soloMatchesList.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: false))).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 8),
                    icon: const Icon(Icons.cloud_sync, size: 28, color: Colors.black87),
                    label: const Text('لعبة الكروب (سحابي)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupSelectScreen())).then((_) => setState(() {}));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// بوابة الكروبات (تم إرجاع ميزة تأكيد اسم الكروب)
// -------------------------------------------------------------
class GroupSelectScreen extends StatefulWidget { const GroupSelectScreen({super.key}); @override State<GroupSelectScreen> createState() => _GroupSelectScreenState(); }
class _GroupSelectScreenState extends State<GroupSelectScreen> {
  final createNameCtrl = TextEditingController(), customCodeCtrl = TextEditingController(), customPinCtrl = TextEditingController(), enterCodeCtrl = TextEditingController();
  bool _isLoading = false;

  void _handleCreate() async {
    if (createNameCtrl.text.trim().isEmpty || customCodeCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    await GroupManager.createGroup(createNameCtrl.text.trim(), customCodeCtrl.text.trim(), customPinCtrl.text.trim().isEmpty ? '1234' : customPinCtrl.text.trim());
    setState(() => _isLoading = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GroupDashboardScreen()));
  }

  void _handleJoin() async {
    if (enterCodeCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    GroupData? remote = await CloudStorage.fetchGroup(enterCodeCtrl.text.trim());
    setState(() => _isLoading = false);

    if (remote == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text('لا يوجد كروب مسجل بهذا الرمز السري.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع'))],
        ),
      );
      return;
    }

    // إرجاع ميزة المطابقة الأمنية لاسم الكروب
    _showConfirmNameModal(remote);
  }

  void _showConfirmNameModal(GroupData group) {
    final nameConfirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد اسم الكروب', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تم العثور على الكروب!\nاكتب اسم الكروب للتأكيد والدخول:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 14),
            TextField(controller: nameConfirmCtrl, decoration: const InputDecoration(labelText: 'اسم الكروب', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
            onPressed: () {
              if (nameConfirmCtrl.text.trim().toLowerCase() == group.name.trim().toLowerCase()) {
                Navigator.pop(ctx);
                GroupManager.activeGroup = group;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GroupDashboardScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم الكروب غير مطابق للرمز السري!')));
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بوابة الكروبات'), backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('دخول كروب جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
              TextField(controller: createNameCtrl, decoration: const InputDecoration(hintText: 'اسم الكروب')),
              TextField(controller: customCodeCtrl, decoration: const InputDecoration(hintText: 'الرمز السري')),
              TextField(controller: customPinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'رمز المشرف (PIN)')),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _handleCreate, child: const Text('إنشاء ودخول')),
            ]))),
            const SizedBox(height: 20),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('لديك كروب؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              TextField(controller: enterCodeCtrl, decoration: const InputDecoration(hintText: 'الرمز السري للكروب')),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _handleJoin, child: const Text('دخول')),
            ]))),
          ],
        ),
      ),
    );
  }
}

class GroupDashboardScreen extends StatefulWidget { const GroupDashboardScreen({super.key}); @override State<GroupDashboardScreen> createState() => _GroupDashboardScreenState(); }
class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  bool _isSyncing = false;

  Future<void> _sync() async {
    if (GroupManager.activeGroup != null) {
      setState(() => _isSyncing = true);
      var updated = await CloudStorage.fetchGroup(GroupManager.activeGroup!.code);
      if (updated != null) setState(() => GroupManager.activeGroup = updated);
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var group = GroupManager.activeGroup;
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? ''), 
        backgroundColor: const Color(0xFF8B1E22), 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.sync),
            onPressed: _sync,
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37)),
                label: const Text('لعبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: true))).then((_) => setState(() {})); },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.history, color: Colors.amber),
                label: Text('لعبات سابقة (${group?.matches.length ?? 0})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: true))).then((_) => setState(() {})); },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.bar_chart, color: Color(0xFF8B1E22)),
                label: const Text('إحصائيات وألقاب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadToHeadScreen())).then((_) => setState(() {})); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// تحديد اللاعبين
// -------------------------------------------------------------
class SetupPlayersScreen extends StatefulWidget {
  final bool isGroupGame;
  const SetupPlayersScreen({super.key, required this.isGroupGame});
  @override State<SetupPlayersScreen> createState() => _SetupPlayersScreenState();
}

class _SetupPlayersScreenState extends State<SetupPlayersScreen> {
  final p1 = TextEditingController(), p2 = TextEditingController(), p3 = TextEditingController(), p4 = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد اللاعبين'), backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: p1, decoration: const InputDecoration(labelText: 'الفريق الأول - لاعب 1', border: OutlineInputBorder())), const SizedBox(height: 8),
          TextField(controller: p2, decoration: const InputDecoration(labelText: 'الفريق الأول - لاعب 2', border: OutlineInputBorder())), const SizedBox(height: 16),
          TextField(controller: p3, decoration: const InputDecoration(labelText: 'الفريق الثاني - لاعب 1', border: OutlineInputBorder())), const SizedBox(height: 8),
          TextField(controller: p4, decoration: const InputDecoration(labelText: 'الفريق الثاني - لاعب 2', border: OutlineInputBorder())), const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MatchScreen(
                isGroupGame: widget.isGroupGame,
                names: [p1.text.trim().isEmpty?'لاعب 1':p1.text.trim(), p2.text.trim().isEmpty?'لاعب 2':p2.text.trim(), p3.text.trim().isEmpty?'لاعب 3':p3.text.trim(), p4.text.trim().isEmpty?'لاعب 4':p4.text.trim()],
              )));
            },
            child: const Text('بدء المباراة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// شاشة المباراة: تصميم الصور الدقيق + الثيمات + الفائز اليدوي/الأقل نقاط
// -------------------------------------------------------------
class MatchScreen extends StatefulWidget {
  final bool isGroupGame;
  final List<String>? names;
  final GameMatch? matchToResume;

  const MatchScreen({super.key, required this.isGroupGame, this.names, this.matchToResume});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late String id, t1p1, t1p2, t2p1, t2p2;
  List<GameRound> rounds = [];
  final c1 = TextEditingController(), c2 = TextEditingController();
  
  bool showConfetti = false;
  String currentStatus = 'مؤجلة';
  int currentWinner = 0; 
  
  Timer? _timer;
  int _seconds = 0;
  
  // الثيمات: 0=النهاري الفاتح، 1=الليلي الداكن، 2=الخلفية الحمراء/الخشبية
  int currentThemeIndex = 0; 

  // إعدادات الثيمات (مطابقة للصورة المرسلة)
  final List<Map<String, dynamic>> appThemes = [
    {
      'bgUrl': 'https://images.unsplash.com/photo-1518623489648-a173ef7824f3?q=80&w=800&auto=format&fit=crop', // ثيم فاتح (جبال)
      'panelBg': Colors.white.withOpacity(0.9),
      'text': Colors.black87,
      'subText': Colors.black54,
      't1Box': Colors.green.shade50, 't1Text': Colors.green.shade700,
      'diffBox': Colors.blue.shade50, 'diffText': Colors.blue.shade700,
      't2Box': Colors.red.shade50, 't2Text': Colors.red.shade700,
      'rowBg1': Colors.white.withOpacity(0.9), 'rowBg2': Colors.grey.shade100.withOpacity(0.9),
      'divider': Colors.grey.shade300,
    },
    {
      'bgUrl': 'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=800&auto=format&fit=crop', // ثيم ليلي داكن
      'panelBg': const Color(0xFF0F172A).withOpacity(0.9),
      'text': Colors.white,
      'subText': Colors.grey.shade400,
      't1Box': const Color(0xFF064E3B), 't1Text': Colors.greenAccent,
      'diffBox': const Color(0xFF1E3A8A), 'diffText': Colors.lightBlueAccent,
      't2Box': const Color(0xFF7F1D1D), 't2Text': Colors.redAccent,
      'rowBg1': const Color(0xFF1E293B).withOpacity(0.9), 'rowBg2': const Color(0xFF0F172A).withOpacity(0.9),
      'divider': Colors.white12,
    },
    {
      'bgUrl': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=800&auto=format&fit=crop', // ثيم عنابي ملكي
      'panelBg': const Color(0xFF2A0800).withOpacity(0.9),
      'text': const Color(0xFFFFE0B2),
      'subText': const Color(0xFFD7CCC8),
      't1Box': const Color(0xFF14532D), 't1Text': Colors.greenAccent,
      'diffBox': const Color(0xFF1E3A8A), 'diffText': Colors.lightBlueAccent,
      't2Box': const Color(0xFF450A0A), 't2Text': Colors.redAccent,
      'rowBg1': const Color(0xFF3E1100).withOpacity(0.9), 'rowBg2': const Color(0xFF2A0800).withOpacity(0.9),
      'divider': Colors.white12,
    }
  ];

  @override
  void initState() {
    super.initState();
    if (widget.matchToResume != null) {
      var m = widget.matchToResume!;
      id = m.id; t1p1 = m.t1p1; t1p2 = m.t1p2; t2p1 = m.t2p1; t2p2 = m.t2p2;
      rounds = List.from(m.rounds);
      c1.text = m.current1; c2.text = m.current2;
      _seconds = m.durationSeconds;
      currentStatus = m.status;
      currentWinner = m.winner;
    } else {
      id = DateTime.now().millisecondsSinceEpoch.toString();
      t1p1 = widget.names![0]; t1p2 = widget.names![1];
      t2p1 = widget.names![2]; t2p2 = widget.names![3];
      _seconds = 0;
    }
    
    if (currentStatus != 'منتهية') {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    c1.dispose(); c2.dispose();
    super.dispose();
  }

  String get formattedTime {
    int m = _seconds ~/ 60;
    int s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get tot1 => rounds.fold(0, (a, b) => a + b.s1) + (int.tryParse(c1.text) ?? 0);
  int get tot2 => rounds.fold(0, (a, b) => a + b.s2) + (int.tryParse(c2.text) ?? 0);

  Future<void> saveState(String status, int winId) async {
    if (status == 'منتهية') _timer?.cancel(); 
    
    setState(() {
      currentStatus = status;
      currentWinner = winId;
      if (status == 'منتهية') showConfetti = true;
    });

    var m = GameMatch(
      id: id, t1p1: t1p1, t1p2: t1p2, t2p1: t2p1, t2p2: t2p2,
      rounds: List.from(rounds), current1: c1.text, current2: c2.text,
      status: status, winner: winId, durationSeconds: _seconds,
    );

    if (widget.isGroupGame) {
      var list = GroupManager.activeGroup?.matches ?? [];
      int idx = list.indexWhere((x) => x.id == id);
      if (idx != -1) list[idx] = m; else list.insert(0, m);
      await GroupManager.updateActiveGroup();
    } else {
      int idx = soloMatchesList.indexWhere((x) => x.id == id);
      if (idx != -1) soloMatchesList[idx] = m; else soloMatchesList.insert(0, m);
    }
    
    if (status == 'مؤجلة' && mounted) Navigator.pop(context);
  }

  void _finishMatchDialog() {
    HapticFeedback.heavyImpact();
    // اقتراح الفائز: الأقل نقاطاً
    int suggestedWinner = 0;
    if (tot1 < tot2) suggestedWinner = 1;
    else if (tot2 < tot1) suggestedWinner = 2;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديد الفائز', textAlign: TextAlign.center),
        content: const Text('من هو الفريق الفائز؟\n(في هذه اللعبة الأقل نقاطاً هو الفائز)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: suggestedWinner == 1 ? Colors.green.shade700 : Colors.grey.shade700, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              saveState('منتهية', 1);
            },
            child: Text('$t1p1 & $t1p2\n${suggestedWinner == 1 ? "(الأقل نقاطاً)" : ""}', textAlign: TextAlign.center),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: suggestedWinner == 2 ? Colors.green.shade700 : Colors.grey.shade700, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              saveState('منتهية', 2);
            },
            child: Text('$t2p1 & $t2p2\n${suggestedWinner == 2 ? "(الأقل نقاطاً)" : ""}', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int diff = (tot1 - tot2).abs();
    bool isFinished = currentStatus == 'منتهية';
    var t = appThemes[currentThemeIndex];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 20), const SizedBox(width: 6),
            Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.5), 
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.palette), onPressed: () => setState(() => currentThemeIndex = (currentThemeIndex + 1) % 3), tooltip: 'تغيير الثيم'),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: NetworkImage(t['bgUrl']), fit: BoxFit.cover),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- 1. البطاقات العلوية الملونة ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // اليمين: الفريق الثاني
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        decoration: BoxDecoration(color: t['t2Box'], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Text('$tot2', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: t['t2Text'], height: 1.1)),
                            const SizedBox(height: 6),
                            Text('$t2p1\n& $t2p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['t2Text'], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // الوسط: الفارق
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        decoration: BoxDecoration(color: t['diffBox'], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Text('$diff', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: t['diffText'], height: 1.1)),
                            const SizedBox(height: 6),
                            Text('الفارق', style: TextStyle(fontSize: 12, color: t['diffText'], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // اليسار: الفريق الأول
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        decoration: BoxDecoration(color: t['t1Box'], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Text('$tot1', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: t['t1Text'], height: 1.1)),
                            const SizedBox(height: 6),
                            Text('$t1p1\n& $t1p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['t1Text'], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. رأس الجدول الدقيق ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t['panelBg'],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: t['divider'], width: 1))
                ),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('الجولة', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['subText'], fontWeight: FontWeight.bold))),
                    Expanded(child: Text('$t2p1 & $t2p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['subText'], fontWeight: FontWeight.bold))),
                    Expanded(child: Text('الفارق', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['subText'], fontWeight: FontWeight.bold))),
                    Expanded(child: Text('$t1p1 & $t1p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: t['subText'], fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

              // --- 3. قائمة الجولات بخط واحد ---
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: t['panelBg'],
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rounds.length,
                    itemBuilder: (ctx, i) {
                      int rDiff = (rounds[i].s1 - rounds[i].s2).abs();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: i % 2 == 0 ? t['rowBg1'] : t['rowBg2']),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: t['subText'], fontSize: 13))),
                            Expanded(child: Text('${rounds[i].s2}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t['text']))),
                            Expanded(child: Text('$rDiff', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: t['subText']))),
                            Expanded(child: Text('${rounds[i].s1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t['text']))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // --- 4. المنطقة السفلية ---
              if (isFinished)
                Container(
                  margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: t['panelBg'], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                  child: Row(
                    children: [
                      // اليمين: الخاسر 
                      Expanded(
                        child: Column(
                          children: [
                            const Text('الخاسر 💔', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            const SizedBox(height: 4),
                            Text(currentWinner == 1 ? '$t2p1 & $t2p2' : '$t1p1 & $t1p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t['text'])),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: t['divider']),
                      // اليسار: الفائز (الأقل نقاطاً)
                      Expanded(
                        child: Column(
                          children: [
                            const Text('الفائز 🏆', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            const SizedBox(height: 4),
                            Text(currentWinner == 1 ? '$t1p1 & $t1p2' : '$t2p1 & $t2p2', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t['text'])),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: t['panelBg'], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                  child: Column(
                    children: [
                      // حقول الإدخال
                      Row(
                        children: [
                          Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(color: t['text']), decoration: InputDecoration(filled: true, fillColor: t['rowBg2'], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), hintText: '0', hintStyle: TextStyle(color: t['subText']), contentPadding: const EdgeInsets.symmetric(vertical: 10)), onChanged: (_) => setState(() {}))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, shape: const CircleBorder(), padding: const EdgeInsets.all(14)),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  rounds.add(GameRound(int.tryParse(c1.text) ?? 0, int.tryParse(c2.text) ?? 0));
                                  c1.clear(); c2.clear();
                                });
                              },
                              child: const Icon(Icons.add),
                            ),
                          ),
                          Expanded(child: TextField(controller: c1, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(color: t['text']), decoration: InputDecoration(filled: true, fillColor: t['rowBg2'], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), hintText: '0', hintStyle: TextStyle(color: t['subText']), contentPadding: const EdgeInsets.symmetric(vertical: 10)), onChanged: (_) => setState(() {}))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // أزرار التأجيل والإنهاء
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: t['subText'])),
                              onPressed: () => saveState('مؤجلة', 0),
                              child: Text('تأجيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: t['text'])),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: _finishMatchDialog,
                              child: const Text('انتهى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
      // إضافة عرض تأثير القصاصات
      floatingActionButton: showConfetti ? const IgnorePointer(child: CustomConfettiOverlay()) : null,
    );
  }
}

// -------------------------------------------------------------
// مؤثر القصاصات
// -------------------------------------------------------------
class CustomConfettiOverlay extends StatefulWidget { const CustomConfettiOverlay({super.key}); @override State<CustomConfettiOverlay> createState() => _CustomConfettiOverlayState(); }
class _CustomConfettiOverlayState extends State<CustomConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Color> colors = [Colors.red, const Color(0xFFD4AF37), Colors.blue, Colors.green, Colors.purple, Colors.orange];
  final random = Random();
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return CustomPaint(size: Size.infinite, painter: ConfettiPainter(_ctrl.value, colors, random)); }
}
class ConfettiPainter extends CustomPainter {
  final double progress; final List<Color> colors; final Random random;
  ConfettiPainter(this.progress, this.colors, this.random);
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 40; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      double x = (size.width / 40) * i + sin(progress * 4 + i) * 20;
      double y = progress * size.height * (0.8 + (i % 5) * 0.1);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// سجل الألعاب والإحصائيات
// -------------------------------------------------------------
class PastMatchesScreen extends StatefulWidget { final bool isGroupGame; const PastMatchesScreen({super.key, required this.isGroupGame}); @override State<PastMatchesScreen> createState() => _PastMatchesScreenState(); }
class _PastMatchesScreenState extends State<PastMatchesScreen> {
  @override Widget build(BuildContext context) {
    var list = widget.isGroupGame ? (GroupManager.activeGroup?.matches ?? []) : soloMatchesList;
    return Scaffold(
      appBar: AppBar(title: const Text('الألعاب السابقة'), backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final match = list[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              title: Text('${match.t1p1} & ${match.t1p2} ضد ${match.t2p1} & ${match.t2p2}'),
              subtitle: Text('النتيجة: ${match.total1} - ${match.total2}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(isGroupGame: widget.isGroupGame, matchToResume: match))).then((_) => setState(() {})); }),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                    setState(() => list.removeAt(i));
                    if (widget.isGroupGame) GroupManager.updateActiveGroup();
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});
  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  String? chosenPlayer;

  List<String> get finishedPlayers {
    Set<String> set = {};
    var matches = GroupManager.activeGroup?.matches ?? [];
    for (var m in matches.where((x) => x.status == 'منتهية')) {
      set.addAll([m.t1p1, m.t1p2, m.t2p1, m.t2p2]);
    }
    return set.toList();
  }

  Map<String, Map<String, int>> calculateStats(String player) {
    Map<String, Map<String, int>> stats = {};
    var matches = GroupManager.activeGroup?.matches ?? [];

    for (var m in matches.where((x) => x.status == 'منتهية')) {
      bool inT1 = (m.t1p1 == player || m.t1p2 == player);
      bool inT2 = (m.t2p1 == player || m.t2p2 == player);
      if (!inT1 && !inT2) continue;

      bool won = inT1 ? (m.winner == 1) : (m.winner == 2);
      List<String> opponents = inT1 ? [m.t2p1, m.t2p2] : [m.t1p1, m.t1p2];

      for (var opp in opponents) {
        stats.putIfAbsent(opp, () => {'wins': 0, 'losses': 0});
        if (won) {
          stats[opp]!['wins'] = stats[opp]!['wins']! + 1;
        } else {
          stats[opp]!['losses'] = stats[opp]!['losses']! + 1;
        }
      }
    }
    return stats;
  }

  void _resetStats() {
    final TextEditingController pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفير الإحصائيات (رمز المشرف)', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز المشرف PIN لتأكيد تصفير الإحصائيات:'),
            const SizedBox(height: 12),
            TextField(controller: pinCtrl, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (pinCtrl.text.trim() == (GroupManager.activeGroup?.adminPin ?? '1234')) {
                setState(() {
                  GroupManager.activeGroup?.matches.removeWhere((m) => m.status == 'منتهية');
                  chosenPlayer = null;
                });
                await GroupManager.updateActiveGroup();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير الإحصائيات بنجاح')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز المشرف غير صحيح!')));
              }
            },
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = finishedPlayers;
    if (chosenPlayer == null && players.isNotEmpty) chosenPlayer = players.first;
    final stats = (chosenPlayer != null) ? calculateStats(chosenPlayer!) : {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الكروب'),
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
        actions: [
          if (players.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'تصفير الإحصائيات',
              onPressed: _resetStats,
            ),
        ],
      ),
      body: players.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد إحصائيات حالياً.\nأنهِ مباراة واضغط "انتهى" لاحتساب النتائج.', textAlign: TextAlign.center),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8B1E22)), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: chosenPlayer,
                        items: players.map((p) => DropdownMenuItem(value: p, child: Text('اللاعب: $p', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setState(() => chosenPlayer = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: stats.isEmpty
                        ? const Center(child: Text('لا توجد مواجهات مسجلة لهذا اللاعب.'))
                        : ListView(
                            children: stats.entries.map((e) {
                              int w = e.value['wins'] ?? 0;
                              int l = e.value['losses'] ?? 0;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: w >= l ? Colors.green.shade100 : Colors.red.shade100,
                                    child: Icon(w >= l ? Icons.emoji_events : Icons.close, color: w >= l ? Colors.green : Colors.red),
                                  ),
                                  title: Text('ضد اللاعب: ${e.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: Text('فوز: $w | خسارة: $l', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
