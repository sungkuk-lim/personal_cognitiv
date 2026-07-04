import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/person_avatar_utils.dart';

class PersonContactPhotoIndex {
  const PersonContactPhotoIndex({
    required this.photos,
    required this.contactsWithPhotos,
  });

  final Map<String, Uint8List> photos;
  final int contactsWithPhotos;
}

class PersonContactAvatarService {
  static Future<bool> ensurePermission() async {
    if (await FlutterContacts.requestPermission(readonly: true)) return true;
    final status = await Permission.contacts.request();
    if (!status.isGranted) return false;
    return FlutterContacts.requestPermission(readonly: true);
  }

  static Future<PersonContactPhotoIndex> loadPhotoIndex() async {
    if (!await ensurePermission()) {
      return const PersonContactPhotoIndex(photos: {}, contactsWithPhotos: 0);
    }

    final briefs = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
      withPhoto: false,
    );

    final index = <String, Uint8List>{};
    var contactsWithPhotos = 0;
    for (final brief in briefs) {
      var bytes = _contactPhotoBytes(brief);
      bytes ??= await _loadContactPhoto(brief.id);
      if (bytes == null || bytes.isEmpty) continue;
      contactsWithPhotos++;
      _indexPhoto(index, bytes, brief);
    }
    return PersonContactPhotoIndex(photos: index, contactsWithPhotos: contactsWithPhotos);
  }

  /// 캐시에 없을 때 연락처에서 직접 사진을 찾습니다.
  static Future<Uint8List?> lookupPhotoForName(String rawName) async {
    if (!await ensurePermission()) return null;

    final graphKeys = contactLookupAliases(rawName);
    if (graphKeys.isEmpty) return null;

    final briefs = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
      withPhoto: false,
    );

    for (final brief in briefs) {
      final contactKeys = _contactKeys(brief);
      if (!contactKeysOverlap(contactKeys, graphKeys)) continue;
      final bytes = await _loadContactPhoto(brief.id);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    return null;
  }

  static Uint8List? photoForName(Map<String, Uint8List> index, String rawName) {
    if (index.isEmpty) return null;

    for (final key in contactLookupAliases(rawName)) {
      final exact = index[key];
      if (exact != null) return exact;
    }

    final graphKeys = contactLookupAliases(rawName);
    Uint8List? best;
    var bestScore = 0;
    for (final entry in index.entries) {
      if (graphKeys.contains(entry.key)) return entry.value;
      for (final graphKey in graphKeys) {
        final score = contactNameMatchScoreForKeys(entry.key, graphKey);
        if (score > bestScore) {
          bestScore = score;
          best = entry.value;
        }
      }
    }
    return bestScore >= 6 ? best : null;
  }

  static Future<Uint8List?> _loadContactPhoto(String contactId) async {
    try {
      var full = await FlutterContacts.getContact(
        contactId,
        withProperties: true,
        withThumbnail: true,
        withPhoto: false,
      );
      var bytes = _contactPhotoBytes(full);
      if (bytes != null) return bytes;

      full = await FlutterContacts.getContact(
        contactId,
        withProperties: true,
        withThumbnail: false,
        withPhoto: true,
      );
      return _contactPhotoBytes(full);
    } catch (e, stack) {
      debugPrint('PersonContactAvatarService photo load failed: $e\n$stack');
      return null;
    }
  }

  static Uint8List? _contactPhotoBytes(Contact? contact) {
    if (contact == null) return null;
    final bytes = contact.photoOrThumbnail;
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }

  static List<String> _contactKeys(Contact contact) {
    return contactIndexKeysForContact(
      displayName: contact.displayName,
      firstName: contact.name.first,
      lastName: contact.name.last,
      nickname: contact.name.nickname,
      middleName: contact.name.middle,
    );
  }

  static void _indexPhoto(Map<String, Uint8List> index, Uint8List photo, Contact contact) {
    for (final key in _contactKeys(contact)) {
      index.putIfAbsent(key, () => photo);
    }
  }
}
