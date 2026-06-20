import 'package:flutter/material.dart';

import 'spike/epub_view_spike.dart';
import 'spike/spike_menu.dart';

void main() {
  runApp(const EpubReaderApp());
}

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SpikeMenuScreen(),
      routes: {
        '/spike/epub_view': (_) => const EpubViewSpikeScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not implemented')),
          body: Center(child: Text('Route: ${settings.name}')),
        ),
      ),
    );
  }
}
