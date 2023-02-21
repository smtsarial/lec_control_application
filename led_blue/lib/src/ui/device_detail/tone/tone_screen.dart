import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ui/device_detail/timer/timer_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

//add enum PlayerState
enum PlayerState { stop, play, pause, loop }

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
  String? path;
  List<String> musicFile = [];
  List<Map> musicFileInfo = [];
  Map selectedMusicFileInfo = {};
  bool isRecording = false;
  bool isRecordingCompleted = false;
  bool isLoading = true;
  Directory appDirectory = Directory('');
  File? file;
  List<double> _waveExtractedData = [];
  bool _isAudioLoading = false;
  bool _isAudioPlaying = false;
  bool _isAudioPaused = false;
  bool _isAudioStopped = false;
  bool _isAudioCompleted = false;
  String _currentDuration = '00:00';

  PlayerController controller = PlayerController();

  final playerWaveStyle = const PlayerWaveStyle(
      fixedWaveColor: Colors.blueAccent,
      liveWaveColor: Colors.white,
      spacing: 15,
      waveThickness: 8);

  @override
  void initState() {
    super.initState();
    _getDir();
    controller = PlayerController();
    controller.onPlayerStateChanged.listen((state) {
      print('state: $state');
    });
    controller.onCurrentDurationChanged.listen((duration) {
      //change duration milliseconds to seconds

      print('duration: ${duration.toMMSS()}');
      setState(() {
        _currentDuration = duration.toMMSS();
      });
    });
    controller.onCurrentExtractedWaveformData.listen((data) {
      print('samet======' + data.length.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate.fixed(
            [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 20),
                  Text(
                    "Tone",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _pickFile,
                    icon: Icon(
                      Icons.adaptive.share,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SafeArea(
                child: Column(
                  children: [
                    // Text(selectedMusicFileInfo['file'].toString()),
                    // Text('**********'),
                    // Text(appDirectory.path.toString()),
                    // Text('**********'),
                    // Text(selectedMusicFileInfo['file'].toString()),

                    selectedMusicFileInfo != {} &&
                            selectedMusicFileInfo['file'] != null
                        ? Column(
                            children: [
                              Text(
                                '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_currentDuration),
                                    Text(controller.maxDuration.toString()),
                                  ],
                                ),
                              ),
                              audioWave(
                                selectedMusicFileInfo['file'].path.toString(),
                              )
                            ],
                          )
                        : Container(),
                    const SizedBox(height: 20),
                    if (musicFile.isNotEmpty)
                      for (var i = 0; i < musicFile.length; i++)
                        GestureDetector(
                          onTap: () async {
                            if (controller.playerState.isPlaying ||
                                controller.playerState.isPaused) {
                              await controller.stopPlayer();
                            }
                            setState(() {
                              musicFileInfo.forEach((element) {
                                element['selected'] = false;
                              });
                              musicFileInfo[i]['selected'] = true;

                              selectedMusicFileInfo = {};

                              selectedMusicFileInfo = musicFileInfo[i];
                              //update all widget with new selected musicFileInfo
                            });
                            //wait 3 seconds to play music
                            _preparePlayer(
                                appDirectory, selectedMusicFileInfo['file']);
                            print('degistii' +
                                selectedMusicFileInfo['file'].toString());
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      width: 2, color: Colors.white)),
                              color: musicFileInfo[i]['selected']
                                  ? const Color(0xFF343145)
                                  : Colors.transparent,
                            ),
                            child: ListTile(
                                title: Text(musicFileInfo[i]['file']
                                        .name
                                        .substring(0, 20) +
                                    '...'),
                                subtitle: Text(musicFileInfo[i]['file'].name),
                                trailing: Text(
                                    musicFileInfo[i]['file'].size.toString())),
                          ),
                        )
                    else
                      Center(
                          child: Text('No file selected. Please select one.',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20)))
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget audioWave(String path) {
    return _isAudioLoading
        ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          )
        : Container(
            padding: EdgeInsets.only(
              bottom: 6,
              right: 10,
              top: 6,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.transparent,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AudioFileWaveforms(
                      size: Size(MediaQuery.of(context).size.width - 85, 100),
                      playerController: controller,
                      enableSeekGesture: true,
                      waveformType: WaveformType.long,
                      waveformData: _waveExtractedData,
                      playerWaveStyle: playerWaveStyle,
                    ),
                  ],
                ),
                if (!controller.playerState.isStopped)
                  IconButton(
                    onPressed: () async {
                      _isAudioPlaying
                          ? changeControllerState(PlayerState.pause)
                          : changeControllerState(PlayerState.play);
                    },
                    icon: Icon(
                      _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
              ],
            ),
          );
  }

  void changeControllerState(PlayerState state) {
    switch (state) {
      case PlayerState.stop:
        _isAudioStopped = true;
        _isAudioPaused = false;
        _isAudioPlaying = false;
        _isAudioCompleted = false;
        controller.stopPlayer();
        break;
      case PlayerState.pause:
        _isAudioStopped = false;
        _isAudioPaused = true;
        _isAudioPlaying = false;
        _isAudioCompleted = false;
        controller.pausePlayer();
        break;
      case PlayerState.play:
        _isAudioStopped = false;
        _isAudioPaused = false;
        _isAudioPlaying = true;
        _isAudioCompleted = false;
        controller.startPlayer();
        break;
      default:
        _isAudioStopped = false;
        _isAudioPaused = false;
        _isAudioPlaying = false;
        _isAudioCompleted = false;
        break;
    }
    setState(() {});
  }

  void _getDir() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory.path}/recording.m4a";
    isLoading = false;
    setState(() {});
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'mp4']);
    if (result != null) {
      musicFile.add(result.files.single.path.toString());
      musicFileInfo.add({'file': result.files.single, 'selected': false});
      setState(() {});
    } else {
      debugPrint("File not picked");
    }
  }

  void _preparePlayer(Directory appDirectory, PlatformFile file) async {
    try {
      setState(() {
        _isAudioLoading = true;
      });
      print(appDirectory.uri);
      print('dataaaaaaa' + file.path.toString());
      await controller.preparePlayer(
        path: file.path.toString(),
        shouldExtractWaveform: true,
      );
      print('object');
      await controller
          .extractWaveformData(
        path: file.path.toString(),
        noOfSamples: playerWaveStyle.getSamplesForWidth(200),
      )
          .then((waveformData) {
        print('idk**//**/**//**//*/*/*/*' + waveformData.toString());
        setState(() {
          _isAudioLoading = false;
        });

        setState(() {
          _waveExtractedData.addAll(waveformData);
        });
      });
    } catch (e) {
      print(e);
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  @override
  void dispose() {
    controller.stopAllPlayers();
    controller.dispose();
    super.dispose();
    super.dispose();
  }
}
