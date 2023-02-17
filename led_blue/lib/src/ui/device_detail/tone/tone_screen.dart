import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ui/device_detail/characteristic_interaction_dialog.dart';
import 'package:led_blue/src/ui/device_detail/device_interaction_tab.dart';
import 'package:led_blue/src/ui/device_detail/timer/timer_screen.dart';
import 'package:led_blue/src/ui/device_detail/tone/chat_bubble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ToneScreenTab extends StatelessWidget {
  final DiscoveredDevice device;

  const ToneScreenTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _TimerScreen(
          viewModel: ToneScreenViewModel(
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
class ToneScreenViewModel extends $TimerScreenViewModel {
  const ToneScreenViewModel({
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

  final ToneScreenViewModel viewModel;

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<_TimerScreen> {
  late final RecorderController recorderController;

  String? path;
  String? musicFile;
  bool isRecording = false;
  bool isRecordingCompleted = false;
  bool isLoading = true;
  late Directory appDirectory;

  @override
  void initState() {
    super.initState();
    _getDir();
    _initialiseControllers();
  }

  void _getDir() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory.path}/recording.m4a";
    isLoading = false;
    setState(() {});
  }

  void _initialiseControllers() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      musicFile = result.files.single.path;
      setState(() {});
    } else {
      debugPrint("File not picked");
    }
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
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
                  "Modi auswählen",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : SafeArea(
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                if (isRecordingCompleted)
                                  WaveBubble(
                                    path: path,
                                    isSender: true,
                                    appDirectory: appDirectory,
                                  ),
                                if (musicFile != null)
                                  WaveBubble(
                                    path: musicFile,
                                    isSender: true,
                                    appDirectory: appDirectory,
                                  ),
                                SafeArea(
                                  child: Row(
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: isRecording
                                            ? AudioWaveforms(
                                                enableGesture: true,
                                                size: const Size(
                                                  double.infinity,
                                                  50,
                                                ),
                                                recorderController:
                                                    recorderController,
                                                waveStyle: const WaveStyle(
                                                  waveColor: Colors.white,
                                                  extendWaveform: true,
                                                  showMiddleLine: false,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  color:
                                                      const Color(0xFF1E1B26),
                                                ),
                                                padding: const EdgeInsets.only(
                                                    left: 18),
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 15),
                                              )
                                            : Container(),
                                      ),
                                      IconButton(
                                        onPressed: _pickFile,
                                        icon: Icon(
                                          Icons.adaptive.share,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _refreshWave,
                                        icon: Icon(
                                          isRecording
                                              ? Icons.refresh
                                              : Icons.send,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        onPressed: _startOrStopRecording,
                                        icon: Icon(isRecording
                                            ? Icons.stop
                                            : Icons.mic),
                                        color: Colors.white,
                                        iconSize: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startOrStopRecording() async {
    try {
      if (isRecording) {
        recorderController.reset();

        final path = await recorderController.stop(false);

        if (path != null) {
          isRecordingCompleted = true;
          debugPrint(path);
          debugPrint("Recorded file size: ${File(path).lengthSync()}");
        }
      } else {
        await recorderController.record(path: path!);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        isRecording = !isRecording;
      });
    }
  }

  void _refreshWave() {
    if (isRecording) recorderController.refresh();
  }
}
