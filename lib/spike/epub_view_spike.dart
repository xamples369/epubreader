import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

import '../shared/fixture_picker.dart';

class EpubViewSpikeScreen extends StatefulWidget {
  const EpubViewSpikeScreen({super.key});

  @override
  State<EpubViewSpikeScreen> createState() => _EpubViewSpikeScreenState();
}

class _EpubViewSpikeScreenState extends State<EpubViewSpikeScreen> {
  EpubController? _controller;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller = null;
    });
    final p = await pickEpubFile();
    if (p == null) return;
    try {
      final bytes = await File(p).readAsBytes();
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike B — epub_view'),
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
    final c = _controller;
    if (c == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    return EpubView(controller: c);
  }
}
