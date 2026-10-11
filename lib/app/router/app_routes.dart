enum AppRoute {
  onboarding('/onboarding'),
  home('/home'),
  game('/game'),
  timeAttack('/game/60s'),
  howToPlay('/how-to-play');

  const AppRoute(this.path);

  final String path;
}
