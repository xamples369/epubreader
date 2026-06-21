import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'inline_canonical_extractor.dart';

class AnchorProbeScreen extends StatefulWidget {
  const AnchorProbeScreen({super.key});

  @override
  State<AnchorProbeScreen> createState() => _AnchorProbeScreenState();
}

class _AnchorProbeScreenState extends State<AnchorProbeScreen> {
  EpubController? _controller;
  List<(String, String)>? _canonicalChapters;
  String? _fixtureName;
  String? _selection;
  String? _matchResult;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller = null;
      _canonicalChapters = null;
      _selection = null;
      _matchResult = null;
      _fixtureName = null;
    });
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      dialogTitle: 'Vyber EPUB fixture na probe',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final canonical = await InlineCanonicalExtractor.extractAll(bytes);
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() {
        _controller = controller;
        _canonicalChapters = canonical;
        _fixtureName = path.split(Platform.pathSeparator).last;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _checkSelectionAgainstCanonical(String selection) {
    final chapters = _canonicalChapters;
    if (chapters == null) return;
    final normalisedSel = _normalize(selection);
    if (normalisedSel.isEmpty) {
      setState(() {
        _selection = selection;
        _matchResult = '⚠️ Prázdna selekcia po normalizácii';
      });
      return;
    }
    final hits = <String>[];
    for (final (id, text) in chapters) {
      if (text.contains(normalisedSel)) hits.add(id);
    }
    setState(() {
      _selection = selection;
      if (hits.isEmpty) {
        _matchResult = '❌ NIE — selekcia sa NEnájde ani v jednej kapitole. '
            'Canonical/render rozchádza. Skopíruj presný text a pošli na rozbor.';
      } else {
        _matchResult = '✅ ÁNO — nájdená v ${hits.length} kapitolách: '
            '${hits.take(3).join(", ")}';
      }
    });
  }

  static String _normalize(String text) {
    final stripped = text.replaceAll('­', '');
    final collapsed = stripped.replaceAll(RegExp(r'[\s ]+'), ' ');
    return collapsed.trim();
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
        title: const Text('Anchor Probe (S0 GATE)'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'S0 GATE: otvor fixture → prečítaj 3-5 fráz priamo z čítača nižšie '
                  '(epub_view nedovoľuje copy) → klikni „Check phrase" → '
                  'NAPÍŠ tých 5-10 slov ručne → Check. '
                  'Cieľ: VŠETKY frázy majú vrátiť ✅.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_fixtureName != null) ...[
                  const SizedBox(height: 6),
                  Text('Fixture: $_fixtureName',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      'Kapitol naparsovaných: '
                      '${_canonicalChapters?.length ?? 0}',
                      style: const TextStyle(fontSize: 11)),
                ],
                if (_selection != null) ...[
                  const SizedBox(height: 8),
                  Text('Selekcia: "${_selection!}"',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ],
                if (_matchResult != null) ...[
                  const SizedBox(height: 4),
                  Text(_matchResult!,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          if (_controller != null)
            Expanded(child: EpubView(controller: _controller!)),
          if (_controller == null)
            const Expanded(
              child: Center(child: Text('Klikni priečinok hore a vyber EPUB')),
            ),
        ],
      ),
      floatingActionButton: _canonicalChapters == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('Check phrase'),
              onPressed: () async {
                final input = await _promptForSelection(context);
                if (input != null && input.isNotEmpty) {
                  _checkSelectionAgainstCanonical(input);
                }
              },
            ),
    );
  }

  Future<String?> _promptForSelection(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Napíš frázu na overenie'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Napíš 5-10 slov z toho čo vidíš v čítači. '
                'Diakritika musí sedieť.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Zrušiť')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Check')),
        ],
      ),
    );
  }
}
