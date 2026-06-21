import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'epub_view_paragraph_bridge.dart';

/// M3 GATE Probe — equivalence verification for Vetva 1.5 (ADR 0005).
///
/// Otázka: dáva volanie `parseParagraphs` z našej strany identický výsledok
/// ako interný `_EpubViewState`?
///
/// Test: porovnáme `bridge.chapterIndexes[i]` proti
/// `EpubController.tableOfContents()[i].startIndex` per chapter. Ak sedia na
/// všetkých 4 fixtures (najmä na **divina** ktorá má SubChapters), Vetva 1.5
/// equivalence je dokázaná → ADR 0005 final.
///
/// Spike sa po dokončení M3 GATE zmaže (T6 plánu).
class ReaderPositionProbeScreen extends StatefulWidget {
  const ReaderPositionProbeScreen({super.key});

  @override
  State<ReaderPositionProbeScreen> createState() =>
      _ReaderPositionProbeScreenState();
}

class _ReaderPositionProbeScreenState
    extends State<ReaderPositionProbeScreen> {
  EpubController? _controller;
  String? _fixtureName;
  String? _error;
  final List<String> _log = [];
  bool _equivalenceReady = false;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
      _fixtureName = null;
      _log.clear();
      _equivalenceReady = false;
    });

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      dialogTitle: 'Vyber EPUB fixture',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() {
        _controller = controller;
        _fixtureName = path.split(Platform.pathSeparator).last;
      });

      controller.loadingState.addListener(() {
        if (controller.loadingState.value == EpubViewLoadingState.success) {
          _logLine('[load] success — equivalence probe ready');
          setState(() => _equivalenceReady = true);
        } else if (controller.loadingState.value ==
            EpubViewLoadingState.error) {
          _logLine('[load] ERROR');
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _logLine(String line) {
    setState(() {
      _log.add(line);
      if (_log.length > 200) {
        _log.removeRange(0, _log.length - 200);
      }
    });
  }

  Future<void> _runEquivalenceProbe() async {
    final c = _controller;
    if (c == null) {
      _logLine('[probe] no controller');
      return;
    }
    if (c.loadingState.value != EpubViewLoadingState.success) {
      _logLine('[probe] not loaded yet — wait for loadingState success');
      return;
    }

    _logLine('=== EQUIVALENCE PROBE START ($_fixtureName) ===');

    final book = await c.document;

    // 1. Naša strana — bridge volá parseChapters + parseParagraphs
    final ours = EpubViewParagraphBridge.extractFlatParagraphs(book);
    _logLine('[ours] flatParagraphs.length = ${ours.flatParagraphs.length}');
    _logLine('[ours] chapterIndexes.length = ${ours.chapterIndexes.length}');
    _logLine('[ours] chapterIndexes (first 10) = '
        '${ours.chapterIndexes.take(10).toList()}');

    // 2. EpubView strana — tableOfContents() vystavuje absolute startIndex
    final viewToc = c.tableOfContents();
    _logLine('[view] tableOfContents().length = ${viewToc.length}');
    final viewStartIndexes = viewToc.map((e) => e.startIndex).toList();
    _logLine('[view] startIndexes (first 10) = '
        '${viewStartIndexes.take(10).toList()}');

    // 3. Compare
    if (ours.chapterIndexes.length != viewToc.length) {
      _logLine('❌ EQUIVALENCE FAILED: chapter count mismatch '
          '(ours=${ours.chapterIndexes.length}, view=${viewToc.length})');
      _logLine('=== PROBE END (FAILED) ===');
      return;
    }

    var allMatch = true;
    final mismatches = <String>[];
    for (var i = 0; i < ours.chapterIndexes.length; i++) {
      final our = ours.chapterIndexes[i];
      final view = viewStartIndexes[i];
      if (our != view) {
        allMatch = false;
        mismatches.add('chapter $i: ours=$our view=$view (Δ=${view - our})');
      }
    }

    if (allMatch) {
      _logLine('✅ EQUIVALENCE PROVEN for $_fixtureName: '
          'all ${ours.chapterIndexes.length} chapter startIndexes match');
      _logLine('=== PROBE END (PASSED) ===');
    } else {
      _logLine('❌ EQUIVALENCE FAILED for $_fixtureName: '
          '${mismatches.length} mismatch(es)');
      for (final m in mismatches.take(10)) {
        _logLine('   $m');
      }
      _logLine('=== PROBE END (FAILED) ===');
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
        title: const Text('M3 GATE — Vetva 1.5 equivalence probe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Otvoriť fixture',
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_fixtureName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text('Fixture: $_fixtureName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Text('Error: $_error'),
            ),
          Container(
            height: 280,
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _log.join('\n'),
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11),
              ),
            ),
          ),
          if (_controller != null)
            Expanded(child: EpubView(controller: _controller!))
          else
            const Expanded(
              child: Center(
                  child: Text('Klikni priečinok hore → vyber fixture\n\n'
                      'Pre M3 GATE otestuj všetky 4: alice, pride, '
                      'frankenstein, divina.\nDivina je kritická — '
                      'má SubChapters.',
                      textAlign: TextAlign.center)),
            ),
        ],
      ),
      floatingActionButton: !_equivalenceReady
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('Run equivalence probe'),
              onPressed: _runEquivalenceProbe,
            ),
    );
  }
}
