part of 'bloc.dart';

enum _Status {
  initializing,
  standard,
  searching,
}

class DiscoverState {
  final _Status status;
  final SnackBarMessage? snackBarMessage;
  final List<SavedConnection> savedConnections;
  final List<ScanResult> foundDevices;

  const DiscoverState([
    this.status = _Status.initializing,
    this.snackBarMessage,
    this.savedConnections = const [],
    this.foundDevices = const [],
  ]);

  DiscoverState copyWith({
    _Status? status,
    SnackBarMessage? snackBarMessage,
    List<SavedConnection>? savedConnections,
    List<ScanResult>? foundDevices,
  }) {
    return DiscoverState(
      status ?? this.status,
      snackBarMessage,
      savedConnections ?? this.savedConnections,
      foundDevices ?? this.foundDevices,
    );
  }

  bool get isSearching => status == _Status.searching;

  bool get isInitializing => status == _Status.initializing;
}
