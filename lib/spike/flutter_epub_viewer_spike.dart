import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../shared/fixture_picker.dart';

class FlutterEpubViewerSpikeScreen extends StatefulWidget {
  const FlutterEpubViewerSpikeScreen({super.key});

  @override
  State<FlutterEpubViewerSpikeScreen> createState() =>
      _FlutterEpubViewerSpikeScreenState();
}

class _FlutterEpubViewerSpikeScreenState
    extends State<FlutterEpubViewerSpikeScreen> {
  final EpubController _controller = EpubController();
  String? _path;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() => _error = null);
    final p = await pickEpubFile();
    if (p == null) return;
    setState(() => _path = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike A — flutter_epub_viewer'),
        actions: [
          IconButton(
            tooltip: 'Otvoriť EPUB',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Chyba: $_error'));
    }
    if (_path == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    return EpubViewer(
      epubSource: EpubSource.fromFile(File(_path!)),
      epubController: _controller,
      displaySettings: EpubDisplaySettings(
        flow: EpubFlow.paginated,
        snap: true,
      ),
      onChaptersLoaded: (chapters) {
        debugPrint(
          'flutter_epub_viewer: loaded ${chapters.length} chapters',
        );
      },
      onEpubLoaded: () => debugPrint('flutter_epub_viewer: ready'),
      onRelocated: (location) {
        debugPrint('flutter_epub_viewer: at ${location.startCfi}');
      },
    );
  }
}
