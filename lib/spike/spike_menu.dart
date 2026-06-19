import 'package:flutter/material.dart';

class SpikeMenuScreen extends StatelessWidget {
  const SpikeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EPUB Renderer Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vyber spike na vyskúšanie:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/flutter_epub_viewer'),
              child: const Text('1. flutter_epub_viewer (WebView + epub.js)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/epub_view'),
              child: const Text('2. epub_view (natívny Flutter)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/epubx_custom'),
              child: const Text('3. epubx + flutter_html (custom)'),
            ),
          ],
        ),
      ),
    );
  }
}
