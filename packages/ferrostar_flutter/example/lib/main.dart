import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ferrostar Flutter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SmokeTestPage(),
    );
  }
}

class SmokeTestPage extends StatefulWidget {
  const SmokeTestPage({super.key});

  @override
  State<SmokeTestPage> createState() => _SmokeTestPageState();
}

class _SmokeTestPageState extends State<SmokeTestPage> {
  static const MethodChannel _channel = MethodChannel('land._001/ferrostar_flutter');

  String _result = 'Tap the button to verify the iOS Ferrostar smoke test.';
  bool _running = false;

  Future<void> _runSmokeTest() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      setState(() {
        _running = false;
        _result = 'Task 4 only wires the smoke test on iOS. Android proof-of-life lands in Task 5.';
      });
      return;
    }

    setState(() {
      _running = true;
      _result = 'Running smokeTest...';
    });

    try {
      final String? response = await _channel.invokeMethod<String>('smokeTest');
      if (!mounted) {
        return;
      }
      setState(() {
        _result = response ?? 'smokeTest returned null';
        _running = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = 'smokeTest failed: ${error.code}: ${error.message ?? 'unknown error'}';
        _running = false;
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = 'smokeTest is not available on this platform yet.';
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ferrostar iOS proof-of-life'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _result,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _running ? null : _runSmokeTest,
                child: Text(_running ? 'Running...' : 'Run smokeTest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
