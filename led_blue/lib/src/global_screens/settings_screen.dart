import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSearch = false;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    _initializeAutoSearch();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Automatisch verbinden',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  CupertinoSwitch(
                    value: _autoSearch,
                    onChanged: (value) async {
                      //set shared preferences here
                      final SharedPreferences prefs = await _prefs;
                      prefs.setBool('autoSearchActive', value);

                      setState(() {
                        _autoSearch = value;
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
          ],
        ),
      ),
    );
  }

  void _initializeAutoSearch() async {
    _prefs.then((SharedPreferences prefs) async {
      setState(() {
        _autoSearch = prefs.getBool('autoSearchActive') ?? false;
      });
    });
  }
}
