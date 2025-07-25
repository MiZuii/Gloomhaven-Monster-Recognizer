import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';
import 'converter.dart';
import 'package:flutter/services.dart' show rootBundle;

// IMAGE DETECTION ISOLATE

class ImageDetectionIsolate
{
  late SendPort _sendPort;
  late ReceivePort _receivePort;
  late Isolate? _isolate;

  final Completer<void> _ready = Completer<void>();
  final Map<String, Completer<dynamic>> _results = {}; // change dynamic to the accual type returned by the model

  Future<void> initialize() async
  {
    ByteData data = await rootBundle.load("assets/models/gmr-yolo11s-seg.tflite");
    ByteBuffer modelBuffer = data.buffer;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateListener,
      {
        'sendPort': _receivePort.sendPort,
        'modelBuffer': modelBuffer
      });
    _receivePort.listen(_hostListener);
    
    return _ready.future; // this future will complete when hostListener will confirm the connection was successfull
  }

  void _hostListener(message)
  {
    if( message is SendPort )
    {
      // connection accepted
      _sendPort = message;
      _ready.complete();
      return;
    }

    // normal message -> read result and update appropriate future
    final String? taskId;
    try {
      taskId = message['id'] as String;
    } catch (e) {
      print("Unknown task");
      return;
    }

    try {
      final dynamic result = message['result'];
      final dynamic error  = message['error'];
      if( error != null )
      {
        _results[taskId]?.completeError(error);
      }
      else
      {
        _results[taskId]?.complete(result);
      }
    } catch (e) {
      _results[taskId]?.completeError(e);
      print("Task $taskId failed with error $e");
    }
  }

  Future<dynamic> compute(CameraImage image, int classId) async
  {
    // wait if isolate is not ready yet
    if (!_ready.isCompleted) {
      await _ready.future;
    }

    // generate task id
    final String taskId = DateTime.now().microsecondsSinceEpoch.toString();
    final taskCompleter = Completer<dynamic>();
    _results[taskId] = taskCompleter;

    _sendPort.send({
      'id': taskId,
      'image': image,
      'classId': classId
    });

    return taskCompleter.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
    _results.forEach((_, completer) {
      if (!completer.isCompleted) {
        completer.completeError('ComputeWorker disposed before task completion.');
      }
    });
    _results.clear();
  }

  static void _isolateListener(Map<String, dynamic> initialMessage) async
  {
    late Interpreter interpreter;

    SendPort creatorSendPort = initialMessage['sendPort'] as SendPort;
    ByteBuffer modelBuffer = initialMessage['modelBuffer'] as ByteBuffer;

    interpreter = await Interpreter.fromBuffer(modelBuffer.asUint8List());
    interpreter.allocateTensors();

    final ReceivePort _receivePort = ReceivePort();
    creatorSendPort.send(_receivePort.sendPort);
    _receivePort.listen((message) {
    if( message is Map<String, dynamic>)
    {
      try {
        final String taskId = message['id'] as String;
        final CameraImage image = message['image'] as CameraImage;
        final int classIdToDetect = message['classId'] as int;

        // transform camera image to image package format
        var img = convertBaseOnTargetDevice(image);

        img = bakeOrientation(img);

        // resize image
        double top  = 0;
        double left = 0;
        double r    = min(640 / image.height, 640 / image.width); 
        if( image.width > image.height )
        {
          img = resize(img, width: 640, maintainAspect: true);
          top = (640 - img.height) / 2;
        }
        else
        {
          img  = resize(img, height: 640, maintainAspect: true);
          left = (640 - img.width) / 2;
        }

        // add padding
        var nimg = Image(width: 640, height: 640, format: Format.float32);
        for( var pixel in nimg )
        {
          pixel.setRgb(114, 114, 114);
        }

        copyExpandCanvas(img, newWidth: 640, newHeight: 640, toImage: nimg);

        // normalize image
        img = normalize(nimg, min: 0, max: 1);

        var output1 = List.filled(1*300*6, 0).reshape([1,300,6]);
        final output = {
          0: output1,
        };

        var input = img.buffer
          .asFloat32List()
          .reshape([1, 640, 640, 3]);

        interpreter.runForMultipleInputs([input], output);

        double bestScore = -1;
        List<double> bbox = [0, 0, 0, 0];
        if(output[0] != null)
        {
          for( List<double> detection in output[0]![0] )
          {
            if( detection[5].toInt() == classIdToDetect )
            {
              if( detection[4] > bestScore )
              {
                bestScore = detection[4];

                // calculate the bounding box
                var x1p = detection[0] * 640;
                var y1p = detection[1] * 640;
                var x2p = detection[2] * 640;
                var y2p = detection[3] * 640;

                bbox[0] = (x1p - left);
                bbox[2] = (x2p - left);
                bbox[1] = (y1p - top);
                bbox[3] = (y2p - top);
              }
            }
          }
        }

        creatorSendPort.send({
          'id': taskId,
          'result':
          {
            'score': bestScore,
            'bbox': bbox,
          },
          'error': null,
        });

      } catch (e) {
        creatorSendPort.send({
          'id': message['id'] as String?,
          'error': "$e"
        });
      }
    }
    else
    {
      creatorSendPort.send({
        'error': "invalid message"
      });
    }
    });
  }
}