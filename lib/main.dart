import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ar3d_paint/ar_paint_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const AR3DPaintApp());
}

class AR3DPaintApp extends StatelessWidget {
  const AR3DPaintApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR 3D Paint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Trasparente: la GLSurfaceView con la camera AR è visibile sotto
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(),
      ),
      home: const AR3DPaintPage(),
    );
  }
}
