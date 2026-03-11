import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppSettings(),
      child: const GoalTrackApp(),
    ),
  );
}

// --- Settings Model ---
class AppSettings extends ChangeNotifier {
  bool _isDarkMode = true;
  Color _primaryAccent = Colors.blueAccent;
  Color _secondaryAccent = Colors.purpleAccent;
  bool _useProgressBars = false;

  bool get isDarkMode => _isDarkMode;
  Color get primaryAccent => _primaryAccent;
  Color get secondaryAccent => _secondaryAccent;
  bool get useProgressBars => _useProgressBars;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleProgressBars() {
    _useProgressBars = !_useProgressBars;
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    _primaryAccent = color;
    notifyListeners();
  }

  void setSecondaryColor(Color color) {
    _secondaryAccent = color;
    notifyListeners();
  }
}

class GoalTrackApp extends StatelessWidget {
  const GoalTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'GoalTrack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: settings.isDarkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: settings.isDarkMode
                ? const Color(0xFF020617)
                : Colors.white,
            primaryColor: settings.primaryAccent,
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
                settings.isDarkMode
                    ? ThemeData.dark().textTheme
                    : ThemeData.light().textTheme
            ),
            colorScheme: settings.isDarkMode
                ? ColorScheme.dark(
              primary: settings.primaryAccent,
              secondary: settings.secondaryAccent,
              surface: const Color(0xFF0F172A),
            )
                : ColorScheme.light(
              primary: settings.primaryAccent,
              secondary: settings.secondaryAccent,
              surface: Colors.grey.shade100,
            ),
          ),
          home: const MainScaffold(),
        );
      },
    );
  }
}

// --- Models ---
enum QuestType { count, steps }
enum QuestFilter { all, running, completed }

class HeroUser {
  final String id;
  final String name;
  final Color color;

  HeroUser({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
  };

  factory HeroUser.fromJson(Map<String, dynamic> json) => HeroUser(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
  );
}

class Quest {
  final String id;
  final String heroId;
  final String title;
  final QuestType type;
  final List<String>? steps;
  final List<bool>? stepCompleted;
  final double target;
  double current;
  final String? unit;
  final DateTime? startDate;
  DateTime? finishDate;

  Duration? get duration {
    if (startDate == null) return null;
    final endDate = finishDate ?? DateTime.now();
    return endDate.difference(startDate!);
  }

  Quest({
    required this.id,
    required this.heroId,
    required this.title,
    required this.type,
    this.steps,
    this.stepCompleted,
    required this.target,
    this.current = 0,
    this.unit,
    DateTime? startDate,
    this.finishDate,
  }) : startDate = startDate ?? DateTime.now();

  bool get isCompleted => current >= target;
  int get progressPct => target == 0 ? 0 : ((current / target) * 100).round().clamp(0, 100);

  Map<String, dynamic> toJson() => {
    'id': id,
    'heroId': heroId,
    'title': title,
    'type': type.index,
    'steps': steps,
    'stepCompleted': stepCompleted,
    'target': target,
    'current': current,
    'unit': unit,
    'startDate': startDate?.toIso8601String(),
    'finishDate': finishDate?.toIso8601String(),
  };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
    id: json['id'],
    heroId: json['heroId'],
    title: json['title'],
    type: QuestType.values[json['type']],
    steps: json['steps']?.cast<String>(),
    stepCompleted: json['stepCompleted']?.cast<bool>(),
    target: json['target'].toDouble(),
    current: json['current']?.toDouble() ?? 0,
    unit: json['unit'],
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
    finishDate: json['finishDate'] != null ? DateTime.parse(json['finishDate']) : null,
  );
}

