import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/features/voice/voice_input_session.dart';



void main() {

  test('sync preserves committed and display across session reuse', () {

    final session = VoiceInputSession();

    session.sync(committed: '세로 모드에서 말한 내용', display: '세로 모드에서 말한 내용');



    expect(session.committed, '세로 모드에서 말한 내용');

    expect(session.displayDraft, '세로 모드에서 말한 내용');



    session.sync(

      committed: '세로 모드에서 말한 내용',

      display: '세로 모드에서 말한 내용 가로 모드에서 말한 내용',

    );



    expect(session.displayDraft, '세로 모드에서 말한 내용 가로 모드에서 말한 내용');

    expect(session.committed, '세로 모드에서 말한 내용');

  });



  test('clear resets draft and preferred input mode', () {

    final session = VoiceInputSession()

      ..sync(committed: '안녕', display: '안녕하세요', preferKeyboard: true);

    expect(session.hasDraft, isTrue);



    session.clear();



    expect(session.committed, isEmpty);

    expect(session.displayDraft, isEmpty);

    expect(session.preferKeyboard, isFalse);

    expect(session.hasDraft, isFalse);

  });

}

