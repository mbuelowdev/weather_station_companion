import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:weather_station_companion/feature/detail/ui/page.dart';
import 'package:weather_station_companion/feature/discover/ui/page.dart';


class RouteGenerator {
  static final routeMap = <String, WidgetBuilder>{
    DiscoverPage.routeName: (_) => const DiscoverPage(),
    DetailPage.routeName: (context) {
      final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return DetailPage(arguments['mac'], arguments['connect']);
    },
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Getting arguments passed in while calling Navigator.pushNamed
    //final args = settings.arguments;
    return CupertinoPageRoute(
      builder: routeMap[settings.name] ?? (_) => _errorRoute(settings.name),
      settings: settings,
    );
  }

  static Widget _errorRoute(String? routeName) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Text('Generator for route $routeName not implemented'),
      ),
    );
  }
}
