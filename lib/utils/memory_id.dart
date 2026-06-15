import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 로컬·게스트 모드 기억에 클라이언트 측 고유 ID를 부여합니다.
String generateMemoryId() => _uuid.v4();

String ensureMemoryId(String id) => id.isNotEmpty ? id : generateMemoryId();
