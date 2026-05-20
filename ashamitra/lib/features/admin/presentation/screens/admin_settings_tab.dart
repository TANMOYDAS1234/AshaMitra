import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/controller/auth_controller.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _auth = Get.find<AuthController>();
  final _lang = Get.find<LanguageController>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _block;
  late final TextEditingController _district;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = _auth.user.value;
    _name     = TextEditingController(text: u?.name     ?? '');
    _block    = TextEditingController(text: u?.block    ?? '');
    _district = TextEditingController(text: u?.district ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _block.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _auth.updateProfile(
      name:     _name.text.trim(),
      block:    _block.text.trim(),
      district: _district.text.trim(),
    );
    setState(() => _saving = false);
    Get.snackbar(
      'profile_updated'.tr,
      'profile_updated_msg'.tr,
      backgroundColor: AppColors.safeGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await ImagePicker().pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (img != null) _auth.updateProfileImage(img.path);
  }

  void _showPhotoOptions() {
    final hasPhoto = _auth.user.value?.profileImagePath != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            _PhotoOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              color: AppColors.primary,
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            _PhotoOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              color: AppColors.sky,
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            if (hasPhoto)
              _PhotoOption(
                icon: Icons.delete_rounded,
                label: 'Remove Photo',
                color: AppColors.emergencyRed,
                onTap: () { Navigator.pop(context); _auth.updateProfileImage(null); },
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('change_language'.tr,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground)),
            const SizedBox(height: 16),
            Obx(() => Column(
                  children: List.generate(LanguageController.labels.length, (i) {
                    final selected = _lang.selectedIndex.value == i;
                    final badges = ['বাং', 'हिं', 'En'];
                    return GestureDetector(
                      onTap: () { _lang.setLanguage(i); Navigator.pop(context); },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : const Color(0xFFF7F8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(badges[i],
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(LanguageController.labels[i],
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.onBackground)),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                )),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.emergencyRed, size: 28),
              ),
              const SizedBox(height: 20),
              Text('admin_logout'.tr,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground)),
              const SizedBox(height: 8),
              const Text('লগআউট করতে চান?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                      ),
                      child: Text('cancel'.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _auth.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emergencyRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('admin_logout'.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground)),
              const SizedBox(height: 20),

              // ── Avatar card ──────────────────────────────────────
              _Card(
                child: Obx(() {
                  final u = _auth.user.value;
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2),
                                    width: 2),
                              ),
                              child: UserAvatar(
                                user: u,
                                size: 72,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                textColor: AppColors.primary,
                              ),
                            ),
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: const Icon(Icons.camera_alt_rounded,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u?.name ?? 'Admin',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onBackground)),
                            const SizedBox(height: 4),
                            Text(u?.phone ?? '',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Admin',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),

              // ── Edit profile form ────────────────────────────────
              _Card(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Profile',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground)),
                      const SizedBox(height: 16),
                      _Field(ctrl: _name, label: 'admin_full_name'.tr,
                          icon: Icons.person_rounded,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'admin_name_required'.tr
                                  : null),
                      const SizedBox(height: 12),
                      _Field(ctrl: _block, label: 'admin_block'.tr,
                          icon: Icons.location_on_rounded),
                      const SizedBox(height: 12),
                      _Field(ctrl: _district, label: 'admin_district'.tr,
                          icon: Icons.map_rounded),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text('admin_save'.tr,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Preferences ──────────────────────────────────────
              _Card(
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.language_rounded,
                      label: 'change_language'.tr,
                      color: AppColors.sky,
                      onTap: _showLanguageSheet,
                      trailing: Obx(() => Text(_lang.currentLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Logout ───────────────────────────────────────────
              GestureDetector(
                onTap: _confirmLogout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            AppColors.emergencyRed.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppColors.emergencyRed, size: 20),
                      SizedBox(width: 8),
                      Text('Logout',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emergencyRed)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: child,
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        validator: validator,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onBackground),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.emergencyRed)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.emergencyRed, width: 1.5)),
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsRow(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onBackground)),
              ),
              if (trailing != null) trailing!,
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoOption(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color == AppColors.emergencyRed
                    ? AppColors.emergencyRed
                    : AppColors.onBackground)),
        onTap: onTap,
      );
}
