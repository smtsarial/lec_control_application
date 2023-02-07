import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:led_blue/src/ble/ble_scanner.dart';
import 'package:provider/provider.dart';

import '../ble/ble_logger.dart';
import '../widgets.dart';
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
    widget.startScan(text.isEmpty ? [] : [Uuid.parse(_uuidController.text)]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Count: ${widget.scannerState.discoveredDevices.length}'),
        ),
        // floatingActionButton: FloatingActionButton(
        //     child: widget.scannerState.scanIsInProgress
        //         ? const Icon(Icons.pause)
        //         : const Icon(Icons.refresh),
        //     onPressed: () {
        //       !widget.scannerState.scanIsInProgress && _isValidUuidInput()
        //           ? _startScanning
        //           : widget.scannerState.scanIsInProgress
        //               ? widget.stopScan
        //               : null;
        //     }),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const SizedBox(height: 16),
                  // const Text('Service UUID (2, 4, 16 bytes):'),
                  // TextField(
                  //   controller: _uuidController,
                  //   enabled: !widget.scannerState.scanIsInProgress,
                  //   decoration: InputDecoration(
                  //       errorText:
                  //           _uuidController.text.isEmpty || _isValidUuidInput()
                  //               ? null
                  //               : 'Invalid UUID format'),
                  //   autocorrect: false,
                  // ),
                  // const SizedBox(height: 16),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     ElevatedButton(
                  //       child: const Text('Scan'),
                  //       onPressed: !widget.scannerState.scanIsInProgress &&
                  //               _isValidUuidInput()
                  //           ? _startScanning
                  //           : null,
                  //     ),
                  //     ElevatedButton(
                  //       child: const Text('Stop'),
                  //       onPressed: widget.scannerState.scanIsInProgress
                  //           ? widget.stopScan
                  //           : null,
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
            Center(
              child: Text(
                'Geräte in der nähe',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            Flexible(
              child: ListView(
                children: [
                  ...widget.scannerState.discoveredDevices
                      .map(
                        (device) => Container(
                          margin: EdgeInsets.symmetric(horizontal: 32),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Colors.grey)),
                          ),
                          child: ListTile(
                            title: Text(device.name),
                            subtitle:
                                Text("${device.id}\nRSSI: ${device.rssi}"),
                            onTap: () async {
                              widget.stopScan();
                              await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          DeviceDetailScreen(device: device)));
                            },
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      );
}
