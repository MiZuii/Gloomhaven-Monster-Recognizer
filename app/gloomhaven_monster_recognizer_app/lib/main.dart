import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home_page.dart';
import 'list_view.dart';
import 'camera_view.dart';

void main() {

  WidgetsFlutterBinding.ensureInitialized();
  // DartPluginRegistrant.ensureInitialized();
  GMRCameraView.initialize();

  runApp(GMRApp());
}

class GMRApp extends StatelessWidget {
  const GMRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GMRAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: GMRHomePage(),
      ),
    );
  }
}

class GMRAppState extends ChangeNotifier {
  var currentMonsterIdx = 0;
  Widget view = GMRListView();

  void setCurrentMonsterIdx(int idx) {
    currentMonsterIdx = idx;
    notifyListeners();
  }

  void changeView(Widget view) {
    this.view = view;
    notifyListeners();
  }
}

