class ApiConstants {
  static const baseUrl = 'https://ashamitra-backend.flintdeorient.in/api';
  static const timeout = Duration(seconds: 30);

  static const authSendOtp = '/auth/send-otp';
  static const authVerifyOtp = '/auth/verify-otp';
  static const patients = '/patients';
  static const reports = '/reports';
  static const triage = '/triage';
}
