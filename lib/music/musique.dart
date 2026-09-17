import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// --- CONTROLEUR AUDIO GLOBAL (Singleton) ---
/// Ce contrôleur conserve l'état audio dans TOUTE l'application.
/// Même si vous changez de page, la musique continue de jouer.
class AudioController extends ChangeNotifier {
  static final AudioController instance = AudioController._internal();
  factory AudioController() => instance;

  AudioController._internal() {
    _initAudio();
  }

  final AudioPlayer player = AudioPlayer();
  List<File> playlist = [];
  int? playingIndex;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  void _initAudio() {
    _loadPlaylist();

    player.onPlayerStateChanged.listen((state) {
      isPlaying = (state == PlayerState.playing);
      notifyListeners();
    });

    player.onDurationChanged.listen((newDuration) {
      duration = newDuration;
      notifyListeners();
    });

    player.onPositionChanged.listen((newPosition) {
      position = newPosition;
      notifyListeners();
    });

    player.onPlayerComplete.listen((_) => nextTrack());
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> paths = playlist.map((file) => file.path).toList();
    await prefs.setStringList('saved_playlist', paths);
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? paths = prefs.getStringList('saved_playlist');
    if (paths != null) {
      playlist = paths.map((p) => File(p)).where((f) => f.existsSync()).toList();
      notifyListeners();
    }
  }

  void playMusic(int index) async {
    if (index < 0 || index >= playlist.length) return;
    await player.play(DeviceFileSource(playlist[index].path));
    playingIndex = index;
    notifyListeners();
  }

  void togglePlayPause() async {
    if (isPlaying) {
      await player.pause();
    } else {
      await player.resume();
    }
  }

  void nextTrack() {
    if (playingIndex != null && playingIndex! < playlist.length - 1) {
      playMusic(playingIndex! + 1);
    }
  }

  void previousTrack() {
    if (playingIndex != null && playingIndex! > 0) {
      playMusic(playingIndex! - 1);
    }
  }

  void seek(Duration pos) {
    player.seek(pos);
  }

  Future<void> addFiles(List<File> newFiles) async {
    playlist.addAll(newFiles);
    await _savePlaylist();
    notifyListeners();
  }

  Future<void> deleteMultipleTracks(Set<int> indices) async {
    if (indices.isEmpty) return;

    List<int> sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));
    bool currentPlayingDeleted = false;

    for (int index in sortedIndices) {
      if (playingIndex == index) {
        currentPlayingDeleted = true;
      } else if (playingIndex != null && index < playingIndex!) {
        playingIndex = playingIndex! - 1;
      }
      playlist.removeAt(index);
    }

    if (currentPlayingDeleted) {
      await player.stop();
      playingIndex = null;
      isPlaying = false;
      position = Duration.zero;
      duration = Duration.zero;
    }

    await _savePlaylist();
    notifyListeners();
  }
}

