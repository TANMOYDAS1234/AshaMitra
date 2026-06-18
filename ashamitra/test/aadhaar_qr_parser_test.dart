import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/features/patients/services/aadhaar_qr_parser.dart';

/// Builds a synthetic UIDAI-style Secure-QR payload from [fields] (0xFF-joined,
/// gzip-compressed) and returns BOTH the gzip bytes and the base-10 BigInteger
/// string a QR reader would hand back.
({Uint8List bytes, String digits}) _makeSecureQr(List<String> fields) {
  final buf = <int>[];
  for (int i = 0; i < fields.length; i++) {
    buf.addAll(utf8.encode(fields[i]));
    buf.add(0xFF); // delimiter after every field (incl. the last)
  }
  final gz = Uint8List.fromList(gzip.encode(buf));
  // bytes → big-endian BigInteger → base-10 string (what the QR encodes).
  var n = BigInt.zero;
  for (final b in gz) {
    n = (n << 8) | BigInt.from(b);
  }
  return (bytes: gz, digits: n.toString());
}

// emailInd, refId, name, dob, gender, co, dist, lm, house, loc, pc, po, state, street, subdist, vtc
List<String> _fields({String version = ''}) {
  final base = <String>[
    '2', '1234ZZ20190101', 'RAVI KUMAR', '01-01-1990', 'M', 'S/O SHYAM',
    'Howrah', 'Near temple', 'H-12', 'Bagnan', '711303', 'Bagnan PO',
    'West Bengal', 'Station Rd', 'Bagnan-II', 'Bagnan',
  ];
  return version.isEmpty ? base : [version, ...base];
}

void main() {
  group('Aadhaar Secure-QR parser', () {
    test('parses a digit-string (no version token)', () {
      final qr = _makeSecureQr(_fields());
      final r = parseAadhaarQr(qr.digits);
      expect(r, isNotNull);
      expect(r!['name'], 'RAVI KUMAR');
      expect(r['gender'], 'Male');
      expect(r['dob'], '01-01-1990');
      expect(r['district'], 'Howrah');
      expect(r['pincode'], '711303');
      expect(r['careOf'], 'S/O SHYAM');
      expect(r['aadhaar'], 'XXXX-XXXX-1234');
      expect(r['address'], contains('West Bengal'));
      expect(r['address'], contains('Bagnan'));
    });

    test('parses raw gzip BYTES directly (byte-mode scan)', () {
      final qr = _makeSecureQr(_fields());
      final r = parseAadhaarQrBytes(qr.bytes);
      expect(r, isNotNull);
      expect(r!['name'], 'RAVI KUMAR');
      expect(r['gender'], 'Male');
    });

    test('handles the V2 version-token off-by-one', () {
      final qr = _makeSecureQr(_fields(version: 'V2'));
      final r = parseAadhaarQr(qr.digits);
      expect(r, isNotNull);
      expect(r!['name'], 'RAVI KUMAR'); // not "V2"
      expect(r['gender'], 'Male');
      expect(r['dob'], '01-01-1990');
    });

    test('parses ASCII-digit bytes (byte-mode that is the digit string)', () {
      final qr = _makeSecureQr(_fields());
      final asciiDigits = Uint8List.fromList(ascii.encode(qr.digits));
      final r = parseAadhaarQrBytes(asciiDigits);
      expect(r, isNotNull);
      expect(r!['name'], 'RAVI KUMAR');
    });

    test('rejects a non-Aadhaar QR (website URL)', () {
      final res = parseAadhaarQrResult('https://uidai.gov.in/card-center');
      expect(res.ok, isFalse);
      expect(res.reason, isNotEmpty);
    });

    test('parses the older XML PrintLetterBarcodeData QR', () {
      const xml = '<?xml version="1.0"?><PrintLetterBarcodeData uid="999988887777" '
          'name="SITA DEVI" gender="F" yob="1985" dist="Hooghly" pc="712401" co="W/O RAM"/>';
      final r = parseAadhaarQr(xml);
      expect(r, isNotNull);
      expect(r!['name'], 'SITA DEVI');
      expect(r['gender'], 'Female');
      expect(r['aadhaar'], 'XXXX-XXXX-7777');
      expect(r['district'], 'Hooghly');
    });
  });
}
