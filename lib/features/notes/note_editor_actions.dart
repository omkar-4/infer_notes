part of 'note_editor_screen.dart';

mixin NoteEditorActions on NoteEditorState {
  Future<void> createNewNote() async {
    if (vaultPath == null) {
      showNotification('Please open a vault first');
      return;
    }
    
    String parentDir = vaultPath!;
    if (selectedSidebarPath != null) {
      if (FileSystemEntity.typeSync(selectedSidebarPath!) == FileSystemEntityType.directory) {
        parentDir = selectedSidebarPath!;
      } else {
        parentDir = File(selectedSidebarPath!).parent.path;
      }
    }
    
    await _createNewItem(parentDir, isFolder: false);
  }

  Future<void> closeNote() async {
    setState(() {
      isNoteOpen = false;
      currentFilePath = null;
      controller.clear();
    });
  }

  Future<void> toggleVault() async {
    if (vaultPath != null) {
      _watchSubscription?.cancel();
      setState(() {
        vaultPath = null;
        _vaultItems.clear();
        isNoteOpen = false;
        currentFilePath = null;
        selectedSidebarPath = null;
      });
      _saveVaultPath(null);
    } else {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          vaultPath = path;
        });
        _saveVaultPath(path);
        _loadVaultItems();
        _watchSubscription?.cancel();
        _watchSubscription = Directory(vaultPath!).watch(recursive: true).listen((event) {
          _watchDebounceTimer?.cancel();
          _watchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
            _loadVaultItems();
          });
        });
      }
    }
  }

  Future<void> deleteNote() async {
    if (selectedSidebarPath == null) {
      showNotification('no note selected');
      return;
    }
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${selectedSidebarPath!.split(Platform.pathSeparator).last}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    
    if (confirm != true) return;

    try {
      final entity = FileSystemEntity.isDirectorySync(selectedSidebarPath!)
          ? Directory(selectedSidebarPath!)
          : File(selectedSidebarPath!);
      await entity.delete(recursive: true);
      
      if (currentFilePath == selectedSidebarPath || 
          (currentFilePath != null && currentFilePath!.startsWith(selectedSidebarPath!))) {
        closeNote();
      }
      setState(() {
        selectedSidebarPath = null;
      });
      showNotification('Deleted successfully');
    } catch (e) {
      showNotification('Failed to delete');
    }
  }

  void openFileFromSidebar(String path) async {
    // 1. Capture current state for async saving
    if (isNoteOpen && currentFilePath != null && unsavedFiles.contains(currentFilePath)) {
      final oldPath = currentFilePath!;
      String contentToSave = controller.text;
      
      saveNoteAtomic(oldPath, contentToSave, isManual: false).then((_) {
         _fileCache[oldPath] = contentToSave; 
      });
    }

    setState(() {
      isCanvasMode = false;
      isNoteOpen = true;
      currentFilePath = path;
      selectedSidebarPath = path;
      
      if (_fileCache.containsKey(path)) {
        final content = _fileCache[path]!;
        controller.text = content;
      } else {
        controller.text = '';
      }
    });

    try {
      String content = await File(path).readAsString();
      if (currentFilePath != path) return;
      if (_fileCache[path] == content) return;

      _fileCache[path] = content;

      setState(() {
        controller.text = content;
      });
    } catch (e) {
      if (currentFilePath == path) {
        showNotification('Failed to open file');
      }
    }
  }

  Future<void> saveNoteAtomic(String path, String content, {bool isManual = false}) async {
    try {
      final file = File(path);
      final parentDir = file.parent;
      final tempDir = Directory('${parentDir.path}${Platform.pathSeparator}.temp');
      
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}${fileName}_${DateTime.now().millisecondsSinceEpoch}.tmp');
      await tempFile.writeAsString(content);
      
      // Atomic rename
      await tempFile.rename(path);
      
      setState(() {
        unsavedFiles.remove(path);
      });
      
      if (isManual) {
        showNotification('Changes saved');
      }
    } catch (e) {
      if (isManual) {
        showNotification('Failed to save file');
      }
    }
  }

  void hideContextMenu() {
    _contextMenuEntry?.remove();
    _contextMenuEntry = null;
  }

  void showSidebarContextMenu(BuildContext context, Offset position, String targetPath, {bool isDirectory = false}) {
    hideContextMenu();
    
    _contextMenuEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDirectory || targetPath == vaultPath) ...[
                    _buildContextMenuItem(context, 'New Note', Icons.insert_drive_file, () {
                      hideContextMenu();
                      String parentDir = isDirectory ? targetPath : (targetPath == vaultPath ? vaultPath! : File(targetPath).parent.path);
                      _createNewItem(parentDir, isFolder: false);
                    }),
                    _buildContextMenuItem(context, 'New Folder', Icons.folder, () {
                      hideContextMenu();
                      String parentDir = isDirectory ? targetPath : (targetPath == vaultPath ? vaultPath! : File(targetPath).parent.path);
                      _createNewItem(parentDir, isFolder: true);
                    }),
                  ],
                  if (targetPath != vaultPath) ...[
                    if (isDirectory || targetPath == vaultPath) const Divider(height: 1),
                    _buildContextMenuItem(context, 'Rename', Icons.edit, () {
                      hideContextMenu();
                      setState(() {
                        isEditingSidebarPath = targetPath;
                        sidebarRenameController.text = targetPath.split(Platform.pathSeparator).last;
                      });
                      Future.delayed(const Duration(milliseconds: 50), () {
                        sidebarRenameFocusNode.requestFocus();
                        if (!isDirectory && sidebarRenameController.text.endsWith('.md')) {
                           sidebarRenameController.selection = TextSelection(baseOffset: 0, extentOffset: sidebarRenameController.text.length - 3);
                        } else {
                           sidebarRenameController.selection = TextSelection(baseOffset: 0, extentOffset: sidebarRenameController.text.length);
                        }
                      });
                    }),
                    _buildContextMenuItem(context, 'Delete', Icons.delete, () {
                      hideContextMenu();
                      setState(() { selectedSidebarPath = targetPath; });
                      deleteNote();
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    );
    Overlay.of(context).insert(_contextMenuEntry!);
  }

  Widget _buildContextMenuItem(BuildContext context, String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // Block operations removed for AppFlowyEditor integration

  Future<void> _createNewItem(String parentDir, {required bool isFolder}) async {
    String baseName = isFolder ? 'dir' : 'untitled';
    
    // Add a random suffix if inside a folder to avoid filename conflicts across the vault
    if (parentDir != vaultPath) {
      final randomSuffix = DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(7);
      baseName = '${baseName}_$randomSuffix';
    }
    
    String ext = isFolder ? '' : '.md';
    String newPath = '$parentDir${Platform.pathSeparator}$baseName$ext';
    int counter = 1;
    
    while (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
      newPath = '$parentDir${Platform.pathSeparator}$baseName-$counter$ext';
      counter++;
    }

    try {
      if (isFolder) {
        await Directory(newPath).create();
      } else {
        await File(newPath).writeAsString('');
      }
      setState(() {
        if (!isFolder) {
          isNoteOpen = true;
          currentFilePath = newPath;
          controller.clear();
        }
        selectedSidebarPath = newPath;
        isEditingSidebarPath = newPath; // trigger inline rename
        sidebarRenameController.text = newPath.split(Platform.pathSeparator).last;
      });
      _loadVaultItems();
      
      Future.delayed(const Duration(milliseconds: 50), () {
        sidebarRenameFocusNode.requestFocus();
        if (!isFolder && sidebarRenameController.text.endsWith('.md')) {
           sidebarRenameController.selection = TextSelection(baseOffset: 0, extentOffset: sidebarRenameController.text.length - 3);
        } else {
           sidebarRenameController.selection = TextSelection(baseOffset: 0, extentOffset: sidebarRenameController.text.length);
        }
      });
    } catch (e) {
      showNotification('Failed to create item');
    }
  }

  Future<void> renameSidebarItem(String oldPath, String newName) async {
    if (isEditingSidebarPath == null) return;
    
    // Lock event
    setState(() {
      isEditingSidebarPath = null;
    });

    if (newName.trim().isEmpty) return;

    try {
      final file = FileSystemEntity.typeSync(oldPath) == FileSystemEntityType.directory 
          ? Directory(oldPath) 
          : File(oldPath);
          
      String dir = file.parent.path;
      String newPath = '$dir${Platform.pathSeparator}$newName';
      
      if (file is File) {
        if (!newPath.endsWith('.md') && !newPath.endsWith('.txt')) {
          newPath += '.md';
        }
      }
      
      if (newPath == oldPath) return;

      if (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
        showNotification('Item already exists');
        return;
      }
      
      await file.rename(newPath);
      
      setState(() {
        if (currentFilePath == oldPath || (currentFilePath != null && currentFilePath!.startsWith(oldPath))) {
          currentFilePath = currentFilePath!.replaceFirst(oldPath, newPath);
        }
        if (selectedSidebarPath == oldPath || (selectedSidebarPath != null && selectedSidebarPath!.startsWith(oldPath))) {
          selectedSidebarPath = selectedSidebarPath!.replaceFirst(oldPath, newPath);
        }
      });
      _loadVaultItems();
    } catch (e) {
      showNotification('Failed to rename item');
    }
  }

  Future<void> renameCurrentNote(String newName) async {
    if (!isNoteOpen || currentFilePath == null || !isEditingTitle) return;
    
    // Immediately lock to prevent double-firing from onSubmitted + onFocusChange
    setState(() {
      isEditingTitle = false;
    });

    try {
      final file = File(currentFilePath!);
      String dir = file.parent.path;
      String newPath = '$dir${Platform.pathSeparator}$newName';
      if (!newPath.endsWith('.md') && !newPath.endsWith('.txt')) {
        newPath += '.md';
      }
      
      if (newPath == currentFilePath) return;

      if (File(newPath).existsSync()) {
        showNotification('File already exists');
        return;
      }
      
      await file.rename(newPath);
      setState(() {
        currentFilePath = newPath;
        selectedSidebarPath = newPath;
      });
      _loadVaultItems();
    } catch (e) {
      showNotification('Failed to rename note');
    }
  }

  Future<void> openFeedbackDialog() async {
    final TextEditingController feedbackController = TextEditingController();
    
    bool? submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          controller: feedbackController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What can we improve?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit Feedback'),
          ),
        ],
      ),
    );

    if (submitted == true && feedbackController.text.trim().isNotEmpty) {
      bool success = await FeedbackService.sendFeedback(feedbackController.text.trim());
      if (success) {
        showNotification('Feedback sent');
      } else {
        showNotification('Failed to send feedback');
      }
    }
    feedbackController.dispose();
  }
}
