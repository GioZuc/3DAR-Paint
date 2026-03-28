import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class Stroke3D {
  final List<Vector3> points;
  final StrokeColor color;
  final double width;

  Stroke3D({required this.color, this.width = 6.0}) : points = [];

  void addPoint(Vector3 p) => points.add(p.clone());
  bool get hasPoints => points.length >= 2;
}

class StrokeColor {
  final double r, g, b;
  const StrokeColor(this.r, this.g, this.b);

  static const StrokeColor cyan    = StrokeColor(0.0,  1.0,  1.0);
  static const StrokeColor red     = StrokeColor(1.0,  0.2,  0.4);
  static const StrokeColor green   = StrokeColor(0.2,  1.0,  0.6);
  static const StrokeColor yellow  = StrokeColor(1.0,  0.9,  0.0);
  static const StrokeColor white   = StrokeColor(1.0,  1.0,  1.0);
  static const StrokeColor magenta = StrokeColor(0.8,  0.0,  1.0);
  static const StrokeColor orange  = StrokeColor(1.0,  0.4,  0.0);
  static const StrokeColor blue    = StrokeColor(0.0,  0.6,  1.0);

  Color toFlutterColor() => Color.fromRGBO(
    (r * 255).round(), (g * 255).round(), (b * 255).round(), 1.0);
}
