import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:weather_station_companion/feature/detail/ui/page.dart';
import 'package:weather_station_companion/feature/discover/data/saved_connection_repository.dart';
import 'package:weather_station_companion/feature/discover/ui/widgets/bluetooth_icon.dart';

import '../bloc/bloc.dart';

class DiscoverPage extends StatefulWidget {
  static const String routeName = '/';

  const DiscoverPage({super.key});

  @override
  State<StatefulWidget> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => DiscoverBloc(),
      child: BlocBuilder<DiscoverBloc, DiscoverState>(
        builder: (BuildContext context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Discover'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: context.read<DiscoverBloc>().state.isSearching ? null : () => context.read<DiscoverBloc>().add(DiscoverSearchTriggered()),
                )
              ],
            ),
            body: _body(context, state),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, DiscoverState state) {
    final bloc = context.read<DiscoverBloc>();

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

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          Visibility(
            visible: state.savedConnections.isNotEmpty,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Saved devices',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          Visibility(
            visible: state.savedConnections.isNotEmpty,
            child: _buildListOfSavedDevices(context, state),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Nearby devices',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Spacer(),
              Visibility(
                visible: state.isSearching,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildListOfFoundDevices(context, state),
        ],
      ),
    );
  }

  Widget _buildListOfSavedDevices(BuildContext context, DiscoverState state) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: state.savedConnections.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const BluetoothIcon(),
          title: Text(state.savedConnections[i].advertisementName),
          subtitle: Text(_getLastSeenText(state.savedConnections[i].lastConnected)),
          onTap: () => _openDetails(context, state.savedConnections[i].mac, false),
          onLongPress: () => _showForgetDialog(context, state.savedConnections[i].advertisementName, state.savedConnections[i].mac),
        );
      },
    );
  }

  Widget _buildListOfFoundDevices(BuildContext context, DiscoverState state) {
    // Only show devices that we don't know yet
    final filteredItems = state.foundDevices.where((e1) => !state.savedConnections.map((e2) => e2.mac).toList().contains(e1.device.remoteId.str)).toList();

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: filteredItems.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const BluetoothIcon(),
          title: Text(filteredItems[i].advertisementData.advName),
          subtitle: Text(filteredItems[i].device.remoteId.str),
          onTap: () => _showConnectDialog(context, filteredItems[i]),
        );
      },
    );
  }

  String _getLastSeenText(DateTime lastSeen) {
    final now = DateTime.now();
    final diffInSeconds = (now.millisecondsSinceEpoch - lastSeen.millisecondsSinceEpoch) ~/ 1000;

    if (diffInSeconds < 60) {
      return 'Last seen a moment ago';
    } else if (diffInSeconds < (60 * 60)) {
      return 'Last seen ${diffInSeconds ~/ 60} minutes ago';
    } else if (diffInSeconds < (60 * 60 * 24 * 2)) {
      return 'Last seen ${diffInSeconds ~/ 60 ~/ 60} hours ago';
    } else {
      return 'Last seen ${DateFormat('yyyy-MM-dd HH:mm').format(lastSeen)}';
    }
  }

  void _openDetails(BuildContext context, String mac, bool connect) {
    final onDetailsClosed = Navigator.pushNamed(
      context,
      DetailPage.routeName,
      arguments: {
        'mac': mac,
        'connect': connect,
      },
    );

    onDetailsClosed.then((_) => context.read<DiscoverBloc>().add(DiscoverDetailPageClosed()));
  }

  Future<void> _showForgetDialog(BuildContext context, String name, String mac) async {
    final bloc = context.read<DiscoverBloc>();

    final choiceIsYes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Do you want to forget "$name"?'),
          content: Text(mac),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Forget'),
            ),
          ],
        );
      },
    );

    if (choiceIsYes ?? false) {
      bloc.add(DiscoverForgetSavedDeviceTriggered(mac));
    }
  }

  Future<void> _showConnectDialog(BuildContext context, ScanResult result) async {
    final choiceIsYes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Do you want to connect to "${result.advertisementData.advName}"?'),
          content: Text(result.device.remoteId.str),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );

    if (choiceIsYes ?? false) {
      _openDetails(context, result.device.remoteId.str, true);
    }
  }
}
