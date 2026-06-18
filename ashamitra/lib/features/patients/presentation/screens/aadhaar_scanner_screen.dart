import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/aadhaar_qr_parser.dart';

/// Full-screen LIVE Aadhaar QR scanner (point-and-lock). Decodes + validates
/// the QR in real time and pops with the PARSED demographic map (or null if the
/// worker backs out). Keeps scanning on a non-Aadhaar QR and shows WHY, so a
/// wrong code (or a hard-to-read one) doesn't silently fail.
class AadhaarScannerScreen extends StatefulWidget {
  const AadhaarScannerScreen({super.key});

  @override
  State<AadhaarScannerScreen> createState() => _AadhaarScannerScreenState();
}

class _AadhaarScannerScreenState extends State<AadhaarScannerScreen> {
  final _controller = MobileScannerController(
    // unrestricted: analyze EVERY frame with no throttle → fastest lock. We
    // keep the high resolution + auto-zoom (what makes the dense Secure-QR
    // decode), and only push detection throughput up for speed.
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1920, 1080),
    autoZoom: true,
  );
  bool _handled = false;
  String? _warning; // Bengali reason shown under the frame
  String? _diag; // technical one-liner (so one real-card scan is self-explanatory)
  Uint8List? _lastBytes; // last decoded payload (for the copy-to-clipboard debug)
  String? _lastString;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      // ignore: deprecated_member_use
      final bytes = b.rawBytes;
      _lastBytes = bytes;
      _lastString = raw;

      AadhaarParseResult res;
      String path;
      if (bytes != null && bytes.isNotEmpty) {
        // Bytes-first: a real Secure-QR usually arrives as byte mode. Pass the
        // bytes UNCHANGED (never String.fromCharCodes for high bytes).
        res = parseAadhaarQrBytesResult(bytes);
        path = 'bytes(${bytes.length})';
        if (!res.ok && raw != null && raw.trim().isNotEmpty) {
          final r2 = parseAadhaarQrResult(raw);
          if (r2.ok) {
            res = r2;
            path = 'string(${raw.length})';
          }
        }
      } else if (raw != null && raw.trim().isNotEmpty) {
        res = parseAadhaarQrResult(raw);
        path = 'string(${raw.length})';
      } else {
        // A symbol was detected but ML Kit gave neither value nor bytes →
        // camera/focus/ECI issue, NOT a parser problem.
        setState(() {
          _warning = 'QR দেখা গেছে কিন্তু পড়া যায়নি — কাছে ধরুন, আলো বাড়ান, স্থির রাখুন';
          _diag = 'fmt=${b.format} type=${b.type} rawValue=null rawBytes=null';
        });
        continue;
      }

      debugPrint('[AadhaarQR] path=$path fmt=${b.format} '
          'rawValue=${raw == null ? "null" : "len${raw.length}"} '
          'rawBytes=${bytes == null ? "null" : "len${bytes.length}"} '
          '=> ${res.ok ? "OK" : "FAIL"} :: ${res.debug}');

      if (res.ok) {
        _handled = true;
        Get.back(result: res.data);
        return;
      }
      setState(() {
        _warning = 'একটি QR পড়া হয়েছে, কিন্তু আধার হিসেবে পড়া গেল না।\n${res.reason}';
        _diag = '$path · ${res.debug}';
      });
    }
  }

  void _copyPayload() {
    final s = _lastBytes != null
        ? 'bytes:${base64Encode(_lastBytes!)}'
        : (_lastString != null ? 'str:${_lastString!}' : null);
    if (s == null) {
      Get.snackbar('ডিবাগ', 'এখনো কোনো QR পড়া হয়নি');
      return;
    }
    Clipboard.setData(ClipboardData(text: s));
    Get.snackbar('ডিবাগ', 'QR পেলোড কপি হয়েছে (${s.length} অক্ষর)');
  }

  @override
  Widget build(BuildContext context) {
    final warn = _warning != null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('আধার QR স্ক্যান'),
        actions: [
          IconButton(
            tooltip: 'ফ্ল্যাশ',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'ক্যামেরা বদলান',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            tooltip: 'QR পেলোড কপি (ডিবাগ)',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _copyPayload,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        // Restrict ML Kit to a TIGHT centre box: it crops the analysed region
        // (even less to process per frame → sub-second lock) while keeping full
        // 1080p resolution there so the dense Secure-QR still decodes.
        final box = (constraints.biggest.shortestSide * 0.60).clamp(160.0, 320.0);
        final scanWindow = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: box,
          height: box,
        );
        return Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            scanWindow: scanWindow,
          ),
          Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              border: Border.all(
                color: warn ? AppColors.warningYellow : AppColors.primary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
            ),
          ),
          Positioned(
            bottom: 56,
            left: 22,
            right: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                const SizedBox(height: 10),
                Text(
                  _warning ??
                      'আধার কার্ডের পিছনের QR কোডটি\nফ্রেমের ভিতরে রাখুন (ভালো আলোয়, কাছ থেকে)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: warn ? AppColors.warningYellow : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'টিপ: আসল কার্ড স্ক্যান করুন — স্ক্রিন/ছবি থেকে নয়',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                if (_diag != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _diag!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        );
      }),
    );
  }
}
