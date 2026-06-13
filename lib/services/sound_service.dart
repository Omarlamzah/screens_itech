import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Plays synthesized notification/alarm tones with no asset files required.
/// Tones are generated as raw PCM WAV bytes and played via audioplayers.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final _player = AudioPlayer();

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> playSuccess() => _tone(880, 0.18);

  Future<void> playNotification() => _tone(660, 0.28);

  Future<void> playError() => _tone(220, 0.5);

  /// Three-note ascending alarm (like a software alert chime).
  Future<void> playAlarm() async {
    await _tone(440, 0.15);
    await Future.delayed(const Duration(milliseconds: 90));
    await _tone(554, 0.15);
    await Future.delayed(const Duration(milliseconds: 90));
    await _tone(659, 0.35);
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  Future<void> _tone(double hz, double dur) async {
    try {
      await _player.play(BytesSource(_buildWav(hz, dur)));
    } catch (_) {}
  }

  /// Generates a mono 44100 Hz 16-bit PCM WAV with exponential decay envelope.
  static Uint8List _buildWav(double hz, double dur) {
    const rate = 44100;
    final n = (rate * dur).round();
    final buf = ByteData(44 + n * 2);

    // RIFF / WAVE header
    _ascii(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + n * 2, Endian.little);
    _ascii(buf, 8, 'WAVE');
    _ascii(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little); // fmt chunk size
    buf.setUint16(20, 1, Endian.little);  // PCM
    buf.setUint16(22, 1, Endian.little);  // mono
    buf.setUint32(24, rate, Endian.little);
    buf.setUint32(28, rate * 2, Endian.little); // byte rate
    buf.setUint16(32, 2, Endian.little);  // block align
    buf.setUint16(34, 16, Endian.little); // bits per sample
    _ascii(buf, 36, 'data');
    buf.setUint32(40, n * 2, Endian.little);

    // PCM samples with exponential decay
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      final env = math.exp(-t * 6.0);
      final sample = (math.sin(2 * math.pi * hz * t) * 28000 * env)
          .round()
          .clamp(-32768, 32767);
      buf.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  static void _ascii(ByteData b, int off, String s) {
    for (int i = 0; i < s.length; i++) {
      b.setUint8(off + i, s.codeUnitAt(i));
    }
  }
}
