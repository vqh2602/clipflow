import 'dart:typed_data';

import 'package:clipflow/core/ui/image_annotation_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List sourceImage() {
    final image = img.Image(width: 120, height: 80);
    img.fill(image, color: img.ColorRgb8(245, 245, 245));
    return Uint8List.fromList(img.encodePng(image));
  }

  testWidgets('image editor exposes all requested editing tools', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 800,
          height: 500,
          child: ImageAnnotationEditor(
            imageBytes: sourceImage(),
            pixelWidth: 120,
            pixelHeight: 80,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('image-editor-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-tool-select')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-tool-pen')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-tool-number')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-tool-text')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-tool-blur')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-shapes')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-color')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-zoom-in')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-zoom-out')), findsOneWidget);
    expect(find.byKey(const Key('image-editor-delete')), findsOneWidget);
  });

  testWidgets('drawing can be undone, redone, and exported', (tester) async {
    final key = GlobalKey<ImageAnnotationEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 800,
          height: 500,
          child: ImageAnnotationEditor(
            key: key,
            imageBytes: sourceImage(),
            pixelWidth: 120,
            pixelHeight: 80,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('image-editor-tool-pen')));
    await tester.pump();
    final canvas = find.byKey(const Key('image-editor-canvas'));
    final rect = tester.getRect(canvas);
    await tester.dragFrom(
      rect.topLeft + const Offset(30, 30),
      const Offset(80, 30),
    );
    await tester.pump();

    expect(key.currentState!.hasAnnotations, isTrue);
    await tester.tap(find.byKey(const Key('image-editor-undo')));
    await tester.pump();
    expect(key.currentState!.hasAnnotations, isFalse);
    await tester.tap(find.byKey(const Key('image-editor-redo')));
    await tester.pump();
    expect(key.currentState!.hasAnnotations, isTrue);

    final bytes = await tester.runAsync(key.currentState!.exportPng);
    expect(bytes, isNotNull);
    final exported = img.decodePng(bytes!);
    expect(exported, isNotNull);
    expect(exported!.width, 120);
    expect(exported.height, 80);
  });

  testWidgets('added annotations can be selected, moved, and deleted', (
    tester,
  ) async {
    final key = GlobalKey<ImageAnnotationEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 800,
          height: 500,
          child: ImageAnnotationEditor(
            key: key,
            imageBytes: sourceImage(),
            pixelWidth: 120,
            pixelHeight: 80,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('image-editor-tool-number')));
    await tester.pump();
    final canvas = find.byKey(const Key('image-editor-canvas'));
    final canvasRect = tester.getRect(canvas);
    final start = canvasRect.center;
    await tester.tapAt(start);
    await tester.pump();
    expect(key.currentState!.hasAnnotations, isTrue);

    await tester.tap(find.byKey(const Key('image-editor-tool-select')));
    await tester.tapAt(start);
    await tester.pump();
    final selection = find.byKey(const Key('image-editor-selection'));
    expect(selection, findsOneWidget);
    final before = tester.getCenter(selection);

    await tester.dragFrom(start, const Offset(70, 35));
    await tester.pump();
    final after = tester.getCenter(selection);
    expect(after.dx, greaterThan(before.dx + 50));
    expect(after.dy, greaterThan(before.dy + 20));

    await tester.tap(find.byKey(const Key('image-editor-delete')));
    await tester.pump();
    expect(key.currentState!.hasAnnotations, isFalse);
    expect(selection, findsNothing);
  });
}
