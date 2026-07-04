/// 음성·키보드 입력 다이얼로그가 닫혔다 열려도 초안을 유지합니다.

class VoiceInputSession {

  String committed = '';

  String displayDraft = '';

  bool preferKeyboard = false;



  void sync({

    required String committed,

    required String display,

    bool? preferKeyboard,

  }) {

    this.committed = committed;

    displayDraft = display;

    if (preferKeyboard != null) this.preferKeyboard = preferKeyboard;

  }



  void clear() {

    committed = '';

    displayDraft = '';

    preferKeyboard = false;

  }



  bool get hasDraft => displayDraft.trim().isNotEmpty || committed.trim().isNotEmpty;

}

