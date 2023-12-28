import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:weather_station_companion/shared/data_sink_format.dart';
import 'package:weather_station_companion/feature/detail/bloc/bloc.dart';

import 'widgets/info_dialog_description_row.dart';
import 'widgets/info_dialog_title_row.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => DetailBloc(widget.mac, widget.connect),
      child: BlocBuilder<DetailBloc, DetailState>(
        builder: (BuildContext context, DetailState state) {
          return PopScope(
            canPop: true,
            onPopInvoked: (_) => _onLeave(context, state.isConnected),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Detail'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.help),
                    onPressed: () => _showInfoDialog(context),
                  ),
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
      return const Center(
        child: CircularProgressIndicator(), // TODO ist evtl nur im debug build so schluchzig
      );
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
                ByteSizeLimit(640),
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
              ],
              onChanged: (int? value) => context.read<DetailBloc>().add(DetailOnInputChanged(
                    _textEditingControllerMAC.text,
                    _textEditingControllerDataSink.text,
                    value!,
                    int.parse(_textEditingControllerMeasurementRate.text),
                    int.parse(_textEditingControllerUploadRate.text),
                    _textEditingControllerWiFiSSID.text,
                    _textEditingControllerWiFiPassword.text,
                    state.wifiPasswordIsVisible,
                  )),
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
                ByteSizeLimit(128),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _textEditingControllerWiFiPassword,
              obscureText: !state.wifiPasswordIsVisible,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: const Text('WiFi Password'),
                suffixIcon: GestureDetector(
                  onTap: () => context.read<DetailBloc>().add(DetailOnInputChanged(
                        _textEditingControllerMAC.text,
                        _textEditingControllerDataSink.text,
                        selectedDataSinkFormat,
                        int.parse(_textEditingControllerMeasurementRate.text),
                        int.parse(_textEditingControllerUploadRate.text),
                        _textEditingControllerWiFiSSID.text,
                        _textEditingControllerWiFiPassword.text,
                        !state.wifiPasswordIsVisible,
                      )),
                  child: Icon(
                    state.wifiPasswordIsVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              inputFormatters: [
                ByteSizeLimit(128),
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

  Future<void> _showInfoDialog(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help'),
          content: const SingleChildScrollView(
            child: Column(
              children: [
                InfoDialogTitleRow('Data Sink'),
                InfoDialogDescriptionRow('Maximal length: 640 bytes'),
                InfoDialogDescriptionRow('Maximal length of HOST part: 128 bytes'),
                InfoDialogDescriptionRow('Maximal length of PATH part: 512 bytes'),
                InfoDialogDescriptionRow('Default: http://configure/'),
                Divider(),
                InfoDialogTitleRow('Measurement Rate (MR)'),
                InfoDialogDescriptionRow('Amount of time between each measurement cycle'),
                InfoDialogDescriptionRow('Valid values: 0 - 65535'),
                InfoDialogDescriptionRow('Default: 60'),
                Divider(),
                InfoDialogTitleRow('Upload Rate (UR)'),
                InfoDialogDescriptionRow('Amount of time between each upload cycle'),
                InfoDialogDescriptionRow('Uploads only happen after a measurement. This means the actual upload time may vary by one measurement cycle.'
                    'For example: MR of 45s and UR of 60s -> the first uploads will happen after 90s, 135s and 180s instead of 60s, 120s and 180s.'),
                InfoDialogDescriptionRow('Can not be grater than MR * 100. Because we can only store 100 measurements on the esp.'),
                InfoDialogDescriptionRow('Valid values: 0 - 65535'),
                InfoDialogDescriptionRow('Default: 600'),
                Divider(),
                InfoDialogTitleRow('Wifi SSID'),
                InfoDialogDescriptionRow('Maximal length: 128 bytes'),
                InfoDialogDescriptionRow('Default: configure'),
                Divider(),
                InfoDialogTitleRow('Wifi Password'),
                InfoDialogDescriptionRow('Maximal length: 128 bytes'),
                InfoDialogDescriptionRow('Default: configure'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }
}

class ByteSizeLimit extends TextInputFormatter {
  final int sizeLimit;

  ByteSizeLimit(this.sizeLimit);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.text.length > sizeLimit ? oldValue : newValue;
  }
}