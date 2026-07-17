import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../core/animated_notification.dart';
import '../updater/updater_service.dart';
import 'package:infer_notes/features/canvas/canvas_screen.dart';
import '../feedback/feedback_service.dart';
import '../../main.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:desktop_updater/desktop_updater.dart';

part 'note_editor_state.dart';
part 'note_editor_actions.dart';
part 'note_editor_ui.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with NoteEditorState, NoteEditorActions, NoteEditorUI {
  bool isCanvasMode = false;
  double _lastScreenWidth = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastScreenWidth > 600 && screenWidth <= 600 && isSidebarVisible) {
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
                duration: isDragging ? Duration.zero : const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: isSidebarVisible ? sidebarWidth : 0.0,
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
                                width: 4,
                                color: Colors.grey.withValues(alpha: 0.2),
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
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.menu, size: 18),
                                        splashRadius: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: () {
                                          setState(() {
                                            isSidebarVisible = !isSidebarVisible;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      isEditingTitle && currentFilePath != null
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
                                                if (currentFilePath != null) {
                                                  setState(() {
                                                    isEditingTitle = true;
                                                    titleController.text = currentFilePath!.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.md$|\.txt$'), '');
                                                  });
                                                  Future.delayed(const Duration(milliseconds: 50), () {
                                                    titleFocusNode.requestFocus();
                                                  });
                                                }
                                              },
                                              child: Text(
                                                currentFilePath == null ? 'Notes' : currentFilePath!.split(Platform.pathSeparator).last,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(isCanvasMode ? Icons.edit_document : Icons.brush, size: 18),
                                        splashRadius: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        tooltip: isCanvasMode ? 'Switch to Notes' : 'Switch to Canvas',
                                        onPressed: () {
                                          setState(() {
                                            isCanvasMode = !isCanvasMode;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.system_update_alt, size: 18),
                                        splashRadius: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        tooltip: 'Check for Updates',
                                        onPressed: UpdaterService.checkUpdatesManually,
                                      ),
                                      IconButton(
                                        icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode, size: 18),
                                        splashRadius: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        tooltip: 'Toggle Theme',
                                        onPressed: () {
                                          themeNotifier.value = Theme.of(context).brightness == Brightness.dark
                                              ? ThemeMode.light
                                              : ThemeMode.dark;
                                        },
                                      ),
                                      if (isNoteOpen)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          splashRadius: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: closeNote,
                                          tooltip: 'Close Note',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: isCanvasMode 
                          ? const CanvasScreen()
                          : !isNoteOpen 
                              ? const Center(child: Text('no note open'))
                              : currentFilePath!.endsWith('.md')
                                  ? (quillController != null 
                                      ? Column(
                                          children: [
                                            QuillSimpleToolbar(
                                              controller: quillController!,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                child: QuillEditor.basic(
                                                  controller: quillController!,
                                                  config: QuillEditorConfig(
                                                    customStyles: DefaultStyles(
                                                      paragraph: DefaultTextBlockStyle(
                                                        Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                          fontSize: 16,
                                                          height: 1.6,
                                                        ),
                                                        const HorizontalSpacing(0, 0),
                                                        const VerticalSpacing(8, 0),
                                                        const VerticalSpacing(0, 0),
                                                        null,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        )
                                      : const Center(child: CircularProgressIndicator()))
                              : Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    controller: controller,
                                    maxLines: null,
                                    expands: true,
                                    keyboardType: TextInputType.multiline,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Start typing your note here...',
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
    return Scaffold(
      body: UpdaterService.controller != null
          ? DesktopUpdateWidget(
              controller: UpdaterService.controller!,
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: scaffoldBody,
              ),
            )
          : scaffoldBody,
    );
  }
}
