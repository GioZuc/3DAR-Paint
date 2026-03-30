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

class _AR3DPaintPageState extends State<AR3DPaintPage>
    with SingleTickerProviderStateMixin {
  static const _ec = EventChannel('ar3d_paint/camera_pose');

  Matrix4 _view = Matrix4.identity();
  Matrix4 _proj = Matrix4.identity();
  Vector3 _camPos = Vector3.zero();
  Vector3 _forward = Vector3.zero();

  StreamSubscription? _sub;
  bool _tracking = false;

  // Forme finalizzate
  final List<Shape3D> _shapes = [];
  // Preview della forma in costruzione
  ShapePreview? _preview;
  // Free stroke in costruzione
  FreeStroke? _currentFree;

  bool _drawing = false;
  DrawMode _mode = DrawMode.free;
  StrokeColor _color = StrokeColor.cyan;
  double _size = 6;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _colorOptions = [
    _ColorOption('Ciano',   StrokeColor.cyan,    Color(0xFF00FFFF)),
    _ColorOption('Rosso',   StrokeColor.red,     Color(0xFFFF3366)),
    _ColorOption('Verde',   StrokeColor.green,   Color(0xFF33FF99)),
    _ColorOption('Giallo',  StrokeColor.yellow,  Color(0xFFFFE500)),
    _ColorOption('Bianco',  StrokeColor.white,   Color(0xFFFFFFFF)),
    _ColorOption('Viola',   StrokeColor.magenta, Color(0xFFCC00FF)),
    _ColorOption('Arancio', StrokeColor.orange,  Color(0xFFFF6600)),
    _ColorOption('Azzurro', StrokeColor.blue,    Color(0xFF0099FF)),
  ];

  static const _modeOptions = [
    _ModeOption(DrawMode.free,    Icons.brush_rounded,         'Libero'),
    _ModeOption(DrawMode.segment, Icons.remove_rounded,        'Segmento'),
    _ModeOption(DrawMode.sphere,  Icons.radio_button_unchecked,'Sfera'),
    _ModeOption(DrawMode.box,     Icons.crop_square_rounded,   'Box'),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _sub = _ec.receiveBroadcastStream().listen((d) {
      final map = (d as Map).cast<String, dynamic>();
      setState(() {
        _view    = Matrix4.fromList((map['view']    as List).cast<double>());
        _proj    = Matrix4.fromList((map['proj']    as List).cast<double>());
        _camPos  = Vector3(map['pos'][0],     map['pos'][1],     map['pos'][2]);
        _forward = Vector3(map['forward'][0], map['forward'][1], map['forward'][2]);
        _tracking = true;
        // Aggiorna il punto corrente della preview in tempo reale
        if (_preview != null) {
          _preview!.current = _camPos + _forward * 0.25;
        }
      });
    });
  }

  // Punto cursore: 0.25m davanti alla camera
  Vector3 get _cursor => _camPos + _forward * 0.25;

  void _onTapDown() {
    final start = _cursor;
    setState(() {
      _drawing = true;
      switch (_mode) {
        case DrawMode.free:
          _currentFree = FreeStroke(color: _color, width: _size);
          _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
            if (!_drawing) return;
            setState(() => _currentFree!.addPoint(_cursor));
          });
        case DrawMode.segment:
        case DrawMode.sphere:
        case DrawMode.box:
          _preview = ShapePreview(
            mode: _mode,
            start: start,
            current: start.clone(),
            color: _color,
            width: _size,
          );
      }
    });
  }

  void _onTapUp() {
    _timer?.cancel();
    final end = _cursor;
    setState(() {
      _drawing = false;
      switch (_mode) {
        case DrawMode.free:
          if (_currentFree != null && _currentFree!.hasPoints) {
            _shapes.add(_currentFree!);
          }
          _currentFree = null;
        case DrawMode.segment:
          if (_preview != null) {
            _shapes.add(Segment3D(
              start: _preview!.start,
              end: end,
              color: _color,
              width: _size,
            ));
          }
          _preview = null;
        case DrawMode.sphere:
          if (_preview != null) {
            final radius = (end - _preview!.start).length;
            if (radius > 0.001) {
              _shapes.add(Sphere3D(
                center: _preview!.start,
                radius: radius,
                color: _color,
                width: _size,
              ));
            }
          }
          _preview = null;
        case DrawMode.box:
          if (_preview != null) {
            _shapes.add(Box3D(
              a: _preview!.start,
              b: end,
              color: _color,
              width: _size,
            ));
          }
          _preview = null;
      }
    });
  }

  void _undo() {
    if (_shapes.isNotEmpty) setState(() => _shapes.removeLast());
  }

  void _clear() => setState(() => _shapes.clear());

  @override
  void dispose() {
    _sub?.cancel(); _timer?.cancel(); _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _currentFlutterColor =>
      _colorOptions.firstWhere((o) => o.color == _color).display;

  @override
  Widget build(BuildContext context) {
    // Passa la free stroke corrente come preview se in modalità libera
    final ShapePreview? previewToPass = _mode == DrawMode.free ? null : _preview;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // ── Painter ──────────────────────────────────────────────────
        Painter3D(
          shapes: [
            ..._shapes,
            if (_mode == DrawMode.free && _currentFree != null) _currentFree!,
          ],
          preview: previewToPass,
          viewMatrix: _view,
          projMatrix: _proj,
          camPos: _camPos,
          forward: _forward,
        ),

        // ── Mirino ───────────────────────────────────────────────────
        Center(child: _Crosshair(active: _drawing, color: _currentFlutterColor)),

        // ── Banner AR ────────────────────────────────────────────────
        if (!_tracking)
          Positioned(
            top: 60, left: 0, right: 0,
            child: Center(child: _TrackingBanner()),
          ),

        // ── UI overlay ───────────────────────────────────────────────
        SafeArea(child: Column(children: [

          // Barra superiore
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _StatusBadge(tracking: _tracking, drawing: _drawing,
                  label: _modeOptions.firstWhere((m) => m.mode == _mode).label),
              const Spacer(),
              _IconBtn(icon: Icons.undo_rounded, onTap: _undo),
              const SizedBox(width: 10),
              _IconBtn(icon: Icons.delete_sweep_rounded, onTap: _clear),
            ]),
          ),

          const Spacer(),

          // ── Selettore colori ────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _colorOptions.length,
              itemBuilder: (_, i) {
                final opt = _colorOptions[i];
                final sel = opt.color == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = opt.color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(right: 14),
                    width: sel ? 48 : 36, height: sel ? 48 : 36,
                    decoration: BoxDecoration(
                      color: opt.display, shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.white30,
                        width: sel ? 3 : 1),
                      boxShadow: sel
                          ? [BoxShadow(color: opt.display.withValues(alpha: 0.7), blurRadius: 14)]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Pulsante disegno + taglie ────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _SizeBtn(label: 'S', selected: _size == 4,
                onTap: () => setState(() => _size = 4)),
            const SizedBox(width: 20),
            GestureDetector(
              onTapDown: (_) => _onTapDown(),
              onTapUp:   (_) => _onTapUp(),
              onTapCancel:    _onTapUp,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _drawing ? _pulseAnim.value : 1.0, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 250, height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _drawing ? _currentFlutterColor : Colors.white,
                    boxShadow: [BoxShadow(
                      color: _drawing
                          ? _currentFlutterColor.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.25),
                      blurRadius: 24, spreadRadius: 2)],
                  ),
                  child: Icon(
                    _modeOptions.firstWhere((m) => m.mode == _mode).icon,
                    size: 36,
                    color: _drawing ? Colors.white : Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 20),
            _SizeBtn(label: 'L', selected: _size == 12,
                onTap: () => setState(() => _size = 12)),
          ]),

          const SizedBox(height: 16),

          // ── Selettore modalità ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _modeOptions.map((opt) {
                final sel = opt.mode == _mode;
                return GestureDetector(
                  onTap: () => setState(() => _mode = opt.mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? _currentFlutterColor.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? _currentFlutterColor : Colors.white24,
                        width: sel ? 1.5 : 1),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(opt.icon, size: 22,
                          color: sel ? _currentFlutterColor : Colors.white60),
                      const SizedBox(height: 4),
                      Text(opt.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: sel ? _currentFlutterColor : Colors.white60,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget ausiliari
// ─────────────────────────────────────────────────────────────

class _ColorOption {
  final String name; final StrokeColor color; final Color display;
  const _ColorOption(this.name, this.color, this.display);
}

class _ModeOption {
  final DrawMode mode; final IconData icon; final String label;
  const _ModeOption(this.mode, this.icon, this.label);
}

class _Crosshair extends StatelessWidget {
  final bool active; final Color color;
  const _Crosshair({required this.active, required this.color});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: active ? 28 : 22, height: active ? 28 : 22,
    child: CustomPaint(painter: _CrosshairPainter(active: active, color: color)));
}

class _CrosshairPainter extends CustomPainter {
  final bool active; final Color color;
  _CrosshairPainter({required this.active, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = active ? color : Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.8 ..strokeCap = StrokeCap.round;
    final cx = size.width/2, cy = size.height/2, arm = size.width * 0.28;
    canvas.drawLine(Offset(cx-arm,cy), Offset(cx-3,cy), p);
    canvas.drawLine(Offset(cx+3,cy), Offset(cx+arm,cy), p);
    canvas.drawLine(Offset(cx,cy-arm), Offset(cx,cy-3), p);
    canvas.drawLine(Offset(cx,cy+3), Offset(cx,cy+arm), p);
    canvas.drawCircle(Offset(cx,cy), 2.2, Paint()..color = p.color);
  }
  @override
  bool shouldRepaint(_CrosshairPainter o) => o.active != active || o.color != color;
}

class _TrackingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.4))),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 13, height: 13,
        child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
      SizedBox(width: 10),
      Text('Inizializzando AR…',
        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
    ]));
}

class _StatusBadge extends StatelessWidget {
  final bool tracking, drawing; final String label;
  const _StatusBadge({required this.tracking, required this.drawing, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(duration: const Duration(milliseconds: 300),
        width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: tracking ? Colors.greenAccent : Colors.orange,
          boxShadow: [BoxShadow(
            color: tracking ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.orange.withValues(alpha: 0.5),
            blurRadius: 6)])),
      const SizedBox(width: 8),
      Text(drawing ? 'Disegnando…' : label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    ]));
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle,
        border: Border.all(color: Colors.white24)),
      child: Icon(icon, color: Colors.white, size: 20)));
}

class _SizeBtn extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _SizeBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: selected ? Colors.white60 : Colors.white24, width: selected ? 2 : 1)),
      child: Center(child: Text(label,
        style: TextStyle(color: Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 15)))));
}
