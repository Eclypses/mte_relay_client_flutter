// The MIT License (MIT)
//
// Copyright (c) Eclypses, Inc.
//
// All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mte_relay_client_plugin_platform_interface.dart';

/// An implementation of [MteRelayClientPluginPlatform] that uses method channels.
class MethodChannelMteRelayClientPlugin extends MteRelayClientPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mte_relay_client_plugin');

  /// Constructor to initialize the method call handler
  MethodChannelMteRelayClientPlugin() {
    methodChannel.setMethodCallHandler(_handleNativeCallback);
  }

  // SECTION: MethodChannel calls back to Flutter App
  final StreamController<String> _relayResponseStreamController =
      StreamController<String>.broadcast();

  final StreamController<dynamic> _relayStreamResponseStreamController =
      StreamController<dynamic>.broadcast();

  final StreamController<String> _relayRequestChunksStreamController =
      StreamController<String>.broadcast();

  final StreamController<String> _relayStreamCompletionStreamController =
      StreamController<String>.broadcast();

  // SECTION: MethodChannel calls to native
  @override
  Future<void> initializeRelay() async {
    await methodChannel.invokeMethod('initializeRelay');
  }

  @override
  Future<Map<dynamic, dynamic>> relayDataTask(dynamic args) async {
    return await methodChannel.invokeMethod('relayDataTask', args);
  }

  @override
  Future<String> relayUploadFile(dynamic args) async {
    return await methodChannel.invokeMethod('relayUploadFile', args);
  }

  @override
  Future<String> relayDownloadFile(dynamic args) async {
    return await methodChannel.invokeMethod('relayDownloadFile', args);
  }

  @override
  Future<String> rePair(dynamic args) async {
    return await methodChannel.invokeMethod('rePair', args);
  }

  @override
  Future<String> adjustRelaySettings(dynamic args) async {
    return await methodChannel.invokeMethod('adjustRelaySettings', args);
  }

  @override
  Future<String> sendChunk(dynamic args) async {
    return await methodChannel.invokeMethod('writeToStream', args);
  }

  @override
  Future<String> closeStream(dynamic args) async {
    return await methodChannel.invokeMethod('closeStream', args);
  }

  // SECTION: Listeners for calls back from native
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case "getFileStream":
        String streamID = call.arguments;
        _relayRequestChunksStreamController.add(streamID);
        return Future.value(null);

      case "relayResponseMessage":
        String message = call.arguments;
        _relayResponseStreamController.add(message);
        return Future.value(message);

      case "streamCompletionPercentage":
        double progress = call.arguments;
        _relayStreamCompletionStreamController.add(progress.toString());
        return Future.value(progress.toString());

      case "relayStreamResponse":
        _relayStreamResponseStreamController.add(call.arguments);
        return Future.value(call.arguments);
    }
  }
  
  @override
  Stream<String> get relayResponseStream =>
      _relayResponseStreamController.stream;

  @override
  Stream<dynamic> get relayStreamResponseStream =>
      _relayStreamResponseStreamController.stream;

  @override
  Stream<String> get relayRequestChunksStream =>
      _relayRequestChunksStreamController.stream;

  @override
  Stream<String> get relayStreamCompletionStream =>
      _relayStreamCompletionStreamController.stream;
}
