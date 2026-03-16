import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with AutomaticKeepAliveClientMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<File> _playlistFiles = [];
  int? _playingIndex;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    // Passage automatique à la suivante quand le morceau finit
    _audioPlayer.onPlayerComplete.listen((event) => _nextTrack());
  }

  // --- LOGIQUE DE SAUVEGARDE ---
  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> paths = _playlistFiles.map((file) => file.path).toList();
    await prefs.setStringList('saved_playlist', paths);
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? paths = prefs.getStringList('saved_playlist');
    if (paths != null && mounted) {
      setState(() => _playlistFiles = paths.map((path) => File(path)).toList());
    }
  }

  // --- COMMANDES DU LECTEUR ---
  void _playMusic(int index) async {
    if (index < 0 || index >= _playlistFiles.length) return;
    await _audioPlayer.play(DeviceFileSource(_playlistFiles[index].path));
    setState(() => _playingIndex = index);
  }

  void _nextTrack() {
    if (_playingIndex != null && _playingIndex! < _playlistFiles.length - 1) {
      _playMusic(_playingIndex! + 1);
    }
  }

  void _previousTrack() {
    if (_playingIndex != null && _playingIndex! > 0) {
      _playMusic(_playingIndex! - 1);
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result != null && mounted) {
      setState(() => _playlistFiles.addAll(result.paths.map((path) => File(path!)).toList()));
      _savePlaylist();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildPlaylist(),
                const SizedBox(height: 180), // Espace pour le dock et la nav bar
              ],
            ),
            if (_playingIndex != null) _buildModernPlayerDock(),
          ],
        ),
      ),
      floatingActionButton: _playlistFiles.isEmpty ? null : Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          backgroundColor: Colors.blueAccent,
          onPressed: _pickFiles,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Audio Focus", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          Text("${_playlistFiles.length} pistes disponibles", style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPlaylist() {
    return Expanded(
      child: _playlistFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _pickFiles, child: const Text("Importer vos sons")),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _playlistFiles.length,
        itemBuilder: (context, index) {
          bool isPlaying = _playingIndex == index;
          String name = _playlistFiles[index].path.split('/').last.replaceAll('.mp3', '');
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isPlaying ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              border: Border.all(color: isPlaying ? Colors.blueAccent.withOpacity(0.5) : Colors.white10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPlaying ? Colors.blueAccent : Colors.white10,
                child: Icon(isPlaying ? Icons.equalizer : Icons.music_note, color: Colors.white),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isPlaying ? Colors.blueAccent : Colors.white, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
              onTap: () => _playMusic(index),
              trailing: isPlaying ? const Icon(Icons.volume_up, color: Colors.blueAccent) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernPlayerDock() {
    String currentName = _playlistFiles[_playingIndex!].path.split('/').last;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 160,
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 110),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black.withOpacity(0.8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Text(currentName, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0)),
                    child: Slider(
                      activeColor: Colors.blueAccent,
                      inactiveColor: Colors.white10,
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 35, color: Colors.white), onPressed: _previousTrack),
                      GestureDetector(
                        onTap: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.resume(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent),
                          child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: Colors.white),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.skip_next_rounded, size: 35, color: Colors.white), onPressed: _nextTrack),
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