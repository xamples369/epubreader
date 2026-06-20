import 'package:flutter/material.dart';

class SpikeMenuScreen extends StatelessWidget {
  const SpikeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EPUB Reader — dev menu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Toto je dočasné dev menu (M1). Reálna Home obrazovka príde v M2.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/epub_view'),
              child: const Text('Otvoriť EPUB čítačku (epub_view)'),
            ),
          ],
        ),
      ),
    );
  }
}
