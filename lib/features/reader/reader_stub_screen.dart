import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../library/library_providers.dart';

class ReaderStubScreen extends ConsumerWidget {
  final String bookId;
  const ReaderStubScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(libraryBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.readerStubTitle)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (books) {
          final matches = books.where((b) => b.id == bookId).toList();
          if (matches.isEmpty) {
            return const Center(child: Text('Book not found'));
          }
          final book = matches.first;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(book.author ?? l.unknownAuthor,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                Text(l.readerStubBody),
              ],
            ),
          );
        },
      ),
    );
  }
}
