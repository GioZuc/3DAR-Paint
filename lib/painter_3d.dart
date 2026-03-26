import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'stroke_model.dart';

class Painter3D extends StatelessWidget {
  final List<Stroke3D> strokes;
  final Stroke3D? currentStroke;
  final Matrix4 cameraPose;
  final bool showGrid;
  final Vector3? gridOrigin;

  const Painter3D({
    super.key,
    required this.strokes,
    required this.currentStroke,
    required this.cameraPose,
    this.showGrid = false,
    this.gridOrigin,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter3D(
        strokes: strokes,
        currentStroke: currentStroke,
        cameraPose: cameraPose,
        showGrid: showGrid,
        gridOrigin: gridOrigin,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Painter3D extends CustomPainter {
  final List<Stroke3D> strokes;
  final Stroke3D? currentStroke;
  final Matrix4 cameraPose;
  final bool showGrid;
  final Vector3? gridOrigin;

  // FOV approssimativo ARCore in portrait (~60° verticale)
  static const double _fovY = 60.0 * pi / 180.0;

  _Painter3D({
    required this.strokes,
    required this.currentStroke,
    required this.cameraPose,
    required this.showGrid,
    this.gridOrigin,
  });

  /// Proietta un punto 3D mondo → pixel schermo.
  /// La matrice ARCore è camera-to-world (column-major):
  ///   colonna 0 = asse X camera (destra)
  ///   colonna 1 = asse Y camera (su)
  ///   colonna 2 = asse Z camera (verso l'utente, fuori dallo schermo)
  ///   colonna 3 = posizione camera nel mondo
  /// La direzione "avanti" della camera (verso la scena) è +Z in ARCore.
  Offset? _project(Vector3 worldPoint, Size size) {
    // Posizione camera nel mondo (colonna 3)
    final camPos = Vector3(
      cameraPose.entry(0, 3),
      cameraPose.entry(1, 3),
      cameraPose.entry(2, 3),
    );

    // Assi della camera nel mondo (colonne 0, 1, 2)
    final right   = Vector3(cameraPose.entry(0, 0), cameraPose.entry(1, 0), cameraPose.entry(2, 0));
    final up      = Vector3(cameraPose.entry(0, 1), cameraPose.entry(1, 1), cameraPose.entry(2, 1));
    // ARCore: Z punta VERSO l'utente. La scena è davanti alla camera quindi in direzione +Z.
    final forward = Vector3(cameraPose.entry(0, 2), cameraPose.entry(1, 2), cameraPose.entry(2, 2));

    // Vettore dal centro camera al punto mondo
    final toPoint = worldPoint - camPos;

    // Coordinate nel sistema camera
    final cx =  toPoint.dot(right);
    final cy =  toPoint.dot(up);
    final cz =  toPoint.dot(forward); // positivo = davanti alla camera

    // Scarta punti dietro la camera
    if (cz <= 0.001) return null;

    // Proiezione prospettica
    final aspect = size.width / size.height;
    final focalY = (size.height / 2.0) / tan(_fovY / 2.0);
    final focalX = focalY * aspect;

    final sx = ( cx / cz) * focalX + size.width  / 2.0;
    final sy = (-cy / cz) * focalY + size.height / 2.0; // Y invertito: schermo Y va verso il basso

    // Scarta punti molto fuori schermo (con margine del 100%)
    if (sx < -size.width  || sx > size.width  * 2) return null;
    if (sy < -size.height || sy > size.height * 2) return null;

    return Offset(sx, sy);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final origin = gridOrigin;
    if (origin == null) return;

    final gridPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.18)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const int lines = 10;
    const double spacing = 0.3; // 30cm tra le linee
    const double extent = lines * spacing; // 3m totali

    final gx = origin.x;
    final gy = origin.y;
    final gz = origin.z;

    // Linee parallele a X (fisse X, variano Z)
    for (int i = -lines; i <= lines; i++) {
      final z = gz + i * spacing;
      final p1 = _project(Vector3(gx - extent, gy, z), size);
      final p2 = _project(Vector3(gx + extent, gy, z), size);
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, i == 0 ? axisPaint : gridPaint);
      }
    }

    // Linee parallele a Z (variano X, fisse Z)
    for (int i = -lines; i <= lines; i++) {
      final x = gx + i * spacing;
      final p1 = _project(Vector3(x, gy, gz - extent), size);
      final p2 = _project(Vector3(x, gy, gz + extent), size);
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, i == 0 ? axisPaint : gridPaint);
      }
    }

    // Pilastri verticali agli angoli per senso della profondità
    final verticalPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.12)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final corners = [
      Vector3(gx - extent, gy, gz - extent),
      Vector3(gx + extent, gy, gz - extent),
      Vector3(gx - extent, gy, gz + extent),
      Vector3(gx + extent, gy, gz + extent),
    ];
    for (final c in corners) {
      final bottom = _project(c, size);
      final top    = _project(Vector3(c.x, c.y + 1.2, c.z), size);
      if (bottom != null && top != null) {
        canvas.drawLine(bottom, top, verticalPaint);
      }
    }
  }

  void _drawStroke(Canvas canvas, Size size, Stroke3D stroke) {
    if (stroke.points.length < 2) return;

    final color = stroke.color.toFlutterColor();

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = stroke.width * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    Offset? prev;
    bool started = false;

    for (final pt in stroke.points) {
      final proj = _project(pt, size);
      if (proj == null) {
        started = false;
        prev = null;
        continue;
      }
      if (!started) {
        path.moveTo(proj.dx, proj.dy);
        started = true;
      } else if (prev != null) {
        final mid = Offset((prev.dx + proj.dx) / 2, (prev.dy + proj.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      prev = proj;
    }
    if (prev != null && started) path.lineTo(prev.dx, prev.dy);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  void _drawCrosshair(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.5;
    final cx = size.width  / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 14, cy), Offset(cx -  5, cy), p);
    canvas.drawLine(Offset(cx +  5, cy), Offset(cx + 14, cy), p);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy -  5), p);
    canvas.drawLine(Offset(cx, cy +  5), Offset(cx, cy + 14), p);
    canvas.drawCircle(Offset(cx, cy), 2,
      Paint()..color = Colors.white.withValues(alpha: 0.75));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _drawGrid(canvas, size);
    for (final s in strokes) _drawStroke(canvas, size, s);
    if (currentStroke != null) _drawStroke(canvas, size, currentStroke!);
    _drawCrosshair(canvas, size);
  }

  @override
  bool shouldRepaint(_Painter3D old) =>
      old.strokes      != strokes      ||
      old.currentStroke != currentStroke ||
      old.cameraPose   != cameraPose   ||
      old.showGrid     != showGrid     ||
      old.gridOrigin   != gridOrigin;
}
