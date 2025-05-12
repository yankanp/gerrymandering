enum Party { red, blue }

class Tile {
  final int index;
  Party party;
  bool selected = false;
  int? districtId;

  Tile({required this.index, required this.party});
}
