import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helpers/widget/widgets.dart';

class BleStatusScreen extends StatelessWidget {
  const BleStatusScreen({required this.status, Key? key}) : super(key: key);

  final BleStatus status;

  String determineText(BleStatus status) {
    switch (status) {
      case BleStatus.unsupported:
        return "This device does not support Bluetooth";
      case BleStatus.unauthorized:
        return "Authorize to use Bluetooth and location";
      case BleStatus.poweredOff:
        return "Bluetooth is powered off on your device turn it on";
      case BleStatus.locationServicesDisabled:
        return "Enable location services";
      case BleStatus.ready:
        return "Bluetooth is up and running";
      default:
        return "Waiting to fetch Bluetooth status $status";
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(determineText(status)),
              //button to get permission to use location and bluetooth
              status == BleStatus.unauthorized
                  ? ElevatedButton(
                      onPressed: () => requestLocationServicesAuthorization(),
                      child: const Text("Authorize"),
                    )
                  : const SizedBox.shrink(),
              status == BleStatus.unauthorized
                  ? Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: Text(
                          'If app settings do not open, please open manually'))
                  : const SizedBox.shrink(),
              status == BleStatus.unauthorized
                  ? ElevatedButton(
                      onPressed: () => openAppSettings(),
                      child: const Text("Open Authorization Settings"),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      );

  requestLocationServicesAuthorization() async {
    var status = await Permission.bluetooth.status;
    var locationStatus = await Permission.location.status;
    var blueAdvertise = await Permission.bluetoothAdvertise.status;
    var blueConnect = await Permission.bluetoothConnect.status;

    if (status.isDenied ||
        locationStatus.isDenied ||
        blueAdvertise.isDenied ||
        blueConnect.isDenied) {
      try {
        requestPermission(Permission.bluetooth);
        requestPermission(Permission.bluetoothAdvertise);
        requestPermission(Permission.bluetoothConnect);
        requestPermission(Permission.location);
      } catch (e) {
        openAppSettings();
      }
    } else {
      openAppSettings();
    }

    if (await Permission.bluetooth.status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> requestPermission(Permission permission) async {
    final status = await permission.request();
  }
}
