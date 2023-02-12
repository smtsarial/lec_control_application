import 'dart:ffi';
import 'dart:io';

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

  final ToneScreenViewModel viewModel;

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<_TimerScreen> {
  List<DiscoveredService> discoveredServices = [];
  bool isOn = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _fileName;
  String? _saveAsFileName;
  List<PlatformFile>? _paths;
  String? _directoryPath;
  String? _extension;
  bool _isLoading = false;
  bool _userAborted = false;
  bool _multiPick = false;
  FileType _pickingType = FileType.any;
  TextEditingController _controller = TextEditingController();

  void _pickFiles() async {
    _resetState();
    try {
      _directoryPath = null;
      _paths = (await FilePicker.platform.pickFiles(
        type: _pickingType,
        allowMultiple: _multiPick,
        onFileLoading: (FilePickerStatus status) => print(status),
        allowedExtensions: (_extension?.isNotEmpty ?? false)
            ? _extension?.replaceAll(' ', '').split(',')
            : null,
      ))
          ?.files;
    } on PlatformException catch (e) {
      _logException('Unsupported operation' + e.toString());
    } catch (e) {
      _logException(e.toString());
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _fileName =
          _paths != null ? _paths!.map((e) => e.name).toString() : '...';
      _userAborted = _paths == null;
    });
  }

  void _clearCachedFiles() async {
    _resetState();
    try {
      bool? result = await FilePicker.platform.clearTemporaryFiles();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: result! ? Colors.green : Colors.red,
          content: Text((result
              ? 'Temporary files removed with success.'
              : 'Failed to clean temporary files')),
        ),
      );
    } on PlatformException catch (e) {
      _logException('Unsupported operation' + e.toString());
    } catch (e) {
      _logException(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectFolder() async {
    _resetState();
    try {
      String? path = await FilePicker.platform.getDirectoryPath();
      setState(() {
        _directoryPath = path;
        _userAborted = path == null;
      });
    } on PlatformException catch (e) {
      _logException('Unsupported operation' + e.toString());
    } catch (e) {
      _logException(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFile() async {
    _resetState();
    try {
      String? fileName = await FilePicker.platform.saveFile(
        allowedExtensions: (_extension?.isNotEmpty ?? false)
            ? _extension?.replaceAll(' ', '').split(',')
            : null,
        type: _pickingType,
      );
      setState(() {
        _saveAsFileName = fileName;
        _userAborted = fileName == null;
      });
    } on PlatformException catch (e) {
      _logException('Unsupported operation' + e.toString());
    } catch (e) {
      _logException(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logException(String message) {
    print(message);
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _resetState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _directoryPath = null;
      _fileName = null;
      _paths = null;
      _saveAsFileName = null;
      _userAborted = false;
    });
  }

  @override
  void initState() {
    try {
      _controller.addListener(() => _extension = _controller.text);
      initilize();
    } catch (e) {
      print(e);
    }

    super.initState();
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

  Color pickerColor = Color(0xff219653);
  Color currentColor = Color(0xff219653);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate.fixed(
            [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: DropdownButton<FileType>(
                              hint: const Text('LOAD PATH FROM'),
                              value: _pickingType,
                              items: FileType.values
                                  .map((fileType) => DropdownMenuItem<FileType>(
                                        child: Text(fileType.toString()),
                                        value: fileType,
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() {
                                    _pickingType = value!;
                                    if (_pickingType != FileType.custom) {
                                      _controller.text = _extension = '';
                                    }
                                  })),
                        ),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints.tightFor(width: 100.0),
                          child: _pickingType == FileType.custom
                              ? TextFormField(
                                  maxLength: 15,
                                  autovalidateMode: AutovalidateMode.always,
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    labelText: 'File extension',
                                  ),
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.none,
                                )
                              : const SizedBox(),
                        ),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints.tightFor(width: 200.0),
                          child: SwitchListTile.adaptive(
                            title: Text(
                              'Pick multiple files',
                              textAlign: TextAlign.right,
                            ),
                            onChanged: (bool value) =>
                                setState(() => _multiPick = value),
                            value: _multiPick,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 50.0, bottom: 20.0),
                          child: Column(
                            children: <Widget>[
                              ElevatedButton(
                                onPressed: () => _pickFiles(),
                                child: Text(
                                    _multiPick ? 'Pick files' : 'Pick file'),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _selectFolder(),
                                child: const Text('Pick folder'),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _saveFile(),
                                child: const Text('Save file'),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _clearCachedFiles(),
                                child: const Text('Clear temporary files'),
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (BuildContext context) => _isLoading
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: const CircularProgressIndicator(),
                                )
                              : _userAborted
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10.0),
                                      child: const Text(
                                        'User has aborted the dialog',
                                      ),
                                    )
                                  : _directoryPath != null
                                      ? ListTile(
                                          title: const Text('Directory path'),
                                          subtitle: Text(_directoryPath!),
                                        )
                                      : _paths != null
                                          ? Container(
                                              padding: const EdgeInsets.only(
                                                  bottom: 30.0),
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.50,
                                              child: Scrollbar(
                                                  child: ListView.separated(
                                                itemCount: _paths != null &&
                                                        _paths!.isNotEmpty
                                                    ? _paths!.length
                                                    : 1,
                                                itemBuilder:
                                                    (BuildContext context,
                                                        int index) {
                                                  final bool isMultiPath =
                                                      _paths != null &&
                                                          _paths!.isNotEmpty;
                                                  final String name =
                                                      'File $index: ' +
                                                          (isMultiPath
                                                              ? _paths!
                                                                      .map((e) =>
                                                                          e.name)
                                                                      .toList()[
                                                                  index]
                                                              : _fileName ??
                                                                  '...');
                                                  final path = kIsWeb
                                                      ? null
                                                      : _paths!
                                                          .map((e) => e.path)
                                                          .toList()[index]
                                                          .toString();

                                                  return ListTile(
                                                    title: Text(
                                                      name,
                                                    ),
                                                    subtitle: Text(path ?? ''),
                                                  );
                                                },
                                                separatorBuilder:
                                                    (BuildContext context,
                                                            int index) =>
                                                        const Divider(),
                                              )),
                                            )
                                          : _saveAsFileName != null
                                              ? ListTile(
                                                  title:
                                                      const Text('Save file'),
                                                  subtitle:
                                                      Text(_saveAsFileName!),
                                                )
                                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
