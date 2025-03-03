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

class Result<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;
  final Map<String, String>? headers;

  Result.success(this.data, {this.headers})
      : errorMessage = null,
        isSuccess = true;

  Result.error(this.errorMessage, {this.headers})
      : data = null,
        isSuccess = false;

  // Convert from a Map (native response)
  factory Result.fromMap(Map<dynamic, dynamic> map) {
    return map['success'] == true
        ? Result.success(map['data'], headers: _parseHeaders(map['headers']))
        : Result.error(map['error'], headers: _parseHeaders(map['headers']));
  }

  // Convert to Map (if needed)
  Map<String, dynamic> toMap() {
    return {
      'success': isSuccess,
      'data': data,
      'error': errorMessage,
      'headers': headers,
    };
  }

  // Helper function to ensure headers are properly formatted
  static Map<String, String>? _parseHeaders(dynamic headers) {
    if (headers is Map) {
      return headers.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return null;
  }
}