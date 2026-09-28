import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';

import '../localization/localization_extensions.dart';
import '../utils/color_parser.dart';

enum ImageEditorTool {
  select,
  hand,
  pen,
  number,
  text,
  blur,
  rectangle,
  ellipse,
  arrow,
}

/// A lightweight, dependency-free image annotation surface.
///
/// Annotation coordinates are stored relative to the displayed image so they
/// remain stable while the editor is resized. Exporting uses the source image
/// resolution instead of the on-screen resolution.
class ImageAnnotationEditor extends StatefulWidget {
  const ImageAnnotationEditor({
    super.key,
    required this.imageBytes,
    required this.pixelWidth,
    required this.pixelHeight,
    this.quarterTurns = 0,
  });

  final Uint8List imageBytes;
  final int pixelWidth;
  final int pixelHeight;
  final int quarterTurns;

  @override
  State<ImageAnnotationEditor> createState() => ImageAnnotationEditorState();
}

class ImageAnnotationEditorState extends State<ImageAnnotationEditor> {
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  final List<_Annotation> _annotations = [];
  final List<_Annotation> _redo = [];
  final FocusNode _focusNode = FocusNode();

  ImageEditorTool _tool = ImageEditorTool.hand;
  Color _color = const Color(0xFFFF3B30);
  double _strokeWidth = 5;
  int _nextNumber = 1;
  _Annotation? _draft;
  _Annotation? _selectedAnnotation;
  Offset? _lastDragPoint;
  Size _canvasSize = Size.zero;

  bool get hasAnnotations => _annotations.isNotEmpty;

  @override
  void didUpdateWidget(covariant ImageAnnotationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quarterTurns != widget.quarterTurns) {
      _annotations.clear();
      _redo.clear();
      _draft = null;
      _selectedAnnotation = null;
      _nextNumber = 1;
      _transformController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<Uint8List?> exportPng() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || _canvasSize.width <= 0) return null;
    final outputWidth = widget.quarterTurns.isOdd
        ? widget.pixelHeight
        : widget.pixelWidth;
    final ratio = outputWidth / _canvasSize.width;
    final image = await boundary.toImage(pixelRatio: ratio.clamp(0.001, 8.0));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  void _selectTool(ImageEditorTool tool) => setState(() {
    _tool = tool;
    if (tool != ImageEditorTool.select) _selectedAnnotation = null;
  });

  void _undo() {
    if (_annotations.isEmpty) return;
    setState(() {
      final removed = _annotations.removeLast();
      if (identical(_selectedAnnotation, removed)) _selectedAnnotation = null;
      _redo.add(removed);
    });
  }

  void _redoLast() {
    if (_redo.isEmpty) return;
    setState(() => _annotations.add(_redo.removeLast()));
  }

  void _deleteSelected() {
    final selected = _selectedAnnotation;
    if (selected == null) return;
    setState(() {
      _annotations.remove(selected);
      _redo.add(selected);
      _selectedAnnotation = null;
    });
  }

