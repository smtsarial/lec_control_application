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
  double _speed = 0.0;
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
  List<Map<String, dynamic>> modiselection = [
    {
      'color': Color(0xffEB5757),
      'selected': false,
    },
    {
      'color': Color(0xffF2994A),
      'selected': true,
    },
    {
      'color': Color(0xffF2C94C),
      'selected': false,
    },
    {
      'color': Color(0xff219653),
      'selected': false,
    },
    {
      'color': Color(0xff6FCF97),
      'selected': false,
    },
    {
      'color': Color(0xffBB6BD9),
      'selected': false,
    },
    {
      'color': Color(0xff6FCF97),
      'selected': false,
    },
    {
      'color': Color(0xffed1c24),
      'selected': false,
    },
  ];
  List<Map<String, dynamic>> modiList = [
    {'name': 'Badge', 'selected': false},
    {'name': 'Basic', 'selected': false},
    {'name': 'Curtain', 'selected': false},
    {'name': 'Trans', 'selected': false},
    {'name': 'Water', 'selected': false},
    {'name': 'Ba', 'selected': false},
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
                child: Row(children: [
                  //listview builder for colors in favColors list
                  for (var i = 0; i < modiList.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          //set all selected false
                          for (var i = 0; i < modiList.length; i++) {
                            modiList[i]['selected'] = false;
                          }
                          modiList[i]['selected'] = true;
                          // changeColor(favColors[i]['color']);
                          // for (var j = 0; j < favColors.length; j++) {
                          //   if (j != i) {
                          //     favColors[j]['selected'] = false;
                          //   }
                          // }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        margin:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xffD1D5DB)),
                          color: modiList[i]['selected']
                              ? Color(0xff2F80ED)
                              : Color(0xff374151),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Text(
                            modiList[i]['name'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xffD1D5DB),
                            ),
                          ),
                        ),
                      ),
                    )
                ]),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 30),
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  //listview builder for colors in favColors list
                  for (var i = 0; i < modiselection.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          //set all selected false
                          for (var i = 0; i < modiselection.length; i++) {
                            modiselection[i]['selected'] = false;
                          }
                          modiselection[i]['selected'] = true;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          color: modiselection[i]['selected']
                              ? Color(0xff2F80ED)
                              : Color(0xff3C3E43),
                        ),
                        width: 90,
                        height: modiselection[i]['selected'] ? 200 : 150,
                      ),
                    )
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Divider(
                      height: 2,
                      thickness: 0.5,
                      indent: 10,
                      endIndent: 10,
                      color: Colors.white,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Geschwindigkeit',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Text(
                                '%' + _speed.toInt().toString(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white30),
                              ),
                              Slider(
                                min: 0,
                                max: 100,
                                inactiveColor: Colors.white,
                                value: _speed,
                                onChanged: (value) {
                                  setState(() {
                                    _speed = value;
                                  });
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Divider(
                      height: 2,
                      thickness: 0.5,
                      indent: 10,
                      endIndent: 10,
                      color: Colors.white,
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
}
