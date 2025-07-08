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
    _controller = CameraController(GMRCameraView.getCamera(1), ResolutionPreset.low);
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
    return MaterialApp(
      home: CameraPreview(_controller),
    );
  }
} 