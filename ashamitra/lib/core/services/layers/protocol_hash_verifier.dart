// ─────────────────────────────────────────────────────────────────────────────
// Layer 5 — Protocol Hash Verify
// Verifies the loaded asha_engine.json has not been tampered with.
// A hash mismatch is a hard block — no band is emitted.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class HashVerifyResult {
  final bool valid;
  final String computedHash;
  final String? expectedHash;  // null if no expected hash registered yet
  final String? error;

  const HashVerifyResult({
    required this.valid,
    required this.computedHash,
    this.expectedHash,
    this.error,
  });

  factory HashVerifyResult.pass(String hash) => HashVerifyResult(
        valid: true,
        computedHash: hash,
        expectedHash: hash,
      );

  factory HashVerifyResult.fail({
    required String computedHash,
    required String expectedHash,
    required String error,
  }) =>
      HashVerifyResult(
        valid: false,
        computedHash: computedHash,
        expectedHash: expectedHash,
        error: error,
      );

  factory HashVerifyResult.unregistered(String computedHash) => HashVerifyResult(
        valid: true, // first run — no expected hash yet, accept and register
        computedHash: computedHash,
        expectedHash: null,
        error: null,
      );
}

class ProtocolHashVerifier {
  static const _enginePath = 'assets/data/asha_engine.json';

  // In-memory expected hash — set on first successful load.
  // In production this would be read from a signed manifest or secure storage.
  String? _registeredHash;

  /// Computes SHA-256 of the engine JSON and compares against registered hash.
  ///
  /// First call: computes hash, registers it, returns valid.
  /// Subsequent calls: computes hash, compares against registered hash.
  /// Mismatch: returns invalid — pipeline must halt.
  Future<HashVerifyResult> verify({String? rawJson}) async {
    final raw = rawJson ?? await rootBundle.loadString(_enginePath);
    final computed = sha256.convert(utf8.encode(raw)).toString();

    // First load — register and pass
    if (_registeredHash == null) {
      _registeredHash = computed;
      return HashVerifyResult.unregistered(computed);
    }

    // Subsequent loads — compare
    if (computed != _registeredHash) {
      return HashVerifyResult.fail(
        computedHash: computed,
        expectedHash: _registeredHash!,
        error: 'HASH_001: Protocol hash mismatch. '
            'asha_engine.json has been modified since last verified load. '
            'Expected: ${_registeredHash!.substring(0, 16)}… '
            'Got: ${computed.substring(0, 16)}… '
            'Pipeline halted. Re-install app or restore signed engine bundle.',
      );
    }

    return HashVerifyResult.pass(computed);
  }

  /// Verifies against an externally provided expected hash.
  /// Used when the signed hash is distributed separately (e.g. from server).
  HashVerifyResult verifyAgainst({
    required String rawJson,
    required String expectedHash,
  }) {
    final computed = sha256.convert(utf8.encode(rawJson)).toString();

    if (computed != expectedHash) {
      return HashVerifyResult.fail(
        computedHash: computed,
        expectedHash: expectedHash,
        error: 'HASH_002: Engine JSON does not match signed expected hash. '
            'Possible tampering or corrupted bundle. Pipeline halted.',
      );
    }

    _registeredHash = computed;
    return HashVerifyResult.pass(computed);
  }

  /// Returns the currently registered hash (for audit log).
  String? get registeredHash => _registeredHash;

  /// Resets the registered hash — use only in tests.
  void resetForTesting() => _registeredHash = null;
}
