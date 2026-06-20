import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../shared/fixture_picker.dart';

class EpubxCustomSpikeScreen extends StatefulWidget {
  const EpubxCustomSpikeScreen({super.key});

  @override
  State<EpubxCustomSpikeScreen> createState() =>
      _EpubxCustomSpikeScreenState();
}

class _EpubxCustomSpikeScreenState extends State<EpubxCustomSpikeScreen> {
  EpubBook? _book;
  int _chapterIndex = 0;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _book = null;
      _chapterIndex = 0;
    });
    final p = await pickEpubFile();
    if (p == null) return;
    try {
      final bytes = await File(p).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      setState(() => _book = book);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike C — epubx + flutter_html'),
        actions: [
          IconButton(
            tooltip: 'Otvoriť EPUB',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _book == null
          ? null
          : _buildChapterNav(_book!.Chapters?.length ?? 0),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Chyba: $_error'));
    }
    final book = _book;
    if (book == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    final chapters = book.Chapters ?? [];
    if (chapters.isEmpty) {
      return const Center(child: Text('Kniha nemá žiadne kapitoly.'));
    }
    final chapter = chapters[_chapterIndex];
    final html = chapter.HtmlContent ?? '<p>(prázdna kapitola)</p>';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(data: html),
    );
  }

  Widget _buildChapterNav(int count) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _chapterIndex > 0
                ? () => setState(() => _chapterIndex--)
                : null,
          ),
          Text('Kapitola ${_chapterIndex + 1} / $count'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _chapterIndex < count - 1
                ? () => setState(() => _chapterIndex++)
                : null,
          ),
        ],
      ),
    );
  }
}
