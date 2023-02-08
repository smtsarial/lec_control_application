import 'dart:ffi';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/ui/device_detail/characteristic_interaction_dialog.dart';
import 'package:led_blue/src/ui/device_detail/device_interaction_tab.dart';
import 'package:provider/provider.dart';

part 'timer_screen.g.dart';
//ignore_for_file: annotate_overrides

class TimerScreenTab extends StatelessWidget {
  final DiscoveredDevice device;

  const TimerScreenTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _TimerScreen(
          viewModel: TimerScreenViewModel(
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
class TimerScreenViewModel extends $TimerScreenViewModel {
  const TimerScreenViewModel({
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

  final TimerScreenViewModel viewModel;

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<_TimerScreen> {
  List<DiscoveredService> discoveredServices = [];
  bool isOn = false;
  double _brightness = 0.0;
  String openTimeDay = 'MO';
  String closeTimeDay = 'MO';

  String openTime = '00:00';
  String closeTime = '00:00';
  bool openRunning = false;
  bool closeRunning = false;

  @override
  void initState() {
    try {
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

  //add type
  List<Map<String, dynamic>> days = [
    {'day': 'MO', 'openSelected': true, 'closeSelected': true, 'value': 129},
    {'day': 'DI', 'openSelected': false, 'closeSelected': false, 'value': 2},
    {'day': 'MI', 'openSelected': false, 'closeSelected': false, 'value': 4},
    {'day': 'DO', 'openSelected': false, 'closeSelected': false, 'value': 8},
    {'day': 'FR', 'openSelected': false, 'closeSelected': false, 'value': 16},
    {'day': 'SA', 'openSelected': false, 'closeSelected': false, 'value': 32},
    {'day': 'SO', 'openSelected': false, 'closeSelected': false, 'value': 64},
  ];

  Future<bool> writeToDevice(List<int> deviceCode) async {
    print('CHANGE STARTED');
    try {
      List<DiscoveredService> data = await discoverServices();
      if (discoveredServices.length > 0 && discoveredServices != null) {
        for (var i = 0; i < discoveredServices.length; i++) {
          for (var j = 0;
              j < discoveredServices[i].characteristics.length;
              j++) {
            //check uuid of characteristic and write value
            DiscoveredCharacteristic characteristic =
                discoveredServices[i].characteristics[j];
            if (characteristic.characteristicId.toString().contains('fff3')) {
              print(characteristic.characteristicId.toString());
              //write value to characteristic with id
              QualifiedCharacteristic data = QualifiedCharacteristic(
                  serviceId: discoveredServices[i].serviceId,
                  characteristicId: characteristic.characteristicId,
                  deviceId: widget.viewModel.deviceId);
              try {
                await widget.viewModel.service
                    .writeCharacterisiticWithoutResponse(data, deviceCode);
                setState(() {
                  isOn = false;
                });
                return true;
              } catch (e) {
                return false;
              }
            }
          }
        }
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
  }

  int returnDayValues(day) {
    switch (day) {
      case 'MO':
        return 129;
      case 'DI':
        return 2;
      case 'MI':
        return 4;
      case 'DO':
        return 8;
      case 'FR':
        return 16;
      case 'SA':
        return 32;
      case 'SO':
        return 64;
      default:
        return 0;
    }
  }

  calculateOutputForPlan(plan) async {
    var total = 0;
    if (plan == 'open') {
      for (var i = 0; i < days.length; i++) {
        if (days[i]['openSelected'] == true) {
          total = total.toInt() + returnDayValues(days[i]['day']);
        }
      }

      if (total > 0) {
        var time = openTime.split(':');
        var hour = int.parse(time[0]);
        var minute = int.parse(time[1]);
        if (widget.viewModel.connectionStatus ==
                DeviceConnectionState.connected ||
            widget.viewModel.connectionStatus ==
                DeviceConnectionState.connecting) {
          await writeToDevice([
            126,
            8,
            82,
            hour,
            minute,
            0,
            0,
            total,
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
          return 0;
        }
      } else {
        return 0;
      }
    } else {
      for (var i = 0; i < days.length; i++) {
        if (days[i]['closeSelected'] == true) {
          total = total.toInt() + returnDayValues(days[i]['day']);
        }
      }
      if (total > 0) {
        var time = closeTime.split(':');
        var hour = int.parse(time[0]);
        var minute = int.parse(time[1]);
        await writeToDevice([
          126,
          8,
          82,
          hour,
          minute,
          0,
          0,
          total,
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
        return 0;
      }
    }
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
                  "Timer",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xffF3F3F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.punch_clock),
                          SizedBox(width: 10),
                          Text(
                            "Automatisch anschalten",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      CupertinoSwitch(
                        value: openRunning,
                        onChanged: (value) {
                          setState(() {
                            openRunning = value;
                          });
                          if (openRunning) {
                            calculateOutputForPlan('open');
                          }
                        },
                      ),
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        //listview builder for colors in favColors list
                        for (var i = 0; i < days.length; i++)
                          GestureDetector(
                            onTap: () {
                              if (!openRunning) {
                                if (days[i]['openSelected']) {
                                  setState(() {
                                    days[i]['openSelected'] = false;
                                  });
                                } else {
                                  setState(() {
                                    days[i]['openSelected'] = true;
                                  });
                                }
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                color: days[i]['openSelected']
                                    ? Colors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              width: 35.0,
                              height: 35.0,
                              child: Center(
                                  child: new Text(days[i]['day'],
                                      style: TextStyle(
                                          color: days[i]['openSelected']
                                              ? Colors.white
                                              : Colors.black))),
                            ),
                          )
                      ]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Uhrzeit",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!openRunning) {
                            showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            ).then((value) {
                              setState(() {
                                openTime = value!.hour.toString() +
                                    ":" +
                                    value.minute.toString();
                              });
                            });
                          }
                        },
                        child: Text(
                          openTime,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
              Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xffF3F3F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.punch_clock),
                          SizedBox(width: 10),
                          Text(
                            "Automatisch ausschalten",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      CupertinoSwitch(
                        value: closeRunning,
                        onChanged: (value) {
                          setState(() {
                            closeRunning = value;
                          });
                          if (closeRunning) {
                            calculateOutputForPlan('close');
                          }
                        },
                      ),
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        //listview builder for colors in favColors list
                        for (var i = 0; i < days.length; i++)
                          GestureDetector(
                            onTap: () {
                              if (!closeRunning) {
                                if (days[i]['closeSelected']) {
                                  setState(() {
                                    days[i]['closeSelected'] = false;
                                  });
                                } else {
                                  setState(() {
                                    days[i]['closeSelected'] = true;
                                  });
                                }
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                color: days[i]['closeSelected']
                                    ? Colors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              width: 35.0,
                              height: 35.0,
                              child: Center(
                                  child: new Text(days[i]['day'],
                                      style: TextStyle(
                                          color: days[i]['closeSelected']
                                              ? Colors.white
                                              : Colors.black))),
                            ),
                          )
                      ]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Uhrzeit",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!closeRunning) {
                            showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            ).then((value) {
                              print(value);
                              setState(() {
                                closeTime = value!.hour.toString() +
                                    ":" +
                                    value.minute.toString();
                              });
                            });
                          }
                        },
                        child: Text(
                          closeTime,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
