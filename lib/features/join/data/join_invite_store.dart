import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinInviteStore {
  JoinInviteStore._();
  static final JoinInviteStore instance = JoinInviteStore._();

  static const _prefsKey = 'join_invite_records_v1';
  static const _activeSessionKey = 'join_invite_active_session_v1';

  final List<JoinInviteRecord> _records = [];
  String? _activeInviteId;
  bool _loaded = false;

  List<JoinInviteRecord> get records => List.unmodifiable(_records);
  String? get activeInviteId => _activeInviteId;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _records.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _records.add(
                JoinInviteRecord.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } catch (_) {}
    }
    _activeInviteId = prefs.getString(_activeSessionKey);
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_records.map((e) => e.toJson()).toList()),
    );
    if (_activeInviteId == null) {
      await prefs.remove(_activeSessionKey);
    } else {
      await prefs.setString(_activeSessionKey, _activeInviteId!);
    }
  }

  String generatePassword({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<List<JoinInviteRecord>> createManualInvites({
    required List<
            ({
              String contact,
              JoinInviteChannel channel,
              String locationId,
              String locationName
            })>
        rows,
    String companyName = 'Acme Corporation',
  }) async {
    await ensureLoaded();
    final now = DateTime.now();
    final created = <JoinInviteRecord>[];
    for (final row in rows) {
      final record = JoinInviteRecord(
        id: 'invite_${now.microsecondsSinceEpoch}_${created.length}',
        contact: row.contact.trim(),
        channel: row.channel,
        source: JoinInviteSource.manual,
        password: generatePassword(),
        status: JoinInviteStatus.invited,
        createdAt: now,
        locationId: row.locationId,
        locationName: row.locationName,
        companyName: companyName,
      );
      created.add(record);
      _records.insert(0, record);
    }
    await _persist();
    return created;
  }

  Future<JoinInviteRecord> createLinkInvitePlaceholder({
    String companyName = 'Acme Corporation',
  }) async {
    await ensureLoaded();
    final now = DateTime.now();
    final record = JoinInviteRecord(
      id: 'link_${now.microsecondsSinceEpoch}',
      contact: JoinShareLinks.generateTempEmail(),
      channel: JoinInviteChannel.email,
      source: JoinInviteSource.link,
      password: generatePassword(),
      status: JoinInviteStatus.invited,
      createdAt: now,
      companyName: companyName,
    );
    _records.insert(0, record);
    await _persist();
    return record;
  }

  JoinInviteRecord? findByCredentials({
    required String contact,
    required String password,
  }) {
    final c = contact.trim().toLowerCase();
    final p = password.trim();
    for (final record in _records) {
      if (record.password != p) continue;
      if (record.contact.trim().toLowerCase() == c) return record;
    }
    return null;
  }

  Future<JoinInviteRecord?> bindContactAndJoin({
    required String id,
    required String contact,
  }) async {
    await ensureLoaded();
    final index = _records.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final current = _records[index];
    final withContact = JoinInviteRecord(
      id: current.id,
      contact: contact.trim(),
      channel: contact.contains('@')
          ? JoinInviteChannel.email
          : JoinInviteChannel.phone,
      source: current.source,
      password: current.password,
      status: current.status,
      createdAt: current.createdAt,
      locationId: current.locationId,
      locationName: current.locationName,
      companyName: current.companyName,
      joinedAt: current.joinedAt,
      reviewedAt: current.reviewedAt,
    );
    _records[index] = withContact;
    await _persist();
    return markJoined(id);
  }

  bool hasContact(String contact) {
    final c = contact.trim().toLowerCase();
    return _records.any((r) => r.contact.trim().toLowerCase() == c);
  }

  JoinInviteRecord? byId(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  JoinInviteRecord? get activeInvite =>
      _activeInviteId == null ? null : byId(_activeInviteId!);

  Future<JoinInviteRecord?> markJoined(String id) async {
    await ensureLoaded();
    final index = _records.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final current = _records[index];
    final nextStatus = current.source == JoinInviteSource.manual
        ? JoinInviteStatus.autoApproved
        : JoinInviteStatus.pendingApproval;
    final updated = current.copyWith(
      status: nextStatus,
      joinedAt: DateTime.now(),
    );
    _records[index] = updated;
    _activeInviteId = updated.id;
    await _persist();
    return updated;
  }

  Future<JoinInviteRecord?> review({
    required String id,
    required bool approve,
    String? locationId,
    String? locationName,
  }) async {
    await ensureLoaded();
    final index = _records.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final updated = _records[index].copyWith(
      status: approve ? JoinInviteStatus.approved : JoinInviteStatus.rejected,
      reviewedAt: DateTime.now(),
      locationId: locationId,
      locationName: locationName,
    );
    _records[index] = updated;
    await _persist();
    return updated;
  }

  Future<void> assignLocation({
    required String id,
    required String locationId,
    required String locationName,
  }) async {
    await ensureLoaded();
    final index = _records.indexWhere((e) => e.id == id);
    if (index < 0) return;
    _records[index] = _records[index].copyWith(
      locationId: locationId,
      locationName: locationName,
    );
    await _persist();
  }

  Future<void> setActiveInvite(String? id) async {
    await ensureLoaded();
    _activeInviteId = id;
    await _persist();
  }

  Future<void> clearActiveInvite() async {
    await setActiveInvite(null);
  }

  List<JoinInviteRecord> managerAlertItems() {
    return _records
        .where(
          (r) =>
              r.status == JoinInviteStatus.pendingApproval ||
              r.status == JoinInviteStatus.autoApproved ||
              r.status == JoinInviteStatus.approved ||
              r.status == JoinInviteStatus.rejected,
        )
        .toList(growable: false);
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _records.clear();
    _activeInviteId = null;
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_activeSessionKey);
  }
}
