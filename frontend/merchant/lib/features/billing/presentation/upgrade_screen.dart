import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../billing_providers.dart';
import '../tier.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});
  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String _currency = 'USD';
  String _period = 'monthly';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final currentTier = ref.watch(currentTierProvider).valueOrNull ?? Tier.free;

    return Scaffold(
      appBar: AppBar(title: Text(t.billingUpgradeTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CurrencyToggle(
              value: _currency,
              onChanged: (c) => setState(() {
                _currency = c;
                if (c == 'CNY') _period = 'monthly'; // CNY annual deferred
              }),
            ),
            if (_currency == 'USD') ...[
              const SizedBox(height: 12),
              _PeriodToggle(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
            ],
            const SizedBox(height: 24),
            _TierCard(tier: Tier.free,   isCurrent: currentTier == Tier.free,   onSubscribe: null),
            const SizedBox(height: 12),
            _TierCard(
              tier: Tier.pro,
              isCurrent: currentTier == Tier.pro,
              onSubscribe: () => _subscribe(Tier.pro),
            ),
            const SizedBox(height: 12),
            _TierCard(
              tier: Tier.growth,
              isCurrent: currentTier == Tier.growth,
              onSubscribe: () => _subscribe(Tier.growth),
            ),
            if (currentTier.isPaid) ...[
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('manage-billing-button'),
                onPressed: _busy ? null : _manageBilling,
                child: Text(t.billingManageBilling),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(Tier tier) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(billingRepositoryProvider)
          .createCheckoutSession(tier: tier, currency: _currency, period: _period);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('launchUrl returned false');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.billingCheckoutFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageBilling() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final url = await ref.read(billingRepositoryProvider).createPortalSession();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.billingCheckoutFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'USD', label: Text(t.billingCurrencyUsd)),
        ButtonSegment(value: 'CNY', label: Text(t.billingCurrencyCny)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'monthly', label: Text(t.billingMonthlyToggle)),
        ButtonSegment(value: 'annual',  label: Text(t.billingAnnualToggle)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.isCurrent, required this.onSubscribe});
  final Tier tier;
  final bool isCurrent;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = switch (tier) {
      Tier.free => t.billingPlanFree,
      Tier.pro => t.billingPlanPro,
      Tier.growth => t.billingPlanGrowth,
    };
    final menus = switch (tier) {
      Tier.free => 1,
      Tier.pro => 5,
      Tier.growth => 9999,
    };
    final dishes = switch (tier) {
      Tier.free => 30,
      Tier.pro => 200,
      Tier.growth => 9999,
    };
    final reparses = switch (tier) {
      Tier.free => 1,
      Tier.pro => 5,
      Tier.growth => 50,
    };
    final qrViews = switch (tier) {
      Tier.free => 2000,
      Tier.pro => 20000,
      Tier.growth => 9999999,
    };
    final languages = switch (tier) {
      Tier.free => 2,
      Tier.pro => 5,
      Tier.growth => 9999,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (isCurrent)
                  Chip(label: Text(t.billingCurrentTag)),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.billingMenusCap(menus)),
            Text(t.billingDishesPerMenuCap(dishes)),
            Text(t.billingReparsesCap(reparses)),
            Text(t.billingQrViewsCap(qrViews)),
            Text(t.billingLanguagesCap(languages)),
            if (tier.isPaid) Text(t.billingCustomBranding),
            if (tier == Tier.growth) Text(t.billingMultiStore),
            if (tier.isPaid) Text(t.billingPriorityCsv),
            const SizedBox(height: 12),
            if (!isCurrent && onSubscribe != null)
              FilledButton(
                key: Key('subscribe-${tier.apiName}-button'),
                onPressed: onSubscribe,
                child: Text(
                  tier == Tier.pro ? t.billingSubscribePro : t.billingSubscribeGrowth,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
