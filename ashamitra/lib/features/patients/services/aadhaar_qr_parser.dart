import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Parses an Aadhaar QR payload into demographic fields. Handles BOTH:
///   • the older XML "PrintLetterBarcodeData" QR, and
///   • the newer "Secure QR" (V1–V4): a big integer in base-10 → big-endian
///     bytes → gzip/zlib/DEFLATE → 0xFF-delimited UTF-8 fields.
///
/// Robust to how a scanner hands us the payload: a decimal digit STRING, the
/// raw BYTES (byte/binary-mode QR), or a mangled Latin-1 string. Runs fully
/// on-device (offline). Only the last 4 digits of the Aadhaar number are ever
/// surfaced (masked); the full number is never assembled or stored.
///
/// Mirrors backend/server.js so the photo path and the live-scan path agree.

/// Result wrapper so the UI can show WHY a parse failed instead of a generic
/// "not an Aadhaar QR". On success [data] holds the demographic map; on failure
/// [data] is null, [reason] is a short Bengali message, [debug] a technical
/// one-liner (lengths, inflate strategy, field count) for the on-screen line + log.
class AadhaarParseResult {
  final Map<String, dynamic>? data;
  final String reason; // Bengali, shown to the worker
  final String debug; // technical trace
  const AadhaarParseResult(this.data, this.reason, this.debug);
  bool get ok => data != null;
}

/// Back-compat string entry point (returns just the map, null on failure).
Map<String, dynamic>? parseAadhaarQr(String? input) =>
    parseAadhaarQrResult(input).data;

/// String entry point that also reports a reason.
AadhaarParseResult parseAadhaarQrResult(String? input) {
  final s = (input ?? '').trim();
  if (s.isEmpty) return const AadhaarParseResult(null, 'খালি QR', 'empty');
  if (s.startsWith('<?xml') || s.contains('PrintLetterBarcodeData')) {
    final m = _parseXml(s);
    return m != null
        ? AadhaarParseResult(m, '', 'xml ok')
        : const AadhaarParseResult(null, 'XML QR — নাম খালি', 'xml: empty name');
  }
  if (RegExp(r'^\d+$').hasMatch(s)) return _parseSecureFromDigits(s);
  // Neither XML nor pure digits → almost certainly byte-mode handed to us as a
  // Latin-1 string. Re-encode (round-trippable for 0..255) and try bytes.
  try {
    return parseAadhaarQrBytesResult(latin1.encode(s));
  } catch (_) {
    return const AadhaarParseResult(
        null, 'সংখ্যা নয় — বাইট মোড, পড়া যায়নি', 'non-digit string, latin1 failed');
  }
}

/// Bytes-first entry point — pass a scanner's rawBytes here UNCHANGED.
Map<String, dynamic>? parseAadhaarQrBytes(List<int> bytes) =>
    parseAadhaarQrBytesResult(bytes).data;

AadhaarParseResult parseAadhaarQrBytesResult(List<int> bytes) {
  if (bytes.isEmpty) return const AadhaarParseResult(null, 'খালি QR', 'empty bytes');
  // (a) bytes are the ASCII of the decimal digit string.
  final digits = _tryAsciiDigits(bytes);
  if (digits != null) return _parseSecureFromDigits(digits);
  // (b) XML delivered as bytes.
  final head = latin1.decode(bytes.take(64).toList(), allowInvalid: true);
  if (head.startsWith('<?xml') || head.contains('PrintLetterBarcodeData')) {
    final m = _parseXml(latin1.decode(bytes, allowInvalid: true));
    return m != null
        ? AadhaarParseResult(m, '', 'xml-bytes ok')
        : const AadhaarParseResult(null, 'XML QR — নাম খালি', 'xml-bytes: empty name');
  }
  // (c) bytes ARE the Secure-QR payload (compressed) — inflate directly.
  return _parseSecureFromBytes(Uint8List.fromList(bytes), origin: 'rawBytes');
}

String? _tryAsciiDigits(List<int> bytes) {
  if (bytes.isEmpty) return null;
  for (final b in bytes) {
    if (b < 0x30 || b > 0x39) return null;
  }
  return String.fromCharCodes(bytes); // safe: all < 128
}

// ---- Secure QR: decimal digit string → bytes -------------------------------
AadhaarParseResult _parseSecureFromDigits(String s) {
  BigInt n;
  try {
    n = BigInt.parse(s);
  } catch (_) {
    return AadhaarParseResult(null, 'সংখ্যা পড়া যায়নি', 'BigInt.parse failed (len=${s.length})');
  }
  return _parseSecureFromBytes(_bigIntToBytes(n), origin: 'digits(${s.length})');
}

Uint8List _bigIntToBytes(BigInt n) {
  final out = <int>[];
  final mask = BigInt.from(0xff);
  while (n > BigInt.zero) {
    out.insert(0, (n & mask).toInt());
    n = n >> 8;
  }
  return Uint8List.fromList(out);
}

