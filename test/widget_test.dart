import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/main.dart';

void main() {
  testWidgets('Spike menu shows three candidate buttons', (tester) async {
    await tester.pumpWidget(const EpubReaderApp());

    expect(find.text('Vyber spike na vyskúšanie:'), findsOneWidget);
    expect(find.textContaining('1. flutter_epub_viewer'), findsOneWidget);
    expect(find.textContaining('2. epub_view'), findsOneWidget);
    expect(find.textContaining('3. epubx + flutter_html'), findsOneWidget);
  });
}
