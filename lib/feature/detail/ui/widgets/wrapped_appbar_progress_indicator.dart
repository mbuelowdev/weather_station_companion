import 'package:flutter/material.dart';

class WrappedAppBarProgressIndicator extends LinearProgressIndicator implements PreferredSizeWidget {
  const WrappedAppBarProgressIndicator({super.key});

  @override
  Size get preferredSize => const Size(double.infinity, 4.0);
}