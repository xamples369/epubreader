import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/main.dart';

void main() {
  testWidgets('Dev menu shows the chosen renderer entry point',
      (tester) async {
    await tester.pumpWidget(const EpubReaderApp());

    expect(find.textContaining('dev menu'), findsAtLeastNWidgets(1));
    expect(find.textContaining('epub_view'), findsAtLeastNWidgets(1));
    expect(find.textContaining('flutter_epub_viewer'), findsNothing);
    expect(find.textContaining('epubx'), findsNothing);
  });
}
