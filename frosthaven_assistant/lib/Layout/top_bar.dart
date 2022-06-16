import 'package:flutter/material.dart';

import '../Resource/game_state.dart';
import 'element_button.dart';

AppBar createTopBar() {
  return AppBar(
    iconTheme: const IconThemeData(color: Colors.white),
    // Here we take the value from the MyHomePage object that was created by
    // the App.build method, and use it to set our appbar title.
    //TODO: scale: minimum 40 height but scale up
    title: const Text(
      "Frosthaven\nAssistant", style: TextStyle(
      fontFamily: 'Pirata',
      color: Colors.white,
      fontSize: 16,
    ),
    ),
    toolbarHeight: 40, // Set this height
    flexibleSpace: const Image(
      height: 40,
      image: AssetImage('assets/images/psd/frosthaven-bar.png'),
      //fit: BoxFit.fitHeight,
      repeat: ImageRepeat.repeat
    ),
    actions: [
      ElementButton(
          key: UniqueKey(),
          color: Colors.red,
          element: Elements.fire,
          icon: 'assets/images/psd/element-fire.png'
      ),
      ElementButton(
          key: UniqueKey(),
          color: Colors.blue,
          element: Elements.ice,
          icon: 'assets/images/psd/element-ice.png'
      ),
      ElementButton(
          key: UniqueKey(),
          color: Colors.grey,
          element: Elements.air,
          icon: 'assets/images/psd/element-air.png'
      ),
      ElementButton(
          key: UniqueKey(),
          color: Colors.green,
          element: Elements.earth,
          icon: 'assets/images/psd/element-earth.png'
      ),
      ElementButton(
          key: UniqueKey(),
          color: Colors.yellow,
          element: Elements.light,
          icon: 'assets/images/psd/element-light.png'
      ),
      ElementButton(
          key: UniqueKey(),
          color: Colors.black,
          element: Elements.dark,
          icon: 'assets/images/psd/element-dark.png'
      ),
    ],
  );
}