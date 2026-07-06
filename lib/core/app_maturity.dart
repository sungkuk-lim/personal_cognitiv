/// 앱 완성도 추정 (0–100).

///

/// [kProCloudGatePercent] 미만: 개발·QA — 관계망 AI 등 클라우드 기능을 Pro·로그인 없이 테스트.

/// [kProCloudGatePercent] 이상: Pro·클라우드 게이트 적용 + 사용자에게 1회 안내.

const int kAppCompletionPercent = 95;



/// Pro·클라우드 게이트가 켜지는 완성도 하한 (상용화 기준).

const int kProCloudGatePercent = 90;



/// Pro·클라우드 설정을 요구하는 helper.

bool get requiresProCloudForGraphAi => kAppCompletionPercent >= kProCloudGatePercent;



/// AI 대화 검색·클라우드 동기화 등 — [kProCloudGatePercent] 이상부터 Pro·로그인 게이트.

bool get requiresProCloudForCloudFeatures => isAppMaturityProductionReady;



/// 출시 준비 완료([kProCloudGatePercent]+) 여부.

bool get isAppMaturityProductionReady => kAppCompletionPercent >= kProCloudGatePercent;

