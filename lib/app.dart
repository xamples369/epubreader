import 'package:flutter/material.dart';

import 'features/library/library_screen.dart';
import 'features/reader/reader_stub_screen.dart';
import 'l10n/app_localizations.dart';
import 'spike/anchor_probe/anchor_probe_screen.dart';

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/dev/anchor_probe') {
          return MaterialPageRoute(
            builder: (_) => const AnchorProbeScreen(),
          );
        }
        if (settings.name == '/reader') {
          final bookId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ReaderStubScreen(bookId: bookId),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not found')),
          body: Center(child: Text('Route: ${settings.name}')),
        ),
      ),
    );
  }
}
