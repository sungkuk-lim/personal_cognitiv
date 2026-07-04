import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../services/person_contact_avatar_service.dart';
import '../utils/person_avatar_utils.dart';
import 'app_providers.dart';

class PersonAvatarCacheState {
  const PersonAvatarCacheState({
    required this.photos,
    required this.loaded,
    required this.contactsEnabled,
    this.contactsWithPhotos = 0,
    this.loading = false,
  });

  final Map<String, Uint8List> photos;
  final bool loaded;
  final bool contactsEnabled;
  final int contactsWithPhotos;
  final bool loading;

  static const empty = PersonAvatarCacheState(
    photos: {},
    loaded: false,
    contactsEnabled: false,
    contactsWithPhotos: 0,
  );

  Uint8List? photoFor(String rawName) => PersonContactAvatarService.photoForName(photos, rawName);

  PersonAvatarCacheState copyWith({
    Map<String, Uint8List>? photos,
    bool? loaded,
    bool? contactsEnabled,
    int? contactsWithPhotos,
    bool? loading,
  }) {
    return PersonAvatarCacheState(
      photos: photos ?? this.photos,
      loaded: loaded ?? this.loaded,
      contactsEnabled: contactsEnabled ?? this.contactsEnabled,
      contactsWithPhotos: contactsWithPhotos ?? this.contactsWithPhotos,
      loading: loading ?? this.loading,
    );
  }
}

class PersonAvatarCacheNotifier extends StateNotifier<PersonAvatarCacheState> {
  PersonAvatarCacheNotifier(this._prefs) : super(PersonAvatarCacheState.empty);

  final SharedPreferences _prefs;

  Future<void> warmIfEnabled() async {
    final enabled = readContactPersonAvatarsEnabled(_prefs);
    if (!enabled) {
      state = PersonAvatarCacheState.empty;
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, contactsEnabled: true);
    final result = await PersonContactAvatarService.loadPhotoIndex();
    state = PersonAvatarCacheState(
      photos: result.photos,
      loaded: true,
      contactsEnabled: readContactPersonAvatarsEnabled(_prefs),
      contactsWithPhotos: result.contactsWithPhotos,
      loading: false,
    );
  }

  void clearContactPhotos() {
    state = PersonAvatarCacheState.empty;
  }

  void mergePhotoForName(String rawName, Uint8List photo) {
    final next = Map<String, Uint8List>.from(state.photos);
    for (final key in contactLookupAliases(rawName)) {
      next.putIfAbsent(key, () => photo);
    }
    state = PersonAvatarCacheState(
      photos: next,
      loaded: true,
      contactsEnabled: readContactPersonAvatarsEnabled(_prefs),
      contactsWithPhotos: state.contactsWithPhotos,
      loading: false,
    );
  }
}

final personAvatarCacheProvider =
    StateNotifierProvider<PersonAvatarCacheNotifier, PersonAvatarCacheState>((ref) {
  return PersonAvatarCacheNotifier(ref.read(preferencesProvider));
});
