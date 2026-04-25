import 'package:supabase_flutter/supabase_flutter.dart';

class TranslateResult {
  const TranslateResult({
    required this.translatedDishCount,
    required this.translatedCategoryCount,
    required this.availableLocales,
  });
  final int translatedDishCount;
  final int translatedCategoryCount;
  final List<String> availableLocales;
}

class OptimizeResult {
  const OptimizeResult({required this.rewrittenDishCount});
  final int rewrittenDishCount;
}

/// Thrown when an Edge Function returns 402 (locale cap) or 429 (monthly batch
/// quota). The UI uses this to route the merchant to /upgrade.
class AiQuotaError implements Exception {
  const AiQuotaError({required this.code, required this.tier, this.cap});
  final String code; // 'locale_cap_exceeded' | 'ai_quota_exceeded'
  final String? tier;
  final int? cap;

  @override
  String toString() =>
      'AiQuotaError($code, tier=$tier${cap != null ? ', cap=$cap' : ''})';
}

class AiRepository {
  AiRepository(this._client);
  final SupabaseClient _client;

  Future<TranslateResult> translateMenu({
    required String menuId,
    required String targetLocale,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'translate-menu',
        body: {'menu_id': menuId, 'target_locale': targetLocale},
      );
      final data = res.data;
      if (data is Map &&
          data['translatedDishCount'] is num &&
          data['translatedCategoryCount'] is num &&
          data['availableLocales'] is List) {
        return TranslateResult(
          translatedDishCount: (data['translatedDishCount'] as num).toInt(),
          translatedCategoryCount: (data['translatedCategoryCount'] as num).toInt(),
          availableLocales:
              (data['availableLocales'] as List).cast<String>(),
        );
      }
      throw StateError('translate-menu returned unexpected shape: $data');
    } on FunctionException catch (e) {
      _maybeThrowQuota(e);
      rethrow;
    }
  }

  Future<OptimizeResult> optimizeDescriptions({required String menuId}) async {
    try {
      final res = await _client.functions.invoke(
        'ai-optimize',
        body: {'menu_id': menuId},
      );
      final data = res.data;
      if (data is Map && data['rewrittenDishCount'] is num) {
        return OptimizeResult(
          rewrittenDishCount: (data['rewrittenDishCount'] as num).toInt(),
        );
      }
      throw StateError('ai-optimize returned unexpected shape: $data');
    } on FunctionException catch (e) {
      _maybeThrowQuota(e);
      rethrow;
    }
  }

  /// Inspects a [FunctionException] and rethrows as [AiQuotaError] when the
  /// status is 402 or 429 (the two budget-style errors). Other status codes
  /// fall through to the caller's catch block.
  void _maybeThrowQuota(FunctionException e) {
    if (e.status != 402 && e.status != 429) return;
    final detail = e.details;
    if (detail is Map) {
      final code = detail['error']?.toString();
      if (code == 'locale_cap_exceeded' || code == 'ai_quota_exceeded') {
        throw AiQuotaError(
          code: code!,
          tier: detail['tier']?.toString(),
          cap: detail['cap'] is num ? (detail['cap'] as num).toInt() : null,
        );
      }
    }
  }
}
