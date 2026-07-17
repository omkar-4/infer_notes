part of 'note_editor_screen.dart';

mixin NoteEditorState on State<NoteEditorScreen> {
  bool isSidebarVisible = true;
  bool isCanvasMode = false;
  double sidebarWidth = 250.0;
  bool isNoteOpen = false;
  String? currentFilePath;
  String? selectedSidebarPath;
  String? vaultPath;
  Set<int> selectedBlocks = {};
  List<FileSystemEntity> _vaultItems = [];
  final Map<String, List<FileSystemEntity>> _dirCache = {};
  final Map<String, String> _fileCache = {};
  Set<String> unsavedFiles = {};
  StreamSubscription<FileSystemEvent>? _watchSubscription;


  final TextEditingController controller = TextEditingController();
  final ScrollController editorScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();
  
  final TextEditingController titleController = TextEditingController();
  final FocusNode titleFocusNode = FocusNode();
  bool isEditingTitle = false;
  
  String? isEditingSidebarPath;
  final TextEditingController sidebarRenameController = TextEditingController();
  final FocusNode sidebarRenameFocusNode = FocusNode();
  
  bool isDragging = false;
  
  OverlayEntry? _notificationEntry;
  Timer? _notificationTimer;
  String _notificationMessage = '';
  
  OverlayEntry? _contextMenuEntry;

  @override
  void initState() {
    super.initState();
    _loadVaultPath();
  }

  void _saveVaultPath(String? path) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      final configDir = Directory('$appData\\InferNotes');
      if (!configDir.existsSync()) configDir.createSync(recursive: true);
      final configFile = File('${configDir.path}\\config.txt');
      if (path != null) {
        configFile.writeAsStringSync(path);
      } else {
        if (configFile.existsSync()) configFile.deleteSync();
      }
    }
  }

  Timer? _watchDebounceTimer;

  void _loadVaultPath() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      final configFile = File('$appData\\InferNotes\\config.txt');
      if (configFile.existsSync()) {
        final path = configFile.readAsStringSync();
        if (Directory(path).existsSync()) {
          setState(() {
            vaultPath = path;
          });
          _loadVaultItems();
          _watchSubscription = Directory(vaultPath!).watch(recursive: true).listen((event) {
            _watchDebounceTimer?.cancel();
            _watchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
              _loadVaultItems();
            });
          });
        }
      }
    }
  }

  void _loadVaultItems() {
    if (vaultPath == null) return;
    final dir = Directory(vaultPath!);
    if (dir.existsSync()) {
      _dirCache.clear();
      setState(() {
        _vaultItems = dir.listSync(recursive: false).where((e) {
          final name = e.path.split(Platform.pathSeparator).last;
          if (name.startsWith('.')) return false;
          if (e is Directory) return true;
          return e.path.endsWith('.md') || e.path.endsWith('.txt');
        }).toList();
        _vaultItems.sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
      });
    }
  }

  void showNotification(String message) {
    _notificationMessage = message;
    
    if (_notificationEntry != null) {
      _notificationEntry!.markNeedsBuild();
      _notificationTimer?.cancel();
    } else {
      _notificationEntry = OverlayEntry(
        builder: (context) => AnimatedNotification(
          message: _notificationMessage,
        ),
      );
      Overlay.of(context).insert(_notificationEntry!);
    }

    _notificationTimer = Timer(const Duration(seconds: 2), () {
      _notificationEntry?.remove();
      _notificationEntry = null;
    });
  }

  @override
  void dispose() {
    _watchDebounceTimer?.cancel();
    _watchSubscription?.cancel();
    controller.dispose();
    focusNode.dispose();
    titleController.dispose();
    titleFocusNode.dispose();
    super.dispose();
  }
}