// --- Main App Logic ---
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _activeHeroId;
  QuestFilter _activeFilter = QuestFilter.all;
  final List<HeroUser> _heroes = [];
  final List<Quest> _quests = [];

  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _loadData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final heroesJson = _heroes.map((h) => jsonEncode(h.toJson())).toList();
      await prefs.setStringList('heroes', heroesJson);
      final questsJson = _quests.map((q) => jsonEncode(q.toJson())).toList();
      await prefs.setStringList('quests', questsJson);
      debugPrint('Data saved successfully');
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final heroesJson = prefs.getStringList('heroes') ?? [];
      setState(() {
        _heroes.clear();
        _heroes.addAll(heroesJson.map((jsonStr) {
          final map = jsonDecode(jsonStr);
          return HeroUser.fromJson(map);
        }));
      });

      final questsJson = prefs.getStringList('quests') ?? [];
      setState(() {
        _quests.clear();
        _quests.addAll(questsJson.map((jsonStr) {
          final map = jsonDecode(jsonStr);
          return Quest.fromJson(map);
        }));
      });

      debugPrint('Data loaded successfully');
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  int _calculateXP(String heroId) {
    double totalXp = 0;
    final heroQuests = _quests.where((q) => q.heroId == heroId);
    for (var q in heroQuests) {
      if (q.isCompleted) {
        totalXp += 100;
      } else {
        totalXp += q.progressPct;
      }
    }
    return totalXp.toInt();
  }

  void _addQuest(Quest q) {
    setState(() => _quests.add(q));
    _saveData();
  }

  void _deleteQuest(String id) {
    setState(() => _quests.removeWhere((q) => q.id == id));
    _saveData();
  }

  void _addHero(String name) {
    final random = math.Random();
    setState(() {
      final newHero = HeroUser(
        id: 'h${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        color: Color.fromARGB(255, random.nextInt(150) + 100, random.nextInt(150) + 100, random.nextInt(150) + 100),
      );
      _heroes.add(newHero);
      _activeHeroId = newHero.id;
    });
    _saveData();
  }

  void _deleteHero(String heroId) {
    setState(() {
      _heroes.removeWhere((h) => h.id == heroId);
      _quests.removeWhere((q) => q.heroId == heroId);
      if (_activeHeroId == heroId) {
        _activeHeroId = null;
      }
    });
    _saveData();
  }

  // Reorder heroes (used in manage dialog)
  void _reorderHeroes(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final hero = _heroes.removeAt(oldIndex);
      _heroes.insert(newIndex, hero);
    });
    _saveData();
  }

  void _toggleStep(Quest quest, int index) {
    setState(() {
      if (quest.stepCompleted == null) return;
      bool wasCompleted = quest.isCompleted;
      quest.stepCompleted![index] = !quest.stepCompleted![index];
      quest.current = quest.stepCompleted!.where((c) => c).length.toDouble();

      if (!wasCompleted && quest.isCompleted) {
        quest.finishDate = DateTime.now();
        _celebrate();
      }
    });
    _saveData();
  }

  void _updateProgress(Quest quest, double value) {
    setState(() {
      bool wasCompleted = quest.isCompleted;
      quest.current = (quest.current + value).clamp(0, quest.target);

      if (!wasCompleted && quest.isCompleted) {
        quest.finishDate = DateTime.now();
        _celebrate();
      }
    });
    _saveData();
  }

  void _celebrate() {
    _celebrationController.reset();
    _celebrationController.forward();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '—';

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildHeroSelection(),
                if (_selectedIndex == 0 && _heroes.isNotEmpty) _buildFilterBar(),
                Expanded(
                  child: _heroes.isEmpty
                      ? _buildEmptyState("Welcome, Commander. Recruit your heroes to begin.")
                      : IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildQuestList(),
                      _buildLeaderboard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConfettiPainter(animation: _celebrationController.value),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: (_heroes.isEmpty || _selectedIndex == 1 || _activeHeroId == null) ? null : FloatingActionButton.extended(
        onPressed: () => _showAddQuestSheet(),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.rocket_launch, color: Colors.white),
        label: const Text('NEW MISSION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _filterChip('ALL', QuestFilter.all),
          const SizedBox(width: 8),
          _filterChip('RUNNING', QuestFilter.running),
          const SizedBox(width: 8),
          _filterChip('DONE', QuestFilter.completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, QuestFilter filter) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white38)),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text('GOALTRACK', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: Colors.blueAccent),
            onSelected: (value) {
              if (value == 'settings') {
                _showSettingsDrawer();
              } else if (value == 'manage_heroes') {
                _showManageHeroesDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_heroes',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Manage Heroes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Theme & Colors'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Version 1.0.0'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
              onPressed: _showAddHeroDialog,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.blueAccent)
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSelection() {
    if (_heroes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_heroes.length > 1)
              _buildHeroToggle(
                isSelected: _activeHeroId == null,
                label: 'ALL',
                icon: Icons.grid_view_rounded,
                color: Colors.purpleAccent,
                onTap: () => setState(() => _activeHeroId = null),
              ),
            if (_heroes.length > 1) const SizedBox(width: 8),
            ..._heroes.map((hero) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildHeroToggle(
                isSelected: _activeHeroId == hero.id,
                label: hero.name,
                icon: Icons.person,
                color: hero.color,
                onTap: () => setState(() => _activeHeroId = hero.id),
                onLongPress: () => _confirmDeleteHero(hero),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroToggle({
    required bool isSelected,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.white54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? color : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageHeroesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Heroes',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '${_heroes.length} hero${_heroes.length != 1 ? 'es' : ''} recruited — drag to reorder',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),

              if (_heroes.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No heroes yet. Recruit your first hero!'),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    onReorder: _reorderHeroes,
                    children: _heroes.map((hero) => _buildHeroManagementTile(hero, key: ValueKey(hero.id))).toList(),
                  ),
                ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CLOSE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddHeroDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ADD HERO', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroManagementTile(HeroUser hero, {required Key key}) {
    final xp = _calculateXP(hero.id);
    final level = (xp / 1000).floor() + 1;
    final questCount = _quests.where((q) => q.heroId == hero.id).length;
    final completedCount = _quests.where((q) => q.heroId == hero.id && q.isCompleted).length;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hero.color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: _heroes.indexOf(hero),
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle, color: Colors.white54),
            ),
          ),
          CircleAvatar(
            radius: 24,
            backgroundColor: hero.color,
            child: Text(
              hero.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hero.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LVL $level',
                        style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completedCount/$questCount done',
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteHero(hero);
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Text(
                    'Settings & Customization',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<AppSettings>(
                  builder: (context, settings, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSettingsSection(
                          title: 'APPEARANCE',
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.dark_mode, color: Colors.blueAccent),
                                        SizedBox(width: 12),
                                        Text('Dark Mode'),
                                      ],
                                    ),
                                    Switch(
                                      value: settings.isDarkMode,
                                      onChanged: (_) => settings.toggleTheme(),
                                      activeColor: Colors.blueAccent,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.show_chart, color: Colors.blueAccent),
                                        SizedBox(width: 12),
                                        Text('Use Progress Bars (compact)'),
                                      ],
                                    ),
                                    Switch(
                                      value: settings.useProgressBars,
                                      onChanged: (_) => settings.toggleProgressBars(),
                                      activeColor: Colors.blueAccent,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          title: 'ACCENT COLORS',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                _buildColorPicker(
                                  label: 'Primary Accent',
                                  currentColor: settings.primaryAccent,
                                  onColorSelected: settings.setPrimaryColor,
                                ),
                                const SizedBox(height: 16),
                                _buildColorPicker(
                                  label: 'Secondary Accent',
                                  currentColor: settings.secondaryAccent,
                                  onColorSelected: settings.setSecondaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          title: 'HERO COLOR SCHEMES',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Each hero gets a unique color',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _heroes.map((hero) {
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: hero.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _activeHeroId == hero.id
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          hero.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_heroes.isEmpty)
                                  const Text(
                                    'Add heroes to see their colors',
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          title: 'MISSION STATS',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  icon: Icons.rocket_launch,
                                  label: 'Total Missions',
                                  value: '${_quests.length}',
                                ),
                                const Divider(color: Colors.white10),
                                _buildStatRow(
                                  icon: Icons.check_circle,
                                  label: 'Completed',
                                  value: '${_quests.where((q) => q.isCompleted).length}',
                                  valueColor: Colors.tealAccent,
                                ),
                                const Divider(color: Colors.white10),
                                _buildStatRow(
                                  icon: Icons.pending,
                                  label: 'In Progress',
                                  value: '${_quests.where((q) => !q.isCompleted).length}',
                                ),
                                const Divider(color: Colors.white10),
                                _buildStatRow(
                                  icon: Icons.access_time,
                                  label: 'Avg Completion Time',
                                  value: _getAverageCompletionTime(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          title: 'DATA',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.backup_outlined, color: Colors.blueAccent),
                                  title: const Text('Export Data'),
                                  subtitle: const Text('Save your progress'),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Export feature coming soon!')),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.restore_outlined, color: Colors.orangeAccent),
                                  title: const Text('Import Data'),
                                  subtitle: const Text('Restore from backup'),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Import feature coming soon!')),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                                  title: const Text('Reset All Data'),
                                  subtitle: const Text('Clear all heroes and quests'),
                                  onTap: () => _confirmResetAllData(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildColorPicker({
    required String label,
    required Color currentColor,
    required Function(Color) onColorSelected,
  }) {
    final colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.amber,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = color.value == currentColor.value;
                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getAverageCompletionTime() {
    final completedQuests = _quests.where((q) => q.isCompleted && q.duration != null).toList();
    if (completedQuests.isEmpty) return '—';

    final totalSeconds = completedQuests.fold<int>(
        0,
            (sum, q) => sum + q.duration!.inSeconds
    );
    final avgDuration = Duration(seconds: totalSeconds ~/ completedQuests.length);
    return _formatDuration(avgDuration);
  }

  void _confirmResetAllData() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will delete all heroes and missions. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _heroes.clear();
                _quests.clear();
                _activeHeroId = null;
                _saveData();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('RESET ALL'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestList() {
    var list = _activeHeroId == null
        ? List<Quest>.from(_quests)
        : _quests.where((q) => q.heroId == _activeHeroId).toList();

    if (_activeFilter == QuestFilter.running) {
      list = list.where((q) => !q.isCompleted).toList();
    } else if (_activeFilter == QuestFilter.completed) {
      list = list.where((q) => q.isCompleted).toList();
    }

    if (list.isEmpty) return _buildEmptyState(_activeHeroId == null ? "No missions found in the galaxy." : "No matching missions for this hero.");

    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final quest = list[index];
            final hero = _heroes.firstWhere((h) => h.id == quest.heroId);
            return QuestCard(
              quest: quest,
              hero: hero,
              onIncrement: () => _updateProgress(quest, 1),
              onCustomAdd: () => _showProgressInputDialog(quest),
              onDelete: () => _confirmDeleteQuest(quest),
              onStepToggle: (i) => _toggleStep(quest, i),
              formatDate: _formatDate,
              formatDuration: _formatDuration,
              useProgressBar: settings.useProgressBars,
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboard() {
    final sorted = List<HeroUser>.from(_heroes)..sort((a, b) => _calculateXP(b.id).compareTo(_calculateXP(a.id)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final h = sorted[index];
        final hQuests = _quests.where((q) => q.heroId == h.id).toList();
        final doneQuests = hQuests.where((q) => q.isCompleted).toList();
        final doneCount = doneQuests.length;
        final totalXP = _calculateXP(h.id);
        final level = (totalXP / 1000).floor() + 1;

        final durations = doneQuests.map((q) => q.duration).whereType<Duration>().toList();
        final avgDuration = durations.isEmpty
            ? null
            : Duration(seconds: durations.map((d) => d.inSeconds).reduce((a, b) => a + b) ~/ durations.length);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: h.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Text('#${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 18)),
              const SizedBox(width: 15),
              CircleAvatar(
                  radius: 24,
                  backgroundColor: h.color,
                  child: Text(h.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('$doneCount DONE • ${hQuests.length - doneCount} RUNNING',
                        style: const TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                    if (avgDuration != null)
                      Text('Avg time: ${_formatDuration(avgDuration)}',
                          style: const TextStyle(fontSize: 8, color: Colors.white38)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$totalXP XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  Text('LVL $level', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      backgroundColor: const Color(0xFF0F172A),
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey.shade600,
      elevation: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Missions'),
        BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded), label: 'Ranks'),
      ],
    );
  }

  void _showProgressInputDialog(Quest quest) {
    final controller = TextEditingController(text: quest.current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Set ${quest.title} Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: _inputStyle('Set value (${quest.unit})'),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${quest.current.toInt()} / ${quest.target.toInt()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (quest.startDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Started: ${_formatDate(quest.startDate!)}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')
          ),
          ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  setState(() {
                    bool wasCompleted = quest.isCompleted;
                    quest.current = val.clamp(0, quest.target);

                    if (!wasCompleted && quest.isCompleted) {
                      quest.finishDate = DateTime.now();
                      _celebrate();
                    }
                  });
                  _saveData();
                  Navigator.pop(context);
                }
              },
              child: const Text('SET VALUE')
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHero(HeroUser hero) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dismiss Hero?'),
        content: Text('Remove ${hero.name}? All mission data will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
              onPressed: () {
                _deleteHero(hero.id);
                Navigator.pop(context);
              },
              child: const Text('REMOVE HERO', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _confirmDeleteQuest(Quest quest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Abort Mission'),
        content: const Text('Cancel this quest? Progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP')),
          TextButton(
              onPressed: () {
                _deleteQuest(quest.id);
                Navigator.pop(context);
              },
              child: const Text('ABORT', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _showAddHeroDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recruit Hero'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputStyle('Hero Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _addHero(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('RECRUIT')
          ),
        ],
      ),
    );
  }

  void _showAddQuestSheet() {
    final titleCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: '1');
    final targetCtrl = TextEditingController(text: '10');
    final stepCtrl = TextEditingController();
    QuestType type = QuestType.count;
    List<String> steps = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mission Briefing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: titleCtrl, decoration: _inputStyle('Mission Name')),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: ChoiceChip(
                      label: const Center(child: Text('NUMERIC')),
                      selected: type == QuestType.count,
                      onSelected: (s) => setModalState(() => type = QuestType.count),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ChoiceChip(
                      label: const Center(child: Text('MILESTONES')),
                      selected: type == QuestType.steps,
                      onSelected: (s) => setModalState(() => type = QuestType.steps),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                if (type == QuestType.count) ...[
                  Row(
                    children: [
                      Expanded(child: TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputStyle('Target'),
                      )),
                      const SizedBox(width: 15),
                      Expanded(child: TextField(
                        controller: unitCtrl,
                        decoration: _inputStyle('Unit label'),
                      )),
                    ],
                  )
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: TextField(
                        controller: stepCtrl,
                        decoration: _inputStyle('Add milestone...'),
                      )),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                        onPressed: () {
                          if (stepCtrl.text.isNotEmpty) {
                            setModalState(() {
                              steps.add(stepCtrl.text);
                              stepCtrl.clear();
                            });
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: steps.asMap().entries.map((e) => Chip(
                      label: Text(e.value, style: const TextStyle(fontSize: 10)),
                      onDeleted: () => setModalState(() => steps.removeAt(e.key)),
                      deleteIconColor: Colors.red,
                    )).toList(),
                  )
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty && _activeHeroId != null) {
                        _addQuest(Quest(
                          id: 'q${DateTime.now().millisecondsSinceEpoch}',
                          heroId: _activeHeroId!,
                          title: titleCtrl.text,
                          type: type,
                          unit: type == QuestType.count ? unitCtrl.text : 'steps',
                          target: type == QuestType.steps ? steps.length.toDouble() : double.tryParse(targetCtrl.text) ?? 1,
                          steps: type == QuestType.steps ? steps : null,
                          stepCompleted: type == QuestType.steps ? List.generate(steps.length, (_) => false) : null,
                        ));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('LAUNCH MISSION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

// --- Components ---
class QuestCard extends StatelessWidget {
  final Quest quest;
  final HeroUser hero;
  final VoidCallback onIncrement;
  final VoidCallback onCustomAdd;
  final VoidCallback onDelete;
  final Function(int) onStepToggle;
  final String Function(DateTime) formatDate;
  final String Function(Duration?) formatDuration;
  final bool useProgressBar;

  const QuestCard({
    super.key,
    required this.quest,
    required this.hero,
    required this.onIncrement,
    required this.onCustomAdd,
    required this.onDelete,
    required this.onStepToggle,
    required this.formatDate,
    required this.formatDuration,
    required this.useProgressBar,
  });

  @override
  Widget build(BuildContext context) {
    // For count-type quests with progress bar enabled, show compact version
    if (useProgressBar && quest.type == QuestType.count) {
      return _buildCompactCard();
    } else {
      return _buildFullCard();
    }
  }

  Widget _buildCompactCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quest.isCompleted ? Colors.tealAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Hero indicator (small)
          CircleAvatar(
            radius: 10,
            backgroundColor: hero.color,
            child: Text(
              hero.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (quest.current / quest.target).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    quest.isCompleted ? Colors.tealAccent : Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Percentage and delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${quest.progressPct}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: quest.isCompleted ? Colors.tealAccent : Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: quest.isCompleted ? Colors.tealAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                CircleAvatar(radius: 12, backgroundColor: hero.color,
                    child: Text(hero.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Text(hero.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueAccent)),
              ]),
              IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white24),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      quest.isCompleted
                          ? 'MISSION SUCCESS (+100 XP)'
                          : '${quest.current.toInt()} / ${quest.target.toInt()} ${quest.unit ?? ""}',
                      style: TextStyle(
                          color: quest.isCompleted ? Colors.tealAccent : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w700
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                            Icons.access_time,
                            size: 12,
                            color: quest.isCompleted ? Colors.tealAccent : Colors.white38
                        ),
                        const SizedBox(width: 4),
                        Text(
                          quest.isCompleted
                              ? 'Completed ${formatDate(quest.finishDate!)}'
                              : 'Started ${formatDate(quest.startDate!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: quest.isCompleted ? Colors.tealAccent.withOpacity(0.7) : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    if (quest.isCompleted && quest.duration != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Duration: ${formatDuration(quest.duration)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!quest.isCompleted && useProgressBar) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (quest.current / quest.target).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          quest.isCompleted ? Colors.tealAccent : Colors.blueAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (!useProgressBar || quest.isCompleted)
                _buildProgressRing(),
            ],
          ),

          if (quest.type == QuestType.steps && quest.steps != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            ...quest.steps!.asMap().entries.map((entry) {
              int idx = entry.key;
              String title = entry.value;
              bool isDone = quest.stepCompleted![idx];
              return InkWell(
                onTap: () => onStepToggle(idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: isDone ? Colors.tealAccent : Colors.white24,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            title,
                            style: TextStyle(
                              color: isDone ? Colors.white38 : Colors.white,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            )
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          if (quest.type == QuestType.count && !quest.isCompleted) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onIncrement,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('BOOST +1', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14)
                  ),
                  child: IconButton(
                      onPressed: onCustomAdd,
                      icon: const Icon(Icons.edit_note, color: Colors.white),
                      padding: const EdgeInsets.all(14)
                  ),
                ),
              ],
            )
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRing() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: RingPainter(
                progress: quest.current / quest.target,
                color: quest.isCompleted ? Colors.tealAccent : Colors.blueAccent
            ),
          ),
        ),
        Text(
            '${quest.progressPct}%',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: quest.isCompleted ? Colors.tealAccent : Colors.white
            )
        ),
      ],
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  RingPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;
    canvas.drawCircle(center, radius - strokeWidth, Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - strokeWidth), -math.pi / 2, 2 * math.pi * (progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0)), false, Paint()..color = color..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = strokeWidth);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StarBackground extends StatelessWidget {
  const StarBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF020617)),
      child: CustomPaint(painter: StarPainter(), size: Size.infinite),
    );
  }
}

class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(123);
    for (int i = 0; i < 150; i++) {
      canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), random.nextDouble() * 1.5, Paint()..color = Colors.white.withOpacity(0.2));
    }
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ConfettiPainter extends CustomPainter {
  final double animation;
  final List<Particle> particles = List.generate(60, (index) => Particle());
  ConfettiPainter({required this.animation});
  @override
  void paint(Canvas canvas, Size size) {
    if (animation == 0 || animation == 1.0) return;
    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(1.0 - animation);
      double x = size.width / 2 + math.cos(p.angle) * p.distance * animation * 2;
      double y = size.height / 2 + math.sin(p.angle) * p.distance * animation * 2 + (animation * animation * 500);
      canvas.drawRect(Rect.fromLTWH(x, y, p.size, p.size), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  final double angle = math.Random().nextDouble() * 2 * math.pi;
  final double distance = math.Random().nextDouble() * 400 + 100;
  final double size = math.Random().nextDouble() * 8 + 4;
  final Color color = [Colors.amber, Colors.blueAccent, Colors.teal, Colors.purpleAccent][math.Random().nextInt(4)];
}