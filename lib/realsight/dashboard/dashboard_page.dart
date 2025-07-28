import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../mobile/auth_service.dart';
import 'package:image_picker/image_picker.dart';

class SentImageData {
  final File file;
  final String filename;
  final String prediction;
  final double confidence;
  final double aiGeneratedProbability;
  final double realProbability;
  SentImageData({
    required this.file,
    required this.filename,
    required this.prediction,
    required this.confidence,
    required this.aiGeneratedProbability,
    required this.realProbability,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<File> _images = [];
  final List<SentImageData> _sentImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _processing = false;
  double _progress = 0.0;

  Future<List<SentImageData>> sendImagesToBackend(List<File> images) async {
    var uri = Uri.parse('https://realsightapp.loca.lt/analyze'); // <-- Set your backend URL
    var request = http.MultipartRequest('POST', uri);
    for (var img in images) {
      request.files.add(await http.MultipartFile.fromPath('files', img.path));
    }
    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final List<dynamic> results = jsonDecode(respStr);
      // Match each result to the file by filename
      return results.map((r) {
        final file = images.firstWhere((f) => f.path.split(Platform.pathSeparator).last == r['filename'], orElse: () => images[0]);
        return SentImageData(
          file: file,
          filename: r['filename'],
          prediction: r['prediction'] ?? '',
          confidence: (r['confidence'] ?? 0.0).toDouble(),
          aiGeneratedProbability: (r['ai_generated_probability'] ?? 0.0).toDouble(),
          realProbability: (r['real_probability'] ?? 0.0).toDouble(),
        );
      }).toList();
    } else {
      throw Exception('Failed to upload images');
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _images.add(File(picked.path));
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _images.add(File(photo.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _sendImages() async {
    if (_images.isEmpty) return;
    setState(() {
      _processing = true;
      _progress = 0.0;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProcessingDialog(progressStream: _progressStream()),
    );
    try {
      final results = await sendImagesToBackend(_images);
      if (mounted) Navigator.of(context).pop();
      setState(() {
        _sentImages.addAll(results);
        _images.clear();
        _processing = false;
        _progress = 0.0;
      });
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      setState(() { _processing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process images: $e')),
      );
    }
  }

  Stream<double> _progressStream() async* {
    const int steps = 40;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      _progress = i / steps;
      yield _progress;
    }
  }

  void _newChat() {
    setState(() {
      _sentImages.clear();
      _images.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final random = Random();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.create_outlined, color: Color(0xFF222222), size: 28),
              tooltip: 'New Chat',
              onPressed: _newChat,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF222222)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : (null),
                    child: (user?.photoURL == null)
                      ? const Icon(Icons.person, color: Color(0xFF222222), size: 22)
                      : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 8,
                bottom: 100 + MediaQuery.of(context).padding.bottom,
              ),
              child: ListView(
                children: [
                  if (_sentImages.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.waving_hand_rounded, color: Color(0xFF222222), size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $username!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Start a new chat or upload an image to get started.',
                                  style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_sentImages.isNotEmpty)
                    ..._sentImages.map((img) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: const Color(0xFFF6F7F5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.file(
                                img.file,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        img.prediction == 'Real' ? Icons.verified : Icons.warning_amber_rounded,
                                        color: img.prediction == 'Real' ? Colors.green : Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        img.prediction == 'Real' ? 'Real Image' : 'AI Generated',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: img.prediction == 'Real' ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Remove divider lines and add probability bar chart
                                  const SizedBox(height: 12),
                                  _ProbabilityBar(
                                    aiProbability: img.aiGeneratedProbability,
                                    realProbability: img.realProbability,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Text('Confidence: ', style: TextStyle(color: Color(0xFF222222))),
                                      Text('${(img.confidence * 100).toStringAsFixed(2)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'File: ${img.filename}',
                                    style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_images.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 90,
              child: SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _images[index],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Sticky bottom bar limited to button card only
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.upload_file, color: Color(0xFF222222)),
                      onPressed: _pickImage,
                      tooltip: 'Upload',
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF222222)),
                      onPressed: _takePhoto,
                      tooltip: 'Camera',
                    ),
                    ElevatedButton(
                      onPressed: _sendImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF222222),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingDialog extends StatefulWidget {
  final Stream<double> progressStream;
  const ProcessingDialog({super.key, required this.progressStream});
  @override
  State<ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<ProcessingDialog> {
  double _progress = 0.0;
  late final Stream<double> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.progressStream;
    _stream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 48, color: Color(0xFF222222)),
            const SizedBox(height: 16),
            const Text('Processing...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222))),
            const SizedBox(height: 24),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFEDEDED),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF222222)),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  final double aiProbability;
  final double realProbability;
  const _ProbabilityBar({required this.aiProbability, required this.realProbability});

  @override
  Widget build(BuildContext context) {
    final aiPercent = (aiProbability * 100).clamp(0, 100);
    final realPercent = (realProbability * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('AI Probability', style: TextStyle(fontSize: 13, color: Color(0xFF222222))),
            const SizedBox(width: 8),
            Text('${aiPercent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              height: 14,
              width: aiPercent > 0 ? aiPercent * 2 : 2, // scale for visual
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Real Probability', style: TextStyle(fontSize: 13, color: Color(0xFF222222))),
            const SizedBox(width: 8),
            Text('${realPercent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              height: 14,
              width: realPercent > 0 ? realPercent * 2 : 2, // scale for visual
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 