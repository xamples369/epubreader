import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'library_book_card.dart';
import 'library_providers.dart';

enum LibraryViewMode { grid, list }

class LibraryViewModeNotifier extends Notifier<LibraryViewMode> {
  @override
  LibraryViewMode build() => LibraryViewMode.grid;

  void toggle() {
    state = state == LibraryViewMode.grid
        ? LibraryViewMode.list
        : LibraryViewMode.grid;
  }
}

final libraryViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
        LibraryViewModeNotifier.new);

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final viewMode = ref.watch(libraryViewModeProvider);
    final booksAsync = ref.watch(libraryBooksProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'devReaderPositionProbe',
            tooltip: 'DEV: reader position probe (M3 GATE)',
            child: const Icon(Icons.science),
            onPressed: () => Navigator.of(context)
                .pushNamed('/dev/reader_position_probe'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'addBook',
            icon: const Icon(Icons.add),
            label: Text(l.addBook),
            onPressed: () => _pickAndAdd(context, ref),
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(l.libraryTitle),
        actions: [
          IconButton(
            tooltip: viewMode == LibraryViewMode.grid ? l.viewList : l.viewGrid,
            icon: Icon(viewMode == LibraryViewMode.grid
                ? Icons.view_list
                : Icons.grid_view),
            onPressed: () =>
                ref.read(libraryViewModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.libraryEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          if (viewMode == LibraryViewMode.grid) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 2 / 3.4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: books.length,
              itemBuilder: (_, i) => LibraryBookGridCard(
                book: books[i],
                onTap: () => Navigator.of(context).pushNamed(
                  '/reader',
                  arguments: books[i].id,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (_, i) => LibraryBookListTile(
              book: books[i],
              onTap: () => Navigator.of(context).pushNamed(
                '/reader',
                arguments: books[i].id,
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _pickAndAdd(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
    allowMultiple: false,
    dialogTitle: 'Vyber EPUB súbor',
  );
  if (result == null || result.files.isEmpty) return;
  final path = result.files.first.path;
  if (path == null) return;

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context)!;
  try {
    final useCase = await ref.read(addBookUseCaseProvider.future);
    await useCase.addBook(File(path));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${l.errorOpenEpub} ($e)')));
  }
}
