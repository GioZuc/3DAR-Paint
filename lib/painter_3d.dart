import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'stroke_model.dart';

class Painter3D extends StatelessWidget{

final List<Stroke3D>strokes;

final Stroke3D?currentStroke;

final Matrix4 viewMatrix;

final Matrix4 projMatrix;

const Painter3D({

super.key,

required this.strokes,

required this.currentStroke,

required this.viewMatrix,

required this.projMatrix

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

final List<Stroke3D>strokes;

final Stroke3D?current;

final Matrix4 view;

final Matrix4 proj;

_Painter3D(
this.strokes,
this.current,
this.view,
this.proj
);

Offset?_project(
Vector3 p,
Size size
){

final world=Vector4(
p.x,
p.y,
p.z,
1
);

final cam=view.transform(world);

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

return Offset(sx,sy);

}

void _drawStroke(
Canvas canvas,
Size size,
Stroke3D s
){

if(s.points.length<2)return;

final paint=Paint()

..color=s.color.toFlutterColor()

..strokeWidth=s.width

..strokeCap=StrokeCap.round

..style=PaintingStyle.stroke;

Offset?prev;

for(final p in s.points){

final pr=_project(p,size);

if(pr==null){
prev=null;
continue;
}

if(prev!=null){

canvas.drawLine(
prev,
pr,
paint
);

}

prev=pr;

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
bool shouldRepaint(covariant _Painter3D old)=>true;

}