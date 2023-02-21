import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ui/device_detail/device_log_tab.dart';
import 'package:led_blue/src/ui/device_detail/mic/mic_screen.dart';
import 'package:led_blue/src/ui/device_detail/modi/modi_screen.dart';
import 'package:led_blue/src/ui/device_detail/timer/timer_screen.dart';
import 'package:led_blue/src/ui/device_detail/tone/tone_screen.dart';
import 'package:led_blue/src/ui/device_list.dart';
import 'package:provider/provider.dart';

import 'device_interaction_tab.dart';

class DeviceDetailTab extends StatelessWidget {
  final DiscoveredDevice device;

  const DeviceDetailTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _DeviceDetail(
          device: device,
          viewModel: DeviceDetailViewModel(
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
class DeviceDetailViewModel extends $TimerScreenViewModel {
  const DeviceDetailViewModel({
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

class _DeviceDetail extends StatefulWidget {
  const _DeviceDetail({
    required this.viewModel,
    required this.device,
    Key? key,
  }) : super(key: key);

  final DeviceDetailViewModel viewModel;
  final DiscoveredDevice device;

  @override
  State<_DeviceDetail> createState() => _DeviceDetailState();
}

class _DeviceDetailState extends State<_DeviceDetail> {
  bool isOn = false;

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          widget.viewModel.disconnect();
          return true;
        },
        child: DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DeviceListScreen()),
                    );
                  },
                ),
              ],
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Container(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: isOn ? Colors.yellow : Colors.white,
                ),
                onPressed: () {
                  try {
                    if (isOn) {
                      ledOff();
                    } else {
                      ledOn();
                    }
                  } catch (e) {
                    isOn = false;
                    ledOn();
                  }
                },
              ),
            ),
            bottomNavigationBar: tabBarNav(),
            body: TabBarView(
              children: [
                DeviceInteractionTab(
                  device: widget.device,
                ),
                ModiScreenTab(device: widget.device),
                ToneScreenTab(device: widget.device),
                MicScreenTab(
                  device: widget.device,
                ),
                TimerScreenTab(device: widget.device),
              ],
            ),
          ),
        ),
      );

  Widget tabBarNav() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TabBar(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        indicatorPadding: EdgeInsets.all(5),
        indicator: BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF2F80ED), Color(0xFF2F80ED)]),
            borderRadius: BorderRadius.circular(20),
            color: Colors.black),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            text: 'FARBE',
          ),
          Tab(
            text: 'MODI',
          ),
          Tab(
            text: 'TÖNE',
          ),
          Tab(
            text: 'MIC',
          ),
          Tab(
            text: 'TIMER',
          ),
        ],
      ),
    );
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
        setState(() {
          isOn = false;
        });
      } else {
        print('led off failed');
        setState(() {
          isOn = true;
        });
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
        setState(() {
          isOn = true;
        });
      } else {
        print('led on failed');
        setState(() {
          isOn = false;
        });
      }
    });
  }
}
