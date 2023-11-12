part of 'bloc.dart';

abstract class DiscoverEvent {}

class DiscoverInitialized extends DiscoverEvent {
  final List<SavedConnection> savedConnections;

  DiscoverInitialized(this.savedConnections);
}

class DiscoverSearchTriggered extends DiscoverEvent {}

class DiscoverSearchDeviceDetected extends DiscoverEvent {
  final List<ScanResult> foundDevices;

  DiscoverSearchDeviceDetected(this.foundDevices);
}

class DiscoverSearchFinished extends DiscoverEvent {}

class DiscoverForgetSavedDeviceTriggered extends DiscoverEvent {
  final String mac;

  DiscoverForgetSavedDeviceTriggered(this.mac);
}

class DiscoverFoundDeviceListTileTapped extends DiscoverEvent {
  final BluetoothDevice device;

  DiscoverFoundDeviceListTileTapped(this.device);
}

class DiscoverDetailPageClosed extends DiscoverEvent {}