import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoodleChef',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const DrawingScreen(),
    );
  }
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  List<Map<String, dynamic>?> points = [];
  final GlobalKey canvasKey = GlobalKey();

  // Drawing tools
  Color selectedColor = Colors.black;
  double strokeWidth = 4.0;
  bool isEraser = false;

  // Game state
  int lives = 3;
  int hunger = 0;
  bool isGameOver = false;
  bool isWin = false;

  // Owl mood
  String owlMood = "meh"; // "happy", "meh", "sad"

  final Color canvasColor = Colors.white;

  // Reference images bitmaps
  Map<String, List<ui.Image>> referenceImages = {
    "good_food": [],
    "bad_food": [],
    "not_food": [],
  };

  @override
  void initState() {
    super.initState();
    loadReferenceImages();
  }

  Future<void> loadReferenceImages() async {
    for (var category in ["good_food", "bad_food", "not_food"]) {
      List<ui.Image> images = [];
      int index = 1;
      while (true) {
        String path = "assets/reference/$category/img$index.png";
        try {
          ByteData data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List());
          final frame = await codec.getNextFrame();
          images.add(frame.image);
          index++;
        } catch (_) {
          break;
        }
      }
      setState(() {
        referenceImages[category] = images;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double toolbarWidth = 80;
    double canvasWidth = screenWidth / 2;
    double hudWidth = screenWidth - toolbarWidth - canvasWidth;

    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: isGameOver
          ? EndScreen(isWin: isWin, onRestart: resetGame)
          : SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toolbar
                  Container(
                    width: toolbarWidth,
                    color: Colors.orange[50],
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          buildColorButton(Colors.black),
                          buildColorButton(Colors.red),
                          buildColorButton(Colors.blue),
                          buildColorButton(Colors.green),
                          buildColorButton(Colors.orange),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isEraser = !isEraser;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isEraser ? Colors.blue : Colors.white,
                                border: Border.all(color: Colors.black),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.cleaning_services,
                                color: isEraser ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 60,
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Slider(
                                min: 1,
                                max: 20,
                                value: strokeWidth,
                                onChanged: (value) {
                                  setState(() => strokeWidth = value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Canvas
                  Container(
                    width: canvasWidth,
                    height: canvasWidth,
                    color: canvasColor,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: canvasKey,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                points.add({
                                  "point": details.localPosition,
                                  "color":
                                      isEraser ? canvasColor : selectedColor,
                                  "stroke": strokeWidth,
                                });
                              });
                            },
                            onPanEnd: (_) => points.add(null),
                            child: CustomPaint(
                              painter: DrawingPainter(points),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: FloatingActionButton(
                            onPressed: () async {
                              final imageBytes = await captureCanvas();
                              if (imageBytes != null) {
                                String result =
                                    await compareBitmapWithReferences(imageBytes);
                                updateGame(result);
                                setState(() {
                                  points.clear();
                                });
                              }
                            },
                            child: const Icon(Icons.check),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: FloatingActionButton(
                            onPressed: () => setState(() => points.clear()),
                            child: const Icon(Icons.clear),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // HUD with Background
                  Container(
                    width: hudWidth,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.orange[50],
                    child: Column(
                      children: [
                        // Background + Owl
                        Container(
                          width: hudWidth * 0.8,
                          height: hudWidth * 0.8,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                "assets/Background.png",
                                width: hudWidth * 0.8,
                                height: hudWidth * 0.8,
                                fit: BoxFit.cover,
                              ),
                              Image.asset(
                                getOwlImage(),
                                width: hudWidth * 0.5,
                                height: hudWidth * 0.5,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Lives (full/broken hearts)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Image.asset(
                                index < lives
                                    ? "assets/FullHeart.png"
                                    : "assets/BrokenHeart.png",
                                width: 36,
                                height: 36,
                                fit: BoxFit.contain,
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 12),

                        // Hunger (full/lost bars)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Image.asset(
                                index < hunger
                                    ? "assets/FullHungerBar.png"
                                    : "assets/LostHungerBar.png",
                                width: 36,
                                height: 36,
                                fit: BoxFit.contain,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Owl image selection
  String getOwlImage() {
    switch (owlMood) {
      case "happy":
        return "assets/HappyOwl.png";
      case "sad":
        return "assets/SadOwl.png";
      default:
        return "assets/MehOwl.png";
    }
  }

  Widget buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
          isEraser = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selectedColor == color && !isEraser
              ? Border.all(width: 3)
              : null,
        ),
      ),
    );
  }

  void updateGame(String result) {
    setState(() {
      if (result == "good_food") {
        hunger = (hunger + 1).clamp(0, 5);
        owlMood = "happy";
      } else if (result == "bad_food") {
        hunger = (hunger - 1).clamp(0, 5);
        owlMood = "sad";
      } else if (result == "not_food") {
        lives -= 1;
        owlMood = "sad";
      }

      if (lives <= 0) {
        isGameOver = true;
        isWin = false;
      } else if (hunger >= 5) {
        isGameOver = true;
        isWin = true;
      }
    });
  }

  void resetGame() {
    setState(() {
      lives = 3;
      hunger = 0;
      points.clear();
      isGameOver = false;
      isWin = false;
      owlMood = "meh";
    });
  }

  Future<Uint8List?> captureCanvas() async {
    try {
      final boundary =
          canvasKey.currentContext?.findRenderObject() as dynamic;
      final image = await boundary.toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<String> compareBitmapWithReferences(Uint8List userBytes) async {
    // Decode user image
    final codec = await ui.instantiateImageCodec(userBytes);
    final frame = await codec.getNextFrame();
    final ui.Image userImage = frame.image;

    String bestCategory = "not_food";
    double bestScore = double.infinity;

    for (var category in referenceImages.keys) {
      for (var refImage in referenceImages[category]!) {
        double score = await bitmapDifference(userImage, refImage);
        if (score < bestScore) {
          bestScore = score;
          bestCategory = category;
        }
      }
    }

    return bestCategory;
  }

  Future<double> bitmapDifference(ui.Image img1, ui.Image img2) async {
    // Resize both images to same size
    int width = 64;
    int height = 64;

    final userBytes = await img1.toByteData(format: ui.ImageByteFormat.rawRgba);
    final refBytes = await img2.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (userBytes == null || refBytes == null) return double.infinity;

    double diff = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int idx = (y * width + x) * 4;
        int r1 = userBytes.getUint8(idx);
        int g1 = userBytes.getUint8(idx + 1);
        int b1 = userBytes.getUint8(idx + 2);

        int r2 = refBytes.getUint8(idx);
        int g2 = refBytes.getUint8(idx + 1);
        int b2 = refBytes.getUint8(idx + 2);

        diff += (r1 - r2).abs() + (g1 - g2).abs() + (b1 - b2).abs();
      }
    }

    return diff;
  }

  // fallback for testing
  String getFakeResult() {
    List<String> options = ["good_food", "bad_food", "not_food"];
    return options[Random().nextInt(3)];
  }
}

class EndScreen extends StatelessWidget {
  final bool isWin;
  final VoidCallback onRestart;
  const EndScreen({super.key, required this.isWin, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isWin ? Colors.green[200] : Colors.red[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isWin ? "🎉 You Win!" : "💀 Game Over",
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
                onPressed: onRestart, child: const Text("Play Again"))
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Map<String, dynamic>?> points;
  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        final paint = Paint()
          ..color = current["color"]
          ..strokeWidth = current["stroke"]
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(current["point"], next["point"], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}