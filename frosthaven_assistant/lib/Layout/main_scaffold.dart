import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Model/campaign.dart';

import 'bottom_bar.dart';
import 'main_list.dart';
import 'menus/main_menu.dart';

Widget createMainScaffold(BuildContext context) {
  return SafeArea(
    bottom: false,
      maintainBottomViewPadding: true,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
    //drawerScrimColor: Colors.yellow,
    bottomNavigationBar: createBottomBar(context),
    appBar: createTopBar(),
    drawer: createMainMenu(context),
    body: const MainList(),
    /*floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),*/ // This trailing comma makes auto-formatting nicer for build methods.
  ));
}