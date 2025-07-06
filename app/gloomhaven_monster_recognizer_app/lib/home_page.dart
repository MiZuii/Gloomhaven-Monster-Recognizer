import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'list_view.dart';
import 'camera_view.dart';

class GMRHomePage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    var appState = context.watch<GMRAppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gloomhaven Monster Recognizer',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
          )
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: appState.view,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if( appState.view is GMRListView ) {
            appState.changeView(GMRCameraView());
          } else {
            appState.changeView(GMRListView());
          }
        },
        child: appState.view is GMRListView ? Icon(Icons.arrow_forward) : Icon(Icons.arrow_back),
      ),
    );
  }
} 