import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class SavedConnection extends Equatable {
  final String mac;
  final String advertisementName;
  final DateTime lastConnected;

  const SavedConnection(this.mac, this.advertisementName, this.lastConnected);

  @override
  List<Object?> get props => [mac, advertisementName, lastConnected];

  factory SavedConnection.fromJson(dynamic json) {
    return SavedConnection(
      json['mac'],
      json['advertisementName'],
      DateTime.parse(json['lastConnected']),
    );
  }

  static List<SavedConnection> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((e) => SavedConnection.fromJson(e)).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'mac': mac,
      'advertisementName': advertisementName,
      'lastConnected': DateFormat('yyyy-MM-ddTHH:mm:ss').format(lastConnected),
    };
  }
}