// ---- Secure QR: raw payload bytes (the core) -------------------------------
AadhaarParseResult _parseSecureFromBytes(Uint8List raw, {required String origin}) {
  final hdr = raw.length >= 4
      ? raw.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()
      : '(short)';
  // Try the bytes as-is and with a restored leading 0x00 (BigInt conversion
  // drops a most-significant zero, which would corrupt the gzip/zlib header).
  final candidates = <Uint8List>[raw, Uint8List.fromList([0, ...raw])];
  for (final cand in candidates) {
    final inf = _inflateAny(cand);
    if (inf == null) continue;
    final r = _splitAndBuild(inf.data, origin: origin, hdr: hdr, strategy: inf.strategy);
    if (r.ok) return r;
  }
  // V1 / already-plain bytes with 0xFF delimiters.
  if (raw.contains(0xFF)) {
    final r = _splitAndBuild(raw, origin: origin, hdr: hdr, strategy: 'raw');
    if (r.ok) return r;
  }
  return AadhaarParseResult(null, 'QR পড়া গেছে কিন্তু ডিকম্প্রেস ব্যর্থ',
      'origin=$origin hdr=$hdr inflate=none len=${raw.length}');
}

class _Inflated {
  final List<int> data;
  final String strategy;
  _Inflated(this.data, this.strategy);
}

/// gzip (1f8b) → zlib (78xx) → raw DEFLATE, in order. null only if all fail.
_Inflated? _inflateAny(List<int> bytes) {
  try {
    return _Inflated(gzip.decode(bytes), 'gzip');
  } catch (_) {}
  try {
    return _Inflated(ZLibCodec().decode(bytes), 'zlib');
  } catch (_) {}
  try {
    return _Inflated(ZLibCodec(raw: true).decode(bytes), 'raw-deflate');
  } catch (_) {}
  return null;
}

AadhaarParseResult _splitAndBuild(List<int> data,
    {required String origin, required String hdr, required String strategy}) {
  // 0xFF-delimited UTF-8 fields. Cap at 18 so we never walk into the trailing
  // JPEG photo / RSA signature (whose bytes also contain 0xFF).
  final f = <String>[];
  int start = 0;
  for (int i = 0; i < data.length && f.length < 18; i++) {
    if (data[i] == 0xFF) {
      f.add(utf8.decode(data.sublist(start, i), allowMalformed: true));
      start = i + 1;
    }
  }
  // VTC (last text field) often has no closing 0xFF — capture a short tail.
  if (f.length < 16 && start < data.length) {
    final end = (start + 200) < data.length ? start + 200 : data.length;
    final tail = data.sublist(start, end);
    if (!tail.contains(0xFF)) f.add(utf8.decode(tail, allowMalformed: true));
  }

  // Version-token off-by-one: V2/V3/V4 cards prepend "V<digit>" as f[0].
  final off = (f.isNotEmpty && RegExp(r'^V\d$').hasMatch(f[0].trim())) ? 1 : 0;
  String at(int i) => (i + off) < f.length ? f[i + off] : '';

  final refId = at(1);
  final last4 = refId.length >= 4 ? refId.substring(0, 4) : '';
  final name = at(2);
  final dob = at(3);
  final g = at(4).trim().toUpperCase();
  final debug = 'origin=$origin hdr=$hdr inflate=$strategy off=$off '
      'fields=${f.length} declen=${data.length} '
      'name="${name.length > 20 ? name.substring(0, 20) : name}" dob="$dob" g="$g"';

  // Validate before returning — reject a junk inflate that happened to split.
  if (f.length < 5) {
    return AadhaarParseResult(null, 'ক্ষেত্র কম — সম্ভবত ভুল ডিকোড', debug);
  }
  if (!RegExp(r'[A-Za-zऀ-ॿঀ-৿]').hasMatch(name)) {
    return AadhaarParseResult(null, 'নাম খালি/অবৈধ — ভুল ডিকোড', debug);
  }
  if (!RegExp(r'^[MFT]$').hasMatch(g)) {
    return AadhaarParseResult(null, 'লিঙ্গ অবৈধ — ভুল ডিকোড', debug);
  }

  final addr = [at(8), at(13), at(7), at(9), at(15), at(11), at(14), at(6), at(12), at(10)]
      .where((v) => v.isNotEmpty)
      .join(', ');
  return AadhaarParseResult({
    'source': 'qr',
    'name': name,
    'dob': dob,
    'gender': g == 'F' ? 'Female' : g == 'M' ? 'Male' : g == 'T' ? 'Transgender' : null,
    'aadhaar': RegExp(r'^\d{4}$').hasMatch(last4) ? 'XXXX-XXXX-$last4' : '',
    'address': addr,
    'district': at(6),
    'pincode': at(10),
    'careOf': at(5),
  }, '', debug);
}

// ---- Older XML QR ----------------------------------------------------------
Map<String, dynamic>? _parseXml(String s) {
  final name = _attr(s, 'name');
  if (name.isEmpty) return null;
  final g = _attr(s, 'gender');
  final parts = ['house', 'street', 'lm', 'loc', 'vtc', 'po', 'subdist', 'dist', 'state', 'pc']
      .map((k) => _attr(s, k))
      .where((v) => v.isNotEmpty)
      .toList();
  final dob = _attr(s, 'dob').isNotEmpty ? _attr(s, 'dob') : _attr(s, 'yob');
  return {
    'source': 'qr',
    'name': name,
    'dob': dob,
    'gender': g == 'F' ? 'Female' : g == 'M' ? 'Male' : null,
    'aadhaar': _mask(_attr(s, 'uid')),
    'address': parts.join(', '),
    'district': _attr(s, 'dist'),
    'pincode': _attr(s, 'pc'),
    'careOf': _attr(s, 'co'),
  };
}

String _mask(String? digits) {
  final d = (digits ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length >= 4 ? 'XXXX-XXXX-${d.substring(d.length - 4)}' : '';
}

String _attr(String s, String k) {
  final m = RegExp('$k="([^"]*)"').firstMatch(s);
  return m != null ? m.group(1)! : '';
}
