import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'stroke_model.dart';

class Painter3D extends StatelessWidget {

final List<Stroke3D> strokes;

final Stroke3D? currentStroke;

final Matrix4 viewMatrix;

final Matrix4 projMatrix;

final Vector3 camPos;

const Painter3D({

super.key,

required this.strokes,

required this.currentStroke,

required this.viewMatrix,

required this.projMatrix,

required this.camPos

});

@override
Widget build(BuildContext context){

return CustomPaint(

painter:_Painter3D(

strokes,
currentStroke,
viewMatrix,
projMatrix

),

child:const SizedBox.expand()

);

}

}

class _Painter3D extends CustomPainter{

final List<Stroke3D> strokes;

final Stroke3D? current;

final Matrix4 view;

final Matrix4 proj;

_Painter3D(

this.strokes,
this.current,
this.view,
this.proj

);

Vector4 _toCameraSpace(Vector3 p){

return view.transform(

Vector4(

p.x,
p.y,
p.z,
1

)

);

}

double _perspectiveWidth(

double base,
double depth

){

// evita divisioni instabili
depth = depth.clamp(
0.02,
50.0
);

// distanza riferimento AR realistica
const refDepth = 0.25;

// prospettiva reale (camera model)
final scale = refDepth / depth;

// curva più naturale
final perspective = scale * scale * 1.4;

double width = base * perspective;

// range realistico AR
return width.clamp(

base * 0.08,
base * 60

);

}

Offset? _project(

Vector3 p,
Size size

){

final cam=_toCameraSpace(p);

// dietro camera
if(cam.z>0)return null;

final clip=proj.transform(cam);

if(clip.w==0)return null;

final ndcX=clip.x/clip.w;

final ndcY=clip.y/clip.w;

final sx=

(ndcX*0.5+0.5)
*size.width;

final sy=

(-ndcY*0.5+0.5)
*size.height;

return Offset(

sx,
sy

);

}

void _drawStroke(

Canvas canvas,
Size size,
Stroke3D s

){

if(s.points.length<2)return;

final paint=Paint()

..color=s.color.toFlutterColor()

..strokeCap=StrokeCap.round

..style=PaintingStyle.stroke;

Offset? prev2D;

Vector3? prev3D;

double prevWidth=s.width;

for(final p in s.points){

final cam=_toCameraSpace(p);

final depth=-cam.z;

final pr=_project(

p,
size

);

if(pr==null){

prev2D=null;

prev3D=null;

continue;

}

if(prev2D!=null && prev3D!=null){

final prevCam=_toCameraSpace(prev3D);

final prevDepth=-prevCam.z;

// depth media segmento
final avgDepth=

(prevDepth+depth)*0.5;

final newWidth=

_perspectiveWidth(

s.width,
avgDepth

);

// smoothing AR jitter
final smoothWidth=

prevWidth*0.82+
newWidth*0.18;

paint.strokeWidth=smoothWidth;

canvas.drawLine(

prev2D,
pr,
paint

);

prevWidth=smoothWidth;

}

prev2D=pr;

prev3D=p;

}

}

@override
void paint(

Canvas canvas,
Size size

){

for(final s in strokes){

_drawStroke(

canvas,
size,
s

);

}

if(current!=null){

_drawStroke(

canvas,
size,
current!

);

}

}

@override
bool shouldRepaint(

covariant _Painter3D old

)=>true;

}