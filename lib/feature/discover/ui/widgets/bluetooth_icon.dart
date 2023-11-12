import 'package:flutter/material.dart';

class BluetoothIcon extends StatelessWidget {
  const BluetoothIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      backgroundColor: Color(0xffd4fdcb), //Color(0xfffdcbfc),//Color(0xffb082c0),
      child: Icon(
        Icons.bluetooth,
        color: Color(0xff5ca954), //Color(0xffb164de), //Color(0xff6b3f80),
      ),
    );
  }

}