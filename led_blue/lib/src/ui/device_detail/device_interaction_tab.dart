import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:functional_data/functional_data.dart';
import 'package:led_blue/src/ble/ble_device_connector.dart';
import 'package:led_blue/src/ble/ble_device_interactor.dart';
import 'package:led_blue/src/helpers/HexColor.dart';
import 'package:led_blue/src/helpers/widget/SizeConfig.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'characteristic_interaction_dialog.dart';

part 'device_interaction_tab.g.dart';
//ignore_for_file: annotate_overrides

class DeviceInteractionTab extends StatelessWidget {
  final DiscoveredDevice device;

  const DeviceInteractionTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (context, deviceConnector, connectionStateUpdate,
                serviceDiscoverer, __) =>
            _DeviceInteractionTab(
          viewModel: DeviceInteractionViewModel(
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
class DeviceInteractionViewModel extends $DeviceInteractionViewModel {
  const DeviceInteractionViewModel({
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

class _DeviceInteractionTab extends StatefulWidget {
  const _DeviceInteractionTab({
    required this.viewModel,
    Key? key,
  }) : super(key: key);

  final DeviceInteractionViewModel viewModel;

  @override
  _DeviceInteractionTabState createState() => _DeviceInteractionTabState();
}

class _DeviceInteractionTabState extends State<_DeviceInteractionTab> {
  List<DiscoveredService> discoveredServices = [];
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  bool isOn = false;
  double _brightness = 0.0;

  @override
  void initState() {
    try {
      initilize();
    } catch (e) {
      print(e);
    }
    getSharedPref();
    super.initState();
  }

  setFavColorsToPref() async {
    await _prefs.then((value) {
      value.setString('favColorsPref', jsonEncode(favColors));
      print('_favColors' + value.getString('favColorsPref').toString());
    });
  }

  getSharedPref() async {
    print('getSharedPref' + jsonEncode(favColors));
    await _prefs.then((value) {
      var sat2 = jsonDecode(value.getString('favColorsPref') ?? '');

      if (sat2 != null) {
        for (int i = 0; i < favColors.length; i++) {
          favColors[i]['color'] = sat2[i]['color'];
          favColors[i]['selected'] = sat2[i]['selected'];
        }
      }
    });
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

  Color pickerColor = Color(0xff219653);

  //add type
  List<Map<String, dynamic>> favColors = [
    {
      'color': '0xffEB5757',
      'selected': false,
    },
    {
      'color': '0xffF2994A',
      'selected': false,
    },
    {
      'color': '0xffF2C94C',
      'selected': false,
    },
    {
      'color': '0xff219653',
      'selected': true,
    },
    {
      'color': '0xff6FCF97',
      'selected': false,
    },
    {
      'color': '0xffBB6BD9',
      'selected': false,
    },
    {
      'color': '0xff6FCF97',
      'selected': false,
    },
    {
      'color': '0xffed1c24',
      'selected': false,
    },
  ];
  void changeFavColors(Color color) {
    setState(() {
      pickerColor = color;
      favColors.forEach((element) {
        if (element['selected']) {
          element['color'] = color.value.toString();
        }
      });
    });
    setFavColorsToPref();
    changeColor(color);
  }

// ValueChanged<Color> callback
  void changeColor(Color color) async {
    print(widget.viewModel.connectionStatus);
    setState(() => pickerColor = color);

    var selectedColorHSV =
        HSVColor.fromColor(pickerColor).withValue(1.0).toColor();
    if (widget.viewModel.connectionStatus == DeviceConnectionState.connected ||
        widget.viewModel.connectionStatus == DeviceConnectionState.connecting) {
      print('COLOR CHANGE');
      setFavColorsToPref();
      Snackbar(context, 'Success');

      await widget.viewModel.service
          .writeDataToFF3Services(widget.viewModel.deviceId, [
        126,
        7,
        5,
        3,
        selectedColorHSV.red,
        selectedColorHSV.green,
        selectedColorHSV.blue,
        0,
        239,
        51,
        51,
        51,
        51,
        51,
        51,
        51
      ]);
    } else {
      Snackbar(context, 'Success');
      print('colorchange33');
      initilize();
      ledOn();
      await widget.viewModel.service
          .writeDataToFF3Services(widget.viewModel.deviceId, [
        126,
        7,
        5,
        3,
        selectedColorHSV.red,
        selectedColorHSV.green,
        selectedColorHSV.blue,
        0,
        239,
        51,
        51,
        51,
        51,
        51,
        51,
        51
      ]);
    }
  }

  changeBrightness() async {
    if (widget.viewModel.connectionStatus == DeviceConnectionState.connected ||
        widget.viewModel.connectionStatus == DeviceConnectionState.connecting) {
      await widget.viewModel.service.writeDataToFF3Services(
          widget.viewModel.deviceId, [
        126,
        4,
        1,
        _brightness.toInt(),
        1,
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
      ]);
    } else {
      print('BRIGHTNESS change33');
      ledOn();
      await widget.viewModel.service.writeDataToFF3Services(
          widget.viewModel.deviceId, [
        126,
        4,
        1,
        _brightness.toInt(),
        1,
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
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8.0, bottom: 16.0),
          child: Text(
            "Farbe",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ClipRect(
            child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.70,
          child: ColorPicker(
            pickerColor:
                HSVColor.fromColor(pickerColor).withValue(1.0).toColor(),
            onColorChanged: changeFavColors,
            colorPickerWidth: SizeConfig.blockSizeHorizontal * 50,
            enableAlpha: false,
            labelTypes: [],
            displayThumbColor: false,
            paletteType: PaletteType.hueWheel,
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: const Radius.circular(2.0),
              topRight: const Radius.circular(2.0),
            ),
            hexInputBar: false,
            portraitOnly: true,
            colorHistory: [],
            showLabel: true,
          ),
        )),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Helligkeit',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          '%' + _brightness.toInt().toString(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white30),
                        ),
                        Slider(
                          min: 0,
                          max: 100,
                          inactiveColor: Colors.white,
                          value: _brightness,
                          onChanged: (value) {
                            setState(() {
                              _brightness = value;
                            });
                            changeBrightness();
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
        SizedBox(height: 30),
        Text(
          'Favs',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: SizeConfig.screenHeight * 0.1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              //listview builder for colors in favColors list
              for (var i = 0; i < favColors.length; i++)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      favColors[i]['selected'] = true;
                      pickerColor = Color(int.parse(favColors[i]['color']));
                      changeColor(Color(int.parse(favColors[i]['color'])));
                      for (var j = 0; j < favColors.length; j++) {
                        if (j != i) {
                          favColors[j]['selected'] = false;
                        }
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Color(int.parse(favColors[i]['color'])),
                    ),
                    width: 45,
                    height: favColors[i]['selected'] ? 100 : 75,
                  ),
                )
            ]),
          ),
        ),
        SizedBox(height: 30),
        Text(
          'Basic Colors',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: SizeConfig.screenHeight * 0.1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              //listview builder for colors in favColors list
              for (var i = 0; i < basicColors.length; i++)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      basicColors[i]['selected'] = true;
                      changeColor(basicColors[i]['color']);
                      for (var j = 0; j < favColors.length; j++) {
                        if (j != i) {
                          basicColors[j]['selected'] = false;
                        }
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: basicColors[i]['color'],
                    ),
                    width: basicColors[i]['selected'] ? 55 : 45,
                    height: basicColors[i]['selected'] ? 50 : 40,
                  ),
                )
            ]),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> basicColors = [
    {
      'color': Color(0xffEB5757),
      'selected': false,
    },
    {
      'color': Color(0xffF2994A),
      'selected': false,
    },
    {
      'color': Color(0xffF2C94C),
      'selected': false,
    },
    {
      'color': Color(0xff219653),
      'selected': true,
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
}

class _ServiceDiscoveryList extends StatefulWidget {
  const _ServiceDiscoveryList({
    required this.deviceId,
    required this.discoveredServices,
    Key? key,
  }) : super(key: key);

  final String deviceId;
  final List<DiscoveredService> discoveredServices;

  @override
  _ServiceDiscoveryListState createState() => _ServiceDiscoveryListState();
}

class _ServiceDiscoveryListState extends State<_ServiceDiscoveryList> {
  late final List<int> _expandedItems;

  @override
  void initState() {
    _expandedItems = [];
    super.initState();
  }

  String _charactisticsSummary(DiscoveredCharacteristic c) {
    final props = <String>[];
    if (c.isReadable) {
      props.add("read");
    }
    if (c.isWritableWithoutResponse) {
      props.add("write without response");
    }
    if (c.isWritableWithResponse) {
      props.add("write with response");
    }
    if (c.isNotifiable) {
      props.add("notify");
    }
    if (c.isIndicatable) {
      props.add("indicate");
    }

    return props.join("\n");
  }

  Widget _characteristicTile(
          DiscoveredCharacteristic characteristic, String deviceId) =>
      ListTile(
        onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Theme(
                data: Theme.of(context).copyWith(
                    dialogBackgroundColor: Color.fromARGB(255, 16, 17, 18)),
                child: CharacteristicInteractionDialog(
                  characteristic: QualifiedCharacteristic(
                      characteristicId: characteristic.characteristicId,
                      serviceId: characteristic.serviceId,
                      deviceId: deviceId),
                ))),
        title: Text(
          '${characteristic.characteristicId}\n(${_charactisticsSummary(characteristic)})',
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      );

  List<ExpansionPanel> buildPanels() {
    final panels = <ExpansionPanel>[];

    widget.discoveredServices.asMap().forEach(
          (index, service) => panels.add(
            ExpansionPanel(
              backgroundColor: Colors.grey,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 16.0),
                    child: Text(
                      'Characteristics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemBuilder: (context, index) => _characteristicTile(
                      service.characteristics[index],
                      widget.deviceId,
                    ),
                    itemCount: service.characteristicIds.length,
                  ),
                ],
              ),
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(
                  '${service.serviceId}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              isExpanded: _expandedItems.contains(index),
            ),
          ),
        );

    return panels;
  }

  @override
  Widget build(BuildContext context) => widget.discoveredServices.isEmpty
      ? const SizedBox()
      : Padding(
          padding: const EdgeInsetsDirectional.only(
            top: 20.0,
            start: 20.0,
            end: 20.0,
          ),
          child: ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                setState(() {
                  if (isExpanded) {
                    _expandedItems.remove(index);
                  } else {
                    _expandedItems.add(index);
                  }
                });
              });
            },
            children: [
              ...buildPanels(),
            ],
          ),
        );
}
