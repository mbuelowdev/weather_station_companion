import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:weather_station_companion/shared/data_sink_format.dart';
import 'package:weather_station_companion/feature/detail/bloc/bloc.dart';

class DetailPage extends StatefulWidget {
  static const String routeName = '/detail';

  final String mac;
  final bool connect;

  const DetailPage(this.mac, this.connect, {super.key});

  @override
  State<StatefulWidget> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final TextEditingController _textEditingControllerMAC = TextEditingController();
  final TextEditingController _textEditingControllerDataSink = TextEditingController();
  int selectedDataSinkFormat = 0;
  final TextEditingController _textEditingControllerMeasurementRate = TextEditingController();
  final TextEditingController _textEditingControllerUploadRate = TextEditingController();
  final TextEditingController _textEditingControllerWiFiSSID = TextEditingController();
  final TextEditingController _textEditingControllerWiFiPassword = TextEditingController();

  bool _showPassword = false;

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => DetailBloc(widget.mac, widget.connect),
      child: BlocBuilder<DetailBloc, DetailState>(
        builder: (BuildContext context, DetailState state) {
          return WillPopScope(
            onWillPop: () => _onLeave(context, state.isConnected),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Detail'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: state.isConnected
                        ? () => context.read<DetailBloc>().add(
                              DetailSaveButtonPressed(
                                _textEditingControllerMAC.text,
                                _textEditingControllerDataSink.text,
                                selectedDataSinkFormat,
                                int.parse(_textEditingControllerMeasurementRate.text),
                                int.parse(_textEditingControllerUploadRate.text),
                                _textEditingControllerWiFiSSID.text,
                                _textEditingControllerWiFiPassword.text,
                              ),
                            )
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () => context.read<DetailBloc>().add(DetailReconnectTriggered()),
                  ),
                ],
              ),
              body: _body(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, DetailState state) {
    _textEditingControllerMAC.text = state.mac;
    _textEditingControllerDataSink.text = state.dataSink;
    selectedDataSinkFormat = state.dataSinkFormat;
    _textEditingControllerMeasurementRate.text = state.measurementRate.toString();
    _textEditingControllerUploadRate.text = state.uploadRate.toString();
    _textEditingControllerWiFiSSID.text = state.wifiSSID;
    _textEditingControllerWiFiPassword.text = state.wifiPassword;

    if (state.isInitializing) {
      return Container();
    }

    if (state.snackBarMessage != null && !state.snackBarMessage!.shown) {
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final snackBar = SnackBar(
          content: Text(state.snackBarMessage!.getMessage()),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      });
    }

    if (state.disconnectedToLeave) {
      Navigator.maybePop(context);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerMAC,
              enabled: false,
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('MAC'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerDataSink,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('Data sink'),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9$?!/.,&\\%+=()]'))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField(
              isExpanded: true,
              value: selectedDataSinkFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('Data sink format'),
              ),
              items: const [
                DropdownMenuItem<int>(
                  value: DataSinkFormat.json,
                  child: Text('JSON'),
                ),
                DropdownMenuItem<int>(
                  value: DataSinkFormat.csv,
                  child: Text('CSV'),
                ),
                DropdownMenuItem<int>(
                  value: DataSinkFormat.mqtt,
                  child: Text('MQTT'),
                ),
              ],
              onChanged: (int? value) => setState(() {
                selectedDataSinkFormat = value ?? DataSinkFormat.json;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerMeasurementRate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('Measurement rate (seconds)'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerUploadRate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('Upload rate (seconds)'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerWiFiSSID,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text('WiFi SSID'),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9$?!/.,&\\%+=()]'))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerWiFiPassword,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: const Text('WiFi Password'),
                suffixIcon: GestureDetector(
                  onTap: () => _togglePasswordVisibility(),
                  child: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9$?!/.,&\\%+=()]'))
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onLeave(BuildContext context, bool isStillConnected) async {
    if (isStillConnected) {
      context.read<DetailBloc>().add(DetailNavigateBackTriggered());

      return false;
    }

    return true;
  }
}
