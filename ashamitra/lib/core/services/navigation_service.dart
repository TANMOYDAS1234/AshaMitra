import 'package:get/get.dart';

class NavigationService {
  static void to(String route, {dynamic arguments}) =>
      Get.toNamed(route, arguments: arguments);

  static void off(String route) => Get.offNamed(route);

  static void offAll(String route) => Get.offAllNamed(route);

  static void back() => Get.back();
}
