part of 'note_editor_screen.dart';

mixin NoteEditorUI on NoteEditorActions {
  List<FileSystemEntity> _getCachedDirItems(Directory dir) {
    if (_dirCache.containsKey(dir.path)) return _dirCache[dir.path]!;
    
    try {
      final items = dir.listSync(recursive: false).where((e) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) return false;
        if (e is Directory) return true;
        return e.path.endsWith('.md') || e.path.endsWith('.txt');
      }).toList()..sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
      _dirCache[dir.path] = items;
      return items;
    } catch (e) {
      return [];
    }
  }

  Widget buildFileSystemTree(List<FileSystemEntity> items, int level, BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length + (level == 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (level == 0 && index == items.length) {
          return const SizedBox(height: 60);
        }

        final item = items[index];
        final name = item.path.split(Platform.pathSeparator).last;
        final isSelected = selectedSidebarPath == item.path;
        
        final bool isEditing = isEditingSidebarPath == item.path;
        Widget titleWidget = isEditing
            ? Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus && isEditingSidebarPath == item.path) {
                    renameSidebarItem(item.path, sidebarRenameController.text.trim());
                  }
                },
                child: TextField(
                  controller: sidebarRenameController,
                  focusNode: sidebarRenameFocusNode,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) => renameSidebarItem(item.path, val.trim()),
                ),
              )
            : Text(
                name + (unsavedFiles.contains(item.path) ? ' ●' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
              );

        if (item is Directory) {
          return Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            child: GestureDetector(
              onSecondaryTapDown: (details) => showSidebarContextMenu(context, details.globalPosition, item.path, isDirectory: true),
              child: Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  title: titleWidget,
                  leading: Icon(Icons.folder, size: 18, color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color),
                  iconColor: isSelected ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color,
                  collapsedIconColor: isSelected ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color,
                  textColor: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.titleMedium?.color,
                  collapsedTextColor: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.titleMedium?.color,
                  tilePadding: EdgeInsets.only(left: 16.0 + (level * 16.0), right: 16.0),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      selectedSidebarPath = item.path;
                    });
                  },
                  children: [
                    buildFileSystemTree(
                      _getCachedDirItems(item),
                      level + 1,
                      context
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            child: GestureDetector(
              onSecondaryTapDown: (details) => showSidebarContextMenu(context, details.globalPosition, item.path, isDirectory: false),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  title: titleWidget,
                  leading: Icon(Icons.insert_drive_file, size: 18, color: isSelected ? Theme.of(context).primaryColor : null),
                  contentPadding: EdgeInsets.only(left: 16.0 + (level * 16.0), right: 16.0),
                  selected: false,
                  minLeadingWidth: 20,
                  onTap: () {
                    // Update selection state instantly before the file IO
                    setState(() {
                      selectedSidebarPath = item.path;
                    });
                    openFileFromSidebar(item.path);
                  },
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget buildSidebar(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AppIconButton(
                    icon: vaultPath == null ? Icons.folder_open : Icons.folder_off,
                    size: 20,
                    onPressed: toggleVault,
                    tooltip: vaultPath == null ? 'Open Vault' : 'Close Vault',
                  ),
                  AppIconButton(icon: Icons.add, size: 20, onPressed: createNewNote, tooltip: 'New Note'),
                  AppIconButton(icon: Icons.delete, size: 20, onPressed: deleteNote, tooltip: 'Delete Selected'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: vaultPath == null 
                ? const Center(child: Text('Open a vault first', style: TextStyle(fontSize: 13)))
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (details) {
                      showSidebarContextMenu(context, details.globalPosition, vaultPath!, isDirectory: true);
                    },
                    child: buildFileSystemTree(_vaultItems, 0, context),
                  ),
          ),
          const Divider(height: 1, thickness: 1),
          SafeArea(
            child: ListTile(
              leading: const Icon(Icons.feedback, size: 18),
              title: const Text('Feedback', style: TextStyle(fontSize: 13)),
              onTap: openFeedbackDialog,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 33,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () => windowManager.minimize(),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 46, minHeight: 32),
                hoverColor: Colors.white.withValues(alpha: 0.15),
                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              IconButton(
                icon: const Icon(Icons.crop_square, size: 14),
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 46, minHeight: 32),
                hoverColor: Colors.white.withValues(alpha: 0.15),
                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => windowManager.close(),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 46, minHeight: 32),
                hoverColor: Colors.red,
                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
          );

          // If the window is impossibly small, just show the buttons safely clipping
          if (constraints.maxWidth < 138) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: buttonRow,
            );
          }

          // Normal layout: App Name (hides if < 250) + Buttons rigidly pushed to the right
          return Row(
            children: [
              Expanded(
                child: DragToMoveArea(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: constraints.maxWidth >= 250
                        ? const Text(
                            'Infer Notes',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              buttonRow,
            ],
          );
        },
      ),
    );
  }
}
