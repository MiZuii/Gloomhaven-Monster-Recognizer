import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'config.g.dart';

class GMRHomePageListEntry extends StatelessWidget {
  final int idx;
  final String label;

  GMRHomePageListEntry({required this.idx, required this.label});

  @override
  Widget build(BuildContext context) {

    var appState = context.watch<GMRAppState>();

    return ListTile(
      title: Text(label.split('_').map((e) => e.substring(0, 1).toUpperCase() + e.substring(1)).join(' ')),
      onTap: () {
        appState.setCurrentMonsterIdx(idx);
      },
      selected: appState.currentMonsterIdx == idx,
      selectedTileColor: Theme.of(context).colorScheme.secondary,
      selectedColor: Theme.of(context).colorScheme.onSecondary,
    );
  }
}

class GMRListView extends StatelessWidget {
  const GMRListView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey('GMRListView'),
      children: [for ( var i = 0; i < monsterLabels.length; i++ ) GMRHomePageListEntry(idx: i, label: monsterLabels[i])],
    );
  }
} 