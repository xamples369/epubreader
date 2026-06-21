import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/book.dart';
import '../../l10n/app_localizations.dart';

class LibraryBookGridCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const LibraryBookGridCard({
    super.key,
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: book.coverPath != null && File(book.coverPath!).existsSync()
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
                : Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.book, size: 48),
                  ),
          ),
          const SizedBox(height: 4),
          Text(book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(book.author ?? l.unknownAuthor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class LibraryBookListTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const LibraryBookListTile({
    super.key,
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 40,
        child: book.coverPath != null && File(book.coverPath!).existsSync()
            ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
            : const Icon(Icons.book),
      ),
      title: Text(book.title),
      subtitle: Text(book.author ?? l.unknownAuthor),
    );
  }
}
