class AttemptRecord {
  const AttemptRecord({
    required this.id,
    required this.uid,
    required this.mode,
    required this.tickerA,
    required this.nameA,
    this.tickerB,
    this.nameB,
    required this.startYmd,
    required this.endYmd,
    required this.returnPctA,
    this.returnPctB,
    required this.createdAtIso,
  });

  final String id;
  final String uid;
  final String mode;
  final String tickerA;
  final String nameA;
  final String? tickerB;
  final String? nameB;
  final String startYmd;
  final String endYmd;
  final double returnPctA;
  final double? returnPctB;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'uid': uid,
      'mode': mode,
      'tickerA': tickerA,
      'nameA': nameA,
      'tickerB': tickerB,
      'nameB': nameB,
      'startYmd': startYmd,
      'endYmd': endYmd,
      'returnPctA': returnPctA,
      'returnPctB': returnPctB,
      'createdAtIso': createdAtIso,
    };
  }

  factory AttemptRecord.fromJson(Map<String, dynamic> json) {
    return AttemptRecord(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      mode: json['mode'] as String? ?? 'SIM',
      tickerA: json['tickerA'] as String? ?? '',
      nameA: json['nameA'] as String? ?? '',
      tickerB: json['tickerB'] as String?,
      nameB: json['nameB'] as String?,
      startYmd: json['startYmd'] as String? ?? '',
      endYmd: json['endYmd'] as String? ?? '',
      returnPctA: (json['returnPctA'] as num?)?.toDouble() ?? 0,
      returnPctB: (json['returnPctB'] as num?)?.toDouble(),
      createdAtIso: json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
