import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge_model.dart';
import '../database/challenge_service.dart';
import 'challenge_detail_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _challengeService = ChallengeService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  String _searchQuery = '';
  String _selectedType = 'Tots';
  String _orderCriterion = 'Data creació';
  bool _ascending = false;

  static const List<String> _allTypes = [
    'Tots',
    'Generals',
    'Personals',
  ];

  static const List<String> _allCriteria = [
    'Data creació',
    'Data venciment',
    'Nom',
  ];

  @override
  void initState() {
    super.initState();
    _checkPredefinedChallenges();
  }

  Future<void> _checkPredefinedChallenges() async {
    try {
      final challenges = await _challengeService
          .streamChallenges(_uid)
          .first
          .timeout(const Duration(seconds: 5));

      await _challengeService.ensureAllPredefinedChallenges(_uid, challenges);
    } catch (e) {
      Future.delayed(const Duration(seconds: 5), _checkPredefinedChallenges);
    }
  }

  void _toggleAscending() => setState(() => _ascending = !_ascending);

  Future<void> _pickType() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(50, 100, 50, 0),
      color: Color(0xFFBAD1C2),
      items: _allTypes
          .map((t) => PopupMenuItem(value: t, child: Text(t, style: TextStyle(color: Color(0xFF25766B)))))
          .toList(),
    );
    if (selected != null) setState(() => _selectedType = selected);
  }

  Widget _buildFilterChip(Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 73, 148, 138),
          border: Border.all(color: Color.fromARGB(255, 36, 78, 73)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  List<ChallengeModel> _applySearchFilterSort(List<ChallengeModel> input) {
    var list = List<ChallengeModel>.from(input);

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((c) =>
              c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedType != 'Tots') {
      if (_selectedType == 'Generals') {
        list = list.where((c) => c.isPredefined).toList();
      } else {
        list = list.where((c) => !c.isPredefined).toList();
      }
    }

    list.sort((a, b) {
      int cmp;
      switch (_orderCriterion) {
        case 'Data creació':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'Data venciment':
          final da = a.dueDate ?? DateTime(9999);
          final db = b.dueDate ?? DateTime(9999);
          cmp = da.compareTo(db);
          break;
        case 'Nom':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        default:
          cmp = 0;
      }
      return _ascending ? cmp : -cmp;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text('Llistat de Reptes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF25766B),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChallengeDetailScreen()),
        ),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: Color(0xFF9BB8A5),
            padding: const EdgeInsets.all(8),
            child: TextField(
              style: TextStyle(color: Color(0xFF25766B)),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: Color(0xFF4FA095)),
                hintText: 'Buscador de reptes pel nom',
                hintStyle: TextStyle(color: Color(0xFF25766B).withOpacity(0.7)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Container(
            color: Color(0xFF9BB8A5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StreamBuilder<List<ChallengeModel>>(
                  stream: _challengeService.streamChallenges(_uid),
                  builder: (ctx, snap) {
                    final pending = snap.hasData
                        ? snap.data!
                            .where((c) => !c.isCompleted && !c.isExpired)
                            .length
                        : 0;
                    return _buildFilterChip(
                      Text('Reptes pendents: $pending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  Image.asset(
                    'assets/filtratgepertipus.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _pickType,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  Image.asset(
                    _ascending
                        ? 'assets/iconodebaixcapadalt.PNG'
                        : 'assets/iconodedaltabaix.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _toggleAscending,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _orderCriterion,
                        dropdownColor: Color(0xFF7C9F88),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        items: _allCriteria
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _orderCriterion = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: Color(0xFF4FA095),
              onRefresh: () => _challengeService.streamChallenges(_uid).first,
              child: StreamBuilder<List<ChallengeModel>>(
                stream: _challengeService.streamChallenges(_uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}', style: TextStyle(color: Color(0xFF25766B))),
                    );
                  }
                  if (!snap.hasData) {
                    return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                  }

                  final challenges = _applySearchFilterSort(snap.data!);
                  if (challenges.isEmpty) {
                    return Center(
                      child: Text(
                        'No hi ha reptes. Crea el teu primer repte!',
                        style: TextStyle(fontSize: 16, color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  final personal = challenges
                      .where((c) => !c.isPredefined)
                      .toList(growable: false);
                  final general = challenges
                      .where((c) => c.isPredefined)
                      .toList(growable: false);

                  return ListView(
                    padding: EdgeInsets.all(8),
                    children: [
                      if (personal.isNotEmpty &&
                          (_selectedType == 'Tots' ||
                              _selectedType == 'Personals')) ...[
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Reptes personals',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF25766B)),
                          ),
                        ),
                        ...personal.map(_buildChallengeCard),
                      ],
                      if (general.isNotEmpty &&
                          (_selectedType == 'Tots' ||
                              _selectedType == 'Generals')) ...[
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Reptes generals',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF25766B)),
                          ),
                        ),
                        ...general.map(_buildChallengeCard),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(ChallengeModel c) {
    Color circleColor = const Color.fromARGB(255, 175, 243, 234);
    if (c.isCompleted) circleColor = const Color.fromARGB(255, 168, 233, 170);
    if (c.isExpired) circleColor = const Color.fromARGB(138, 230, 206, 205);
    Color circlebackgroudcolor = const Color.fromARGB(227, 34, 145, 153);
    if (c.isCompleted) circlebackgroudcolor = const Color.fromARGB(172, 45, 150, 48);
    if (c.isExpired) circlebackgroudcolor = const Color.fromARGB(139, 244, 67, 54);

    return Card(
      color: Color.fromARGB(61, 35, 224, 161),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: circlebackgroudcolor,
          child: Icon(
            c.isPredefined ? Icons.auto_awesome : Icons.person,
            color: circleColor,
          ),
        ),
        title: Text(c.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(255, 26, 90, 87), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LinearProgressIndicator(
                value: c.targetCount > 0
                    ? c.currentCount / c.targetCount
                    : 0,
                backgroundColor: const Color.fromARGB(221, 245, 255, 250),
                color: c.isCompleted
                    ? const Color.fromARGB(192, 15, 241, 22)
                    : c.isExpired
                        ? Colors.red
                        : Color.fromARGB(223, 23, 87, 81),
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            
            const SizedBox(height: 4),
            Text(
              '${c.currentCount}/${c.targetCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeDetailScreen(challenge: c),
          ),
        ),
      ),
    );
  }
}