import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../services/local_memory_store.dart';
import '../utils/trust_source.dart';

class TrustDashboardStats {
  const TrustDashboardStats({
    required this.userRecordCount,
    required this.aiAssistCount,
    required this.hiddenInternalCount,
    required this.storageIsLocal,
    required this.graphAiEnabled,
    required this.memoryPulseEnabled,
    required this.proactiveRecallEnabled,
    required this.cloudConfigured,
  });

  final int userRecordCount;
  final int aiAssistCount;
  final int hiddenInternalCount;
  final bool storageIsLocal;
  final bool graphAiEnabled;
  final bool memoryPulseEnabled;
  final bool proactiveRecallEnabled;
  final bool cloudConfigured;
}

TrustDashboardStats buildTrustDashboardStats({
  required List<Memory> allMemories,
  required SharedPreferences prefs,
  bool guestMode = false,
  bool privacyMode = false,
}) {
  final visible = allMemories.where(isUserFacingMemory).toList();
  return TrustDashboardStats(
    userRecordCount: countUserRecordMemories(visible),
    aiAssistCount: countAiAssistedMemories(visible),
    hiddenInternalCount: allMemories.where((m) => !isUserFacingMemory(m)).length,
    storageIsLocal: isLocalOnlyMode(prefs, privacyMode: privacyMode, guestMode: guestMode) || !AppEnv.isConfigured,
    graphAiEnabled: readGraphAiEnabled(prefs),
    memoryPulseEnabled: readMemoryPulseEnabled(prefs),
    proactiveRecallEnabled: readProactiveRecallEnabled(prefs),
    cloudConfigured: AppEnv.isConfigured,
  );
}
