import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.onBackground);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onBackground);
  static const body = TextStyle(fontSize: 16, color: AppColors.onBackground);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onPrimary);
}
