import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

// ─── Modalità di disegno ───────────────────────────────────────────────────
enum DrawMode { free, segment, sphere, box }

// ─── Classe base per tutte le forme ───────────────────────────────────────
abstract class Shape3D {
  final StrokeColor color;
  final double width;
  const Shape3D({required this.color, required this.width});
}

// ─── Pennello libero ───────────────────────────────────────────────────────
class FreeStroke extends Shape3D {
  final List<Vector3> points;
  FreeStroke({required super.color, super.width = 6.0}) : points = [];
  void addPoint(Vector3 p) => points.add(p.clone());
  bool get hasPoints => points.length >= 2;
}

// ─── Segmento ──────────────────────────────────────────────────────────────
class Segment3D extends Shape3D {
  final Vector3 start;
  final Vector3 end;
  const Segment3D({
    required this.start,
    required this.end,
    required super.color,
    super.width = 6.0,
  });
}

// ─── Sfera (wireframe: 3 cerchi su piani XY, XZ, YZ) ─────────────────────
class Sphere3D extends Shape3D {
  final Vector3 center;
  final double radius;
  const Sphere3D({
    required this.center,
    required this.radius,
    required super.color,
    super.width = 4.0,
  });
}

// ─── Parallelepipedo (2 vertici opposti) ──────────────────────────────────
class Box3D extends Shape3D {
  final Vector3 a; // vertice 1
  final Vector3 b; // vertice opposto
  const Box3D({
    required this.a,
    required this.b,
    required super.color,
    super.width = 4.0,
  });

  // Tutti e 8 i vertici
  List<Vector3> get corners => [
    Vector3(a.x, a.y, a.z),
    Vector3(b.x, a.y, a.z),
    Vector3(b.x, b.y, a.z),
    Vector3(a.x, b.y, a.z),
    Vector3(a.x, a.y, b.z),
    Vector3(b.x, a.y, b.z),
    Vector3(b.x, b.y, b.z),
    Vector3(a.x, b.y, b.z),
  ];

  // 12 spigoli come coppie di indici nei corners
  static const List<List<int>> edges = [
    [0,1],[1,2],[2,3],[3,0], // faccia anteriore
    [4,5],[5,6],[6,7],[7,4], // faccia posteriore
    [0,4],[1,5],[2,6],[3,7], // spigoli laterali
  ];
}

// ─── Preview dinamica durante il disegno ──────────────────────────────────
// Usata per mostrare la forma mentre l'utente tiene premuto
class ShapePreview {
  final DrawMode mode;
  final Vector3 start;    // punto al pushdown
  Vector3 current;        // punto corrente (aggiornato in tempo reale)
  final StrokeColor color;
  final double width;

  ShapePreview({
    required this.mode,
    required this.start,
    required this.current,
    required this.color,
    required this.width,
  });
}

// ─── Colori ────────────────────────────────────────────────────────────────
class StrokeColor {
  final double r, g, b;
  const StrokeColor(this.r, this.g, this.b);

  static const StrokeColor cyan    = StrokeColor(0.0, 1.0, 1.0);
  static const StrokeColor red     = StrokeColor(1.0, 0.2, 0.4);
  static const StrokeColor green   = StrokeColor(0.2, 1.0, 0.6);
  static const StrokeColor yellow  = StrokeColor(1.0, 0.9, 0.0);
  static const StrokeColor white   = StrokeColor(1.0, 1.0, 1.0);
  static const StrokeColor magenta = StrokeColor(0.8, 0.0, 1.0);
  static const StrokeColor orange  = StrokeColor(1.0, 0.4, 0.0);
  static const StrokeColor blue    = StrokeColor(0.0, 0.6, 1.0);

  Color toFlutterColor() => Color.fromRGBO(
    (r * 255).round(), (g * 255).round(), (b * 255).round(), 1.0);
}

// Alias per retrocompatibilità
typedef Stroke3D = FreeStroke;
