import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_service.dart';
import 'models/day_id.dart';
import 'providers.dart';
import 'ui/day/day_page.dart';
import 'ui/journal/journal_page.dart';
import 'ui/navigation.dart';
import 'ui/search/search_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/settings/sign_in_page.dart';
import 'ui/shell/adaptive_shell.dart';
import 'ui/theme.dart';

const _loading = '/cargando';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref.listen(currentUserProvider, (_, next) => auth.value = next, fireImmediately: true);
  ref.onDispose(auth.dispose);

  final router = GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final waiting = location == _loading || location == Routes.signIn;
      // A dónde volver después de cargar o de ingresar.
      final from = state.uri.queryParameters['from'] ?? (waiting ? Routes.today : state.uri.toString());
      final user = auth.value;
      if (user.isLoading && !user.hasValue) {
        return location == _loading ? null : Uri(path: _loading, queryParameters: {'from': from}).toString();
      }
      if (user.value == null) {
        return location == Routes.signIn ? null : Uri(path: Routes.signIn, queryParameters: {'from': from}).toString();
      }
      return waiting ? from : null;
    },
    routes: [
      GoRoute(path: _loading, builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInPage()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      ShellRoute(
        builder: (context, state, child) {
          final id = state.pathParameters['id'];
          return AdaptiveShell(
            location: state.matchedLocation,
            selectedDayId: (id != null && isValidDayId(id)) ? id : todayId(),
            child: child,
          );
        },
        routes: [
          GoRoute(path: Routes.today, pageBuilder: (context, state) => _dayPage(state, todayId())),
          GoRoute(
            path: '/day/:id',
            redirect: (_, state) {
              final id = state.pathParameters['id']!;
              if (!isValidDayId(id) || isFutureDayId(id) || id == todayId()) return Routes.today;
              return null;
            },
            pageBuilder: (context, state) => _dayPage(state, state.pathParameters['id']!),
          ),
          // En pantalla ancha el historial y la búsqueda están en el panel
          // lateral, así que a la derecha se muestra el día de hoy.
          GoRoute(
            path: Routes.journal,
            pageBuilder: (context, state) =>
                isWide(context) ? _dayPage(state, todayId()) : NoTransitionPage(child: const JournalPage()),
          ),
          GoRoute(
            path: Routes.search,
            pageBuilder: (context, state) =>
                isWide(context) ? _dayPage(state, todayId()) : NoTransitionPage(child: const SearchPage()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

Page<void> _dayPage(GoRouterState state, String id) =>
    NoTransitionPage(child: DayPage(key: ValueKey(id), dayId: id));
