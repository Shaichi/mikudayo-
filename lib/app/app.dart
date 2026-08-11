import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import 'theme.dart';

/// Root widget của ứng dụng Miku.
class MikuApp extends ConsumerWidget {
  const MikuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Miku Japanese Conversation',
      debugShowCheckedModeBanner: false,
      theme: MikuTheme.light(),
      home: const HomeScreen(),
    );
  }
}
