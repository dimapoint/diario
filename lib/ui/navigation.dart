import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/day_id.dart';

abstract final class Routes {
  static const today = '/';
  static const journal = '/diario';
  static const search = '/buscar';
  static const settings = '/ajustes';
  static const signIn = '/ingresar';

  static String day(String dayId) => dayId == todayId() ? today : '/day/$dayId';
}

void goToDay(BuildContext context, String dayId) => context.go(Routes.day(dayId));
