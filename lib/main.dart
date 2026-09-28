
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
}

class GameMatch {
  final String id, t1p1, t1p2, t2p1, t2p2;
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
}

// قائمة مباريات الألعاب العادية
List<GameMatch> soloMatchesList = [];

// إدارة الكروبات
class GroupData {
  String code;
  String name;
  List<GameMatch> matches = [];
  GroupData({required this.code, required this.name});
}

class GroupManager {
  // تخزين الكروبات في قائمة لدعم تكرار نفس الرمز لأسماء مختلفة
  static final List<GroupData> allGroups = [];
  static GroupData? activeGroup;

  // إنشاء كروب مخصص
  static bool createGroupCustom(String name, String customCode) {
    String cleanName = name.trim();
    String cleanCode = customCode.trim();
    if (cleanName.isEmpty || cleanCode.isEmpty) return false;

    // فحص ما إذا كان نفس الاسم ونفس الرمز موجودين معاً
    int idx = allGroups.indexWhere((g) => g.code == cleanCode && g.name == cleanName);
    if (idx != -1) {
      activeGroup = allGroups[idx];
    } else {
      var newG = GroupData(code: cleanCode, name: cleanName);
      allGroups.add(newG);
      activeGroup = newG;
    }
    return true;
  }

  // البحث عن الكروبات المطابقة للرمز
  static List<GroupData> findGroupsByCode(String code) {
    String cleanCode = code.trim();
    return allGroups.where((g) => g.code == cleanCode).toList();
  }

