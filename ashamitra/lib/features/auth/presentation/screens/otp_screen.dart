import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/app_button.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = Get.find<AuthController>();
  late final String _phone;
  String? _pilotOtp;
  final List<TextEditingController> _boxes =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _phone    = args['phone']?.toString()    ?? '';
      _pilotOtp = args['pilotOtp']?.toString();
    } else {
      _phone    = args?.toString() ?? '';
      _pilotOtp = null;
    }
    // Auto-fill boxes if pilot OTP received
    if (_pilotOtp != null && _pilotOtp!.length == 6) {
      for (int i = 0; i < 6; i++) {
        _boxes[i].text = _pilotOtp![i];
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _boxes) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _boxes.map((c) => c.text).join();

  void _onBoxChanged(int index, String val) {
    if (val.isNotEmpty && index < 5) _nodes[index + 1].requestFocus();
    if (val.isEmpty && index > 0) _nodes[index - 1].requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06), blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.onBackground),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_rounded, size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text('otp_title'.tr,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onBackground)),
                const SizedBox(height: 6),
                Text(
                  'otp_subtitle'.trParams({'phone': _phone}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                // ── Pilot mode OTP banner ────────────────────────────────
                if (_pilotOtp != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pilot Mode — OTP',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E), letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(_pilotOtp!,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                    color: Color(0xFF92400E), letterSpacing: 8)),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(
                          6,
                          (i) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                              child: _OtpBox(
                                controller: _boxes[i],
                                focusNode: _nodes[i],
                                onChanged: (val) => _onBoxChanged(i, val),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(() => AppButton(
                            label: 'verify_otp'.tr,
                            onPressed: _otp.length == 6
                                ? () => _ctrl.verifyOtp(_phone, _otp)
                                : null,
                            isLoading: _ctrl.isLoading.value,
                            width: double.infinity,
                          )),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {},
                        child: Text('resend_otp'.tr,
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox(
      {required this.controller,
      required this.focusNode,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onBackground),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF5F7FF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
