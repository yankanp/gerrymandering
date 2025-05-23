import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gerrymandering_app/tile.dart';

class GerrymanderingGame extends StatefulWidget {
  const GerrymanderingGame({super.key});

  @override
  State<GerrymanderingGame> createState() => _GerrymanderingGameState();
}

class _GerrymanderingGameState extends State<GerrymanderingGame> {
  final int gridSize = 6;
  final int districtSize = 6;
  final List<Tile> tiles = [];
  final Map<int, List<int>> districts = {};
  int nextDistrictId = 1;
  final List<int> selectionHistory = [];

  final List<int> dragSelectedIndexes = []; // list preserves order
  GlobalKey gridKey = GlobalKey();
  final Map<int, GlobalKey> tileKeys = {};

  DateTime? _lastDragTime;

  @override
  void initState() {
    super.initState();
    _generateTiles();
  }

  void _generateTiles() {
    tiles.clear();
    tileKeys.clear();
    final rand = Random();
    for (int i = 0; i < gridSize * gridSize; i++) {
      tiles
          .add(Tile(index: i, party: rand.nextBool() ? Party.red : Party.blue));
      tileKeys[i] = GlobalKey();
    }
    districts.clear();
    nextDistrictId = 1;
    dragSelectedIndexes.clear();
    selectionHistory.clear();
    setState(() {});
  }

  void _completeDistrict() {
    if (dragSelectedIndexes.length != districtSize) return;
    final id = nextDistrictId++;
    for (var i in dragSelectedIndexes) {
      tiles[i].districtId = id;
    }
    districts[id] = List.from(dragSelectedIndexes);
    selectionHistory.add(id);
    dragSelectedIndexes.clear();
    setState(() {});
  }

  Map<Party, int> _calculateResults() {
    final result = {Party.red: 0, Party.blue: 0};
    for (var entry in districts.entries) {
      final counts = {Party.red: 0, Party.blue: 0};
      for (var i in entry.value) {
        counts[tiles[i].party] = counts[tiles[i].party]! + 1;
      }
      final majority =
          counts[Party.red]! > counts[Party.blue]! ? Party.red : Party.blue;
      result[majority] = result[majority]! + 1;
    }
    return result;
  }

  Party _districtMajority(int districtId) {
    final tilesInDistrict = districts[districtId]!;
    int redCount = 0;
    for (var i in tilesInDistrict) {
      if (tiles[i].party == Party.red) redCount++;
    }
    return redCount > (districtSize ~/ 2) ? Party.red : Party.blue;
  }

  Color _partyColor(Party party) =>
      party == Party.red ? Colors.red : Colors.blue;

  void _handleDrag(DragUpdateDetails details) {
    final now = DateTime.now();
    if (_lastDragTime != null &&
        now.difference(_lastDragTime!).inMilliseconds < 20) return;
    _lastDragTime = now;

    RenderBox? gridBox =
        gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;

    Offset localPosition = gridBox.globalToLocal(details.globalPosition);
    double tileSize = gridBox.size.width / gridSize;
    int row = (localPosition.dy / tileSize).floor();
    int col = (localPosition.dx / tileSize).floor();
    if (row < 0 || col < 0 || row >= gridSize || col >= gridSize) return;

    int index = row * gridSize + col;

    if (index < 0 ||
        index >= tiles.length ||
        tiles[index].districtId != null ||
        dragSelectedIndexes.contains(index)) return;

    if (dragSelectedIndexes.isEmpty ||
        _isAdjacent(dragSelectedIndexes.last, index)) {
      dragSelectedIndexes.add(index);
      setState(() {});
      if (dragSelectedIndexes.length == districtSize) {
        _completeDistrict();
      }
    }
  }

  bool _isAdjacent(int a, int b) {
    int ax = a % gridSize, ay = a ~/ gridSize;
    int bx = b % gridSize, by = b ~/ gridSize;
    return ((ax - bx).abs() + (ay - by).abs()) == 1;
  }

  void _ungroupDistrict(int districtId) {
    for (var i in districts[districtId]!) {
      tiles[i].districtId = null;
    }
    districts.remove(districtId);
    selectionHistory.remove(districtId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final results = _calculateResults();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerrymandering Puzzle'),
        backgroundColor: Colors.teal,
        actions: [
          TextButton(
            onPressed: _generateTiles,
            child: const Text("Reset", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Text(
              "Red wins: ${results[Party.red]} | Blue wins: ${results[Party.blue]}",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            flex: 5,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GestureDetector(
                key: gridKey,
                onPanUpdate: _handleDrag,
                onPanEnd: (_) {
                  if (dragSelectedIndexes.length < districtSize) {
                    dragSelectedIndexes.clear();
                    setState(() {});
                  }
                },
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    childAspectRatio: 1,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    final tile = tiles[index];
                    final isSelected = dragSelectedIndexes.contains(index);
                    final borderColor = isSelected
                        ? Colors.green
                        : tile.districtId != null
                            ? _partyColor(_districtMajority(tile.districtId!))
                            : Colors.transparent;

                    return GestureDetector(
                      onTap: () {
                        if (tile.districtId != null) {
                          _ungroupDistrict(tile.districtId!);
                        }
                      },
                      child: Container(
                        key: tileKeys[index],
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: tile.party == Party.red
                              ? Colors.red[100]
                              : Colors.blue[100],
                          border: Border.all(color: borderColor, width: 3),
                        ),
                        child: Center(
                            child: Icon(
                          Icons.home,
                          size: 40,
                          color: tile.party == Party.red
                              ? Colors.red[900]
                              : Colors.blue[900],
                        )),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
