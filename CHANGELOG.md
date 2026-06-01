# 화장실 급해요 - 변경 이력

---

## [1.0.0+3] - 2026-06-01 (공개 테스트 출시)

### 변경
- applicationId / namespace `com.realweb21.toiletapp` → `com.bsangshop.toilet_app` 수정 (`android/app/build.gradle.kts`)
- versionCode 1→2→3 순차 증가 (Play Console 기존 버전 충돌로 인한 재빌드)
- .gitignore에 서명 키 파일(`*.jks`, `*.keystore`, `android/key.properties`) 추가

---

## [미출시] - 진행 중

### 수정
- 구글 지도 길안내 개선: 목적지를 이름 대신 좌표로 전달, 기본 이동수단 도보(mode=w / travelmode=walking) 설정, 출발지 생략으로 현재 위치 자동 사용 (`navigation_service.dart`)
- 카카오맵 길안내 개선: 앱 스킴에서 sp 제거(GPS 현재 위치 자동 사용), 웹 폴백에서 from/to 포맷으로 출발지 좌표 전달, 도보(by=FOOT) 유지 (`navigation_service.dart`)
- 네이버 지도 길안내 개선: nmap://navigation(자동차) → nmap://route?type=walk(도보) 변경, 출발지 파라미터 제거(GPS 자동), 웹 폴백 URL /v5/→/p/ 수정 및 출발지·목적지 좌표 정상 전달 (`navigation_service.dart`)
- 화장실 타입 필터 라벨 오타 수정: '개발' → '개방' (`toilet_list_panel.dart`)
- `toilet.dart` typeLabel에 `'dev'` 타입 → '개방화장실' 케이스 추가
- 패널 최소화 시 Column RenderFlex overflow 5.9px 수정: `_minSize` 0.08 → 0.12로 증가, `ClipRRect` 추가 (`toilet_list_panel.dart`)
- 패널 헤더 텍스트 변경: '내 주변 화장실 xx개' → '내주변 화장실(1km 내) : xx개' (`toilet_list_panel.dart`)
- 커뮤니티 화장실 목록: 주소 없을 때 좌표(📍 lat, lng) 표시 (`community_screen.dart`)
- OSM 임포트 데이터(`device_id=osm_import_v1`) 커뮤니티 목록에서 제외, 실사용자 등록 데이터만 표시 (`community_service.dart`)
- OSM 임포트 데이터를 지도에서 공중화장실(파란 마커)로 표시: `CommunityService.getOsmToilets()` 추가, `map_screen.dart`에서 `Toilet` 객체로 변환 병합 (`community_service.dart`, `map_screen.dart`)
- OSM 화장실 이름 정규화: 이름 없음 또는 '화장실'인 경우 '공중화장실'로 표시 (`map_screen.dart`)

---

## 형식 안내

```
## [버전] - YYYY-MM-DD

### 추가
- 새로 추가된 기능

### 변경
- 기존 기능의 변경 사항

### 수정
- 버그 수정

### 제거
- 제거된 기능
```
