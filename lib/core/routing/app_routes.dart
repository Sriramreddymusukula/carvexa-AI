/// Named destinations for shell tabs, detail screens, and task flows.
abstract final class AppRoutes {
  static const String splash = '/';

  /// Bottom-nav destinations. These are the four top-level tabs.
  static const String home = '/home';
  static const String catalog = '/catalog';
  static const String favorites = '/favorites';
  static const String profile = '/profile';

  /// Opens the catalogue ready to search, wherever the user tapped search.
  ///
  /// Uses a query flag rather than naming a source, so the catalogue decides
  /// which of *its* sources can search.
  static String catalogSearching({String? query}) => Uri(
    path: catalog,
    queryParameters: <String, String>{'focus': 'search', 'q': ?query},
  ).toString();

  /// One vehicle's details page, pushed from any destination.
  ///
  /// The id is opaque and minted by our backend, and is URL-encoded here so the
  /// route survives any id format the catalogue might use tomorrow.
  static const String carDetailPattern = '/car/:id';
  static String carDetails(String id) => '/car/${Uri.encodeComponent(id)}';

  /// Side-by-side comparison of the shortlist.
  ///
  /// Takes no ids: the shortlist is app state, not a URL, so the screen reads it
  /// from the controller rather than from the route.
  static const String compare = '/compare';
  static const String ai = '/assistant';

  /// Tab destinations in display order. Drives the navigation bar so the bar
  /// and the router can never fall out of sync.
  static const List<String> tabs = <String>[home, catalog, favorites, profile];

  static const String homeLabel = 'Home';
  static const String catalogLabel = 'Catalog';
  static const String favoritesLabel = 'Favorites';
  static const String profileLabel = 'Profile';

  /// First tab shown after the splash screen. Kept as a constant so the
  /// splash -> shell handoff is one obvious line in the router.
  static const String initialTab = home;

  static String labelFor(String route) => switch (route) {
    home => homeLabel,
    catalog => catalogLabel,
    favorites => favoritesLabel,
    profile => profileLabel,
    _ => '',
  };

  static String pathForIndex(int index) =>
      (index >= 0 && index < tabs.length) ? tabs[index] : initialTab;
}
