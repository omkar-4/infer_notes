import 'package:infer_notes/features/aura/aura_status_bar.dart';
import 'package:infer_notes/features/settings/settings_dialog.dart';
import 'package:infer_notes/features/aura/aura_metrics_engine.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:async';
import '../../core/animated_notification.dart';
import '../updater/updater_service.dart';
import 'package:infer_notes/features/canvas/canvas_screen.dart';
import '../feedback/feedback_service.dart';
import '../../main.dart';
import '../../core/theme.dart';
import 'package:window_manager/window_manager.dart';

import 'blocks/block_model.dart';
import 'blocks/block_editor_controller.dart';
import 'blocks/block_editor.dart';

part 'note_editor_state.dart';
part 'note_editor_actions.dart';
part 'note_editor_ui.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with NoteEditorState, NoteEditorActions, NoteEditorUI {
  double _lastScreenWidth = 0;
  final ScrollController _toolbarScrollController = ScrollController();
  final GlobalKey<BlockEditorState> blockEditorKey = GlobalKey<BlockEditorState>();
  Rect? localSelectionRect;
  Rect? globalSelectionRect;
  Offset? dragStartLocal;
  Offset? dragStartGlobal;
  bool isDragSelecting = false;

  @override
  void initState() {
    super.initState();
    
    UpdaterService.onStateChange = (state, error) {
      if (mounted) {
        _handleUpdaterStateChange(state, error);
      }
    };
  }

  void _handleUpdaterStateChange(UpdaterState state, UpdaterError? error) {
    if (error != null) {
      String msg = 'An unknown error occurred.';
      switch (error) {
        case UpdaterError.noInternetConnection: msg = 'No internet connection.'; break;
        case UpdaterError.manifestNotFound: msg = 'Update file not found on server (404). Please report this through the feedback portal in the sidebar.'; break;
        case UpdaterError.manifestFormatError: msg = 'The update data is corrupted. Please report this through the feedback portal in the sidebar.'; break;
        case UpdaterError.manifestFetchFailed: msg = 'Failed to check for updates. The server returned an error. Please report this through the feedback portal in the sidebar.'; break;
        case UpdaterError.downloadFailed: msg = 'Download failed.'; break;
        case UpdaterError.checksumMismatch: msg = 'Download corrupted or tampered.'; break;
        case UpdaterError.installationFailed: msg = 'Installation failed.'; break;
        case UpdaterError.miscError: msg = 'An unexpected error occurred.'; break;
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Error'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ignore'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                UpdaterService.checkUpdatesManually();
              },
              child: const Text('Try Again'),
            ),
          ],
        )
      );
    } else if (state == UpdaterState.idle) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You are already using the latest version (${UpdaterService.latestAppVersion}).'), duration: const Duration(seconds: 2)));
    } else if (state == UpdaterState.readyToInstall) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Ready'),
          content: const Text('A new update has been securely downloaded. Restart now to apply?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Update on Next Launch'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                UpdaterService.executeInstall();
              },
              child: const Text('Restart Now'),
            ),
          ],
        )
      );
    }
  }



  void _focusClosestBlockToPoint(Offset localPosition) {
    final workareaBox = context.findRenderObject() as RenderBox?;
    if (workareaBox == null) return;
    final globalPos = workareaBox.localToGlobal(localPosition);
    
    final blockKeys = blockEditorKey.currentState?.blockKeys;
    if (blockKeys == null || blockKeys.isEmpty) return;
    
    double minDistance = double.infinity;
    double minHorizDistance = double.infinity;
    MarkdownBlock? closestGlobalBlock;
    MarkdownBlock? closestHorizontalBlock;
    
    for (var block in blockController.blocks) {
      final key = blockKeys[block.id];
      if (key == null || key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      
      final blockPos = box.localToGlobal(Offset.zero);
      final blockRect = blockPos & box.size;
      
      final bool intersectsVertically = globalPos.dy >= blockRect.top && globalPos.dy <= blockRect.bottom;
      
      if (intersectsVertically) {
        final dist = (globalPos.dx - blockRect.center.dx).abs();
        if (dist < minHorizDistance) {
          minHorizDistance = dist;
          closestHorizontalBlock = block;
        }
      }
      
      final distToCenter = (globalPos - blockRect.center).distance;
      if (distToCenter < minDistance) {
        minDistance = distToCenter;
        closestGlobalBlock = block;
      }
    }
    
    final targetBlock = closestHorizontalBlock ?? closestGlobalBlock;
    if (targetBlock != null) {
      targetBlock.focusNode.requestFocus();
      targetBlock.controller.selection = TextSelection.collapsed(offset: targetBlock.controller.text.length);
    }
    blockController.clearSelection();
  }

  void _setLayoutMode(String mode) async {
    if (mode == 'zen') {
      await windowManager.setFullScreen(true);
    } else if (layoutMode == 'zen' && mode != 'zen') {
      await windowManager.setFullScreen(false);
    }
    setState(() {
      layoutMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    final bool isScreenTooSmall = screenWidth <= (sidebarWidth + 8);
    final bool effectiveSidebarVisible = isSidebarVisible && !isScreenTooSmall && layoutMode != 'zen';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastScreenWidth > 600 && screenWidth <= 600 && isSidebarVisible) {
        setState(() { isSidebarVisible = false; });
      }
      if (isScreenTooSmall && isSidebarVisible) {
        setState(() { isSidebarVisible = false; });
      }
      _lastScreenWidth = screenWidth;
    });

    double editorMaxWidth = 700.0;
    if (layoutMode == 'centered_wide') {
      editorMaxWidth = 1000.0;
    } else if (layoutMode == 'zen') {
      editorMaxWidth = 800.0;
    }

    Widget editorContent = !isNoteOpen 
        ? const Center(child: Text('no note open'))
        : BlockEditor(
            key: blockEditorKey,
            controller: blockController,
            fontFamily: selectedFont == 'Serif'
                ? 'Times New Roman'
                : (selectedFont == 'Monospace' ? 'JetBrains Mono' : 'Google Sans'),
            maxWidth: editorMaxWidth,
            scrollController: editorScrollController,
          );

    Widget scaffoldBody = Listener(
      onPointerDown: (_) {
        if (_contextMenuEntry != null) {
          hideContextMenu();
        }
      },
      child: SafeArea(
        child: Row(
          children: [
            AnimatedContainer(
              duration: isScreenTooSmall || isDragging ? Duration.zero : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: effectiveSidebarVisible ? sidebarWidth : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: sidebarWidth,
                  maxWidth: sidebarWidth,
                  child: Row(
                    children: [
                      Expanded(child: buildSidebar(context)),
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          onHorizontalDragStart: (details) {
                            setState(() { isDragging = true; });
                          },
                          onHorizontalDragEnd: (details) {
                            setState(() { isDragging = false; });
                          },
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              sidebarWidth += details.delta.dx;
                              if (sidebarWidth < 220) sidebarWidth = 220;
                              if (sidebarWidth > MediaQuery.of(context).size.width / 2) {
                                sidebarWidth = MediaQuery.of(context).size.width / 2;
                              }
                            });
                          },
                          child: Container(
                            width: 12.0,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 1.0,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  if (layoutMode != 'zen') ...[
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double rightSideWidth = (isNoteOpen && !isCanvasMode) ? 350.0 : 120.0;
                          final double minRequiredWidth = rightSideWidth + 48.0;
                          
                          double titleWidth = 0.0;
                          if (currentFilePath != null && !isCanvasMode) {
                            if (isEditingTitle) {
                              titleWidth = 200.0;
                            } else {
                              final text = currentFilePath!.split(Platform.pathSeparator).last;
                              final TextPainter textPainter = TextPainter(
                                text: TextSpan(text: text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                textDirection: Directionality.of(context),
                              )..layout();
                              titleWidth = textPainter.size.width;
                            }
                          }
                          
                          final double titleThreshold = minRequiredWidth + titleWidth + 16.0;
                          final bool showTitle = constraints.maxWidth >= titleThreshold;
                          final bool isTight = constraints.maxWidth < minRequiredWidth;

                          Widget contentRow = Row(
                            children: [
                              AppIconButton(
                                icon: Icons.menu,
                                size: 20,
                                onPressed: isScreenTooSmall 
                                    ? null 
                                    : () {
                                        setState(() {
                                          isSidebarVisible = !isSidebarVisible;
                                        });
                                      },
                                tooltip: isScreenTooSmall ? 'Window too small' : 'Toggle Sidebar',
                              ),
                              const SizedBox(width: 8),
                              if (showTitle && currentFilePath != null && !isCanvasMode)
                                isEditingTitle
                                    ? SizedBox(
                                        width: 200,
                                        height: 30,
                                        child: Focus(
                                          onFocusChange: (hasFocus) {
                                            if (!hasFocus && isEditingTitle) {
                                              renameCurrentNote(titleController.text.trim());
                                            }
                                          },
                                          child: TextField(
                                            controller: titleController,
                                            focusNode: titleFocusNode,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              border: OutlineInputBorder(),
                                            ),
                                            onSubmitted: (value) {
                                              renameCurrentNote(value.trim());
                                            },
                                          ),
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            isEditingTitle = true;
                                            titleController.text = currentFilePath!.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.md$|\.txt$'), '');
                                          });
                                          Future.delayed(const Duration(milliseconds: 50), () {
                                            titleFocusNode.requestFocus();
                                          });
                                        },
                                        child: Text(
                                          currentFilePath!.split(Platform.pathSeparator).last + (unsavedFiles.contains(currentFilePath) ? ' ●' : ''),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              if (!isTight) const Spacer(),

                              AppIconButton(
                                icon: isCanvasMode ? Icons.edit_document : Icons.brush,
                                onPressed: () {
                                  if (currentFilePath != null && unsavedFiles.contains(currentFilePath)) {
                                    saveNoteAtomic(currentFilePath!, blockController.getMarkdown(), isManual: false).then((_) {
                                      _fileCache[currentFilePath!] = blockController.getMarkdown();
                                    });
                                  }
                                  setState(() {
                                    isCanvasMode = !isCanvasMode;
                                  });
                                },
                                tooltip: isCanvasMode ? 'Switch to Notes' : 'Switch to Canvas',
                              ),
                              AppIconButton(
                                icon: Icons.system_update_alt,
                                onPressed: UpdaterService.checkUpdatesManually,
                                tooltip: 'Check for Updates',
                              ),
                              AppIconButton(
                                icon: Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
                                onPressed: () {
                                  themeNotifier.value = Theme.of(context).brightness == Brightness.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark;
                                },
                                tooltip: 'Toggle Theme',
                              ),
                              if (isNoteOpen && !isCanvasMode) ...[
                                AppIconButton(
                                  icon: Icons.save,
                                  onPressed: () => saveNoteAtomic(currentFilePath!, blockController.getMarkdown(), isManual: true),
                                  tooltip: 'Save',
                                ),
                                AppIconButton(
                                  icon: Icons.close,
                                  onPressed: closeNote,
                                  tooltip: 'Close Note',
                                ),
                              ],
                            ],
                          );

                          if (isTight) {
                            return ScrollbarTheme(
                              data: ScrollbarThemeData(
                                thickness: WidgetStateProperty.all(6.0),
                                radius: const Radius.circular(4.0),
                                crossAxisMargin: 2.0,
                              ),
                              child: Scrollbar(
                                controller: _toolbarScrollController,
                                thumbVisibility: true,
                                interactive: true,
                                child: SingleChildScrollView(
                                  controller: _toolbarScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: minRequiredWidth),
                                    child: contentRow,
                                  ),
                                ),
                              ),
                            );
                          }

                          return contentRow;
                        },
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                  ],
                  Expanded(
                    child: isCanvasMode 
                        ? const CanvasScreen()
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (details) {
                              final workareaBox = context.findRenderObject() as RenderBox?;
                              if (workareaBox != null) {
                                final workareaWidth = workareaBox.size.width;
                                if (details.localPosition.dx >= workareaWidth - 20) {
                                  return;
                                }
                              }
                              _focusClosestBlockToPoint(details.localPosition);
                            },
                            onPanStart: (details) {
                              final workareaBox = context.findRenderObject() as RenderBox?;
                              if (workareaBox == null) return;
                              final workareaWidth = workareaBox.size.width;
                              if (details.localPosition.dx >= workareaWidth - 20) {
                                return;
                              }
                              double editorMaxWidth = 700.0;
                              if (layoutMode == 'centered_wide') {
                                editorMaxWidth = 1000.0;
                              } else if (layoutMode == 'zen') {
                                editorMaxWidth = 800.0;
                              }
                              final leftMargin = (workareaWidth - editorMaxWidth) / 2.0;
                              final rightMargin = leftMargin + editorMaxWidth;
                              final startX = details.localPosition.dx;
                              if (startX < leftMargin || startX > rightMargin) {
                                setState(() {
                                  dragStartLocal = details.localPosition;
                                  dragStartGlobal = details.globalPosition;
                                  localSelectionRect = Rect.fromPoints(dragStartLocal!, dragStartLocal!);
                                  globalSelectionRect = Rect.fromPoints(dragStartGlobal!, dragStartGlobal!);
                                  isDragSelecting = true;
                                });
                              }
                            },
                            onPanUpdate: (details) {
                              if (dragStartLocal != null) {
                                final workareaBox = context.findRenderObject() as RenderBox?;
                                if (workareaBox != null) {
                                  final workareaWidth = workareaBox.size.width;
                                  final maxAllowedX = workareaWidth - 20.0;

                                  double clampedLocalX = details.localPosition.dx;
                                  if (clampedLocalX > maxAllowedX) {
                                    clampedLocalX = maxAllowedX;
                                  }

                                  final double deltaX = details.localPosition.dx - clampedLocalX;
                                  final double clampedGlobalX = details.globalPosition.dx - deltaX;

                                  final clampedLocalPos = Offset(clampedLocalX, details.localPosition.dy);
                                  final clampedGlobalPos = Offset(clampedGlobalX, details.globalPosition.dy);

                                  setState(() {
                                    localSelectionRect = Rect.fromPoints(dragStartLocal!, clampedLocalPos);
                                    globalSelectionRect = Rect.fromPoints(dragStartGlobal!, clampedGlobalPos);
                                    final blockKeys = blockEditorKey.currentState?.blockKeys;
                                    if (blockKeys != null && blockKeys.isNotEmpty) {
                                      blockController.selectOverlappingBlocks(globalSelectionRect!, blockKeys);
                                    }
                                  });
                                }
                              }
                            },
                            onPanEnd: (_) {
                              setState(() {
                                dragStartLocal = null;
                                dragStartGlobal = null;
                                localSelectionRect = null;
                                globalSelectionRect = null;
                                isDragSelecting = false;
                              });
                            },
                            child: Stack(
                              children: [
                                 editorContent,
                                if (isDragSelecting && localSelectionRect != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: SelectionPainter(localSelectionRect),
                                      ),
                                    ),
                                  ),
                                if (layoutMode == 'zen')
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: FloatingExitZenButton(
                                      onPressed: () => _setLayoutMode('centered_narrow'),
                                    ),
                                  ),
                                if (isNoteOpen && !isCanvasMode)
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: FloatingToolsMenu(
                                      selectedFont: selectedFont,
                                      layoutMode: layoutMode,
                                      onFontChanged: (val) => setState(() => selectedFont = val),
                                      onLayoutChanged: (val) => _setLayoutMode(val),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.f11): const FullscreenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) {
              if (isNoteOpen && currentFilePath != null) {
                saveNoteAtomic(currentFilePath!, blockController.getMarkdown(), isManual: true);
              }
              return null;
            },
          ),
          FullscreenIntent: CallbackAction<FullscreenIntent>(
            onInvoke: (_) async {
              final bool isFull = await windowManager.isFullScreen();
              await windowManager.setFullScreen(!isFull);
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  if (layoutMode != 'zen') const CustomTitleBar(),
                  Expanded(child: scaffoldBody),
                  if (currentFilePath != null && layoutMode != 'zen') AuraStatusBar(filePath: currentFilePath!),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: ValueListenableBuilder<double>(
                  valueListenable: UpdaterService.downloadProgressNotifier,
                  builder: (context, progress, child) {
                    if (progress <= 0.0 || progress >= 1.0) return const SizedBox.shrink();
                    return Container(
                      width: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2), 
                            blurRadius: 8, 
                            offset: const Offset(0, 4)
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Downloading Update...', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress, 
                            backgroundColor: Theme.of(context).dividerColor,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  final Rect? rect;
  SelectionPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    if (rect == null) return;
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect!, paint);
    canvas.drawRect(rect!, borderPaint);
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) => oldDelegate.rect != rect;
}

class FloatingExitZenButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FloatingExitZenButton({super.key, required this.onPressed});

  @override
  State<FloatingExitZenButton> createState() => _FloatingExitZenButtonState();
}

class _FloatingExitZenButtonState extends State<FloatingExitZenButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: _hovered ? 1.0 : 0.2,
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.fullscreen_exit, size: 16),
          label: const Text('Exit Zen', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class FullscreenIntent extends Intent {
  const FullscreenIntent();
}

class FloatingToolsMenu extends StatefulWidget {
  final String selectedFont;
  final String layoutMode;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<String> onLayoutChanged;

  const FloatingToolsMenu({
    super.key,
    required this.selectedFont,
    required this.layoutMode,
    required this.onFontChanged,
    required this.onLayoutChanged,
  });

  @override
  State<FloatingToolsMenu> createState() => _FloatingToolsMenuState();
}

class _FloatingToolsMenuState extends State<FloatingToolsMenu> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TYPOGRAPHY & LAYOUT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text('Font Style', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSegmentedGroup(
                  items: ['Sans-Serif', 'Serif', 'Monospace'],
                  selected: widget.selectedFont,
                  onChanged: widget.onFontChanged,
                ),
                const SizedBox(height: 16),
                const Text('Editor Width', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSegmentedGroup(
                  items: ['centered_narrow', 'centered_wide', 'zen'],
                  labels: {
                    'centered_narrow': 'Narrow',
                    'centered_wide': 'Wide',
                    'zen': 'Zen',
                  },
                  selected: widget.layoutMode,
                  onChanged: widget.onLayoutChanged,
                ),
              ],
            ),
          ),
        ],
        FloatingActionButton(
          mini: true,
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          onPressed: () => setState(() => _isOpen = !_isOpen),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: _isOpen ? 0.125 : 0.0,
            child: Icon(_isOpen ? Icons.close : Icons.tune),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedGroup({
    required List<String> items,
    Map<String, String>? labels,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: items.map((item) {
          final isSel = item == selected;
          final label = labels != null ? (labels[item] ?? item) : item;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? Theme.of(context).primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel 
                        ? Colors.white 
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
