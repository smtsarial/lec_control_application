import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ble/ble_scanner.dart';
import 'package:led_blue/src/ble/ble_status_monitor.dart';
import 'package:led_blue/src/ui/ble_status_screen.dart';
import 'package:led_blue/src/ui/device_list.dart';
import 'package:provider/provider.dart';

import 'src/ble/ble_logger.dart';

const _themeColor = Color.fromARGB(255, 16, 17, 18);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final _ble = FlutterReactiveBle();
  final _bleLogger = BleLogger(ble: _ble);
  final _scanner = BleScanner(ble: _ble, logMessage: _bleLogger.addToLog);
  final _monitor = BleStatusMonitor(_ble);
  final _connector = BleDeviceConnector(
    ble: _ble,
    logMessage: _bleLogger.addToLog,
  );
  final _serviceDiscoverer = BleDeviceInteractor(
    bleDiscoverServices: _ble.discoverServices,
    readCharacteristic: _ble.readCharacteristic,
    writeWithResponse: _ble.writeCharacteristicWithResponse,
    writeWithOutResponse: _ble.writeCharacteristicWithoutResponse,
    subscribeToCharacteristic: _ble.subscribeToCharacteristic,
    logMessage: _bleLogger.addToLog,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: _scanner),
        Provider.value(value: _monitor),
        Provider.value(value: _connector),
        Provider.value(value: _serviceDiscoverer),
        Provider.value(value: _bleLogger),
        StreamProvider<BleScannerState?>(
          create: (_) => _scanner.state,
          initialData: const BleScannerState(
            discoveredDevices: [],
            scanIsInProgress: false,
          ),
        ),
        StreamProvider<BleStatus?>(
          create: (_) => _monitor.state,
          initialData: BleStatus.unknown,
        ),
        StreamProvider<ConnectionStateUpdate>(
          create: (_) => _connector.state,
          initialData: const ConnectionStateUpdate(
            deviceId: 'Unknown device',
            connectionState: DeviceConnectionState.disconnected,
            failure: null,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Reactive BLE example',
        color: _themeColor,
        theme: ThemeData(
            fontFamily: 'Roboto',
            primaryTextTheme:
                Typography(platform: TargetPlatform.android).white,
            textTheme: Typography(platform: TargetPlatform.android).white,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: _themeColor),
        home: Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/images/main_bg.png"),
                fit: BoxFit.cover),
          ),
          child: const DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'Roboto', fontWeight: FontWeight.w900),
            child: const HomeScreen(),
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Consumer<BleStatus?>(
        builder: (_, status, __) {
          if (status == BleStatus.ready) {
            return const DeviceListScreen();
          } else {
            return BleStatusScreen(status: status ?? BleStatus.unknown);
          }
        },
      );
}
