import 'package:flutter/material.dart';

class InfoDialogDescriptionRow extends StatelessWidget {
  final String description;

  const InfoDialogDescriptionRow(this.description, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• '),
        Flexible(child: Text(description)),
      ],
    );
  }

}