import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'dart:math';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera initialization error: $e");
  }
  runApp(const RonbenTennisAiApp());
}

class RonbenTennisAiApp extends StatelessWidget {
  const RonbenTennisAiApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RONBEN TENNIS AI Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060914),
        primaryColor: const Color(0xFF00FF66),
      ),
      home: const CourtAnalyzerScreen(),
    );
  }
}

class CourtAnalyzerScreen extends StatefulWidget {
  const CourtAnalyzerScreen({Key? key}) : super(key: key);

  @override
  State<CourtAnalyzerScreen> createState() => CourtAnalyzerScreenState();
}

class CourtAnalyzerScreenState extends State<CourtAnalyzerScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  ObjectDetector? _objectDetector;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _gameMode = "טניס"; 
  bool _isCourtReady = false; 
  bool _isDetecting = false;
  bool _isOutDetected = false;
  String _aiStatusMessage = "SYSTEM: READY // STANDBY FOR CALIBRATION";
  
  double? _ballX;
  double? _ballY;
  double _mockSpeed = 0.0;
  List<Offset> _shotTrajectory = [];

  int _playerAScoreIndex = 0;
  int _playerBScoreIndex = 0;
  final List<String> _tennisScores = ["0", "15", "30", "40", "Adv", "Game"];

  final double courtLeft = 50.0;
  final double courtRight = 330.0;
  final double courtTop = 200.0;
  final double courtBottom = 480.0;

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initializeHardware();
  }

  void _initializeHardware() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);

    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCourtReady = true;
        _aiStatusMessage = "SUCCESS: CAMERA HARDWARE ONLINE";
      });
    }
  }

  void _analyzeImpactLocation(double x, double y, bool hitWallDirectly) {
    bool isOutsideLines = (x < courtLeft || x > courtRight || y < courtTop || y > courtBottom);
    final random = Random();

    _shotTrajectory = [
      Offset(x - 60, y - 80),
      Offset(x - 30, y - 40),
      Offset(x, y), 
    ];

    setState(() {
      _ballX = x;
      _ballY = y;
      _mockSpeed = 105.0 + random.nextInt(75); 

      if (_gameMode == "טניס") {
        if (isOutsideLines) {
          _triggerOut("OUT DETECTED // POINT TO PLAYER B");
          _updateScore(playerBScore: true);
        } else {
          _aiStatusMessage = "IN DETECTED // PLAY CONTINUES";
        }
      } else {
        if (isOutsideLines) {
          if (hitWallDirectly) {
            _triggerOut("OUT: DIRECT WALL IMPACT // POINT TO PLAYER B");
            _updateScore(playerBScore: true);
          } else {
            _aiStatusMessage = "IN: BOUNCE THEN WALL // VALID PADEL SHOT";
          }
        } else {
          _aiStatusMessage = "IN DETECTED // FLOOR REBOUND REGISTERED";
        }
      }
    });
  }

  void _updateScore({required bool playerBScore}) {
    setState(() {
      if (playerBScore) {
        if (_playerBScoreIndex < _tennisScores.length - 1) _playerBScoreIndex++;
      } else {
        if (_playerAScoreIndex < _tennisScores.length - 1) _playerAScoreIndex++;
      }
      
      if (_tennisScores[_playerAScoreIndex] == "Game" || _tennisScores[_playerBScoreIndex] == "Game") {
        _aiStatusMessage = "MATCH SET OVER // SCORES RESETTING...";
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _playerAScoreIndex = 0;
            _playerBScoreIndex = 0;
          });
        });
      }
    });
  }

  void _triggerOut(String message) async {
    if (_isOutDetected) return;
    setState(() {
      _isOutDetected = true;
      _aiStatusMessage = message;
    });

    try {
      await _audioPlayer.play(UrlSource('https://www.soundjay.com/buttons/sounds/button-2.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _isOutDetected = false);
    });
  }

  void _simulateShot({required bool forceOut, bool wallFirst = false}) {
    final random = Random();
    double x, y;

    if (forceOut) {
      x = random.nextBool() ? courtLeft - 18 : courtRight + 18;
      y = random.nextBool() ? courtTop - 18 : courtBottom - 18;
    } else {
      x = courtLeft + random.nextDouble() * (courtRight - courtLeft);
      y = courtTop + random.nextDouble() * (courtBottom - courtTop);
    }

    _analyzeImpactLocation(x, y, wallFirst);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _objectDetector?.close();
    _audioPlayer.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // תצוגת המצלמה החיה ברקע של האפליקציה בנייד
          _cameraController != null && _cameraController!.value.isInitialized
              ? SizedBox.expand(child: CameraPreview(_cameraController!))
              : const Center(child: CircularProgressIndicator(color: Color(0xFF00FF66))),

          Positioned.fill(
            child: CustomPaint(
              painter: OfficialCourtPainter(
                courtLeft, courtRight, courtTop, courtBottom, 
                _ballX, _ballY, _gameMode, _isCourtReady, _shotTrajectory
              ),
            ),
          ),
          Positioned(
            top: 45, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xEE0A0E17),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _blinkController,
                            builder: (context, child) {
                              return Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _isCourtReady ? const Color(0xFF00FF66) : Colors.redAccent.withOpacity(_blinkController.value),
                                  shape: BoxShape.circle
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(_isCourtReady ? "AI ENGINE: LIVE" : "AI ENGINE: SCANNING", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00FF66))),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _gameMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: "טניס", child: Text("TENNIS")),
                          DropdownMenuItem(value: "פאדל", child: Text("PADEL")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _gameMode = val);
                        },
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("PLAYER A: ${_tennisScores[_playerAScoreIndex]}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                      Text("PLAYER B: ${_tennisScores[_playerBScoreIndex]}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 12),
                  Text(_aiStatusMessage, style: const TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace'), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (_isOutDetected)
            Positioned.fill(
              child: Container(
                color: Colors.red.withOpacity(0.15),
                child: const Center(
                  child: Text('!! OUT !!', style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          Positioned(
            bottom: 25, left: 15, right: 15,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF101C2C)),
                    onPressed: () {
                      _simulateShot(forceOut: false);
                      _updateScore(playerBScore: false); 
                    },
                    child: const Text("SIMULATE IN"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C1010)),
                    onPressed: () => _simulateShot(forceOut: true, wallFirst: true),
                    child: Text(_gameMode == "טניס" ? "SIMULATE OUT" : "WALL DIRECT HIT"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class OfficialCourtPainter extends CustomPainter {
  final double l, r, t, b; final double? bx, by; final String mode; final bool isReady; final List<Offset> trajectory;
  OfficialCourtPainter(this.l, this.r, this.t, this.b, this.bx, this.by, this.mode, this.isReady, this.trajectory);

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()..color = const Color(0xFF00E5FF).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTRB(l, t, r, b), paintBase);
    canvas.drawLine(Offset(l, (t + b) / 2), Offset(r, (t + b) / 2), paintBase);

    if (mode == "טניס") {
      double width = r - l; double alley = width * 0.08;
      canvas.drawLine(Offset(l + alley, t), Offset(l + alley, b), paintBase);
      canvas.drawLine(Offset(r - alley, t), Offset(r - alley, b), paintBase);
    }

    if (trajectory.length >= 2) {
      canvas.drawLine(trajectory[0], trajectory[1], Paint()..color = const Color(0xFF00FF66)..strokeWidth = 2.5);
    }
    if (bx != null && by != null) {
      canvas.drawCircle(Offset(bx!, by!), 6, Paint()..color = const Color(0xFF00FF66));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TechGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF141E33).withOpacity(0.15)..strokeWidth = 1;
    double spacing = 35;
    for (double i = 0; i < size.width; i += spacing) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); }
    for (double i = 0; i < size.height; i += spacing) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}