import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:led_blue/src/ble/ble_scanner.dart';
import 'package:led_blue/src/helpers/widget/drawer_widget.dart';
import 'package:provider/provider.dart';

import '../ble/ble_logger.dart';
import '../helpers/widget/widgets.dart';
import 'device_detail/device_detail_screen.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleScanner, BleScannerState?, BleLogger>(
        builder: (_, bleScanner, bleScannerState, bleLogger, __) => _DeviceList(
          scannerState: bleScannerState ??
              const BleScannerState(
                discoveredDevices: [],
                scanIsInProgress: false,
              ),
          startScan: bleScanner.startScan,
          stopScan: bleScanner.stopScan,
          toggleVerboseLogging: bleLogger.toggleVerboseLogging,
          verboseLogging: bleLogger.verboseLogging,
        ),
      );
}

class _DeviceList extends StatefulWidget {
  const _DeviceList({
    required this.scannerState,
    required this.startScan,
    required this.stopScan,
    required this.toggleVerboseLogging,
    required this.verboseLogging,
  });

  final BleScannerState scannerState;
  final void Function(List<Uuid>) startScan;
  final VoidCallback stopScan;
  final VoidCallback toggleVerboseLogging;
  final bool verboseLogging;

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<_DeviceList> {
  late TextEditingController _uuidController;
  bool _isScanInProgress = false;

  @override
  void initState() {
    super.initState();
    _uuidController = TextEditingController()
      ..addListener(() => setState(() {}));
    _startScanning();
  }

  @override
  void dispose() {
    widget.stopScan();
    _uuidController.dispose();
    super.dispose();
  }

  bool _isValidUuidInput() {
    final uuidText = _uuidController.text;
    if (uuidText.isEmpty) {
      return true;
    } else {
      try {
        Uuid.parse(uuidText);
        return true;
      } on Exception {
        return false;
      }
    }
  }

  void _startScanning() {
    setState(() => _isScanInProgress = true);
    final text = _uuidController.text;
    //scan 5 seconds than stop

    widget.startScan(text.isEmpty ? [] : [Uuid.parse(_uuidController.text)]);
    Future.delayed(Duration(seconds: 5), () {
      widget.stopScan();
      setState(() => _isScanInProgress = false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
              'Geräte in der nähe | Count: ${widget.scannerState.discoveredDevices.length}'),
        ),
        drawer: DrawerWidget(stopScan: widget.stopScan),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              Flexible(
                child: ListView(
                  children: [
                    ...widget.scannerState.discoveredDevices
                        .map(
                          (device) => Container(
                            margin: EdgeInsets.symmetric(horizontal: 20),
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey)),
                            ),
                            child: ListTile(
                              title: Text(device.name),
                              trailing: Icon(
                                Icons.flash_on_outlined,
                                color: Colors.white,
                              ),
                              subtitle:
                                  Text("${device.id}\nRSSI: ${device.rssi}"),
                              onTap: () async {
                                widget.stopScan();
                                await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            DeviceDetailTab(device: device)));
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
              // put refresh button here to refresh the list
              // if you want to scan again
              _isScanInProgress
                  ? Container()
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: GestureDetector(
                        onTap: !widget.scannerState.scanIsInProgress &&
                                _isValidUuidInput()
                            ? _startScanning
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Geräte suchen',
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.refresh,
                              size: 20,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    )
            ],
          ),
        ),
      );
}
