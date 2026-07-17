import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:infer_notes/core/theme.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late PainterController _controller;
  bool _showEraserSettings = false;
  double _eraserSize = 20.0;
  final double _penSize = 4.0;
  
  // Use a ValueNotifier for the pointer so we don't rebuild the entire canvas every frame!
  final ValueNotifier<Offset?> _pointerNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _controller = PainterController(
      settings: PainterSettings(
        freeStyle: FreeStyleSettings(
          color: Colors.black,
          strokeWidth: _penSize,
        ),
      ),
    );
  }

  void _setMode(FreeStyleMode mode) {
    setState(() {
      _controller.freeStyleMode = mode;
      if (mode == FreeStyleMode.erase) {
        _showEraserSettings = true;
      } else {
        _showEraserSettings = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentSize = _controller.freeStyleMode == FreeStyleMode.erase ? _eraserSize : _penSize;
    
    _controller.freeStyleSettings = _controller.freeStyleSettings.copyWith(
      color: isDarkMode ? Colors.white : Colors.black,
      strokeWidth: currentSize,
    );

    // A quick toolbar to demonstrate drawing modes
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          width: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              AppIconButton(
                icon: Icons.edit,
                tooltip: 'Draw',
                isSelected: _controller.freeStyleMode == FreeStyleMode.draw,
                onPressed: () => _setMode(FreeStyleMode.draw),
              ),
              AppIconButton(
                icon: Icons.cleaning_services,
                tooltip: 'Erase',
                isSelected: _controller.freeStyleMode == FreeStyleMode.erase,
                onPressed: () {
                  if (_controller.freeStyleMode == FreeStyleMode.erase) {
                    setState(() => _showEraserSettings = !_showEraserSettings);
                  } else {
                    _setMode(FreeStyleMode.erase);
                  }
                },
              ),
              AppIconButton(
                icon: Icons.undo,
                tooltip: 'Undo',
                onPressed: () {
                  if (_controller.canUndo) _controller.undo();
                },
              ),
              AppIconButton(
                icon: Icons.redo,
                tooltip: 'Redo',
                onPressed: () {
                  if (_controller.canRedo) _controller.redo();
                },
              ),
              AppIconButton(
                icon: Icons.delete,
                tooltip: 'Clear',
                onPressed: () => _controller.clearDrawables(),
              ),
            ],
          ),
        ),
      ),
    ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: Stack(
            children: [
              ClipRect(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor, // Theme canvas background
                  child: Listener(
                    onPointerHover: (event) => _pointerNotifier.value = event.localPosition,
                    onPointerMove: (event) => _pointerNotifier.value = event.localPosition,
                    onPointerDown: (event) => _pointerNotifier.value = event.localPosition,
                    child: MouseRegion(
                      cursor: _controller.freeStyleMode == FreeStyleMode.erase 
                          ? SystemMouseCursors.precise  // Always show precise crosshair
                          : (_controller.freeStyleMode == FreeStyleMode.draw ? SystemMouseCursors.precise : SystemMouseCursors.basic),
                      onExit: (_) {
                        _pointerNotifier.value = null;
                      },
                      child: FlutterPainter(
                        controller: _controller,
                      ),
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<Offset?>(
                valueListenable: _pointerNotifier,
                builder: (context, pos, child) {
                  if (pos == null || _controller.freeStyleMode != FreeStyleMode.erase) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: pos.dx - (_eraserSize / 2),
                    top: pos.dy - (_eraserSize / 2),
                    child: IgnorePointer(
                      child: Container(
                        width: _eraserSize,
                        height: _eraserSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_showEraserSettings)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Eraser Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Slider(
                              value: _eraserSize,
                              min: 10,
                              max: 100,
                              activeColor: Theme.of(context).primaryColor,
                              onChanged: (val) {
                                setState(() {
                                  _eraserSize = val;
                                });
                              },
                            ),
                            Text('${_eraserSize.toInt()}px', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showEraserSettings = false;
                                });
                              },
                              child: const Text('OK', style: TextStyle(fontSize: 12)),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