  // الدخول المباشر إذا كان الاسم مطابقاً
  static bool joinGroupByNameAndCode(String code, String name) {
    String cleanCode = code.trim();
    String cleanName = name.trim();
    int idx = allGroups.indexWhere((g) => g.code == cleanCode && g.name.toLowerCase() == cleanName.toLowerCase());
    if (idx != -1) {
      activeGroup = allGroups[idx];
      return true;
    } else {
      // إنشاء الكروب بالاسم والرمز المدخلين
      var newG = GroupData(code: cleanCode, name: cleanName);
      allGroups.add(newG);
      activeGroup = newG;
      return true;
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
      title: 'لوحة الألعاب',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B1E22)),
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
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
      'https://images.unsplash.com/photo-1541278107931-e006523892df?q=80&w=1000&auto=format&fit=crop';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('لوحة تحكم الألعاب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
          color: Colors.black.withOpacity(0.6),
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
                    icon: const Icon(Icons.groups, size: 28, color: Colors.black87),
                    label: const Text('لعبة الكروب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
// 2. شاشة بوابة الكروب: التحقق من تشابه الرمز وطلب الاسم عند الحاجة
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

  @override
  void dispose() {
    createNameCtrl.dispose();
    customCodeCtrl.dispose();
    enterCodeCtrl.dispose();
    super.dispose();
  }

  void _handleCreate() {
    String name = createNameCtrl.text.trim();
    String code = customCodeCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة اسم الكروب أولاً')));
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة الرمز السري للكروب')));
      return;
    }

    GroupManager.createGroupCustom(name, code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إنشاء الكروب باسم: $name'), duration: const Duration(seconds: 3)),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GroupDashboardScreen()),
    );
  }

  void _handleJoin() {
    String code = enterCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الرمز السري للكروب')));
      return;
    }

    List<GroupData> matchingGroups = GroupManager.findGroupsByCode(code);

    // الحالة 1: الرمز غير مسجل سابقاً أو مسجل لكروب واحد فقط
    if (matchingGroups.isEmpty) {
      // كروب جديد تماماً، يطلب تحديد الاسم
      _askForGroupNameDialog(code, 'لم يتم العثور على كروب بهذا الرمز. اكتب اسم الكروب للدخول:');
    } else if (matchingGroups.length == 1) {
      // كروب واحد فقط يمتلك هذا الرمز -> دخول مباشر
      GroupManager.activeGroup = matchingGroups.first;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GroupDashboardScreen()),
      );
    } else {
      // الحالة 2: هناك أكثر من كروب يحملون نفس الرمز بالصدفة -> طلب اسم الكروب للتحديد
      _askForGroupNameDialog(code, 'تنبيه: يوجد أكثر من كروب بهذا الرمز!\nيرجى كتابة اسم الكروب للدخول إلى مجموعتك:');
    }
  }

  // نافذة طلب اسم الكروب
  void _askForGroupNameDialog(String code, String message) {
    final TextEditingController nameConfirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد اسم الكروب', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: nameConfirmCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الكروب',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.groups),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1E22), foregroundColor: Colors.white),
            onPressed: () {
              String name = nameConfirmCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              GroupManager.joinGroupByNameAndCode(code, name);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GroupDashboardScreen()),
              );
            },
            child: const Text('تأكيد ودخول'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة الكروبات'),
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, size: 64, color: Color(0xFF8B1E22)),
            const SizedBox(height: 12),
            const Text(
              'أنشئ كروب وحدد الرمز السري، أو ادخل إلى كروبك بكتابة الرمز السري الخاص به',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // إنشاء كروب جديد
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.group_add, color: Color(0xFF8B1E22)),
                        SizedBox(width: 8),
                        Text('دخول كروب جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                      ],
                    ),
                    const Divider(height: 18),
                    TextField(
                      controller: createNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'اسم الكروب (مثلاً: دوري الأصدقاء)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customCodeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'اختر رمزاً سرياً (بأي لغة أو أرقام)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_open),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1E22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _handleCreate,
                      child: const Text('حفظ الكروب ودخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // لديك كروب
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('لديك كروب؟ ضع الرمز السري', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 18),
                    TextField(
                      controller: enterCodeCtrl,
                      decoration: InputDecoration(
                        hintText: 'اكتب الرمز السري الخاص بالكروب',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => enterCodeCtrl.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _handleJoin,
                      child: const Text('دخول للكروب بالرمز السري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
// 3. داخل الكروب: الخيارات الثلاثة (لعبة جديدة / لعبات سابقة / إحصائيات)
// -------------------------------------------------------------
class GroupDashboardScreen extends StatefulWidget {
  const GroupDashboardScreen({super.key});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    var group = GroupManager.activeGroup;
    String gName = group?.name ?? 'الكروب';
    String gCode = group?.code ?? '';
    int matchesCount = group?.matches.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(gName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
            Text('الرمز السري: $gCode', style: const TextStyle(fontSize: 12, color: Colors.amber)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'نسخ الرمز السري',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: gCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز السري لمشاركته!')));
            },
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37)),
                label: const Text('لعبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SetupPlayersScreen(isGroupGame: true)),
                  ).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.history, color: Colors.amber),
                label: Text('لعبات سابقة ($matchesCount)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PastMatchesScreen(isGroupGame: true)),
                  ).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(color: Color(0xFF8B1E22), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.bar_chart, color: Color(0xFF8B1E22)),
                label: const Text('إحصائيات (لاعب ضد لاعب)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF8B1E22))),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HeadToHeadScreen()),
                  );
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
// الشاشات التكميلية (تحديد اللاعبين، تسجيل النتائج، السجل، والإحصائيات)
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
    p1.dispose();
    p2.dispose();
    p3.dispose();
    p4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGroupGame ? 'لاعبي مباراة الكروب' : 'تحديد لاعبي الفريقين'),
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
      ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1E22),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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
    c1.dispose();
    c2.dispose();
    super.dispose();
  }

  int get tot1 => rounds.fold(0, (a, b) => a + b.s1) + (int.tryParse(c1.text) ?? 0);
  int get tot2 => rounds.fold(0, (a, b) => a + b.s2) + (int.tryParse(c2.text) ?? 0);

  void _editRound(int index) {
    var edit1 = TextEditingController(text: '${rounds[index].s1}');
    var edit2 = TextEditingController(text: '${rounds[index].s2}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل نتيجة لعبة ${index + 1}', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: dynamic,
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

  void save(String status, int win) {
    var m = GameMatch(
      id: id, t1p1: t1p1, t1p2: t1p2, t2p1: t2p1, t2p2: t2p2,
      rounds: List.from(rounds), current1: c1.text, current2: c2.text,
      status: status, winner: win,
    );

    List<GameMatch> targetList = widget.isGroupGame
        ? (GroupManager.activeGroup?.matches ?? [])
        : soloMatchesList;

    int idx = targetList.indexWhere((x) => x.id == id);
    if (idx != -1) targetList[idx] = m; else targetList.insert(0, m);
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

class PastMatchesScreen extends StatelessWidget {
  final bool isGroupGame;
  const PastMatchesScreen({super.key, required this.isGroupGame});

  @override
  Widget build(BuildContext context) {
    var list = isGroupGame
        ? (GroupManager.activeGroup?.matches ?? [])
        : soloMatchesList;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGroupGame ? 'لعبات الكروب السابقة' : 'الألعاب السابقة'),
        backgroundColor: const Color(0xFF8B1E22),
        foregroundColor: Colors.white,
      ),
      body: list.isEmpty
          ? const Center(child: Text('لا توجد مباريات مسجلة بعد.'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                title: Text('${list[i].t1p1} & ${list[i].t1p2} ضد ${list[i].t2p1} & ${list[i].t2p2}'),
                subtitle: Text('الحالة: ${list[i].status} | النتيجة: ${list[i].total1} - ${list[i].total2}'),
                trailing: list[i].status == 'مؤجلة'
                    ? IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScreen(isGroupGame: isGroupGame, matchToResume: list[i]),
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
              ),
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
      ),
      body: players.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد مباريات منتهية داخل الكروب بعد.\nأنهِ مباراة واضغط "انتهى" لتظهر النتائج هنا.', textAlign: TextAlign.center),
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
