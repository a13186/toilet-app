import 'package:flutter/material.dart';

import '../screens/search_screen.dart';

export '../screens/search_screen.dart' show SearchSelection;

class MapSearchBar extends StatelessWidget {
  final ValueChanged<SearchSelection> onSelected;

  const MapSearchBar({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<SearchSelection>(
          MaterialPageRoute(
            builder: (_) => const SearchScreen(),
            fullscreenDialog: true,
          ),
        );
        if (result != null) onSelected(result);
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '화장실 이름 또는 장소 검색',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
