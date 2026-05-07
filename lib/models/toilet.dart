class Toilet {
  final String id;
  final String name;
  final String? roadAddress;
  final String? address;
  final double latitude;
  final double longitude;
  final String type;
  final bool isPaid;
  final int maleToilets;
  final int maleUrinals;
  final int femaleToilets;
  final int disabledMaleToilets;
  final int disabledFemaleToilets;
  final int childMaleToilets;
  final int childFemaleToilets;
  final bool? babyChangingMale;
  final bool? babyChangingFemale;
  final bool? emergencyBell;
  final String? openTime;
  final String? openTimeDetail;
  final String? managementOrg;
  final String? managementTel;
  final double? avgCleanliness;
  final bool? hasBidet;
  final bool? hasPaper;
  final int ratingCount;
  final double? distanceMeters;

  const Toilet({
    required this.id,
    required this.name,
    this.roadAddress,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.isPaid,
    this.maleToilets = 0,
    this.maleUrinals = 0,
    this.femaleToilets = 0,
    this.disabledMaleToilets = 0,
    this.disabledFemaleToilets = 0,
    this.childMaleToilets = 0,
    this.childFemaleToilets = 0,
    this.babyChangingMale,
    this.babyChangingFemale,
    this.emergencyBell,
    this.openTime,
    this.openTimeDetail,
    this.managementOrg,
    this.managementTel,
    this.avgCleanliness,
    this.hasBidet,
    this.hasPaper,
    this.ratingCount = 0,
    this.distanceMeters,
  });

  factory Toilet.fromMap(Map<String, dynamic> m) => Toilet(
        id: m['id'] as String,
        name: m['name'] as String,
        roadAddress: m['road_address'] as String?,
        address: m['address'] as String?,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        type: m['type'] as String? ?? 'public',
        isPaid: m['is_paid'] as bool? ?? false,
        maleToilets: m['male_toilets'] as int? ?? 0,
        maleUrinals: m['male_urinals'] as int? ?? 0,
        femaleToilets: m['female_toilets'] as int? ?? 0,
        disabledMaleToilets: m['disabled_male_toilets'] as int? ?? 0,
        disabledFemaleToilets: m['disabled_female_toilets'] as int? ?? 0,
        childMaleToilets: m['child_male_toilets'] as int? ?? 0,
        childFemaleToilets: m['child_female_toilets'] as int? ?? 0,
        babyChangingMale: m['baby_changing_male'] as bool?,
        babyChangingFemale: m['baby_changing_female'] as bool?,
        emergencyBell: m['emergency_bell'] as bool?,
        openTime: m['open_time'] as String?,
        openTimeDetail: m['open_time_detail'] as String?,
        managementOrg: m['management_org'] as String?,
        managementTel: m['management_tel'] as String?,
        avgCleanliness: (m['avg_cleanliness'] as num?)?.toDouble(),
        hasBidet: m['has_bidet'] as bool?,
        hasPaper: m['has_paper'] as bool?,
        ratingCount: m['rating_count'] as int? ?? 0,
        distanceMeters: (m['distance_meters'] as num?)?.toDouble(),
      );

  String get typeLabel => switch (type) {
        'public' => '공중화장실',
        'open' => '개방화장실',
        'simple' => '간이화장실',
        'mobile' => '이동화장실',
        'private' => '사설화장실',
        _ => '화장실',
      };

  String get distanceLabel {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) return '${distanceMeters!.round()}m';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}
