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
  List<int>? currentSamples = [];
  List<int> visibleSamples = [];
  int? localMax;
  int? localMin;

  Random rng = new Random();
  late AnimationController controller;
  bool isRecording = false;
  bool memRecordingState = false;
  late bool isActive;
  DateTime? startTime;

  @override
  void initState() {
    try {
      initilize();
    } catch (e) {
      print(e);
    }
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    setState(() {
      initPlatformState();
    });
  }

  // Responsible for switching between recording / idle state
  void _controlMicStream({Command command: Command.change}) async {
    switch (command) {
      case Command.change:
        _changeListening();
        break;
      case Command.start:
        _startListening();
        break;
      case Command.stop:
        _stopListening();
        break;
    }
  }

  Future<bool> _changeListening() async =>
      !isRecording ? await _startListening() : _stopListening();

  late int bytesPerSample;
  late int samplesPerSecond;

  Future<bool> _startListening() async {
    print("START LISTENING");
    if (isRecording) return false;
    // if this is the first time invoking the microphone()
    // method to get the stream, we don't yet have access
    // to the sampleRate and bitDepth properties
    print("wait for stream");

    // Default option. Set to false to disable request permission dialogue
    MicStream.shouldRequestPermission(true);

    stream = await MicStream.microphone(
        audioSource: AudioSource.DEFAULT,
        sampleRate: 1000 * (rng.nextInt(50) + 30),
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AUDIO_FORMAT);
    // after invoking the method for the first time, though, these will be available;
    // It is not necessary to setup a listener first, the stream only needs to be returned first
    print(
        "Start Listening to the microphone, sample rate is ${await MicStream.sampleRate}, bit depth is ${await MicStream.bitDepth}, bufferSize: ${await MicStream.bufferSize}");
    bytesPerSample = (await MicStream.bitDepth)! ~/ 8;
    samplesPerSecond = (await MicStream.sampleRate)!.toInt();
    localMax = null;
    localMin = null;

    setState(() {
      isRecording = true;
      startTime = DateTime.now();
    });
    visibleSamples = [];
    listener = stream!.listen(_calculateSamples);
    return true;
  }

  void _calculateSamples(samples) {
    _calculateWaveSamples(samples);
    var points = toPoints(visibleSamples);
    // print('samet' + points[440].direction.toString());
    Path path = new Path();
    path.addPolygon(points, false);
    var brightness = path.getBounds().center.dy.toInt();
    if (brightness < 30) {
      brightness = 0;
    } else if (brightness < 200 && brightness > 150) {
      brightness = 64;
    } else if (brightness < 150 && brightness > 120) {
      brightness = 50;
    } else if (brightness < 120 && brightness > 100) {
      brightness = 40;
    } else if (brightness < 100 && brightness > 80) {
      brightness = 30;
    } else if (brightness < 80 && brightness > 60) {
      brightness = 20;
    } else if (brightness < 60 && brightness > 30) {
      brightness = 10;
    }
    print(brightness);
    changeBrightness(brightness);
  }

  void _calculateWaveSamples(samples) {
    bool first = true;
    visibleSamples = [];
    int tmp = 0;
    for (int sample in samples) {
      if (sample > 128) sample -= 255;
      if (first) {
        tmp = sample * 128;
      } else {
        tmp += sample;
        visibleSamples.add(tmp);

        localMax ??= visibleSamples.last;
        localMin ??= visibleSamples.last;

        localMax = max(localMax!, visibleSamples.last);
        localMin = min(localMin!, visibleSamples.last);
        tmp = 0;
      }
      first = !first;
    }
  }

  List<Offset> toPoints(List<int>? samples) {
    var sum = samples!.reduce((value, current) => value + current);
    var avg = sum / samples.length;
    // print('avg: $avg');
    List<Offset> points = [];
    if (samples == null)
      samples = List<int>.filled(context.size!.width.toInt(), (0.5).toInt());
    double pixelsPerSample = context.size!.width / samples.length;
    for (int i = 0; i < samples.length; i++) {
      var dy = 0.5 *
          context.size!.height *
          pow((samples[i] - localMin!) / (localMax! - localMin!), 5);
      var point = Offset(i * pixelsPerSample, dy);
      points.add(point);
    }

    // print('points: $points');
    return points;
  }

  bool _stopListening() {
    if (!isRecording) return false;
    print("Stop Listening to the microphone");
    listener.cancel();

    setState(() {
      isRecording = false;
      currentSamples = null;
      startTime = null;
    });
    return true;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    if (!mounted) return;
    isActive = true;

    // Statistics(false);

    controller =
        AnimationController(duration: Duration(seconds: 1), vsync: this)
          ..addListener(() {
            if (isRecording) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed)
              controller.reverse();
            else if (status == AnimationStatus.dismissed) controller.forward();
          })
          ..forward();
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

  Future<void> runDeviceCode() async {
    //find first selected modiList item
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
                (isRecording ? " (Recording)" : "---"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 130,
              ),
              CustomPaint(
                painter: WavePainter(
                  samples: visibleSamples,
                  // color: Color.fromRGBO(visibleSamples[0], visibleSamples[400],
                  //     visibleSamples.last, 1),
                  color: Colors.blue,
                  localMax: localMax,
                  localMin: localMin,
                  context: context,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                      onTap: () {
                        _controlMicStream();
                      },
                      child: Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                              color: isRecording ? Colors.green : Colors.grey,
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
