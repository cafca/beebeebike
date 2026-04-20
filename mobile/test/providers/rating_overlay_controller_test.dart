import 'dart:async';

import 'package:beebeebike/api/ratings_api.dart';
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/rating_overlay_provider.dart';
import 'package:beebeebike/services/rating_fetch_policy.dart';
import 'package:beebeebike/services/rating_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Fakes ----

class _FakeOverlay implements RatingOverlaySurface {
  int clears = 0;
  int detaches = 0;
  final List<Map<String, dynamic>> updates = [];
  bool _attached = true;

  @override
  bool get isAttached => _attached;

  @override
  Future<void> update(Map<String, dynamic> fc) async {
    updates.add(fc);
  }

  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  Future<void> detach() async {
    detaches++;
    _attached = false;
  }
}

class _FakeRatingsApi implements RatingsApi {
  final List<({String bbox, CancelToken? token})> calls = [];
  bool blockNext = false;
  Map<String, dynamic> response = const {
    'type': 'FeatureCollection',
    'features': [],
  };

  @override
  Future<Map<String, dynamic>> getOverlay(
    String bbox, {
    CancelToken? cancelToken,
  }) async {
    calls.add((bbox: bbox, token: cancelToken));
    if (blockNext) {
      // Resolve only when the CancelToken is cancelled — mirrors Dio's
      // real behavior, so the controller's `on DioException` catch runs.
      final completer = Completer<Map<String, dynamic>>();
      cancelToken?.whenCancel.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(DioException(
            requestOptions: RequestOptions(path: '/api/ratings'),
            type: DioExceptionType.cancel,
          ));
        }
      });
      return completer.future;
    }
    return response;
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);
  final User? _initial;

  @override
  Future<User?> build() async => _initial;

  void setUser(User? u) => state = AsyncData(u);
}

// ---- Fixtures ----

const _anon = User(id: 'anon', accountType: 'anonymous');
const _named = User(id: 'user-1', accountType: 'registered');

const _berlin = Bbox(
  west: 13.40,
  south: 52.51,
  east: 13.42,
  north: 52.53,
);

typedef _Setup = ({
  ProviderContainer container,
  _FakeRatingsApi api,
  _FakeAuthController auth,
});

_Setup _setup({User? initialUser = _anon}) {
  final api = _FakeRatingsApi();
  final container = ProviderContainer(overrides: [
    ratingsApiProvider.overrideWithValue(api),
    authControllerProvider
        .overrideWith(() => _FakeAuthController(initialUser)),
  ]);
  // Force the overridden factory to run so we can hand the fake back.
  final auth = container.read(authControllerProvider.notifier)
      as _FakeAuthController;
  return (container: container, api: api, auth: auth);
}

