import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'stroke_model.dart';
import 'painter_3d.dart';

class AR3DPaintPage extends StatefulWidget {
  const AR3DPaintPage({super.key});
  @override
  State<AR3DPaintPage> createState() => _AR3DPaintPageState();
}

class _AR3DPaintPageState extends State<AR3DPaintPage> with WidgetsBindingObserver {
  static const _ec = EventChannel('ar3d_paint/camera_pose');
  Matrix4 _pose = Matrix4.identity();
  StreamSubscription? _sub;
  bool _tracking = false;
  Vector3? _gridOrigin;

  final List<Stroke3D> _strokes = [];
  Stroke3D? _current;
  bool _drawing = false;
  StrokeColor _color = StrokeColor.cyan;
  double _size = 6.0;
  Timer? _timer;
  // showGrid=true  → mostra griglia 3D (sfondo scuro semi-trasparente)
  // showGrid=false → sfondo trasparente, camera AR visibile
  bool _showGrid = false;

  static const _colors = {
    'Ciano': StrokeColor.cyan,
    'Rosso': StrokeColor.red,
    'Verde': StrokeColor.green,
    'Giallo': StrokeColor.yellow,
    'Bianco': StrokeColor.white,
    'Viola': StrokeColor.magenta,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _ec.receiveBroadcastStream().listen((d) {
      setState(() {
        _pose = Matrix4.fromList((d as List).cast<double>());
        if (!_tracking) {
          // Prima pose valida: ancora la griglia 0.5m sotto la camera
          _gridOrigin = Vector3(
            _pose.entry(0, 3),
            _pose.entry(1, 3) - 0.5,
            _pose.entry(2, 3),
          );
        }
        _tracking = true;
      });
    }, onError: (_) => setState(() => _tracking = false));
  }

  void _startDraw() {
    setState(() {
      _drawing = true;
      _current = Stroke3D(color: _color, width: _size);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_drawing || _current == null) return;
      // Punto 0.3m davanti alla camera lungo l'asse forward (+Z in ARCore)
      final pos = _pose.getColumn(3);
      final forward = Vector3(
        _pose.entry(0, 2),
        _pose.entry(1, 2),
        _pose.entry(2, 2),
      );
      final paintPoint = Vector3(pos.x, pos.y, pos.z) + forward * 0.3;
      setState(() => _current!.addPoint(paintPoint));
    });
  }

  void _stopDraw() {
    _timer?.cancel();
    setState(() {
      _drawing = false;
      if (_current != null && _current!.hasPoints) _strokes.add(_current!);
      _current = null;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Trasparente quando camera attiva, scuro quando griglia attiva
      backgroundColor: _showGrid ? Colors.black87 : Colors.transparent,
      body: Stack(children: [

        // Painter 3D (griglia + stroke)
        Painter3D(
          strokes: _strokes,
          currentStroke: _current,
          cameraPose: _pose,
          showGrid: _showGrid,
          gridOrigin: _gridOrigin,
        ),

        // Banner inizializzazione AR (piccolo, non bloccante)
        if (!_tracking)
          Positioned(
            top: 80, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Inizializzando AR...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
          ),

        // UI overlay
        SafeArea(child: Column(children: [
          // Barra superiore
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _tracking ? Colors.greenAccent : Colors.orange,
                )),
                const SizedBox(width: 8),
                Text(_drawing ? 'Disegnando...' : 'AR 3D Paint',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ])),
            const Spacer(),
            // Toggle griglia / camera reale
            GestureDetector(
              onTap: () => setState(() => _showGrid = !_showGrid),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _showGrid ? Colors.white24 : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38)),
                child: Icon(
                  _showGrid ? Icons.grid_on : Icons.camera_alt_outlined,
                  color: Colors.white, size: 20))),
            const SizedBox(width: 8),
            // Undo
            GestureDetector(
              onTap: () { if (_strokes.isNotEmpty) setState(() => _strokes.removeLast()); },
              child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.undo, color: Colors.white, size: 20))),
            const SizedBox(width: 8),
            // Clear
            GestureDetector(
              onTap: () => setState(() => _strokes.clear()),
              child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 20))),
          ])),

          const Spacer(),

          // Selettore colori
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: _colors.entries.map((e) {
              final sel = e.value == _color;
              final c = e.value.toFlutterColor();
              return GestureDetector(
                onTap: () => setState(() => _color = e.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 12),
                  width: sel ? 46 : 36, height: sel ? 46 : 36,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: sel ? 3 : 1),
                    boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 12)] : [],
                  )));
            }).toList())),

          const SizedBox(height: 16),

          // Controlli taglia e pulsante disegno
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () => setState(() => _size = 4.0),
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _size == 4.0 ? Colors.white24 : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38)),
                child: const Center(child: Text('S', style: TextStyle(color: Colors.white))))),
            const SizedBox(width: 16),
            // Pulsante disegno principale
            GestureDetector(
              onTapDown: (_) => _startDraw(),
              onTapUp: (_) => _stopDraw(),
              onTapCancel: () => _stopDraw(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _drawing ? 88 : 76, height: _drawing ? 88 : 76,
                decoration: BoxDecoration(
                  color: _drawing ? _color.toFlutterColor() : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: _drawing
                      ? _color.toFlutterColor().withValues(alpha: 0.6)
                      : Colors.white30,
                    blurRadius: 20)]),
                child: Icon(
                  _drawing ? Icons.brush : Icons.brush_outlined,
                  color: _drawing ? Colors.white : Colors.black,
                  size: 34))),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() => _size = 10.0),
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _size == 10.0 ? Colors.white24 : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38)),
                child: const Center(child: Text('L', style: TextStyle(color: Colors.white))))),
          ]),
          const SizedBox(height: 28),
        ])),
      ]),
    );
  }
}
