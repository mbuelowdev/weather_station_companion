import 'package:flutter/material.dart';

class InfoDialogTitleRow extends StatelessWidget {
  final String title;

  const InfoDialogTitleRow(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

}