/// Drain microtasks and zero-delay timers so async work inside the
/// controller settles before assertions run.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('attach is idempotent when called twice', () async {
    final s = _setup();
    addTearDown(s.container.dispose);
    await s.container.read(authControllerProvider.future);

    final controller =
        s.container.read(ratingOverlayControllerProvider.notifier);

    var attachCount = 0;
    final overlay1 = _FakeOverlay();

    await controller.attach(
      cameraProbe: () async => null,
      attachOverlay: () async {
        attachCount++;
        return overlay1;
      },
    );
    expect(attachCount, 1);

    // Second attach must NOT re-run the factory. This matters because
    // MapLibre's onStyleLoadedCallback can fire more than once and would
    // otherwise try to re-add an already-registered source + layers.
    await controller.attach(
      cameraProbe: () async => null,
      attachOverlay: () async {
        attachCount++;
        return _FakeOverlay();
      },
    );
    expect(attachCount, 1);
  });

  test('onCameraIdle skips fetch below min zoom, fires above', () async {
    final s = _setup(initialUser: null);
    addTearDown(s.container.dispose);
    await s.container.read(authControllerProvider.future);

    final controller =
        s.container.read(ratingOverlayControllerProvider.notifier);
    var zoom = kRatingOverlayMinZoom - 1;
    await controller.attach(
      cameraProbe: () async =>
          CameraState(zoom: zoom, viewport: _berlin),
      attachOverlay: () async => _FakeOverlay(),
    );
    // Null user → skip initial fetch; confirms the auth gate.
    await _pump();
    expect(s.api.calls, isEmpty);

    controller.onCameraIdle();
    await _pump();
    expect(s.api.calls, isEmpty,
        reason: 'below min zoom should not fetch');

    zoom = kRatingOverlayMinZoom + 4;
    controller.onCameraIdle();
    await _pump();
    expect(s.api.calls, hasLength(1),
        reason: 'above min zoom should fetch');
  });

  test('rapid onCameraIdle cancels the in-flight request', () async {
    final s = _setup(initialUser: null);
    addTearDown(s.container.dispose);
    await s.container.read(authControllerProvider.future);

    final controller =
        s.container.read(ratingOverlayControllerProvider.notifier);
    var viewport = _berlin;
    s.api.blockNext = true;
    await controller.attach(
      cameraProbe: () async =>
          CameraState(zoom: 14, viewport: viewport),
      attachOverlay: () async => _FakeOverlay(),
    );

    controller.onCameraIdle();
    await _pump();
    expect(s.api.calls, hasLength(1));
    final firstToken = s.api.calls.last.token!;
    expect(firstToken.isCancelled, isFalse);

    // Large pan — policy decides a refetch is needed.
    viewport = Bbox(
      west: _berlin.west + _berlin.width * 2,
      south: _berlin.south,
      east: _berlin.east + _berlin.width * 2,
      north: _berlin.north,
    );
    controller.onCameraIdle();
    await _pump();

    expect(s.api.calls, hasLength(2));
    expect(firstToken.isCancelled, isTrue,
        reason: 'second onCameraIdle should cancel the first token');
  });

  test('auth change clears overlay and refetches for new user', () async {
    final s = _setup();
    addTearDown(s.container.dispose);
    await s.container.read(authControllerProvider.future);

    final controller =
        s.container.read(ratingOverlayControllerProvider.notifier);
    final overlay = _FakeOverlay();
    await controller.attach(
      cameraProbe: () async =>
          const CameraState(zoom: 14, viewport: _berlin),
      attachOverlay: () async => overlay,
    );
    await _pump();
    // Initial fetch fired because auth resolved before attach.
    expect(s.api.calls, hasLength(1));
    expect(overlay.clears, 0);

    s.auth.setUser(_named);
    await _pump();
    expect(overlay.clears, 1,
        reason: 'switching user must clear the previous overlay');
    expect(s.api.calls, hasLength(2),
        reason: 'new user must trigger a refetch');
  });

  test('detach cancels in-flight and tears down the overlay', () async {
    final s = _setup();
    addTearDown(s.container.dispose);
    await s.container.read(authControllerProvider.future);

    final controller =
        s.container.read(ratingOverlayControllerProvider.notifier);
    final overlay = _FakeOverlay();
    s.api.blockNext = true;
    await controller.attach(
      cameraProbe: () async =>
          const CameraState(zoom: 14, viewport: _berlin),
      attachOverlay: () async => overlay,
    );
    await _pump();
    expect(s.api.calls, hasLength(1));
    final token = s.api.calls.last.token!;

    await controller.detach();
    expect(token.isCancelled, isTrue);
    expect(overlay.detaches, 1);

    // After detach, onCameraIdle is a no-op.
    controller.onCameraIdle();
    await _pump();
    expect(s.api.calls, hasLength(1));
  });

  test('attach skips initial fetch when auth is still loading', () async {
    // Override authControllerProvider with a controller whose build()
    // never resolves — simulates the cold-start race we want to avoid.
    final api = _FakeRatingsApi();
    final container = ProviderContainer(overrides: [
      ratingsApiProvider.overrideWithValue(api),
      authControllerProvider
          .overrideWith(() => _PendingAuthController()),
    ]);
    addTearDown(container.dispose);

    final controller =
        container.read(ratingOverlayControllerProvider.notifier);
    await controller.attach(
      cameraProbe: () async =>
          const CameraState(zoom: 14, viewport: _berlin),
      attachOverlay: () async => _FakeOverlay(),
    );
    await _pump();
    expect(api.calls, isEmpty,
        reason: 'no fetch until auth resolves');
  });
}

class _PendingAuthController extends AuthController {
  @override
  Future<User?> build() => Completer<User?>().future;
}
