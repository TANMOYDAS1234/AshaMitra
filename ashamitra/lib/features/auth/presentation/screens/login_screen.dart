import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../widgets/auth_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AuthController>();
    return Scaffold(
      body: AuthForm(
        onSubmit: (phone) => ctrl.login(phone),
        isLoading: ctrl.isLoading,
        errorMsg: ctrl.errorMsg,
      ),
    );
  }
}
