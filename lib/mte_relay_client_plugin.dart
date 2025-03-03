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
import 'mte_relay_client_plugin_platform_interface.dart';

class MteRelayClientPlugin {
  
  // SECTION: Calls to ative
  Future<String?> getPlatformVersion() {
    return MteRelayClientPluginPlatform.instance.getPlatformVersion();
  }

  Future<void> initializeRelay() {
    return MteRelayClientPluginPlatform.instance.initializeRelay();
  }

  Future<Map<dynamic, dynamic>> relayDataTask(dynamic args) {
    return MteRelayClientPluginPlatform.instance.relayDataTask(args);
  }

  Future<String> relayUploadFile(dynamic args) {
    return MteRelayClientPluginPlatform.instance.relayUploadFile(args);
  }

  Future<String> relayDownloadFile(dynamic args) {
    return MteRelayClientPluginPlatform.instance.relayDownloadFile(args);
  }

  Future<String> rePair(dynamic args) {
    return MteRelayClientPluginPlatform.instance.rePair(args);
  }

  Future<String> adjustRelaySettings(dynamic args) {
    return MteRelayClientPluginPlatform.instance.adjustRelaySettings(args);
  }

  Future<void> sendChunk(dynamic args) {
    return MteRelayClientPluginPlatform.instance.sendChunk(args);
  }

  Future<void> closeStream(dynamic args) {
    return MteRelayClientPluginPlatform.instance.closeStream(args);
  }

  // SECTION: Callback methods to Flutter App.
  Stream<String> get relayResponseStream =>
      MteRelayClientPluginPlatform.instance.relayResponseStream;

  Stream<dynamic> get relayStreamResponseStream =>
      MteRelayClientPluginPlatform.instance.relayStreamResponseStream;

  Stream<String> get relayRequestChunksStream =>
      MteRelayClientPluginPlatform.instance.relayRequestChunksStream;

  Stream<String> get relayStreamCompletionStream =>
      MteRelayClientPluginPlatform.instance.relayStreamCompletionStream;

}
