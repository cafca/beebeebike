import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../providers/auth_provider.dart';
import '../providers/home_eta_provider.dart';
import '../providers/location_provider.dart';
import '../providers/brush_provider.dart';
import '../providers/route_provider.dart';
import '../providers/search_history_provider.dart';
import '../screens/login_screen.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paint_roller_icon.dart';
import 'saved_item.dart';

/// Landing-state bottom sheet. Two snap points: peek (~16 %) and a mid
/// stop sized to fit the Go Home row + three recent items. Paint FAB is
/// visually present but disabled in this build.
class HomeSheet extends ConsumerStatefulWidget {
  const HomeSheet({
    super.key,
    required this.onNavigateHome,
    required this.sheetController,
  });

  final VoidCallback onNavigateHome;
  final DraggableScrollableController sheetController;

  @override
  ConsumerState<HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends ConsumerState<HomeSheet> {
  static const double _peek = 0.16;
  static const double _mid = 0.46;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: widget.sheetController,
      initialChildSize: _peek,
      minChildSize: _peek,
      maxChildSize: _mid,
      snap: true,
      snapSizes: const [_peek, _mid],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BbbColors.panel,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
            boxShadow: BbbShadow.panel,
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              const _Grabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _GoHomeRow(onNavigateHome: widget.onNavigateHome),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _RecentSection(sheetController: widget.sheetController),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: BbbColors.grabber,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _GoHomeRow extends ConsumerWidget {
  const _GoHomeRow({required this.onNavigateHome});

  final VoidCallback onNavigateHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final loggedIn = user?.email != null;
    final home = ref.watch(homeLocationProvider).valueOrNull;
    final enabled = home != null;
    final eta = enabled ? ref.watch(homeEtaMinutesProvider) : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: loggedIn
              ? _GoHomeButton(
                  enabled: enabled,
                  etaMinutes: eta,
                  onTap: enabled ? onNavigateHome : null,
                )
              : const _LogInButton(),
        ),
        const SizedBox(width: 10),
        const _PaintFab(),
      ],
    );
  }
}

class _LogInButton extends StatelessWidget {
  const _LogInButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: BbbColors.ink,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.login_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.settingsLogIn,
                  style: BbbText.cardTitle().copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoHomeButton extends StatelessWidget {
  const _GoHomeButton({
    required this.enabled,
    required this.etaMinutes,
    this.onTap,
  });

  final bool enabled;
  final AsyncValue<int?>? etaMinutes;
  final VoidCallback? onTap;

  String? _subtitle() {
    if (!enabled) return null;
    final eta = etaMinutes;
    if (eta == null) return null;
    return eta.when(
      loading: () => 'Calculating ETA…',
      error: (_, __) => '—',
      data: (mins) => mins == null ? '—' : '$mins min',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = _subtitle();
    final bg = enabled ? BbbColors.ink : BbbColors.bgAlt;
    final fg = enabled ? Colors.white : BbbColors.inkFaint;
    final iconBg = enabled
        ? const Color.fromRGBO(255, 255, 255, 0.14)
        : BbbColors.divider;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 17,
                  color: fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeGoHome,
                      style: BbbText.cardTitle().copyWith(color: fg),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: BbbText.monoSub(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaintFab extends ConsumerWidget {
  const _PaintFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = ref.watch(
      brushControllerProvider.select((s) => s.paintMode),
    );
    final label = active ? l10n.paintExit : l10n.paintEnter;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Material(
            key: const ValueKey('paint-fab'),
            color: active ? BbbColors.brand : BbbColors.panel,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: active ? BbbColors.brand : BbbColors.divider,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(BbbRadius.ctrl),
            ),
            child: InkWell(
              onTap: () =>
                  ref.read(brushControllerProvider.notifier).togglePaintMode(),
              borderRadius: BorderRadius.circular(BbbRadius.ctrl),
              child: const Center(child: PaintRollerIcon(size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

class _EyebrowLabel extends StatelessWidget {
  const _EyebrowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: BbbText.eyebrow());
  }
}

/// Recent destinations. Hidden when history is empty. Straight-line distances
/// compute lazily on first sheet pull-up (size > peek) to avoid GPS cost when
/// the sheet stays collapsed.
class _RecentSection extends ConsumerStatefulWidget {
  const _RecentSection({required this.sheetController});

  final DraggableScrollableController sheetController;

  @override
  ConsumerState<_RecentSection> createState() => _RecentSectionState();
}

class _RecentSectionState extends ConsumerState<_RecentSection> {
  static const double _pullThreshold = 0.25;
  bool _distancesRequested = false;
  Map<String, double>? _distancesMeters;

  @override
  void initState() {
    super.initState();
    widget.sheetController.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    widget.sheetController.removeListener(_onSheetChanged);
    super.dispose();
  }

  void _onSheetChanged() {
    if (_distancesRequested) return;
    if (!widget.sheetController.isAttached) return;
    if (widget.sheetController.size <= _pullThreshold) return;
    _distancesRequested = true;
    _computeDistances();
  }

  Future<void> _computeDistances() async {
    final history = ref.read(searchHistoryProvider);
    if (history.isEmpty) return;
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final map = <String, double>{};
    for (final loc in history.take(3)) {
      map[loc.id] = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        loc.lat,
        loc.lng,
      );
    }
    setState(() => _distancesMeters = map);
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _onTap(Location destination) async {
    final notifier = ref.read(routeControllerProvider.notifier);
    if (ref.read(routeControllerProvider).origin == null) {
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition();
      } catch (_) {}
      if (!mounted) return;
      notifier.setOrigin(Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lng: pos?.longitude ?? 13.4533,
        lat: pos?.latitude ?? 52.5065,
      ));
    }
    notifier.setDestination(destination);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(searchHistoryProvider).take(3).toList();
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: _EyebrowLabel(l10n.searchSectionRecent.toUpperCase()),
        ),
        for (var i = 0; i < history.length; i++)
          SavedItem(
            icon: Icons.history,
            iconBg: BbbColors.bgAlt,
            iconColor: BbbColors.inkMuted,
            title: history[i].name,
            subtitle: history[i].label,
            time: _formatDistance(_distancesMeters?[history[i].id]),
            onTap: () => _onTap(history[i]),
            isLast: i == history.length - 1,
          ),
      ],
    );
  }
}

