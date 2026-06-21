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
