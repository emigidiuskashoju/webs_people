import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'bw_api.dart';
import 'bw_delivery_screen.dart';

/// Opens a Shoopicky delivery when Webs is started from a link.
///
/// The Shoopicky website's "Track in Webs" buttons open:
///   `webs://bw/track?code=BW-XXXXXX`  (buyer)
///   `webs://bw/deliver?link=SECURE_LINK`  (seller / admin)
/// https://webzapp.org/p/bw/... works the same way.
///
/// Like NotificationTapGate, a link that arrives while the splash screen is
/// showing waits until the main screen is up — otherwise start-up would
/// replace the screen it opened.
class BwLinks {
  BwLinks._();
  static final BwLinks instance = BwLinks._();

  GlobalKey<NavigatorState>? _navigator;
  StreamSubscription<Uri>? _subscription;
  int _readyScreens = 0;
  Uri? _pending;

  /// Called once at app start. The stream also delivers the link that started the app.
  void start(GlobalKey<NavigatorState> navigator) {
    _navigator = navigator;
    _subscription ??= AppLinks().uriLinkStream.listen(_handle, onError: (_) {});
  }

  /// Called by MainNavigationScreen after its first frame.
  void markReadyAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readyScreens++;
      final pending = _pending;
      _pending = null;
      if (pending != null) _handle(pending);
    });
  }

  /// Called when MainNavigationScreen goes away (e.g. logout).
  void markNotReady() {
    if (_readyScreens > 0) _readyScreens--;
  }

  void _handle(Uri uri) {
    final screen = screenFor(uri);
    if (screen == null) return;
    final navigator = _navigator?.currentState;
    if (_readyScreens == 0 || navigator == null) {
      _pending = uri; // the latest link wins
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  /// The delivery screen for a link, or null when the link is not a Shoopicky one.
  static Widget? screenFor(Uri uri) {
    final List<String> parts;
    if (uri.scheme == 'webs' && uri.host == 'bw') {
      parts = uri.pathSegments;
    } else if (uri.scheme == 'https' && uri.host == 'webzapp.org' && uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'p' && uri.pathSegments[1] == 'bw') {
      parts = uri.pathSegments.sublist(2);
    } else {
      return null;
    }
    final action = parts.isEmpty ? '' : parts.first;

    if (action == 'track') {
      final code = BwApi.normalizeCode(uri.queryParameters['code'] ?? '');
      return RegExp(r'^[A-Z]{2}-[A-Z0-9]{6}$').hasMatch(code) ? BwDeliveryScreen.buyer(code: code) : null;
    }
    if (action == 'deliver') {
      final link = uri.queryParameters['link'] ?? '';
      return BwApi.isSellerLink(link) ? BwDeliveryScreen.seller(link: link) : null;
    }
    return null;
  }
}
