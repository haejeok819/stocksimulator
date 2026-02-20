String toUserMessage(Object error, {String fallback = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.'}) {
  final String raw = error.toString().trim();
  final String normalized = raw
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  if (normalized.isEmpty) {
    return fallback;
  }

  if (normalized.contains('Requested asset does not exist') ||
      normalized.contains('Year asset not found') ||
      normalized.contains('Top50 meta asset not found')) {
    return '선택한 자산의 데이터 파일을 찾을 수 없습니다. 앱을 최신 버전으로 업데이트한 뒤 다시 시도해주세요.';
  }

  if (normalized.contains('거래일 데이터를 찾을 수 없습니다') || normalized.contains('연도별 데이터가 없습니다')) {
    return '선택한 자산의 거래일 데이터가 아직 준비되지 않았습니다.';
  }

  if (normalized.contains('선택한 기간에 거래 데이터가 없습니다')) {
    return '선택한 기간에는 거래 데이터가 없습니다. 기간을 다시 선택해주세요.';
  }

  return normalized;
}
