import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

class Services {
  static Future<void> init() async {
    GetIt.I.registerSingleton(Logger());
  }
}