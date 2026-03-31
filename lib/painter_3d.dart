import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'stroke_model.dart';

class Painter3D extends StatelessWidget {
  final List<Shape3D> shapes;
  final ShapePreview? preview;
  final Matrix4 viewMatrix;
  final Matrix4 projMatrix;
  final Vector3 camPos;
  final Vector3 forward;

  const Painter3D({
    super.key,
    required this.shapes,
    required this.preview,
    required this.viewMatrix,
    required this.projMatrix,
    required this.camPos,
    required this.forward,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Painter3D(
        shapes,
        preview,
        viewMatrix,
        projMatrix,
        camPos,
        forward,
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ───────────────────────────────────────────────

class _Painter3D extends CustomPainter {
  final List<Shape3D> shapes;
  final ShapePreview? preview;
  final Matrix4 view;
  final Matrix4 proj;
  final Vector3 camPos;
  final Vector3 forward;

  late final Vector3 _cursor;

  _Painter3D(
    this.shapes,
    this.preview,
    this.view,
    this.proj,
    this.camPos,
    this.forward,
  ) {
    _cursor = camPos + forward * 0.25;
  }

  Vector4 _toCam(Vector3 p) {
    return view.transform(Vector4(p.x, p.y, p.z, 1));
  }

  Offset? _project(Vector3 p, Size size) {
    final cam = _toCam(p);
    if (cam.z > 0) return null;

    final clip = proj.transform(cam);
    if (clip.w == 0) return null;

    final sx = (clip.x / clip.w * 0.5 + 0.5) * size.width;
    final sy = (-clip.y / clip.w * 0.5 + 0.5) * size.height;

    return Offset(sx, sy);
  }

  double _pw(double base, double depth) {
    depth = depth.clamp(0.02, 50.0);
    final s = 0.25 / depth;

    return (base * s * s * 1.4).clamp(
      base * 0.08,
      base * 60,
    );
  }

  Color _depthColor(Color c, double depth) {
    depth = depth.clamp(0.01, 20.0);
    final b = (0.25 / depth).clamp(0.15, 1.0);

    return Color.fromRGBO(
      (c.r * 255 * b).round().clamp(0, 255),
      (c.g * 255 * b).round().clamp(0, 255),
      (c.b * 255 * b).round().clamp(0, 255),
      c.opacity,
    );
  }

  Color _proximity(Color c, double dist) {
    final boost = (1.0 - (dist / 0.15).clamp(0.0, 1.0)) * 0.25;
    if (boost <= 0) return c;

    return Color.fromRGBO(
      ((c.r + (1.0 - c.r) * boost) * 255).round().clamp(0, 255),
      ((c.g + (1.0 - c.g) * boost) * 255).round().clamp(0, 255),
      ((c.b + (1.0 - c.b) * boost) * 255).round().clamp(0, 255),
      c.opacity,
    );
  }

  Paint _segPaint(
    Color base,
    double avgDepth,
    double width,
    double proxDist,
  ) {
    final c = _proximity(
      _depthColor(base, avgDepth),
      proxDist,
    );

    return Paint()
      ..color = c
      ..strokeWidth = _pw(width, avgDepth)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
  }

  double _proxDist(List<Vector3> pts) {
    double d = double.infinity;

    for (final p in pts) {
      final v = (_cursor - p).length;
      if (v < d) d = v;
    }

    return d;
  }

  void _drawFree(Canvas canvas, Size size, FreeStroke s) {
    if (s.points.length < 2) return;

    final base = s.color.toFlutterColor();
    final dist = _proxDist(s.points);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset? prev2D;
    Vector3? prev3D;
    double prevW = s.width;

    for (final p in s.points) {
      final cam = _toCam(p);
      final depth = -cam.z;

      final pr = _project(p, size);
      if (pr == null) {
        prev2D = null;
        prev3D = null;
        continue;
      }

      if (prev2D != null && prev3D != null) {
        final pd = -_toCam(prev3D).z;
        final avg = (pd + depth) * 0.5;

        final nw = _pw(s.width, avg);
        final sw = prevW * 0.82 + nw * 0.18;
        prevW = sw;

        paint
          ..strokeWidth = sw
          ..color = _proximity(
            _depthColor(base, avg),
            dist,
          );

        canvas.drawLine(prev2D, pr, paint);
      }

      prev2D = pr;
      prev3D = p;
    }
  }

  void _drawSegment(
    Canvas canvas,
    Size size,
    Vector3 a,
    Vector3 b,
    Color base,
    double width,
  ) {
    final pa = _project(a, size);
    final pb = _project(b, size);
    if (pa == null || pb == null) return;

    final da = -_toCam(a).z;
    final db = -_toCam(b).z;
    final avg = (da + db) * 0.5;

    final dist = _proxDist([a, b]);

    canvas.drawLine(
      pa,
      pb,
      _segPaint(base, avg, width, dist),
    );
  }

  void _drawSphere(
    Canvas canvas,
    Size size,
    Vector3 center,
    double radius,
    Color base,
    double width,
  ) {
    const int segs = 48;
    final dist = (_cursor - center).length;

    void drawCircle(List<Vector3> pts) {
      Offset? prev;

      for (int i = 0; i <= segs; i++) {
        final p = pts[i % segs];
        final pr = _project(p, size);

        if (pr == null) {
          prev = null;
          continue;
        }

        final depth = -_toCam(p).z;

        if (prev != null) {
          canvas.drawLine(
            prev,
            pr,
            _segPaint(base, depth, width, dist),
          );
        }

        prev = pr;
      }
    }

    drawCircle(List.generate(segs, (i) {
      final a = 2 * pi * i / segs;
      return Vector3(
        center.x + radius * cos(a),
        center.y + radius * sin(a),
        center.z,
      );
    }));

    drawCircle(List.generate(segs, (i) {
      final a = 2 * pi * i / segs;
      return Vector3(
        center.x + radius * cos(a),
        center.y,
        center.z + radius * sin(a),
      );
    }));

    drawCircle(List.generate(segs, (i) {
      final a = 2 * pi * i / segs;
      return Vector3(
        center.x,
        center.y + radius * cos(a),
        center.z + radius * sin(a),
      );
    }));
  }

  void _drawBox(
    Canvas canvas,
    Size size,
    Vector3 a,
    Vector3 b,
    Color base,
    double width,
  ) {
    final box = Box3D(
      a: a,
      b: b,
      color: StrokeColor(0, 0, 0),
      width: width,
    );

    final corners = box.corners;
    final dist = _proxDist(corners);

    for (final edge in Box3D.edges) {
      final p1 = corners[edge[0]];
      final p2 = corners[edge[1]];

      final pr1 = _project(p1, size);
      final pr2 = _project(p2, size);
      if (pr1 == null || pr2 == null) continue;

      final d1 = -_toCam(p1).z;
      final d2 = -_toCam(p2).z;
      final avg = (d1 + d2) * 0.5;

      canvas.drawLine(
        pr1,
        pr2,
        _segPaint(base, avg, width, dist),
      );
    }
  }

  void _drawPreview(Canvas canvas, Size size, ShapePreview pv) {
    final base = pv.color.toFlutterColor().withValues(alpha: 0.6);

    switch (pv.mode) {
      case DrawMode.free:
        break;

      case DrawMode.segment:
        _drawSegment(
          canvas,
          size,
          pv.start,
          pv.current,
          base,
          pv.width,
        );
        break;

      case DrawMode.sphere:
        final radius = (pv.current - pv.start).length;

        if (radius > 0.001) {
          _drawSphere(
            canvas,
            size,
            pv.start,
            radius,
            base,
            pv.width,
          );
        }
        break;

      case DrawMode.box:
        _drawBox(
          canvas,
          size,
          pv.start,
          pv.current,
          base,
          pv.width,
        );
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shapes) {
      final base = s.color.toFlutterColor();

      if (s is FreeStroke) {
        _drawFree(canvas, size, s);
      } else if (s is Segment3D) {
        _drawSegment(canvas, size, s.start, s.end, base, s.width);
      } else if (s is Sphere3D) {
        _drawSphere(canvas, size, s.center, s.radius, base, s.width);
      } else if (s is Box3D) {
        _drawBox(canvas, size, s.a, s.b, base, s.width);
      }
    }

    if (preview != null) {
      _drawPreview(canvas, size, preview!);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter3D old) {
    return true;
  }
}
