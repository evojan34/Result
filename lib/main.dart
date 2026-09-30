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
// نماذج البيانات (تم إزالة الهدف)
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
  static const String currentVersion = '1.0.0';

  static String _formatKey(String code) {
    return base64Url.encode(utf8.encode(code.trim().toLowerCase())).replaceAll('=', '');
  }

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

// -------------------------------------------------------------
// 1. الشاشة الرئيسية
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

  void _checkUpdateAlert() async {
    final updateInfo = await CloudStorage.checkForUpdates();
    if (updateInfo != null && mounted) {
      String latest = updateInfo['version'] ?? '1.0.0';
      String note = updateInfo['notes'] ?? 'يوجد إصدار جديد من تطبيق Natija!';
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
                      HapticFeedback.lightImpact();
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
                      HapticFeedback.lightImpact();
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
                      HapticFeedback.mediumImpact();
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
  final TextEditingController customPinCtrl = TextEditingController();
  final TextEditingController enterCodeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    createNameCtrl.dispose();
    customCodeCtrl.dispose();
    customPinCtrl.dispose();
    enterCodeCtrl.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    String name = createNameCtrl.text.trim();
    String code = customCodeCtrl.text.trim();
    String pin = customPinCtrl.text.trim().isEmpty ? '1234' : customPinCtrl.text.trim();

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة اسم الكروب والرمز السري')));
      return;
    }

    setState(() => _isLoading = true);
    await GroupManager.createGroup(name, code, pin);
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
                  const Icon(Icons.shield_outlined, size: 64, color: Color(0xFF8B1E22)),
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
                          TextField(controller: customCodeCtrl, decoration: const InputDecoration(hintText: 'الرمز السري المخصص للكروب', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          TextField(
                            controller: customPinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'رمز المشرف السري (Admin PIN) للحذف والتصفير', border: OutlineInputBorder()),
                          ),
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
// 3. داخل الكروب المشترك (بدون اللايف)
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

  void _verifyAdminAndExecute(String actionTitle, Function onVerified) {
    final TextEditingController pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(actionTitle, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز المشرف السري (Admin PIN) للمتابعة:', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (pinCtrl.text.trim() == (GroupManager.activeGroup?.adminPin ?? '1234')) {
                Navigator.pop(ctx);
                onVerified();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز المشرف غير صحيح!')));
              }
            },
            child: const Text('تأكيد'),
          )
        ],
      ),
    );
  }

  void _confirmDeleteGroup() {
    _verifyAdminAndExecute('مسح الكروب نهائياً', () async {
      await GroupManager.deleteActiveGroup();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GroupSelectScreen()));
    });
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
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: true))).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.history, color: Colors.amber),
                label: Text('لعبات سابقة ($matchesCount)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: true))).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.bar_chart, color: Color(0xFF8B1E22)),
                label: const Text('إحصائيات وألقاب اللاعبين', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                onPressed: () {
                  HapticFeedback.lightImpact();
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
// 4. تحديد اللاعبين (بدون إعدادات سقف هدف)
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

// -------------------------------------------------------------
// 5. شاشة المباراة (التصميم العصري الجديد والمضغوط)
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

  // دالة الحفظ الذكية (بدون تعليق الشاشة)
  Future<void> saveState(String status, int win) async {
    if (status == 'منتهية') _timer?.cancel(); 
    
    setState(() {
      currentStatus = status;
      currentWinner = win;
    });

    var m = GameMatch(
      id: id, t1p1: t1p1, t1p2: t1p2, t2p1: t2p1, t2p2: t2p2,
      rounds: List.from(rounds), current1: c1.text, current2: c2.text,
      status: status, winner: win, durationSeconds: _seconds,
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
    
    // الخروج فقط في حالة التأجيل
    if (status == 'مؤجلة' && mounted) {
       Navigator.pop(context);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    int diff = (tot1 - tot2).abs();
    bool isFinished = currentStatus == 'منتهية';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 20),
            const SizedBox(width: 6),
            Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B1E22), 
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. رأس الصفحة (الفرق على الأطراف والفارق في المنتصف) ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // الفريق الأول (يمين)
                    Column(
                      children: [
                        Text('$tot1', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.red.shade700, height: 1.1)),
                        Text('$t1p1\n& $t1p2', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // الفارق (وسط)
                    Column(
                      children: [
                        const Text('الفارق', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('$diff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade700, height: 1.1)),
                      ],
                    ),
                    // الفريق الثاني (يسار)
                    Column(
                      children: [
                        Text('$tot2', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.green.shade700, height: 1.1)),
                        Text('$t2p1\n& $t2p2', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // --- 2. قائمة الجولات المضغوطة (تتسع لـ 9 جولات وأكثر) ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  itemCount: rounds.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: i % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          // التسلسل فقط على الطرف الأيمن
                          SizedBox(width: 30, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500, fontSize: 16))),
                          
                          // نتيجة الفريق الأول
                          Expanded(child: Center(child: Text('${rounds[i].s1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)))),
                          
                          // نتيجة الفريق الثاني
                          Expanded(child: Center(child: Text('${rounds[i].s2}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)))),
                          
                          // أيقونات التعديل (تصغر أو تختفي عند الانتهاء)
                          if (!isFinished) Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(onTap: () => _editRound(i), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.edit, size: 18, color: Colors.blue.shade400))),
                              InkWell(onTap: () => setState(()=>rounds.removeAt(i)), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.delete, size: 18, color: Colors.red.shade400))),
                            ],
                          ) else const SizedBox(width: 52), // موازنة المساحة
                        ],
                      ),
                    );
                  },
                ),
              ),

              // --- 3. المنطقة السفلية (إما شريط الإدخال أو شريط الفائز/الخاسر) ---
              if (isFinished)
                Column(
                  children: [
                    Divider(thickness: 3, color: Colors.grey.shade300, height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('🏆 الفائز', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                                const SizedBox(height: 6),
                                Text(currentWinner == 1 ? '$t1p1 & $t1p2' : '$t2p1 & $t2p2', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ),
                          Container(width: 2, height: 60, color: Colors.grey.shade200),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('💔 الخاسر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                                const SizedBox(height: 6),
                                Text(currentWinner == 1 ? '$t2p1 & $t2p2' : '$t1p1 & $t1p2', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                )
              else
                Column(
                  children: [
                    // حقول الإدخال المضغوطة
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
                      child: Row(
                        children: [
                          Expanded(child: TextField(controller: c1, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: '0', contentPadding: const EdgeInsets.symmetric(vertical: 10)), onChanged: (_) => setState(() {}))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white, shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
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
                          Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: '0', contentPadding: const EdgeInsets.symmetric(vertical: 10)), onChanged: (_) => setState(() {}))),
                        ],
                      ),
                    ),
                    
                    // أزرار تأجيل وإنهاء
                    Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () => saveState('مؤجلة', 0),
                              child: const Text('تأجيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('من الفريق الفائز؟', textAlign: TextAlign.center),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dCtx); // يغلق نافذة السؤال فقط
                                          setState(() => showConfetti = true); // يشغل الاحتفال
                                          saveState('منتهية', 1); // يغير حالة الشاشة بذكاء بدون تعليق
                                        },
                                        child: Text('$t1p1 و $t1p2'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dCtx);
                                          setState(() => showConfetti = true);
                                          saveState('منتهية', 2);
                                        },
                                        child: Text('$t2p1 و $t2p2'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text('انتهى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                )
            ],
          ),
          if (showConfetti) const CustomConfettiOverlay(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// مؤثر القصاصات الاحتفالية
// -------------------------------------------------------------
class CustomConfettiOverlay extends StatefulWidget {
  const CustomConfettiOverlay({super.key});

  @override
  State<CustomConfettiOverlay> createState() => _CustomConfettiOverlayState();
}

class _CustomConfettiOverlayState extends State<CustomConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Color> colors = [Colors.red, const Color(0xFFD4AF37), Colors.blue, Colors.green, Colors.purple, Colors.orange];
  final random = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: ConfettiPainter(_ctrl.value, colors, random),
          );
        },
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final Random random;
  ConfettiPainter(this.progress, this.colors, this.random);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 40; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      double x = (size.width / 40) * i + sin(progress * 4 + i) * 20;
      double y = progress * size.height * (0.8 + (i % 5) * 0.1);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// سجل الألعاب السابقة
// -------------------------------------------------------------
class PastMatchesScreen extends StatefulWidget {
  final bool isGroupGame;
  const PastMatchesScreen({super.key});

  @override
  State<PastMatchesScreen> createState() => _PastMatchesScreenState();
}

class _PastMatchesScreenState extends State<PastMatchesScreen> {
  String _formatTime(int sec) {
    if (sec == 0) return '';
    int m = sec ~/ 60;
    int s = sec % 60;
    return '⏱️ ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
                    subtitle: Text('النتيجة: ${match.total1} - ${match.total2} | ${_formatTime(match.durationSeconds)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.blue),
                          tooltip: 'فتح اللعبة',
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

// -------------------------------------------------------------
// شاشة الإحصائيات والألقاب
// -------------------------------------------------------------
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

  Map<String, String> getSpecialTitles() {
    var matches = GroupManager.activeGroup?.matches.where((x) => x.status == 'منتهية').toList() ?? [];
    if (matches.isEmpty) return {};

    Map<String, int> wins = {};
    Map<String, int> losses = {};
    Map<String, int> duoWins = {};

    for (var m in matches) {
      String p1 = m.t1p1, p2 = m.t1p2, p3 = m.t2p1, p4 = m.t2p2;
      String d1 = p1.compareTo(p2) < 0 ? '$p1 & $p2' : '$p2 & $p1';
      String d2 = p3.compareTo(p4) < 0 ? '$p3 & $p4' : '$p4 & $p3';

      if (m.winner == 1) {
        wins[p1] = (wins[p1] ?? 0) + 1;
        wins[p2] = (wins[p2] ?? 0) + 1;
        losses[p3] = (losses[p3] ?? 0) + 1;
        losses[p4] = (losses[p4] ?? 0) + 1;
        duoWins[d1] = (duoWins[d1] ?? 0) + 1;
      } else if (m.winner == 2) {
        wins[p3] = (wins[p3] ?? 0) + 1;
        wins[p4] = (wins[p4] ?? 0) + 1;
        losses[p1] = (losses[p1] ?? 0) + 1;
        losses[p2] = (losses[p2] ?? 0) + 1;
        duoWins[d2] = (duoWins[d2] ?? 0) + 1;
      }
    }

    String executioner = wins.entries.isNotEmpty ? wins.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'لا يوجد';
    String victim = losses.entries.isNotEmpty ? losses.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'لا يوجد';
    String bestDuo = duoWins.entries.isNotEmpty ? duoWins.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'لا يوجد';

    return {
      'executioner': executioner,
      'victim': victim,
      'bestDuo': bestDuo,
    };
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
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير الإحصائيات بنجاح')));
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
    final titles = getSpecialTitles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات وألقاب الكروب'),
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
                child: Text('لا توجد إحصائيات حالياً.\nأنهِ مباراة واضغط "انتهى" لاحتساب النتائج وتوليد الألقاب.', textAlign: TextAlign.center),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('⚔️ الجلّاد: ${titles['executioner']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('🎯 الضحية: ${titles['victim']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('🤝 أفضل ثنائي: ${titles['bestDuo']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
