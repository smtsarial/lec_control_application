import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:core';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ui/device_detail/characteristic_interaction_dialog.dart';
import 'package:led_blue/src/ui/device_detail/device_interaction_tab.dart';
import 'package:led_blue/src/ui/device_detail/timer/timer_screen.dart';
import 'package:provider/provider.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:collection/collection.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/material.dart';
import 'dart:async';

enum Command {
  start,
  stop,
  change,
}

const AUDIO_FORMAT = AudioFormat.ENCODING_PCM_8BIT;

class MicScreenTab extends StatelessWidget {
  final DiscoveredDevice device;

  const MicScreenTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _TimerScreen(
          viewModel: MicScreenViewModel(
              deviceId: device.id,
              connectionStatus: connectionStateUpdate.connectionState,
              deviceConnector: deviceConnector,
              service: serviceDiscoverer,
              discoverServices: () =>
                  serviceDiscoverer.discoverServices(device.id)),
        ),
      );
}

@immutable
@FunctionalData()
class MicScreenViewModel extends $TimerScreenViewModel {
  const MicScreenViewModel({
    required this.deviceId,
    required this.connectionStatus,
    required this.deviceConnector,
    required this.discoverServices,
    required this.service,
  });

  final String deviceId;
  final DeviceConnectionState connectionStatus;
  final BleDeviceConnector deviceConnector;
  final BleDeviceInteractor service;

  @CustomEquality(Ignore())
  final Future<List<DiscoveredService>> Function() discoverServices;

  bool get deviceConnected =>
      connectionStatus == DeviceConnectionState.connected;

  Future<void> connect() async {
    print('connected');
    await deviceConnector.connect(deviceId);
  }

  void disconnect() {
    deviceConnector.disconnect(deviceId);
  }
}

class _TimerScreen extends StatefulWidget {
  const _TimerScreen({
    required this.viewModel,
    Key? key,
  }) : super(key: key);

  final MicScreenViewModel viewModel;

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<_TimerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<DiscoveredService> discoveredServices = [];
  Stream? stream;
  late StreamSubscription listener;
  bool _isRecording = false;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  late NoiseMeter _noiseMeter;
  int localmax = 0;
  int localmin = 0;

  @override
  void initState() {
    super.initState();
    _noiseMeter = new NoiseMeter(onError);
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  void onData(NoiseReading noiseReading) {
    this.setState(() {
      if (!this._isRecording) {
        this._isRecording = true;
      }
    });

    int meandecibel = noiseReading.meanDecibel.toInt();

    if (meandecibel > localmax) localmax = meandecibel;
    if (meandecibel < localmin) localmin = meandecibel;
    print('LocalMin: ' +
        localmin.toString() +
        ' LocalMax: ' +
        localmax.toString());
    int brightness = ((64 * meandecibel) ~/ localmax).toInt();
    changeBrightness(brightness);
  }

  void onError(Object error) {
    print(error.toString());
    _isRecording = false;
  }

  void start() async {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);
    } catch (err) {
      print(err);
    }
  }

  void stop() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription!.cancel();
        _noiseSubscription = null;
      }
      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  initilize() async {
    await widget.viewModel.connect().then((value) async {
      //discoverServices();
    });
  }

  Future<List<DiscoveredService>> discoverServices() async {
    final result = await widget.viewModel.discoverServices();

    setState(() {
      discoveredServices = result;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate.fixed(
            [
              Padding(
                padding:
                    const EdgeInsetsDirectional.only(top: 8.0, bottom: 16.0),
                child: Text(
                  "Mic",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                (_isRecording ? " (Recording)" : "---"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                      onTap: _isRecording ? stop : start,
                      child: Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                              color: _isRecording ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                )
                              ]),
                          child: Image.asset('assets/images/record.png'))),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  changeBrightness(int _brightness) async {
    if (widget.viewModel.connectionStatus == DeviceConnectionState.connected ||
        widget.viewModel.connectionStatus == DeviceConnectionState.connecting) {
      print('BRIGHTNESS changed11');
      await widget.viewModel.service.writeDataToFF3Services(
          widget.viewModel.deviceId, [
        126,
        4,
        1,
        _brightness.toInt(),
        1,
        255,
        255,
        0,
        239,
        33,
        33,
        33,
        33,
        33,
        33,
        33
      ]);
    } else {
      print('BRIGHTNESS changed');
      ledOn();
      await widget.viewModel.service.writeDataToFF3Services(
          widget.viewModel.deviceId, [
        126,
        4,
        1,
        _brightness.toInt(),
        1,
        255,
        255,
        0,
        239,
        33,
        33,
        33,
        33,
        33,
        33,
        33
      ]);
    }
  }

  ledOff() async {
    print('led off');
    await widget.viewModel.service.writeDataToFF3Services(
        widget.viewModel.deviceId, [
      126,
      4,
      4,
      0,
      0,
      0,
      256,
      0,
      239,
      51,
      51,
      51,
      51,
      51,
      51,
      51
    ]).then((value) {
      if (value) {
        print('led off success');
      } else {
        print('led off failed');
      }
    });
  }

  ledOn() async {
    print('led on');

    await widget.viewModel.service.writeDataToFF3Services(
        widget.viewModel.deviceId, [
      126,
      4,
      4,
      240,
      0,
      0,
      256,
      0,
      239,
      51,
      51,
      51,
      51,
      51,
      51,
      51
    ]).then((value) {
      if (value) {
        print('led on success');
      } else {
        print('led on failed');
      }
    });
  }
}

class WavePainter extends CustomPainter {
  int? localMax;
  int? localMin;
  List<int>? samples;
  late List<Offset> points;
  Color? color;
  BuildContext? context;
  Size? size;

  // Set max val possible in stream, depending on the config
  // int absMax = 255*4; //(AUDIO_FORMAT == AudioFormat.ENCODING_PCM_8BIT) ? 127 : 32767;
  // int absMin; //(AUDIO_FORMAT == AudioFormat.ENCODING_PCM_8BIT) ? 127 : 32767;

  WavePainter(
      {this.samples, this.color, this.context, this.localMax, this.localMin});

  @override
  void paint(Canvas canvas, Size? size) {
    this.size = context!.size;
    size = this.size;
    Paint paint = new Paint()
      ..color = color!
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    if (samples!.length == 0) return;
    points = toPoints(samples);
    // print('samet' + points[440].direction.toString());
    Path path = new Path();
    path.addPolygon(points, false);
    // print(path.getBounds().center.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldPainting) => true;

  // Maps a list of ints and their indices to a list of points on a cartesian grid
  List<Offset> toPoints(List<int>? samples) {
    var sum = samples!.reduce((value, current) => value + current);
    var avg = sum / samples.length;
    // print('avg: $avg');
    List<Offset> points = [];
    if (samples == null)
      samples = List<int>.filled(size!.width.toInt(), (0.5).toInt());
    double pixelsPerSample = size!.width / samples.length;
    for (int i = 0; i < samples.length; i++) {
      var dy = 0.5 *
          size!.height *
          pow((samples[i] - localMin!) / (localMax! - localMin!), 1);
      var point = Offset(i * pixelsPerSample, dy);
      points.add(point);
    }

    // print('points: $points');
    return points;
  }
}
