import 'package:beebeebike/services/rating_fetch_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// A small viewport near Berlin-Mitte used across several tests.
const _berlin = Bbox(
  west: 13.40,
  south: 52.51,
  east: 13.42,
  north: 52.53,
);

void main() {
  group('Bbox', () {
    test('scaleAroundCenter expands by factor around center', () {
      final scaled = _berlin.scaleAroundCenter(2.0);
      // Width/height should double.
      expect(scaled.width, closeTo(_berlin.width * 2, 1e-9));
      expect(scaled.height, closeTo(_berlin.height * 2, 1e-9));
      // Center preserved.
      expect(scaled.centerLng, closeTo(_berlin.centerLng, 1e-9));
      expect(scaled.centerLat, closeTo(_berlin.centerLat, 1e-9));
    });

    test('contains is true for a sub-bbox and false otherwise', () {
      final inside = _berlin.scaleAroundCenter(0.5);
      final outside = Bbox(
        west: _berlin.west - 0.01,
        south: _berlin.south,
        east: _berlin.east,
        north: _berlin.north,
      );
      expect(_berlin.contains(inside), isTrue);
      expect(_berlin.contains(outside), isFalse);
    });

    test('toQueryString uses west,south,east,north', () {
      final q = _berlin.toQueryString();
      expect(q, '13.4,52.51,13.42,52.53');
    });
  });

  group('decideFetch', () {
    test('skips fetch below min zoom', () {
      final decision = decideFetch(
        zoom: kRatingOverlayMinZoom - 0.1,
        viewport: _berlin,
        lastFetched: null,
      );
      expect(decision.shouldFetch, isFalse);
    });

    test('fetches on first call when zoom is high enough', () {
      final decision = decideFetch(
        zoom: 14,
        viewport: _berlin,
        lastFetched: null,
      );
      expect(decision.shouldFetch, isTrue);
      // Fetched bbox should be the viewport expanded around its center.
      final expected = _berlin.scaleAroundCenter(kRatingOverlayBboxExpansion);
      expect(decision.fetchBbox!.west, closeTo(expected.west, 1e-9));
      expect(decision.fetchBbox!.east, closeTo(expected.east, 1e-9));
      expect(decision.fetchBbox!.south, closeTo(expected.south, 1e-9));
      expect(decision.fetchBbox!.north, closeTo(expected.north, 1e-9));
    });

    test('skips refetch when viewport sits inside the safe inner window', () {
      // Simulate the overlay having fetched the expanded Berlin bbox.
      final lastFetched = _berlin.scaleAroundCenter(kRatingOverlayBboxExpansion);
      // A tiny pan that stays well inside the inner 60% window.
      final panned = Bbox(
        west: _berlin.west + 0.0005,
        south: _berlin.south + 0.0005,
        east: _berlin.east + 0.0005,
        north: _berlin.north + 0.0005,
      );
      final decision = decideFetch(
        zoom: 14,
        viewport: panned,
        lastFetched: lastFetched,
      );
      expect(decision.shouldFetch, isFalse);
    });

    test('refetches when viewport moves outside the safe inner window', () {
      final lastFetched = _berlin.scaleAroundCenter(kRatingOverlayBboxExpansion);
      // Pan east by roughly one viewport width — well beyond the 60% inner.
      final panned = Bbox(
        west: _berlin.west + _berlin.width,
        south: _berlin.south,
        east: _berlin.east + _berlin.width,
        north: _berlin.north,
      );
      final decision = decideFetch(
        zoom: 14,
        viewport: panned,
        lastFetched: lastFetched,
      );
      expect(decision.shouldFetch, isTrue);
      // Fetched bbox is centered on the new viewport, not the old one.
      expect(
        decision.fetchBbox!.centerLng,
        closeTo(panned.centerLng, 1e-9),
      );
    });
  });
}
