import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ui/device_detail/device_log_tab.dart';
import 'package:led_blue/src/ui/device_detail/timer/timer_screen.dart';
import 'package:provider/provider.dart';

import 'device_interaction_tab.dart';

class DeviceDetailScreen extends StatelessWidget {
  final DiscoveredDevice device;

  const DeviceDetailScreen({required this.device, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Consumer<BleDeviceConnector>(
        builder: (_, deviceConnector, __) => _DeviceDetail(
          device: device,
          disconnect: deviceConnector.disconnect,
        ),
      );
}

class _DeviceDetail extends StatelessWidget {
  const _DeviceDetail({
    required this.device,
    required this.disconnect,
    Key? key,
  }) : super(key: key);

  final DiscoveredDevice device;
  final void Function(String deviceId) disconnect;
  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          disconnect(device.id);
          return true;
        },
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              actions: [],
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(device.name),
            ),
            bottomNavigationBar: tabBarNav(),
            body: TabBarView(
              children: [
                DeviceInteractionTab(
                  device: device,
                ),
                const DeviceLogTab(),
                TimerScreenTab(device: device)
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
}
