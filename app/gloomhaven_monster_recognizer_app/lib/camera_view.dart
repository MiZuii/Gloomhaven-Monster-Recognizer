import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';

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
  late FlutterVision _vision;
  List<Map<String, dynamic>> _latestDetectionResult = [];
  bool _isModelDetecting = false;

  @override
  void initState() {
    super.initState();

    // model initialization
    _vision = FlutterVision();

    // camera initialization
    _controller = CameraController(GMRCameraView.getCamera(0), ResolutionPreset.low);
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      // load YOLO model
      loadYoloModel().then((_) {
        _controller.startImageStream(recognitionModelImageStream);
        setState(() {});
      });
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

  Future<void> loadYoloModel() async {
    await _vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: 'assets/models/gmr-yolo11s-seg.tflite',
        modelVersion: "yolov11seg",
        numThreads: 8,
        useGpu: true);
  }

  void recognitionModelImageStream(CameraImage image) async
  {
    if( _isModelDetecting )
    {
      return;
    }

    setState(() {
      _isModelDetecting = true;
    });

    final result = await _vision.yoloOnFrame(
      bytesList: image.planes.map((plane) => plane.bytes).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.4,
      confThreshold: 0.4,
      classThreshold: 0.5);

    setState(() {
      _latestDetectionResult = result;
      _isModelDetecting = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _vision.closeYoloModel();
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