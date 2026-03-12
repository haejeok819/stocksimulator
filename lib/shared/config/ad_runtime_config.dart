class AdRuntimeConfig {
  AdRuntimeConfig._();

  /// 전체 광고 노출 강제 비활성화 스위치.
  ///
  /// - `true`: 광고 제거 구매 여부/저장값과 무관하게 모든 광고를 숨깁니다.
  /// - `false`: 기존 로직(광고 제거 구매 상태)에 따라 광고를 노출합니다.
  static const bool forceDisableAllAds = true;
}
