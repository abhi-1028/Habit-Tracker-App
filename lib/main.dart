import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'services/habit_store.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitTrackerApp());
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late Future<void> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _load();
  }

  Future<void> _load() async {
    // Storage is required for the app to start; notifications are optional
    // during bootstrap and must never prevent a fresh install from opening.
    await LocalStorageService.init();
    await HabitStore.instance.loadSavedHabits();
    try {
      await NotificationService.initialize();
    } catch (_) {
      // Notification support can be initialized later from Settings.
      // Do not turn an otherwise healthy app launch into a loading failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'We could not start Habit Tracker.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(() => _bootstrap = _load()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (!LocalStorageService.loadOnboardingComplete() || LocalStorageService.loadProfileName().trim().isEmpty) {
          return const _ProfileOnboardingScreen();
        }
        return const MainNavigation();
      },
    );
  }
}

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: .94, end: 1.04).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF120B22),
              cs.surface,
              const Color(0xFF071C24),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => Transform.rotate(angle: _rotation.value * 0.25, child: child),
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                  width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: .22),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 46,
                  color: cs.onPrimary,
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Habit Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Preparing your streaks…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(animation: _controller, builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) { final active = ((_controller.value * 3).floor() % 3) == i; return AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 4), width: active ? 10 : 6, height: active ? 10 : 6, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: active ? 1 : .35))); }))),
            ],
          ),
        ),
      ),
    );
  }
}

class HabitTrackerApp extends StatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  @override
  void initState() {
    super.initState();
    LocalStorageService.themeModeNotifier.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    LocalStorageService.themeModeNotifier.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  ThemeMode get _themeMode {
    final value = LocalStorageService.themeModeNotifier.value;
    if (value == 'system') return ThemeMode.system;
    if (value == 'light' || value == 'sunset' || value == 'lavender') return ThemeMode.light;
    return ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Tracker',
      theme: AppTheme.themeFor(LocalStorageService.themeModeNotifier.value, Brightness.light),
      darkTheme: AppTheme.themeFor(LocalStorageService.themeModeNotifier.value, Brightness.dark),
      themeMode: _themeMode,
      home: const _BootstrapScreen(),
    );
  }
}


class _ProfileOnboardingScreen extends StatefulWidget {
  const _ProfileOnboardingScreen();
  @override State<_ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}
class _ProfileOnboardingScreenState extends State<_ProfileOnboardingScreen> {
  final _controller = TextEditingController();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  Future<void> _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await LocalStorageService.saveProfileName(name);
    await LocalStorageService.saveOnboardingComplete(true);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavigation()));
    }
  }
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 96, height: 96, decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, size: 48, color: cs.onPrimaryContainer)),
      const SizedBox(height: 24),
      Text('Welcome to Habit Tracker', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('Let’s personalize your habit journey.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 28),
      TextField(controller: _controller, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name', hintText: 'Enter your name', prefixIcon: Icon(Icons.person_outline_rounded))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: _continue, child: const Text('Start my journey'))),
      const SizedBox(height: 10),
      Text('Your name is stored only on this device.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ])))));
  }
}
