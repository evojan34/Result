import 'dart:convert';
import 'dart:io';
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
      );
}

List<GameMatch> soloMatchesList = [];

class GroupData {
  String code;
  String name;
  List<GameMatch> matches = [];
  GroupData({required this.code, required this.name});

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'matches': matches.map((m) => m.toJson()).toList(),
      };

  factory GroupData.fromJson(Map<String, dynamic> j) {
    var g = GroupData(code: j['code'] ?? '', name: j['name'] ?? 'كروب');
    if (j['matches'] != null) {
      g.matches = (j['matches'] as List)
          .map((m) => GameMatch.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return g;
  }
}

// -------------------------------------------------------------
// محرك السحابة والتحديثات المستقبلية
// -------------------------------------------------------------
class CloudStorage {
  static const String host = 'https://games-242da-default-rtdb.firebaseio.com';
  static const String currentVersion = '1.0.0';

  static String _formatKey(String code) {
    return base64Url.encode(utf8.encode(code.trim().toLowerCase())).replaceAll('=', '');
  }

  // فحص التحديثات الجديدة عبر السحابة
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('$host/app_update.json'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        if (body != 'null' && body.trim().isNotEmpty) {
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            client.close();
            return data;
          }
        }
      }
      client.close();
    } catch (_) {}
    return null;
  }

  // حفظ الكروب في قاعدة بياناتك
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

  // استرجاع الكروب
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

  // حذف الكروب نهائياً
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

  static Future<bool> createGroup(String name, String code) async {
    String cleanName = name.trim();
    String cleanCode = code.trim();
    if (cleanName.isEmpty || cleanCode.isEmpty) return false;

    var newGroup = GroupData(code: cleanCode, name: cleanName);
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
    );
  }
}

