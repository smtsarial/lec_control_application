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

class ModiScreenTab extends StatelessWidget {
  final DiscoveredDevice device;

  const ModiScreenTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _TimerScreen(
          viewModel: ModiScreenViewModel(
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
class ModiScreenViewModel extends $TimerScreenViewModel {
  const ModiScreenViewModel({
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

  final ModiScreenViewModel viewModel;

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

      getSelectedCategoryItems();
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

  List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'Badge', 'selected': false, 'value': 10},
    {'id': 2, 'name': 'Basic', 'selected': true, 'value': 20},
    {'id': 3, 'name': 'Curtain', 'selected': false, 'value': 30},
    {'id': 4, 'name': 'Trans', 'selected': false, 'value': 40},
    {'id': 5, 'name': 'Water', 'selected': false, 'value': 50},
    {'id': 6, 'name': 'Ba', 'selected': false, 'value': 60},
  ];

  Future<void> runDeviceCode() async {
    //find first selected modiList item
    int modiIndex =
        categories.indexWhere((element) => element['selected'] == true);
  }

  void changeCategoryOnDevice(Map<String, dynamic> categoryItem) {
    print(categoryItem);
    widget.viewModel.service.writeDataToFF3Services(widget.viewModel.deviceId, [
      126,
      5,
      3,
      categoryItem['value'].toInt(),
      6,
      255,
      255,
      0,
      239,
      33,
      33,
      33,
      33,
      33,
      33,
      33
    ]).then((value) {
      if (value) {
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Error Occured! Modifying Modi'),
            action: SnackBarAction(
              label: 'Ok',
              onPressed: () {
                //close snackbar
              },
            )));
      }
    });
  }

  Future<void> setModiSpeed() async {
    widget.viewModel.service.writeDataToFF3Services(widget.viewModel.deviceId, [
      126,
      4,
      2,
      _speed.toInt(),
      255,
      255,
      255,
      0,
      239,
      33,
      33,
      33,
      33,
      33,
      33,
      33
    ]).then((value) {
      if (value) {
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Error Occured !'),
            action: SnackBarAction(
              label: 'Ok',
              onPressed: () {
                //close snackbar
              },
            )));
      }
    });
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
                  for (var i = 0; i < categories.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          //set all selected false
                          for (var i = 0; i < categories.length; i++) {
                            categories[i]['selected'] = false;
                          }
                          categories[i]['selected'] = true;
                          getSelectedCategoryItems();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        margin:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xffD1D5DB)),
                          color: categories[i]['selected']
                              ? Color(0xff2F80ED)
                              : Color(0xff374151),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Text(
                            categories[i]['name'],
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
              Container(
                height: 300,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  scrollDirection: Axis.vertical,
                  child: Column(children: [
                    //listview builder for colors in favColors list
                    for (var i = 0; i < categoryItems.length; i++)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            //set all selected false
                            for (var i = 0; i < categoryItems.length; i++) {
                              categoryItems[i]['selected'] = false;
                            }
                            categoryItems[i]['selected'] = true;
                            changeCategoryOnDevice(categoryItems[i]);
                          });
                        },
                        child: Container(
                          child: Center(
                            child: Text(
                              categoryItems[i]['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    categoryItems[i]['selected'] ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 5),
                          margin:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: categoryItems[i]['selected']
                                ? Color(0xff2F80ED)
                                : Color(0xff3C3E43),
                          ),
                          width: categoryItems[i]['selected']
                              ? double.infinity
                              : 300,
                          height: 40,
                        ),
                      )
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isOn ? "An" : "Aus",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          CupertinoSwitch(
                            value: isOn,
                            onChanged: (value) {
                              setState(() {
                                isOn = value;
                                if (isOn) {
                                  ledOn();
                                } else {
                                  ledOff();
                                }
                              });
                            },
                          ),
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
                                max: 64,
                                inactiveColor: Colors.white,
                                value: _speed,
                                onChanged: (value) {
                                  setState(() {
                                    _speed = value;
                                  });
                                  setModiSpeed();
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

  List<Map<String, dynamic>> modiselection = [
    {
      'color': Color(0xffEB5757),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 1,
    },
    {
      'color': Color(0xffF2994A),
      'selected': true,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 2,
    },
    {
      'color': Color(0xffF2C94C),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 2,
    },
    {
      'color': Color(0xff219653),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 6,
    },
    {
      'color': Color(0xff6FCF97),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 5,
    },
    {
      'color': Color(0xffBB6BD9),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 4,
    },
    {
      'color': Color(0xff6FCF97),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 3,
    },
    {
      'color': Color(0xffed1c24),
      'selected': false,
      'value': 1,
      'name': 'Magic Back',
      'categoryId': 2,
    },
  ];
  List<Map<String, dynamic>> categoryItems = [];

  void getSelectedCategoryItems() {
    List<Map<String, dynamic>> categoryItem = [];
    //get first selected item
    var selectedItem =
        categories.firstWhere((element) => element['selected'] == true);
    print(selectedItem);
    //get all items of selected category
    categoryItem = modiselection
        .where((element) => element['categoryId'] == selectedItem['id'])
        .toList();
    print(modiselection);
    setState(() {
      categoryItems = categoryItem;
    });
  }
}
