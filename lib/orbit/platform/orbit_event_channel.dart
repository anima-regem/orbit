import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/orbit_event_v2.dart';

class OrbitEventChannel {
  OrbitEventChannel() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel = const MethodChannel('orbit/events');
  final StreamController<OrbitEventV2> _controller =
      StreamController<OrbitEventV2>.broadcast();

  Stream<OrbitEventV2> get events => _controller.stream;

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'orbitEventV2') {
      return;
    }

    final dynamic rawArgs = call.arguments;
    if (rawArgs is! Map) {
      return;
    }

    final OrbitEventV2? event = OrbitEventV2.tryParse(rawArgs);
    if (event != null) {
      _controller.add(event);
    }
  }
}
