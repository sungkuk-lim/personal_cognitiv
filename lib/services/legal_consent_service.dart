import 'package:shared_preferences/shared_preferences.dart';

const String prefLegalConsentAccepted = 'legal_consent_accepted_v1';
const String prefLegalConsentVersion = 'legal_consent_version';
const int kCurrentLegalConsentVersion = 1;

bool readLegalConsentAccepted(SharedPreferences prefs) {
  final version = prefs.getInt(prefLegalConsentVersion) ?? 0;
  return prefs.getBool(prefLegalConsentAccepted) == true &&
      version >= kCurrentLegalConsentVersion;
}

Future<void> writeLegalConsentAccepted(SharedPreferences prefs) async {
  await prefs.setBool(prefLegalConsentAccepted, true);
  await prefs.setInt(prefLegalConsentVersion, kCurrentLegalConsentVersion);
}
