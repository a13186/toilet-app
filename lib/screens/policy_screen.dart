import 'package:flutter/material.dart';

const _kTermsContent = '''
제1조 (목적)
이 약관은 화장실 찾기 앱(이하 "서비스")의 이용조건 및 절차에 관한 기본적인 사항을 규정함을 목적으로 합니다.

제2조 (용어의 정의)
1. "서비스"란 화장실 찾기 앱을 통해 제공되는 화장실 위치 정보 및 커뮤니티 기능을 말합니다.
2. "이용자"란 이 약관에 동의하고 서비스를 이용하는 모든 사람을 말합니다.

제3조 (약관의 효력 및 변경)
1. 이 약관은 서비스 화면에 게시하거나 기타 방법으로 공지함으로써 효력이 발생합니다.
2. 운영자는 관련 법령을 위반하지 않는 범위 내에서 약관을 개정할 수 있으며, 변경 시 사전 공지합니다.

제4조 (서비스의 제공)
1. 서비스는 전국 공중화장실 위치 정보를 지도 기반으로 제공합니다.
2. 이용자는 화장실 정보를 직접 등록하거나 평가·후기를 작성할 수 있습니다.
3. 서비스는 행정안전부 공공데이터 및 OpenStreetMap 데이터를 활용합니다.

제5조 (이용자의 의무)
1. 이용자는 허위 정보를 등록하거나 타인을 비방하는 내용을 작성해서는 안 됩니다.
2. 이용자는 서비스 운영을 방해하는 행위를 해서는 안 됩니다.
3. 부적절한 콘텐츠는 운영자에 의해 삭제될 수 있습니다.

제6조 (책임의 한계)
운영자는 이용자가 서비스를 통해 취득한 화장실 정보의 정확성·신뢰성을 보장하지 않으며, 이와 관련하여 발생한 손해에 대해 책임을 지지 않습니다.

제7조 (서비스의 중단)
운영자는 시스템 점검, 통신 장애, 천재지변 등 불가피한 사유가 있는 경우 서비스 제공을 중단할 수 있습니다.

제8조 (준거법 및 재판 관할)
이 약관은 대한민국 법령에 따라 해석되며, 분쟁이 발생한 경우 운영자의 주소지 관할 법원을 전속 관할 법원으로 합니다.

부칙
이 약관은 2025년 1월 1일부터 시행합니다.
''';

const _kPrivacyContent = '''
화장실 찾기(이하 "서비스")는 이용자의 개인정보를 소중히 여기며, 「개인정보 보호법」에 따라 아래와 같이 개인정보 처리방침을 공지합니다.

제1조 (수집하는 개인정보 항목)
서비스는 다음과 같은 최소한의 정보를 수집합니다.
· 기기 고유 식별자(Device ID): 화장실 등록, 평가, 즐겨찾기 관리 등 서비스 이용을 위해 자동으로 수집됩니다.
· 위치 정보: 주변 화장실 검색을 위해 이용자의 동의를 받아 수집되며, 서버에 저장되지 않습니다.

제2조 (개인정보 수집 및 이용 목적)
수집된 정보는 다음 목적으로만 사용됩니다.
1. 화장실 정보 등록 및 조회 서비스 제공
2. 이용자 작성 평가·후기 관리
3. 즐겨찾기 및 방문 기록 서비스 제공
4. 서비스 품질 개선

제3조 (개인정보 보유 및 이용 기간)
서비스 이용 종료(앱 삭제) 시까지 보유하며, 이용자 요청 시 즉시 삭제합니다. 단, 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보유합니다.

제4조 (개인정보의 제3자 제공)
서비스는 이용자의 개인정보를 제3자에게 제공하지 않습니다. 단, 법령의 규정에 의한 경우는 예외로 합니다.

제5조 (개인정보 처리 위탁)
서비스는 데이터베이스 관리를 위해 Supabase(미국 소재)를 이용하며, 수집된 데이터는 해당 서비스의 서버에 저장됩니다. Supabase의 개인정보 처리방침은 supabase.com/privacy에서 확인하실 수 있습니다.

제6조 (이용자의 권리)
이용자는 언제든지 자신의 정보에 대한 조회·수정·삭제를 요청할 수 있습니다.

제7조 (위치정보의 보호)
위치 정보는 이용자가 화장실 검색 시에만 사용되며, 서버에 저장되지 않습니다.

제8조 (개인정보 보호책임자)
개인정보 관련 문의는 앱 내 서비스 안내를 통해 연락하시기 바랍니다.

부칙
이 방침은 2025년 1월 1일부터 시행합니다.
''';

enum PolicyType { terms, privacy }

class PolicyScreen extends StatelessWidget {
  final PolicyType type;

  const PolicyScreen.terms({super.key}) : type = PolicyType.terms;
  const PolicyScreen.privacy({super.key}) : type = PolicyType.privacy;

  String get _title => switch (type) {
        PolicyType.terms => '이용약관',
        PolicyType.privacy => '개인정보 처리방침',
      };

  String get _content => switch (type) {
        PolicyType.terms => _kTermsContent,
        PolicyType.privacy => _kPrivacyContent,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Text(
          _content,
          style: const TextStyle(fontSize: 14, height: 1.75, color: Colors.black87),
        ),
      ),
    );
  }
}
