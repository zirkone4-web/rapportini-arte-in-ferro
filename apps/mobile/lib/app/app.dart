import 'package:arte_in_ferro_rapportini/app/app_theme.dart';
import 'package:arte_in_ferro_rapportini/core/gps/location_service.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/repositories/auth_repository.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/sign_in.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/sign_out.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/watch_auth_state.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_event.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_state.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/pages/auth_failure_page.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/pages/login_page.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/pages/splash_page.dart';
import 'package:arte_in_ferro_rapportini/features/home/presentation/pages/home_page.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/repositories/rapportini_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RapportiniApp extends StatelessWidget {
  const RapportiniApp({
    required this.authRepository,
    required this.rapportiniRepository,
    required this.locationService,
    super.key,
  });

  final AuthRepository authRepository;
  final RapportiniRepository rapportiniRepository;
  final LocationService locationService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<RapportiniRepository>.value(
          value: rapportiniRepository,
        ),
        RepositoryProvider<LocationService>.value(value: locationService),
      ],
      child: BlocProvider(
        create: (_) => AuthBloc(
          signIn: SignIn(authRepository),
          signOut: SignOut(authRepository),
          watchAuthState: WatchAuthState(authRepository),
        )..add(const AuthSubscriptionRequested()),
        child: MaterialApp(
          title: 'Arte In Ferro Lascari App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        if (previous is AuthUnauthenticated &&
            current is AuthUnauthenticated) {
          return false;
        }
        return true;
      },
      builder: (context, state) {
        return switch (state) {
          AuthAuthenticated(:final user) => HomePage(user: user),
          AuthUnauthenticated() => const LoginPage(),
          AuthFailure(:final message) => AuthFailurePage(message: message),
          AuthInitial() || AuthLoading() => const SplashPage(),
        };
      },
    );
  }
}