/// --- PAGE MUSIQUE ---
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with AutomaticKeepAliveClientMixin {
  final AudioController _audioCtrl = AudioController.instance;

  // Multi-sélection
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _audioCtrl.addListener(_onAudioControllerUpdate);
  }

  @override
  void dispose() {
    _audioCtrl.removeListener(_onAudioControllerUpdate);
    super.dispose();
  }

  void _onAudioControllerUpdate() {
    if (mounted) setState(() {});
  }

  // --- GESTION SELECTION ---
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _audioCtrl.playlist.length) {
        _selectedIndices.clear();
        _isSelectionMode = false;
      } else {
        _selectedIndices.addAll(List.generate(_audioCtrl.playlist.length, (i) => i));
      }
    });
  }

  void _confirmDeleteSelected() {
    if (_selectedIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Supprimer ${_selectedIndices.length} musique(s) ?",
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Ces pistes seront retirées de votre playlist.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _audioCtrl.deleteMultipleTracks(_selectedIndices);
              setState(() {
                _selectedIndices.clear();
                _isSelectionMode = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Musiques supprimées de la playlist"),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result != null && mounted) {
      List<File> newFiles = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();
      _audioCtrl.addFiles(newFiles);
    }
  }

  String _getFileName(String path) {
    return path.split(RegExp(r'[/\\]')).last.replaceAll(
        RegExp(r'\.(mp3|wav|m4a|flac|aac)$', caseSensitive: false), '');
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final playlist = _audioCtrl.playlist;
    final hasPlayingTrack = _audioCtrl.playingIndex != null &&
        _audioCtrl.playingIndex! < playlist.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isSelectionMode) _buildSelectionBar(),
                _buildPlaylist(),
                if (hasPlayingTrack) const SizedBox(height: 180) else const SizedBox(height: 80),
              ],
            ),
            if (hasPlayingTrack) _buildModernPlayerDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final playlist = _audioCtrl.playlist;
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 15, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Musiques",
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "${playlist.length} piste(s) disponible(s)",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: "Ajouter des musiques",
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
                onPressed: _pickFiles,
              ),
              if (playlist.isNotEmpty)
                IconButton(
                  tooltip: "Mode Sélection",
                  icon: Icon(
                    _isSelectionMode ? Icons.close : Icons.checklist_rtl_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      _selectedIndices.clear();
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    final playlist = _audioCtrl.playlist;
    bool allSelected = _selectedIndices.length == playlist.length && playlist.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      color: Colors.blueAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        allSelected ? "Tout décocher" : "Tout sélectionner",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _selectedIndices.isEmpty ? null : _confirmDeleteSelected,
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
            label: Text(
              "Supprimer (${_selectedIndices.length})",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist() {
    final playlist = _audioCtrl.playlist;

    return Expanded(
      child: playlist.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music_outlined, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _pickFiles,
              icon: const Icon(Icons.file_upload_rounded, color: Colors.white),
              label: const Text(
                "Importer vos sons",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: playlist.length,
        itemBuilder: (context, index) {
          bool isPlaying = _audioCtrl.playingIndex == index;
          bool isSelected = _selectedIndices.contains(index);
          String name = _getFileName(playlist[index].path);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected
                  ? Colors.redAccent.withOpacity(0.2)
                  : (isPlaying
                  ? Colors.blueAccent.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05)),
              border: Border.all(
                color: isSelected
                    ? Colors.redAccent
                    : (isPlaying
                    ? Colors.blueAccent.withOpacity(0.5)
                    : Colors.white10),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIndices.add(index);
                  });
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(index);
                } else {
                  _audioCtrl.playMusic(index);
                }
              },
              leading: _isSelectionMode
                  ? Checkbox(
                value: isSelected,
                activeColor: Colors.redAccent,
                onChanged: (_) => _toggleSelection(index),
              )
                  : CircleAvatar(
                backgroundColor: isPlaying ? Colors.blueAccent : Colors.white10,
                child: Icon(
                  isPlaying
                      ? (_audioCtrl.isPlaying ? Icons.equalizer : Icons.pause)
                      : Icons.music_note,
                  color: Colors.white,
                ),
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.blueAccent : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: _isSelectionMode
                  ? null
                  : IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white30, size: 22),
                onPressed: () {
                  setState(() {
                    _selectedIndices.clear();
                    _selectedIndices.add(index);
                  });
                  _confirmDeleteSelected();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernPlayerDock() {
    final playlist = _audioCtrl.playlist;
    String currentName = _getFileName(playlist[_audioCtrl.playingIndex!].path);
    double maxDuration = _audioCtrl.duration.inSeconds.toDouble() > 0
        ? _audioCtrl.duration.inSeconds.toDouble()
        : 1.0;
    double currentPosition =
    _audioCtrl.position.inSeconds.toDouble().clamp(0.0, maxDuration);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 150,
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black.withOpacity(0.85),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.25),
              blurRadius: 25,
              spreadRadius: 2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.blueAccent,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: currentPosition,
                      max: maxDuration,
                      onChanged: (v) => _audioCtrl.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_audioCtrl.position),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        Text(_formatDuration(_audioCtrl.duration),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 32, color: Colors.white),
                        onPressed: _audioCtrl.previousTrack,
                      ),
                      GestureDetector(
                        onTap: _audioCtrl.togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.blueAccent),
                          child: Icon(
                            _audioCtrl.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 32, color: Colors.white),
                        onPressed: _audioCtrl.nextTrack,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}