import 'package:flutter/material.dart';

enum BackgroundVariant {
  /// Gradient + city-skyline asset anchored to the bottom.
  /// Used by: welcome, login, signup, settings, loading screens.
  standard,

  /// Gradient only — no bottom asset.
  /// Used by: chat screen.
  plain,
}

/// Scaffold wrapper that paints the brand background behind the body.
///
/// The [Scaffold] is the root widget so anything that relies on it via
/// `Scaffold.of(context)` (drawers, SnackBars, FAB animations, etc.) works
/// reliably. The background lives inside the body via a [Stack] with
/// [Scaffold.extendBodyBehindAppBar] enabled, which lets the artwork extend
/// edge-to-edge under the status bar, the (transparent) app bar, and the
/// system navigation area.
class BackgroundScaffold extends StatelessWidget {
  const BackgroundScaffold({
    super.key,
    this.variant = BackgroundVariant.standard,
    this.appBar,
    this.drawer,
    this.body,
    this.bottomNavigationBar,
  });

  final BackgroundVariant variant;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? body;
  final Widget? bottomNavigationBar;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.98],
    colors: [Color(0xFF7DA9F0), Color(0xFFF6FAFF)],
  );

  @override
  Widget build(BuildContext context) {
    // The PNG has wide transparent padding on its sides, so plain `fitWidth`
    // leaves the city silhouette appearing tiny in the centre. We instead
    // pin a fixed-height strip at the bottom and use `BoxFit.cover` so the
    // image scales up until it covers that strip — cropping the empty
    // padding off the sides and rendering the city much larger.
    final cityStripHeight = MediaQuery.sizeOf(context).height * 0.35;

    return Scaffold(
      backgroundColor: const Color(0xFF7DA9F0),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: appBar,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: _gradient),
          ),
          if (variant == BackgroundVariant.standard)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: cityStripHeight,
              child: Image.asset(
                'assets/images/bg_city.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          if (body != null) Positioned.fill(child: body!),
        ],
      ),
    );
  }
}
