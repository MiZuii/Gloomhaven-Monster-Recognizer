import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';
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

        var img = convertBaseOnTargetDevice(image);
        img = bakeOrientation(img);
        img = resize(img, height: 640, width: 640, maintainAspect: true);
        img = normalize(img, min: 0, max: 1);

        var output1 = List.filled(1*83*8400, 0).reshape([1,83,8400]);
        var output2 = List.filled(1*160*160*32, 0).reshape([1,160,160,32]);
        final output = {
          0: output1,
          1: output2,
        };

        var input = img
          .toList()
          .map((e) => e.toList())
          .toList()
          .reshape([1, 640, 640, 3]);

        interpreter.runForMultipleInputs([input], output);

        print("MODEL FINISHED DETECTION");

        double bestScore = 0;
        List<double> bbox = [0, 0, 0, 0];
        if(output[0] != null)
        {
          for( List<double> detection in output[0]![0] )
          {
            if(detection[4+classIdToDetect] > bestScore)
            {
              bestScore = detection[4+classIdToDetect];
              bbox[0] = detection[0];
              bbox[1] = detection[1];
              bbox[2] = detection[2];
              bbox[3] = detection[3];
            }
          }
        }
        print("SENDING: $bestScore $bbox");

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