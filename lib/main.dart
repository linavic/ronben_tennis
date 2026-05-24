import 'package:flutter/material.dart';
import 'dart:math';

void main() {
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
  String _gameMode = "טניס"; 
  bool _isCourtReady = true; 
  bool _isOutDetected = false;
  String _aiStatusMessage = "AI CORE: CONNECTED TO GPU SERVER // STREAMING TEST MATCH";
  
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

  // פונקציה שמקבלת את הנתונים האמיתיים משרת ה-AI של כרטיס המסך
  void receiveGpuData(double x, double y, bool isOut, bool hitWallDirectly) {
    setState(() {
      _ballX = x;
      _ballY = y;
      _mockSpeed = 110.0 + Random().nextInt(60);
      _shotTrajectory = [Offset(x - 40, y - 60), Offset(x, y)];

      if (isOut) {
        if (_gameMode == "פאדל" && !hitWallDirectly) {
          _aiStatusMessage = "TRACKING: IN // BOUNCE THEN WALL IMPACT (VALID)";
        } else {
          _isOutDetected = true;
          _aiStatusMessage = "CRITICAL: !! OUT !! BOUNDARY VIOLATION";
          _playerBScoreIndex = (_playerBScoreIndex < _tennisScores.length - 1) ? _playerBScoreIndex + 1 : _playerBScoreIndex;
        }
      } else {
        _aiStatusMessage = "TRACKING: IN // IMPACT REGISTERED";
        _playerAScoreIndex = (_playerAScoreIndex < _tennisScores.length - 1) ? _playerAScoreIndex + 1 : _playerAScoreIndex;
      }
    });

    if (_isOutDetected) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _isOutDetected = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TechGridPainter())),
          Positioned.fill(
            child: CustomPaint(
              painter: OfficialCourtPainter(courtLeft, courtRight, courtTop, courtBottom, _ballX, _ballY, _gameMode, _shotTrajectory),
            ),
          ),
          
          // דשבורד עליון ולוח תוצאות
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
                      const Text("GPU ACCELERATION: ACTIVE // 60 FPS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00FF66), fontFamily: 'monospace')),
                      DropdownButton<String>(
                        value: _gameMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: "טניס", child: Text("TENNIS")),
                          DropdownMenuItem(value: "פאדל", child: Text("PADEL")),
                        ],
                        onChanged: (val) { if (val != null) setState(() => _gameMode = val); },
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("PLAYER A: ${_tennisScores[_playerAScoreIndex]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                      Text("PLAYER B: ${_tennisScores[_playerBScoreIndex]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 12),
                  Text(_aiStatusMessage, style: const TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace'), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),

          // מד מהירות בצד
          Positioned(
            top: 175, left: 15,
            child: Container(
              padding: const EdgeInsets.all(6),
              color: Colors.black.withOpacity(0.6),
              child: Text("BALL SPEED: ${_mockSpeed.toStringAsFixed(0)} KM/H", style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontFamily: 'monospace')),
            ),
          ),

          // אפקט פלאש אאוט
          if (_isOutDetected)
            Positioned.fill(
              child: Container(
                color: Colors.red.withOpacity(0.15),
                child: const Center(
                  child: Text('!! OUT !!', style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

          // כפתורי הדמיה מהירים (עד שנחבר את הפייתון שיזרוק נתונים אוטומטית)
          Positioned(
            bottom: 25, left: 15, right: 15,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF101C2C)),
                    onPressed: () => receiveGpuData(courtLeft + 50, courtTop + 50, false, false),
                    child: const Text("TEST IN IMPACT"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C1010)),
                    onPressed: () => receiveGpuData(courtLeft - 15, courtTop - 15, true, true),
                    child: const Text("TEST OUT IMPACT"),
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
  final double l, r, t, b; final double? bx, by; final String mode; final List<Offset> trajectory;
  OfficialCourtPainter(this.l, this.r, this.t, this.b, this.bx, this.by, this.mode, this.trajectory);

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
      canvas.drawCircle(Offset(bx!, by!), 14, Paint()..color = const Color(0xFF00FF66).withOpacity(0.15)..style = PaintingStyle.fill);
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