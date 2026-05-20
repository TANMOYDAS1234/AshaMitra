import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> requestMicrophone() async =>
      (await Permission.microphone.request()).isGranted;

  static Future<bool> requestLocation() async =>
      (await Permission.location.request()).isGranted;
}
