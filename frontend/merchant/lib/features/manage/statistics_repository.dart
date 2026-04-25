import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef StatisticsRange = ({DateTime from, DateTime to});

class VisitsOverview {
  final int totalViews;
  final int uniqueSessions;
  const VisitsOverview({required this.totalViews, required this.uniqueSessions});
}

class VisitsByDayPoint {
  final DateTime day;
  final int count;
  const VisitsByDayPoint(this.day, this.count);
}

class TopDish {
  final String dishId;
  final String dishName;
  final int count;
  const TopDish({required this.dishId, required this.dishName, required this.count});
}

class LocaleTraffic {
  final String locale;
  final int count;
  const LocaleTraffic(this.locale, this.count);
}

class StatisticsData {
  final VisitsOverview overview;
  final List<VisitsByDayPoint> byDay;
  final List<TopDish> topDishes;
  final List<LocaleTraffic> byLocale;
  const StatisticsData({
    required this.overview,
    required this.byDay,
    required this.topDishes,
    required this.byLocale,
  });
}

class StatisticsRepository {
  StatisticsRepository(this._client);
  final SupabaseClient _client;

  Future<StatisticsData> fetch({required String storeId, required StatisticsRange range}) async {
    final from = range.from.toUtc().toIso8601String();
    final to = range.to.toUtc().toIso8601String();
    final overview = await _client.rpc('get_visits_overview',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    final byDay = await _client.rpc('get_visits_by_day',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    final topDishes = await _client.rpc('get_top_dishes',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to, 'p_limit': 5});
    final byLocale = await _client.rpc('get_traffic_by_locale',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    return StatisticsData(
      overview: _overviewFromJson(overview as Map<String, dynamic>),
      byDay: ((byDay as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_dayFromJson)
          .toList(growable: false),
      topDishes: ((topDishes as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_topDishFromJson)
          .toList(growable: false),
      byLocale: ((byLocale as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_localeFromJson)
          .toList(growable: false),
    );
  }

  Future<String> exportCsv({required String storeId, required StatisticsRange range}) async {
    final res = await _client.functions.invoke(
      'export-statistics-csv',
      body: {
        'store_id': storeId,
        'from': range.from.toUtc().toIso8601String(),
        'to': range.to.toUtc().toIso8601String(),
      },
    );
    final data = res.data;
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    throw StateError('Unexpected CSV response type: ${data.runtimeType}');
  }
}

VisitsOverview _overviewFromJson(Map<String, dynamic> j) => VisitsOverview(
      totalViews: (j['total_views'] as num?)?.toInt() ?? 0,
      uniqueSessions: (j['unique_sessions'] as num?)?.toInt() ?? 0,
    );

VisitsByDayPoint _dayFromJson(Map<String, dynamic> j) => VisitsByDayPoint(
      DateTime.parse(j['day'] as String),
      (j['count'] as num).toInt(),
    );

TopDish _topDishFromJson(Map<String, dynamic> j) => TopDish(
      dishId: j['dish_id'] as String,
      dishName: j['dish_name'] as String,
      count: (j['count'] as num).toInt(),
    );

LocaleTraffic _localeFromJson(Map<String, dynamic> j) => LocaleTraffic(
      j['locale'] as String,
      (j['count'] as num).toInt(),
    );
