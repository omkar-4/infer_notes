import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../core/animated_notification.dart';
import '../updater/updater_service.dart';
import 'package:infer_notes/features/canvas/canvas_screen.dart';
import '../feedback/feedback_service.dart';
import '../../main.dart';
import '../../core/theme.dart';
import 'package:window_manager/window_manager.dart';


part 'note_editor_state.dart';
part 'note_editor_actions.dart';
part 'note_editor_ui.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with NoteEditorState, NoteEditorActions, NoteEditorUI, WindowListener {
  double _lastScreenWidth = 0;
  final ScrollController _toolbarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
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
      // Means already up to date if manually checked (not silent)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are already using the latest version.')));
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

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (UpdaterService.state == UpdaterState.downloading) {
      final shouldQuit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Downloading'),
          content: const Text('An update is currently downloading. Are you sure you want to quit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Wait'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Quit', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (shouldQuit != true) return;
    }

    // Force atomic save of all unsaved notes before closing
    for (String path in unsavedFiles.toList()) {
      if (_fileCache.containsKey(path)) {
        await saveNoteAtomic(path, _fileCache[path]!, isManual: false);
      }
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Auto-hide when window width exactly equals sidebar size + safety margin of 8px
    final bool isScreenTooSmall = screenWidth <= (sidebarWidth + 8);
    final bool effectiveSidebarVisible = isSidebarVisible && !isScreenTooSmall;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastScreenWidth > 600 && screenWidth <= 600 && isSidebarVisible) {
        setState(() { isSidebarVisible = false; });
      }
      // Sync state if it was forced hidden by extreme shrink
      if (isScreenTooSmall && isSidebarVisible) {
        setState(() { isSidebarVisible = false; });
      }
      _lastScreenWidth = screenWidth;
    });

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
                // Snap instantly to 0 if screen is too small to prevent any layout overflow during animation
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
                    // Custom thin toolbar
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate exactly how much width we need for the right side and left menu
                          final double rightSideWidth = (isNoteOpen && !isCanvasMode) ? 200.0 : 120.0;
                          final double minRequiredWidth = rightSideWidth + 48.0; // 40px menu + 8px spacing
                          
                          // Dynamically measure the title width so we know EXACTLY when to hide it
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
                          
                          // 16px safety buffer to ensure it hides right as they touch
                          final double titleThreshold = minRequiredWidth + titleWidth + 16.0;
                          
                          final bool showTitle = constraints.maxWidth >= titleThreshold;
                          final bool isTight = constraints.maxWidth < minRequiredWidth;

                          Widget contentRow = Row(
                            children: [
                              AppIconButton(
                                icon: Icons.menu,
                                size: 20,
                                onPressed: isScreenTooSmall 
                                    ? null // Native disabled state, perfectly grays out the button!
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
                                    saveNoteAtomic(currentFilePath!, controller.text, isManual: false).then((_) {
                                      _fileCache[currentFilePath!] = controller.text;
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
                                  onPressed: () => saveNoteAtomic(currentFilePath!, controller.text, isManual: true),
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
                                thickness: WidgetStateProperty.all(6.0), // Thicker, easy to grab
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
                    Expanded(
                      child: isCanvasMode 
                          ? const CanvasScreen()
                          : !isNoteOpen 
                              ? const Center(child: Text('no note open'))
                              : Scrollbar(
                                  controller: editorScrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  child: SingleChildScrollView(
                                    controller: editorScrollController,
                                    child: TextField(
                                      controller: controller,
                                      maxLines: null,
                                      scrollPhysics: const NeverScrollableScrollPhysics(),
                                      keyboardType: TextInputType.multiline,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Start typing...',
                                        contentPadding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 16.0), // add right padding back so text doesn't overlap the scrollbar thumb
                                      ),
                                      onChanged: (val) {
                                        if (currentFilePath != null) {
                                          _fileCache[currentFilePath!] = val;
                                          setState(() {
                                            unsavedFiles.add(currentFilePath!);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ), // Row
        ), // SafeArea
      ); // Listener
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveIntent(), // for Mac
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (SaveIntent intent) {
              if (isNoteOpen && currentFilePath != null) {
                saveNoteAtomic(currentFilePath!, controller.text, isManual: true);
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Column(
            children: [
              const CustomTitleBar(),
              Expanded(child: scaffoldBody),
            ],
          ),
        ),
      ),
    );
  }
}

class SaveIntent extends Intent {
  const SaveIntent();
}
