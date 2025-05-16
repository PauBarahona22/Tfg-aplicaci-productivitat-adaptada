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
      final hasPre = challenges.any((c) => c.isPredefined);
      if (!hasPre) {
        await _challengeService.createPredefinedChallenges(_uid);
      }
    } catch (e) {
      Future.delayed(const Duration(seconds: 5), _checkPredefinedChallenges);
    }
  }

  void _toggleAscending() => setState(() => _ascending = !_ascending);

  Future<void> _pickType() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(50, 100, 50, 0),
      items: _allTypes
          .map((t) => PopupMenuItem(value: t, child: Text(t)))
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
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  List<ChallengeModel> _applySearchFilterSort(List<ChallengeModel> input) {
    var list = List<ChallengeModel>.from(input);

    // Búsqueda
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((c) =>
              c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filtrar por tipo
    if (_selectedType != 'Tots') {
      if (_selectedType == 'Generals') {
        list = list.where((c) => c.isPredefined).toList();
      } else {
        list = list.where((c) => !c.isPredefined).toList();
      }
    }

    // Orden
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
      appBar: AppBar(title: const Text('Llistat de Reptes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChallengeDetailScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 1) Buscador
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscador de reptes pel nom',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // 2) Fila de filtros con iconos custom como en tareas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pendientes
                StreamBuilder<List<ChallengeModel>>(
                  stream: _challengeService.streamChallenges(_uid),
                  builder: (ctx, snap) {
                    final pending = snap.hasData
                        ? snap.data!
                            .where((c) => !c.isCompleted && !c.isExpired)
                            .length
                        : 0;
                    return _buildFilterChip(
                      Text('Reptes pendents: $pending'),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Filtrar por tipo (icono custom)
                _buildFilterChip(
                  Image.asset(
                    'assets/filtratgepertipus.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _pickType,
                ),

                const SizedBox(width: 8),

                // Ascendente/Descendente (icono custom)
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

                // Criterio de orden
                Expanded(
                  child: _buildFilterChip(
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _orderCriterion,
                        items: _allCriteria
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
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

          // 3) Lista de retos bajo StreamBuilder
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  _challengeService.streamChallenges(_uid).first,
              child: StreamBuilder<List<ChallengeModel>>(
                stream: _challengeService.streamChallenges(_uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final challenges = _applySearchFilterSort(snap.data!);
                  if (challenges.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hi ha reptes. Crea el teu primer repte!',
                        style: TextStyle(fontSize: 16),
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
                    children: [
                      if (personal.isNotEmpty &&
                          (_selectedType == 'Tots' ||
                              _selectedType == 'Personals')) ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Reptes personals',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...personal.map(_buildChallengeCard),
                      ],
                      if (general.isNotEmpty &&
                          (_selectedType == 'Tots' ||
                              _selectedType == 'Generals')) ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Reptes generals',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
    Color circleColor = Colors.blue;
    if (c.isCompleted) circleColor = Colors.green;
    if (c.isExpired) circleColor = Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: circleColor.withOpacity(0.2),
          child: Icon(
            c.isPredefined ? Icons.auto_awesome : Icons.person,
            color: circleColor,
          ),
        ),
        title: Text(c.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: c.targetCount > 0
                  ? c.currentCount / c.targetCount
                  : 0,
              backgroundColor: Colors.grey[300],
              color: c.isCompleted
                  ? Colors.green
                  : c.isExpired
                      ? Colors.red
                      : Colors.blue,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${c.currentCount}/${c.targetCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.isCompleted ? Colors.green : Colors.grey[700],
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
