import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';

void main() {
  test('retired account, leaderboard, and About routes are absent', () {
    final routeNames = AppRoute.values.map((route) => route.name).toSet();

    expect(routeNames, isNot(contains('nickname')));
    expect(routeNames, isNot(contains('leaderboard')));
    expect(routeNames, isNot(contains('about')));
    expect(routeNames, contains('home'));
    expect(routeNames, contains('howToPlay'));
  });
}
