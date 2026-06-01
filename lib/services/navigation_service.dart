import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  static Future<void> openGoogleMaps(
      double lat, double lng, {double? originLat, double? originLng, String? name}) async {
    // 앱 스킴: 좌표 + 도보 모드(mode=w)
    final appUri = Uri.parse('google.navigation:q=$lat,$lng&mode=w');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      // 웹 폴백: 목적지 좌표, 출발지 생략(현재 위치 자동), 도보 모드
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openKakaoMap(
      double lat, double lng, String name, {double? originLat, double? originLng}) async {
    // sp 생략 시 카카오맵 앱이 GPS 현재 위치를 출발지로 자동 사용, by=FOOT=도보
    final appUri = Uri.parse('kakaomap://route?ep=$lat,$lng&by=FOOT');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      final encodedName = Uri.encodeComponent(name);
      // 웹 폴백: link/walk 접두사로 도보 모드 기본 선택
      final webUri = (originLat != null && originLng != null)
          ? Uri.parse(
              'https://map.kakao.com/link/walk/from/${Uri.encodeComponent('현재위치')},$originLat,$originLng/to/$encodedName,$lat,$lng')
          : Uri.parse('https://map.kakao.com/link/walk/$encodedName,$lat,$lng');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openNaverMap(
      double lat, double lng, String name, String appName,
      {double? originLat, double? originLng}) async {
    final encodedName = Uri.encodeComponent(name);
    // 앱 스킴: 출발지 생략(GPS 현재 위치 자동), type=walk 도보 모드
    final appUri = Uri.parse(
        'nmap://route?elat=$lat&elng=$lng&ename=$encodedName&type=walk&appname=$appName');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      // 웹 폴백: /p/directions/{출발지lng,lat,이름}/{목적지lng,lat,이름}/-/walk
      // 네이버 지도는 경도(lng),위도(lat) 순서
      final destSegment = '$lng,$lat,$encodedName';
      final webUri = (originLat != null && originLng != null)
          ? Uri.parse(
              'https://map.naver.com/p/directions/$originLng,$originLat,${Uri.encodeComponent('현재위치')}/$destSegment/-/walk')
          : Uri.parse(
              'https://map.naver.com/p/directions/-/$destSegment/-/walk');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