  void _zoom(double factor) {
    final current = _transformController.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.5, 6.0);
    _transformController.value = Matrix4.diagonal3Values(target, target, 1);
    setState(() {});
  }

  Offset _normalized(Offset point) => Offset(
    (point.dx / _canvasSize.width).clamp(0.0, 1.0),
    (point.dy / _canvasSize.height).clamp(0.0, 1.0),
  );

  _Annotation? _hitTest(Offset point) {
    for (final annotation in _annotations.reversed) {
      if (_annotationBounds(annotation).inflate(10).contains(point)) {
        return annotation;
      }
    }
    return null;
  }

  Rect _annotationBounds(_Annotation annotation) {
    Offset denormalize(Offset point) =>
        Offset(point.dx * _canvasSize.width, point.dy * _canvasSize.height);
    if (annotation is _StrokeAnnotation) {
      if (annotation.points.isEmpty) return Rect.zero;
      final points = annotation.points.map(denormalize);
      var left = double.infinity;
      var top = double.infinity;
      var right = double.negativeInfinity;
      var bottom = double.negativeInfinity;
      for (final point in points) {
        left = math.min(left, point.dx);
        top = math.min(top, point.dy);
        right = math.max(right, point.dx);
        bottom = math.max(bottom, point.dy);
      }
      return Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      ).inflate(math.max(4, annotation.width / 2));
    }
    if (annotation is _RegionAnnotation) {
      return Rect.fromPoints(
        denormalize(annotation.start),
        denormalize(annotation.end),
      );
    }
    if (annotation is _NumberAnnotation) {
      return Rect.fromCircle(center: denormalize(annotation.point), radius: 17);
    }
    if (annotation is _TextAnnotation) {
      final origin = denormalize(annotation.point);
      final painter = _textPainter(annotation)
        ..layout(maxWidth: math.max(20, _canvasSize.width - origin.dx));
      return origin & painter.size;
    }
    return Rect.zero;
  }

  void _translateSelected(Offset requestedDelta) {
    final annotation = _selectedAnnotation;
    if (annotation == null) return;
    final bounds = _annotationBounds(annotation);
    final dx = requestedDelta.dx.clamp(
      -bounds.left,
      _canvasSize.width - bounds.right,
    );
    final dy = requestedDelta.dy.clamp(
      -bounds.top,
      _canvasSize.height - bounds.bottom,
    );
    final normalizedDelta = Offset(
      dx / _canvasSize.width,
      dy / _canvasSize.height,
    );
    if (annotation is _StrokeAnnotation) {
      for (var i = 0; i < annotation.points.length; i++) {
        annotation.points[i] += normalizedDelta;
      }
    } else if (annotation is _RegionAnnotation) {
      annotation.start += normalizedDelta;
      annotation.end += normalizedDelta;
    } else if (annotation is _NumberAnnotation) {
      annotation.point += normalizedDelta;
    } else if (annotation is _TextAnnotation) {
      annotation.point += normalizedDelta;
    }
  }

  void _panStart(DragStartDetails details) {
    final point = _normalized(details.localPosition);
    if (_tool == ImageEditorTool.select) {
      return;
    }
    setState(() {
      _redo.clear();
      _draft = switch (_tool) {
        ImageEditorTool.pen => _StrokeAnnotation(
          points: [point],
          color: _color,
          width: _strokeWidth,
        ),
        ImageEditorTool.blur => _RegionAnnotation(
          start: point,
          end: point,
          kind: ImageEditorTool.blur,
          color: _color,
          width: _strokeWidth,
        ),
        ImageEditorTool.rectangle ||
        ImageEditorTool.ellipse ||
        ImageEditorTool.arrow => _RegionAnnotation(
          start: point,
          end: point,
          kind: _tool,
          color: _color,
          width: _strokeWidth,
        ),
        _ => null,
      };
    });
  }

  void _panDown(DragDownDetails details) {
    if (_tool != ImageEditorTool.select) return;
    setState(() {
      _selectedAnnotation = _hitTest(details.localPosition);
      _lastDragPoint = details.localPosition;
    });
  }

  void _panUpdate(DragUpdateDetails details) {
    if (_tool == ImageEditorTool.select && _selectedAnnotation != null) {
      final previous = _lastDragPoint ?? details.localPosition;
      setState(() {
        _translateSelected(details.localPosition - previous);
        _lastDragPoint = details.localPosition;
      });
      return;
    }
    final point = _normalized(details.localPosition);
    final draft = _draft;
    if (draft is _StrokeAnnotation) {
      setState(() => draft.points.add(point));
    } else if (draft is _RegionAnnotation) {
      setState(() => draft.end = point);
    }
  }

  void _panEnd(DragEndDetails details) {
    if (_tool == ImageEditorTool.select) {
      _lastDragPoint = null;
      return;
    }
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _annotations.add(draft);
      _draft = null;
    });
  }

  Future<void> _tap(TapUpDetails details) async {
    final point = _normalized(details.localPosition);
    if (_tool == ImageEditorTool.select) {
      setState(() => _selectedAnnotation = _hitTest(details.localPosition));
      return;
    }
    if (_tool == ImageEditorTool.number) {
      setState(() {
        _redo.clear();
        _annotations.add(
          _NumberAnnotation(point: point, number: _nextNumber++, color: _color),
        );
      });
      return;
    }
    if (_tool != ImageEditorTool.text) return;
    final controller = TextEditingController();
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.image_editor_add_text),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('image-editor-text-field'),
            controller: controller,
            autofocus: true,
            placeholder: context.l10n.image_editor_enter_text,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.l10n.image_editor_add),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() {
      _redo.clear();
      _annotations.add(
        _TextAnnotation(point: point, text: value.trim(), color: _color),
      );
    });
  }

  Future<void> _pickColor() async {
    final controller = TextEditingController(
      text:
          '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
    final colors = <Color>[
      const Color(0xFFFF3B30),
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
      const Color(0xFF34C759),
      const Color(0xFF00C7BE),
      const Color(0xFF007AFF),
      const Color(0xFF5856D6),
      const Color(0xFFAF52DE),
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
    ];
    Color selected = _color;
    final result = await showCupertinoDialog<Color>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text(context.l10n.image_editor_annotation_color),
          content: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: colors
                      .map(
                        (color) => GestureDetector(
                          onTap: () => setDialogState(() {
                            selected = color;
                            controller.text =
                                '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                          }),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected == color
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors.systemGrey3,
                                width: selected == color ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                CupertinoTextField(
                  key: const Key('image-editor-color-field'),
                  controller: controller,
                  placeholder: '#FF3B30',
                  onChanged: (value) {
                    final parsed = ColorParser.parse(value);
                    if (parsed != null) {
                      setDialogState(() => selected = parsed);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: Text(context.l10n.image_editor_select),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _color = result);
  }

  Future<void> _chooseShape() async {
    final tool = await showCupertinoModalPopup<ImageEditorTool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.image_editor_choose_shape),
        actions: [
          _shapeAction(
            context,
            ImageEditorTool.rectangle,
            context.l10n.image_editor_rectangle,
          ),
          _shapeAction(
            context,
            ImageEditorTool.ellipse,
            context.l10n.image_editor_ellipse,
          ),
          _shapeAction(
            context,
            ImageEditorTool.arrow,
            context.l10n.image_editor_arrow,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    if (tool != null && mounted) _selectTool(tool);
  }

  Widget _shapeAction(
    BuildContext context,
    ImageEditorTool tool,
    String label,
  ) => CupertinoActionSheetAction(
    onPressed: () => Navigator.of(context).pop(tool),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final width = widget.quarterTurns.isOdd
        ? widget.pixelHeight.toDouble()
        : widget.pixelWidth.toDouble();
    final height = widget.quarterTurns.isOdd
        ? widget.pixelWidth.toDouble()
        : widget.pixelHeight.toDouble();
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.delete ||
                event.logicalKey == LogicalKeyboardKey.backspace)) {
          _deleteSelected();
        }
      },
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fitted = applyBoxFit(
                  BoxFit.contain,
                  Size(width, height),
                  constraints.biggest,
                ).destination;
                _canvasSize = fitted;
                return ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    panEnabled: _tool == ImageEditorTool.hand,
                    scaleEnabled: _tool == ImageEditorTool.hand,
                    minScale: 0.5,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(120),
                    child: Center(
                      child: SizedBox(
                        width: fitted.width,
                        height: fitted.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              key: _captureKey,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  RotatedBox(
                                    quarterTurns: widget.quarterTurns,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                  ..._annotations.map(_buildAnnotation),
                                  if (_draft != null) _buildAnnotation(_draft!),
                                ],
                              ),
                            ),
                            if (_selectedAnnotation != null)
                              _buildSelection(_selectedAnnotation!),
                            if (_tool != ImageEditorTool.hand)
                              GestureDetector(
                                key: const Key('image-editor-canvas'),
                                behavior: HitTestBehavior.opaque,
                                onTapUp: _tap,
                                onPanDown: _panDown,
                                onPanStart: _panStart,
                                onPanUpdate: _panUpdate,
                                onPanEnd: _panEnd,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelection(_Annotation annotation) {
    final rect = _annotationBounds(annotation).inflate(4);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Container(
          key: const Key('image-editor-selection'),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.activeBlue, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotation(_Annotation annotation) {
    if (annotation is _RegionAnnotation &&
        annotation.kind == ImageEditorTool.blur) {
      final region = annotation;
      final rect = _rectFrom(region.start, region.end);
      return Positioned.fromRect(
        rect: rect,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: CupertinoColors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _AnnotationPainter(annotation: annotation)),
      ),
    );
  }

  Rect _rectFrom(Offset start, Offset end) => Rect.fromPoints(
    Offset(start.dx * _canvasSize.width, start.dy * _canvasSize.height),
    Offset(end.dx * _canvasSize.width, end.dy * _canvasSize.height),
  );

  Widget _buildToolbar() {
    final shapeSelected = {
      ImageEditorTool.rectangle,
      ImageEditorTool.ellipse,
      ImageEditorTool.arrow,
    }.contains(_tool);
    return Container(
      key: const Key('image-editor-toolbar'),
      height: 50,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            _toolButton(
              ImageEditorTool.select,
              Icons.mouse_outlined,
              context.l10n.image_editor_select,
            ),
            _toolButton(
              ImageEditorTool.hand,
              CupertinoIcons.hand_draw,
              context.l10n.image_editor_move,
            ),
            _toolButton(
              ImageEditorTool.pen,
              CupertinoIcons.pencil,
              context.l10n.image_editor_pen,
            ),
            _toolButton(
              ImageEditorTool.number,
              CupertinoIcons.number_circle,
              context.l10n.image_editor_number,
            ),
            _toolButton(
              ImageEditorTool.text,
              CupertinoIcons.textformat,
              context.l10n.text,
            ),
            _toolButton(
              ImageEditorTool.blur,
              CupertinoIcons.drop,
              context.l10n.image_editor_blur,
            ),
            _barButton(
              key: const Key('image-editor-shapes'),
              icon: Icons.category_outlined,
              selected: shapeSelected,
              tooltip: context.l10n.image_editor_shapes,
              onPressed: _chooseShape,
            ),
            _barButton(
              key: const Key('image-editor-color'),
              icon: CupertinoIcons.circle_fill,
              iconColor: _color,
              tooltip: context.l10n.image_editor_choose_color,
              onPressed: _pickColor,
            ),
            SizedBox(
              width: 76,
              child: CupertinoSlider(
                key: const Key('image-editor-stroke-width'),
                value: _strokeWidth,
                min: 2,
                max: 18,
                onChanged: (value) => setState(() => _strokeWidth = value),
              ),
            ),
            _barButton(
              key: const Key('image-editor-zoom-out'),
              icon: Icons.zoom_out,
              tooltip: context.l10n.image_editor_zoom_out,
              onPressed: () => _zoom(0.8),
            ),
            _barButton(
              key: const Key('image-editor-zoom-in'),
              icon: Icons.zoom_in,
              tooltip: context.l10n.image_editor_zoom_in,
              onPressed: () => _zoom(1.25),
            ),
            _barButton(
              key: const Key('image-editor-delete'),
              icon: CupertinoIcons.delete,
              tooltip: context.l10n.delete,
              onPressed: _selectedAnnotation == null ? null : _deleteSelected,
            ),
            _barButton(
              key: const Key('image-editor-undo'),
              icon: CupertinoIcons.arrow_uturn_left,
              tooltip: context.l10n.image_editor_undo,
              onPressed: _annotations.isEmpty ? null : _undo,
            ),
            _barButton(
              key: const Key('image-editor-redo'),
              icon: CupertinoIcons.arrow_uturn_right,
              tooltip: context.l10n.image_editor_redo,
              onPressed: _redo.isEmpty ? null : _redoLast,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(ImageEditorTool tool, IconData icon, String tooltip) =>
      _barButton(
        key: Key('image-editor-tool-${tool.name}'),
        icon: icon,
        tooltip: tooltip,
        selected: _tool == tool,
        onPressed: () => _selectTool(tool),
      );

  Widget _barButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
    Color? iconColor,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Tooltip(
      message: tooltip,
      child: CupertinoButton(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(38, 38),
        borderRadius: BorderRadius.circular(8),
        color: selected
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoColors.transparent,
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 20,
          color:
              iconColor ??
              (selected
                  ? CupertinoColors.white
                  : CupertinoColors.label.resolveFrom(context)),
        ),
      ),
    ),
  );
}

sealed class _Annotation {
  const _Annotation();
}

class _StrokeAnnotation extends _Annotation {
  _StrokeAnnotation({
    required this.points,
    required this.color,
    required this.width,
  });
  final List<Offset> points;
  final Color color;
  final double width;
}

class _RegionAnnotation extends _Annotation {
  _RegionAnnotation({
    required this.start,
    required this.end,
    required this.kind,
    required this.color,
    required this.width,
  });
  Offset start;
  Offset end;
  final ImageEditorTool kind;
  final Color color;
  final double width;
}

class _NumberAnnotation extends _Annotation {
  _NumberAnnotation({
    required this.point,
    required this.number,
    required this.color,
  });
  Offset point;
  final int number;
  final Color color;
}

class _TextAnnotation extends _Annotation {
  _TextAnnotation({
    required this.point,
    required this.text,
    required this.color,
  });
  Offset point;
  final String text;
  final Color color;
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.annotation});
  final _Annotation annotation;

  @override
  void paint(Canvas canvas, Size size) {
    Offset denormalize(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    final annotation = this.annotation;
    if (annotation is _StrokeAnnotation) {
      final paint = Paint()
        ..color = annotation.color
        ..strokeWidth = annotation.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < annotation.points.length; i++) {
        final point = denormalize(annotation.points[i]);
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    } else if (annotation is _RegionAnnotation &&
        annotation.kind != ImageEditorTool.blur) {
      final start = denormalize(annotation.start);
      final end = denormalize(annotation.end);
      final paint = Paint()
        ..color = annotation.color
        ..strokeWidth = annotation.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final rect = Rect.fromPoints(start, end);
      switch (annotation.kind) {
        case ImageEditorTool.rectangle:
          canvas.drawRect(rect, paint);
        case ImageEditorTool.ellipse:
          canvas.drawOval(rect, paint);
        case ImageEditorTool.arrow:
          canvas.drawLine(start, end, paint);
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          const head = 16.0;
          canvas.drawLine(
            end,
            end - Offset(math.cos(angle - 0.55), math.sin(angle - 0.55)) * head,
            paint,
          );
          canvas.drawLine(
            end,
            end - Offset(math.cos(angle + 0.55), math.sin(angle + 0.55)) * head,
            paint,
          );
        default:
          break;
      }
    } else if (annotation is _NumberAnnotation) {
      final center = denormalize(annotation.point);
      const radius = 15.0;
      canvas.drawCircle(center, radius, Paint()..color = annotation.color);
      final painter = TextPainter(
        text: TextSpan(
          text: '${annotation.number}',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    } else if (annotation is _TextAnnotation) {
      final point = denormalize(annotation.point);
      final painter = _textPainter(annotation)
        ..layout(maxWidth: math.max(20, size.width - point.dx));
      painter.paint(canvas, point);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}

TextPainter _textPainter(_TextAnnotation annotation) => TextPainter(
  text: TextSpan(
    text: annotation.text,
    style: TextStyle(
      color: annotation.color,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      shadows: const [Shadow(color: Color(0x99000000), blurRadius: 2)],
    ),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 4,
);