// -------------------------------------------------------------
// 1. الشاشة الرئيسية مع نظام فحص التحديثات
// -------------------------------------------------------------
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final String bgImageUrl =
      'https://images.pexels.com/photos/262333/pexels-photo-262333.jpeg';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateAlert();
    });
  }

  // فحص إصدار التطبيق وعرض نافذة التحديث
  void _checkUpdateAlert() async {
    final updateInfo = await CloudStorage.checkForUpdates();
    if (updateInfo != null && mounted) {
      String latest = updateInfo['version'] ?? '1.0.0';
      String note = updateInfo['notes'] ?? 'يوجد إصدار جديد من تطبيق Natija بميزات إضافية!';
      String url = updateInfo['url'] ?? '';

      if (latest != CloudStorage.currentVersion) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.system_update, color: Color(0xFF8B1E22)),
                SizedBox(width: 8),
                Text('تحديث جديد متاح'),
              ],
            ),
            content: Text('الإصدار الحالي: ${CloudStorage.currentVersion}\nالإصدار الجديد: $latest\n\n$note'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ رابط التحديث، الصقه في المتصفح للتحميل.')),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('نسخ رابط التحديث'),
              ),
            ],
          ),
        );
      }
    }
  }

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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(image: NetworkImage(bgImageUrl), fit: BoxFit.cover),
        ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E22),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_circle, color: Color(0xFFD4AF37)),
                    label: const Text('لعبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: false)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                    ),
                    icon: const Icon(Icons.history, color: Colors.amber),
                    label: Text('الألعاب السابقة (${soloMatchesList.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: false)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                    ),
                    icon: const Icon(Icons.cloud_sync, size: 28, color: Colors.black87),
                    label: const Text('لعبة الكروب (سحابي)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupSelectScreen()),
                      ).then((_) => setState(() {}));
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
// 2. بوابة الكروبات
// -------------------------------------------------------------
class GroupSelectScreen extends StatefulWidget {
  const GroupSelectScreen({super.key});

  @override
  State<GroupSelectScreen> createState() => _GroupSelectScreenState();
}

class _GroupSelectScreenState extends State<GroupSelectScreen> {
  final TextEditingController createNameCtrl = TextEditingController();
  final TextEditingController customCodeCtrl = TextEditingController();
  final TextEditingController enterCodeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    createNameCtrl.dispose();
    customCodeCtrl.dispose();
    enterCodeCtrl.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    String name = createNameCtrl.text.trim();
    String code = customCodeCtrl.text.trim();

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة اسم الكروب والرمز السري')));
      return;
    }

    setState(() => _isLoading = true);
    await GroupManager.createGroup(name, code);
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GroupDashboardScreen()),
    );
  }

  void _handleJoin() async {
    String code = enterCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الرمز السري للكروب')));
      return;
    }

    setState(() => _isLoading = true);
    GroupData? remote = await CloudStorage.fetchGroup(code);
    setState(() => _isLoading = false);

    if (remote == null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('تنبيه'),
            ],
          ),
          content: Text('لا يوجد كروب مسجل بهذا الرمز السري ($code).\nيرجى التأكد من الرمز السري ثانية.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('رجوع'),
            ),
          ],
        ),
      );
      return;
    }

    _showConfirmNameModal(remote);
  }

  void _showConfirmNameModal(GroupData group) {
    final TextEditingController nameConfirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد اسم الكروب', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تم العثور على الكروب!\nاكتب اسم الكروب للتأكيد والدخول:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameConfirmCtrl,
              decoration: const InputDecoration(labelText: 'اسم الكروب', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
            onPressed: () {
              String entered = nameConfirmCtrl.text.trim();
              if (entered.isEmpty) return;

              if (entered.toLowerCase() == group.name.trim().toLowerCase()) {
                Navigator.pop(ctx);
                GroupManager.activeGroup = group;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupDashboardScreen()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اسم الكروب غير مطابق للرمز السري المدخل!')),
                );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1E22)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.cloud_done, size: 64, color: Color(0xFF8B1E22)),
                  const SizedBox(height: 12),
                  const Text(
                    'الكروبات تحفظ وتسترجع تلقائياً من السحابة عبر الرمز السري واسم الكروب',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('دخول كروب جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                          const Divider(height: 18),
                          TextField(controller: createNameCtrl, decoration: const InputDecoration(hintText: 'اسم الكروب', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          TextField(controller: customCodeCtrl, decoration: const InputDecoration(hintText: 'الرمز السري المخصص', border: OutlineInputBorder())),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
                            onPressed: _handleCreate,
                            child: const Text('حفظ الكروب سحابياً ودخول'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('لديك كروب؟ ضع الرمز السري', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const Divider(height: 18),
                          TextField(controller: enterCodeCtrl, decoration: const InputDecoration(hintText: 'اكتب الرمز السري للكروب', border: OutlineInputBorder())),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                            onPressed: _handleJoin,
                            child: const Text('دخول للكروب بالرمز السري'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// -------------------------------------------------------------
// 3. داخل الكروب المشترك
// -------------------------------------------------------------
class GroupDashboardScreen extends StatefulWidget {
  const GroupDashboardScreen({super.key});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  bool _isSyncing = false;

  Future<void> _sync() async {
    if (GroupManager.activeGroup != null) {
      setState(() => _isSyncing = true);
      var updated = await CloudStorage.fetchGroup(GroupManager.activeGroup!.code);
      if (updated != null) {
        setState(() {
          GroupManager.activeGroup = updated;
        });
      }
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة النتائج سحابياً بنجاح!')));
    }
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح الكروب نهائياً', textAlign: TextAlign.center),
        content: const Text('هل أنت متأكد من مسح هذا الكروب من السيرفر نهائياً؟ لن يستطيع أحد الدخول إليه بعد ذلك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await GroupManager.deleteActiveGroup();
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GroupSelectScreen()));
            },
            child: const Text('نعم، مسح الكروب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var group = GroupManager.activeGroup;
    String gName = group?.name ?? 'الكروب';
    String gCode = group?.code ?? '';
    int matchesCount = group?.matches.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$gName ($gCode)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'مزامنة وتحديث النتائج',
            onPressed: _sync,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            tooltip: 'مسح الكروب',
            onPressed: _confirmDeleteGroup,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37)),
                label: const Text('لعبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: true))).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.history, color: Colors.amber),
                label: Text('لعبات سابقة ($matchesCount)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: true))).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.bar_chart, color: Color(0xFF8B1E22)),
                label: const Text('إحصائيات (لاعب ضد لاعب)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadToHeadScreen())).then((_) => setState(() {}));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// الشاشات المتبقية (تحديد اللاعبين، شاشة المباراة، السجل، والإحصائيات)
// -------------------------------------------------------------
class SetupPlayersScreen extends StatefulWidget {
  final bool isGroupGame;
  const SetupPlayersScreen({super.key, required this.isGroupGame});

  @override
  State<SetupPlayersScreen> createState() => _SetupPlayersScreenState();
}

class _SetupPlayersScreenState extends State<SetupPlayersScreen> {
  final p1 = TextEditingController(), p2 = TextEditingController(), p3 = TextEditingController(), p4 = TextEditingController();

  @override
  void dispose() {
    p1.dispose(); p2.dispose(); p3.dispose(); p4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isGroupGame ? 'لاعبي مباراة الكروب' : 'تحديد لاعبي الفريقين'), backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: p1, decoration: const InputDecoration(labelText: 'الفريق الأول - لاعب 1', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: p2, decoration: const InputDecoration(labelText: 'الفريق الأول - لاعب 2', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: p3, decoration: const InputDecoration(labelText: 'الفريق الثاني - لاعب 1', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: p4, decoration: const InputDecoration(labelText: 'الفريق الثاني - لاعب 2', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchScreen(
                    isGroupGame: widget.isGroupGame,
                    names: [
                      p1.text.trim().isEmpty ? 'لاعب 1' : p1.text.trim(),
                      p2.text.trim().isEmpty ? 'لاعب 2' : p2.text.trim(),
                      p3.text.trim().isEmpty ? 'لاعب 3' : p3.text.trim(),
                      p4.text.trim().isEmpty ? 'لاعب 4' : p4.text.trim(),
                    ],
                  ),
                ),
              );
            },
            child: const Text('بدء المباراة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    if (widget.matchToResume != null) {
      var m = widget.matchToResume!;
      id = m.id; t1p1 = m.t1p1; t1p2 = m.t1p2; t2p1 = m.t2p1; t2p2 = m.t2p2;
      rounds = List.from(m.rounds);
      c1.text = m.current1; c2.text = m.current2;
    } else {
      id = DateTime.now().millisecondsSinceEpoch.toString();
      t1p1 = widget.names![0]; t1p2 = widget.names![1];
      t2p1 = widget.names![2]; t2p2 = widget.names![3];
    }
  }

  @override
  void dispose() {
    c1.dispose(); c2.dispose();
    super.dispose();
  }

  int get tot1 => rounds.fold(0, (a, b) => a + b.s1) + (int.tryParse(c1.text) ?? 0);
  int get tot2 => rounds.fold(0, (a, b) => a + b.s2) + (int.tryParse(c2.text) ?? 0);

  void _editRound(int index) {
    var edit1 = TextEditingController(text: '${rounds[index].s1}');
    var edit2 = TextEditingController(text: '${rounds[index].s2}');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل نتيجة لعبة ${index + 1}', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: edit1, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '$t1p1 & $t1p2')),
            const SizedBox(height: 10),
            TextField(controller: edit2, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '$t2p1 & $t2p2')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                rounds[index].s1 = int.tryParse(edit1.text) ?? 0;
                rounds[index].s2 = int.tryParse(edit2.text) ?? 0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }

  void save(String status, int win) async {
    var m = GameMatch(
      id: id, t1p1: t1p1, t1p2: t1p2, t2p1: t2p1, t2p2: t2p2,
      rounds: List.from(rounds), current1: c1.text, current2: c2.text,
      status: status, winner: win,
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

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل اللعبة'), backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [Text('$t1p1 & $t1p2', style: const TextStyle(fontWeight: FontWeight.bold)), Text('$tot1', style: const TextStyle(fontSize: 26, color: Color(0xFF8B1E22), fontWeight: FontWeight.bold))]),
                const Text('المجموع', style: TextStyle(fontWeight: FontWeight.bold)),
                Column(children: [Text('$t2p1 & $t2p2', style: const TextStyle(fontWeight: FontWeight.bold)), Text('$tot2', style: const TextStyle(fontSize: 26, color: Color(0xFF8B1E22), fontWeight: FontWeight.bold))]),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (int i = 0; i < rounds.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('${rounds[i].s1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('لعبة ${i + 1} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _editRound(i)),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => setState(() => rounds.removeAt(i))),
                          ],
                        ),
                        Text('${rounds[i].s2}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: c1, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'), onChanged: (_) => setState(() {}))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('لعبة ${rounds.length + 1}')),
                      Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'), onChanged: (_) => setState(() {}))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        rounds.add(GameRound(int.tryParse(c1.text) ?? 0, int.tryParse(c2.text) ?? 0));
                        c1.clear(); c2.clear();
                      });
                    },
                    child: Text('تأكيد لعبة ${rounds.length + 1} وفتح التالية'),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => save('مؤجلة', 0), child: const Text('تأجيل'))),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) => AlertDialog(
                          title: const Text('الفريق الفائز'),
                          actions: [
                            TextButton(onPressed: () { Navigator.pop(context); save('منتهية', 1); }, child: Text('$t1p1 و $t1p2')),
                            TextButton(onPressed: () { Navigator.pop(context); save('منتهية', 2); }, child: Text('$t2p1 و $t2p2')),
                          ],
                        ),
                      );
                    },
                    child: const Text('انتهى'),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class PastMatchesScreen extends StatefulWidget {
  final bool isGroupGame;
  const PastMatchesScreen({super.key, required this.isGroupGame});

  @override
  State<PastMatchesScreen> createState() => _PastMatchesScreenState();
}

class _PastMatchesScreenState extends State<PastMatchesScreen> {
  @override
  Widget build(BuildContext context) {
    var list = widget.isGroupGame
        ? (GroupManager.activeGroup?.matches ?? [])
        : soloMatchesList;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGroupGame ? 'لعبات الكروب السابقة' : 'الألعاب السابقة'),
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
      ),
      body: list.isEmpty
          ? const Center(child: Text('لا توجد مباريات مسجلة بعد.'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final match = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    title: Text('${match.t1p1} & ${match.t1p2} ضد ${match.t2p1} & ${match.t2p2}'),
                    subtitle: Text('الحالة: ${match.status} | النتيجة: ${match.total1} - ${match.total2}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل نتيجة اللعبة',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchScreen(isGroupGame: widget.isGroupGame, matchToResume: match),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'مسح اللعبة',
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('تأكيد مسح اللعبة'),
                                content: const Text('هل أنت متأكد من حذف هذه اللعبة؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      setState(() {
                                        list.removeAt(i);
                                      });
                                      if (widget.isGroupGame) {
                                        await GroupManager.updateActiveGroup();
                                      }
                                      Navigator.pop(dCtx);
                                    },
                                    child: const Text('مسح'),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفير ومسح الإحصائيات', textAlign: TextAlign.center),
        content: const Text(
          'هل تريد مسح سجل نتائج المواجهات؟ سيتم تصفير النتائج ومزامنتها سحابياً عند الجميع.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              setState(() {
                GroupManager.activeGroup?.matches.removeWhere((m) => m.status == 'منتهية');
                chosenPlayer = null;
              });
              await GroupManager.updateActiveGroup();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير الإحصائيات بنجاح')));
            },
            child: const Text('نعم، مسح وتصفير'),
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
        title: const Text('إحصائيات الكروب (لاعب ضد لاعب)'),
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
                  const SizedBox(height: 16),
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
