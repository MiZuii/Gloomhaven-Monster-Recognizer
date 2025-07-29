import 'main.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'isolates/detection_isolate.dart';
import 'package:provider/provider.dart';

class GMRCameraView extends StatefulWidget {

  static late List<CameraDescription> _cameras;

  const GMRCameraView({
    super.key,
  });

  static Future<void> initialize() async {
    _cameras = await availableCameras();
  }

  static CameraDescription getCamera(int idx) {
    if( idx >= _cameras.length ) {
      throw Exception('Camera index out of bounds, device has ${_cameras.length} cameras');
    }
    return _cameras[idx];
  }

  @override
  State<GMRCameraView> createState() => _GMRCameraViewState();
}

class _GMRCameraViewState extends State<GMRCameraView> {
  late CameraController _controller;
  late ImageDetectionIsolate _imageDetectionIsolate;
  bool _isModelDetecting = false;
  dynamic _latestModelResults;

  @override
  void initState() {
    super.initState();

    // isolate init
    _imageDetectionIsolate = ImageDetectionIsolate();
    _imageDetectionIsolate.initialize();

    // camera initialization
    _controller = CameraController(GMRCameraView.getCamera(0), ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _controller.startImageStream((image) => recognitionModelImageStream(context, image));

    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  void recognitionModelImageStream(BuildContext context, CameraImage image)
  {
    var appState = Provider.of<GMRAppState>(context, listen: false);

    if( _isModelDetecting )
    {
      return;
    }

    setState(() {
      _isModelDetecting = true;
    });


    _imageDetectionIsolate.compute(image, appState.currentMonsterIdx).then((result) => {
      setState(() {
        _latestModelResults = result;
        _isModelDetecting = false;
        print("LATEST MODEL RESULT: $result");
      })
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _imageDetectionIsolate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    // Get the preview size from the controller
    final previewSize = _controller.value.previewSize;
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller),
            if (_latestModelResults != null &&
                _latestModelResults['bbox'] != null &&
                _latestModelResults['bbox'] is List &&
                _latestModelResults['bbox'].length == 4 &&
                previewSize != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: BoundingBoxPainter(
                      _latestModelResults['bbox'],
                      previewSize: previewSize,
                      widgetSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    child: Container(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> bbox;
  final Size previewSize;
  final Size widgetSize;
  BoundingBoxPainter(this.bbox, {required this.previewSize, required this.widgetSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (bbox.length != 4) return;
    final paint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    // bbox: [x1, y1, x2, y2] in 640x640
    // Scale to widget size
    double scaleX = widgetSize.width / 640.0;
    double scaleY = widgetSize.height / 640.0;
    final rect = Rect.fromLTRB(
      bbox[0].toDouble() * scaleX,
      bbox[1].toDouble() * scaleY,
      bbox[2].toDouble() * scaleX,
      bbox[3].toDouble() * scaleY,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 