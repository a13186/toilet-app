import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  static Future<void> openGoogleMaps(double lat, double lng) async {
    final appUri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng'
        '&travelmode=walking',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openKakaoMap(
      double lat, double lng, String name) async {
    final appUri = Uri.parse('kakaomap://route?ep=$lat,$lng&by=FOOT');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      final encodedName = Uri.encodeComponent(name);
      final webUri = Uri.parse(
          'https://map.kakao.com/link/to/$encodedName,$lat,$lng');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openNaverMap(
      double lat, double lng, String name, String appName) async {
    final encodedName = Uri.encodeComponent(name);
    final appUri = Uri.parse(
        'nmap://navigation?elat=$lat&elng=$lng&ename=$encodedName&appname=$appName');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      final webUri = Uri.parse(
          'https://map.naver.com/v5/directions/-/-/-/walk?c=$lng,$lat,15,0,0,0,dh');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
