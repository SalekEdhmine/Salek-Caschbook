import 'dart:math';

const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
final _rand = Random.secure();

/// Erzeugt eine 15-stellige ID im PocketBase-Format, damit lokal
/// erzeugte Datensätze schon vor dem Sync die gleiche ID wie auf dem
/// Server haben (kein Remapping von Fremdschlüsseln nötig).
String generatePbId() =>
    List.generate(15, (_) => _chars[_rand.nextInt(_chars.length)]).join();
