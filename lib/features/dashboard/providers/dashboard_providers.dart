import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../../services/cache_manager.dart';
import '../../../shared/constants/cache_durations.dart';

final balanceSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final uid = SupabaseService.instance.currentUid;
  if (uid.isEmpty) return {'totalOwed': 0.0, 'totalOwe': 0.0};
  cacheManager.touch('balances', CacheDurations.dashboardBalances);
  return SupabaseService.instance.getBalanceTotals(uid);
});
