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

import 'dart:convert';

// IMPORTANT *********************************************************************
// This example application is currently set to access an Eclypses demo api to 
// demonstrate the plugin. Upon startup, the application performs a network call 
// to the 'echo' route to confirm the API is running. 
// *******************************************************************************

import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mte_relay_client_plugin/mte_relay_client_plugin.dart';
import 'package:mte_relay_client_plugin/mte_relay_response_model.dart';
import 'package:path_provider/path_provider.dart';

import 'local_file_helper.dart';
import 'multipart_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var relayServerUrl = "https://aws-relay-server-demo.eclypses.com";

  String responseMessage = 'Awaiting response...';
  final _mteRelayClientPlugin = MteRelayClientPlugin();
  var authToken = "";
  final headersToEncrypt = ['Content-Type'];
  String? _result;
  double _progress = 0.0;
  late MultipartHelper builder;
  late File file;
  String lastUpload = "";
  Color _responseTextColor = Colors.green;
  Timer? _hideResultTimer;
  final displayResultTimeout = 3;
  bool relayUrlIsSet = false;

  @override
  void initState() {
    super.initState();

    if (relayServerUrl == "<your-aws-relay-server-url>") {
      _responseTextColor = Colors.red;
      setState(() {
        _result =
            "\n\n\nRelay Server Url variable must be set in code prior to running this Demo project.";
      });
    } else {
      relayUrlIsSet = true;
    }

    // Listen for responses from the plugin
    _mteRelayClientPlugin.relayResponseStream.listen((message) {
      _showResult(true, message);
    });

    _mteRelayClientPlugin.relayStreamResponseStream.listen((args) {
      bool success = args['success'] as bool;

      Uint8List? data = args['data'] as Uint8List?;
      if (data == null) {
        _showResult(false, "Error: Response data is missing.");
      }

      String? relayError = args["relayError"] as String?;
      String? pluginError = args["pluginError"] as String?;

      if (pluginError != null || relayError != null) {
        String errorMessage = "Error: ${pluginError ?? relayError}";
        _showResult(false, errorMessage);
      }

      // Retrieve a sample Header Value
      Map<String, String>? headers = parseHeaders(args);
      final headerName = "Vary";
      String? header = headers?[headerName];
      if (header != null && header.isNotEmpty) {
        print(
          "Retrieved header from FileStream Response: \n\tkey=$headerName\n\tvalue=$header",
        );
      }
      if (data != null) {
        try {
          final dynamic jsonObject = json.decode(utf8.decode(data));
          String formattedJson = JsonEncoder.withIndent(
            '  ',
          ).convert(jsonObject);
          print(formattedJson);
          _showResult(true, formattedJson);
        } catch (e) {
          _showResult(false, "Error: Invalid JSON response.\nDetails: $e");
        }
      }
    });

    _mteRelayClientPlugin.relayRequestChunksStream.listen((streamID) {
      startSendingChunks(streamID); // Start sending chunks
    });

    _mteRelayClientPlugin.relayStreamCompletionStream.listen((progressStr) {
      double? progress = double.tryParse(progressStr);
      _updateProgress(progress ?? 0);
    });

    initializeRelay();
  }

  Future<void> initializeRelay() async {
    try {
      final localFileHelper = LocalFileManager();
      await localFileHelper
          .copyAssetsToDocumentsDirectory(); // Now safe to call
    } catch (e) {
      print("⚠️ Error initializing app: $e");
    }

    try {
      await _mteRelayClientPlugin.initializeRelay();
      _showResult(true, "Relay Initialized");
    } on PlatformException {
      _showResult(false, 'Failed to initialize Relay.');
    }
  }

  Future<void> login() async {
    String urlWithPath = "$relayServerUrl/api/login";
    final body = jsonEncode({"email": "jHalpert.com", "password": "P@ssw0rd!"});
    try {
      final dynamic args = {
        'url': urlWithPath,
        'method': 'POST',
        'headers': {'Content-Type': 'application/json'},
        'headersToEncrypt': headersToEncrypt,
        'body': body,
      };
      Map<dynamic, dynamic> response = await _mteRelayClientPlugin
          .relayDataTask(args);

      // Retrieve sample Header Value
      final headerName = "Date";
      final result = Result.fromMap(response);
      String? header = result.headers?[headerName];
      if (header != null && header.isNotEmpty) {
        print(
          "Retrieved header from Login Response: \n\tkey=$headerName\n\tvalue=$header",
        );
      }

      // Display Result
      final dynamic jsonObject = json.decode(utf8.decode(result.data));
      _showResult(true, JsonEncoder.withIndent('  ').convert(jsonObject));
    } on PlatformException {
      _showResult(false, 'Failed to Login with Relay.');
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  Future<void> getPatients() async {
    String urlWithPath = "$relayServerUrl/api/patients";
    try {
      final dynamic args = {
        'url': urlWithPath,
        'method': 'GET',
        'headers': {'Content-Type': 'application/json'},
        'headersToEncrypt': headersToEncrypt,
      };
      Map<dynamic, dynamic> response = await _mteRelayClientPlugin
          .relayDataTask(args);
      final result = Result.fromMap(response);
      final dynamic jsonObject = json.decode(utf8.decode(result.data));
      _showResult(true, JsonEncoder.withIndent('  ').convert(jsonObject));
    } on PlatformException {
      _showResult(false, 'Failed to getPatients with Relay.');
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  Future<void> kyc() async {
    String urlWithPath = "$relayServerUrl/api/kyc";

    final boundary = 'Boundary-${DateTime.now().millisecondsSinceEpoch}';
    final body = BytesBuilder();

    final List<Map<String, dynamic>> parameters = [
      {"key": "firstName", "value": "Jim", "type": "text"},
      {"key": "lastName", "value": "Halpert", "type": "text"},
      {"key": "ssn", "value": "111-22-3333", "type": "text"},
      {"key": "file1", "src": getFileToUpload("image"), "type": "file"},
      {"key": "file2", "src": getFileToUpload("resume"), "type": "file"},
    ];

    for (final param in parameters) {
      if (param['disabled'] != null) continue;

      final paramName = param['key'];
      body.add(utf8.encode('--$boundary\r\n'));
      body.add(
        utf8.encode('Content-Disposition: form-data; name="$paramName"'),
      );

      if (param['contentType'] != null) {
        body.add(utf8.encode('\r\nContent-Type: ${param['contentType']}\r\n'));
      }

      final paramType = param['type'];
      if (paramType == 'text') {
        final paramValue = param['value'];
        body.add(utf8.encode('\r\n\r\n$paramValue\r\n'));
      } else if (paramType == 'file') {
        final file = await param["src"];
        String filename = file.path.split(Platform.pathSeparator).last;
        body.add(utf8.encode('; filename="$filename"\r\n'));
        body.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
        body.add(await file.readAsBytes());
        body.add(utf8.encode('\r\n'));
      }
    }
    body.add(utf8.encode('--$boundary--\r\n'));

    Uint8List bodyBytes = body.toBytes();
    String bodyStr = "";

    if (isUtf8Text(bodyBytes)) {
      bodyStr = utf8.decode(bodyBytes, allowMalformed: false);
    } else {
      bodyStr = base64Encode(bodyBytes);
    }

    // Send to relay
    try {
      final dynamic args = {
        'url': urlWithPath,
        'method': 'POST',
        'headers': {'Content-Type': 'multipart/form-data; boundary=$boundary'},
        'headersToEncrypt': headersToEncrypt,
        'body': bodyStr,
      };
      Map<dynamic, dynamic> response = await _mteRelayClientPlugin
          .relayDataTask(args);
      final result = Result.fromMap(response);
      _responseTextColor = result.isSuccess ? Colors.green : Colors.red;
      final dynamic jsonObject = json.decode(utf8.decode(result.data));
      _showResult(true, JsonEncoder.withIndent('  ').convert(jsonObject));
    } on PlatformException {
      _showResult(false, 'KYC failed with Relay.');
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  Future<void> uploadFileStream(String filesize) async {
    file = await getFileToUpload(filesize);
    String filename = file.path.split(Platform.pathSeparator).last;

    String urlWithPath = "$relayServerUrl/api/files/upload";
    final uri = Uri.parse(urlWithPath);

    builder = MultipartHelper(filename);

    final httpClientRequest = await HttpClient().postUrl(uri);

    // Set required headers
    httpClientRequest.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=${builder.boundary}',
    );
    int contentLength = await builder.calculateContentLength(file);
    httpClientRequest.headers.set(
      HttpHeaders.contentLengthHeader,
      contentLength.toString(),
    );

    final args = await convertHttpRequestToMap(
      httpClientRequest,
      headersToEncrypt,
    );
    String result = await _mteRelayClientPlugin.relayUploadFile(args);
    _showResult(true, result);
  }

  Future<void> downloadFileStream() async {
    final urlEncodedFilename = Uri.encodeComponent(lastUpload);
    final downloadLocation = await getDownloadUrl(lastUpload);
    print("Download Location:\n$downloadLocation");
    String urlWithPath =
        "$relayServerUrl/api/files/download/stream/$urlEncodedFilename";
    try {
      final arguments = {
        'url': urlWithPath,
        'method': 'GET',
        'headers': {'Content-Type': 'application/json'},
        'headersToEncrypt': headersToEncrypt,
        'downloadLocation': downloadLocation,
      };
      String result = await _mteRelayClientPlugin.relayDownloadFile(arguments);
      _showResult(true, result);
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  Future<void> rePair() async {
    String result = "";
    try {
      final dynamic args = {'url': relayServerUrl};
      result = await _mteRelayClientPlugin.rePair(args);

      _showResult(true, result);
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  Future<void> adjustRelaySettings() async {
    String result = "No result";
    try {
      final dynamic args = {
        // Any argument not included or that is the same as the existing RelaySetting is disregarded
        'serverUrl': relayServerUrl,
        'streamChunkSize': 1024 * 512, // current default is 1024 * 1024
        'pairPoolSize': 5, // current default is 3
        'persistPairs': false, // current default is false
      };
      result = await _mteRelayClientPlugin.adjustRelaySettings(args);

      _showResult(true, result);
    } catch (error) {
      _showResult(false, "Error: $error");
    }
  }

  void _showResult(bool isSuccess, String result) {
    _responseTextColor = isSuccess ? Colors.green : Colors.red;
    if (["fail", "unable"].any((word) => result.toLowerCase().contains(word))) {
      _responseTextColor = Colors.red;
    }

    String formattedResult = result;

    // Try to parse the result as JSON and pretty-print if valid
    try {
      final decodedJson = jsonDecode(result);
      formattedResult = const JsonEncoder.withIndent('  ').convert(decodedJson);
    } catch (e) {
      // Not a JSON, keep the original text
    }

    setState(() {
      _result = formattedResult;
    });

    // Cancel any existing timer
    _hideResultTimer?.cancel();

    // Start a new timer to clear the result after 3 seconds
    _hideResultTimer = Timer(Duration(seconds: displayResultTimeout), () {
      setState(() {
        _result = null;
        _responseTextColor = Colors.green;
      });
    });
  }

  void _updateProgress(double progress) {
    setState(() {
      _progress = progress;
    });

    // Hide the progress bar when upload completes
    if (progress == 1.0) {
      setState(() {
        _progress = 0.0;
      });
    }
  }

  Future<File> getFileToUpload(String filesize) async {
    const filenames = [
      "The Gettysburg Address.txt", // 1.5kb
      "War and Peace.txt", // 20mb
      "25X - War and Peace.txt", // 100mb
      "JimHalpert.jpeg", // 381kb
      "Jim_Halpert_Resume.pdf", // 4kb
    ];
    var filename = "";
    switch (filesize) {
      case "small":
        filename = filenames[0];
        break;
      case "medium":
        filename = filenames[1];
        break;
      case "large":
        filename = filenames[2];
        break;
      case "image":
        filename = filenames[3];
        break;
      case "resume":
        filename = filenames[4];
        break;
      default:
        filename = filenames[0];
    }

    lastUpload = filename;
    final directory = await getApplicationDocumentsDirectory();
    String dirStr = directory.path;
    return File("$dirStr/$filename");
  }

  void startSendingChunks(String streamID) async {
    // Write data to the request stream
    final writeStream = builder.assembleMultipartWithFile(file);
    await for (final chunk in writeStream) {
      final dynamic args = {
        "streamID": streamID,
        "data": Uint8List.fromList(chunk),
      };
      _mteRelayClientPlugin.sendChunk(args);
    }

    // Notify Swift to close the stream
    final dynamic args = {"streamID": streamID};
    _mteRelayClientPlugin.closeStream(args);
  }

  Future<Map<String, dynamic>> convertHttpRequestToMap(
    HttpClientRequest request,
    List<String> headersToEncrypt,
  ) async {
    // Get headers as a Map
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });

    // Extract other properties
    final map = {
      'url': request.uri.toString(),
      'method': request.method,
      'headers': headers,
      'headersToEncrypt': headersToEncrypt,
    };
    return map;
  }

  Future<String> getDownloadUrl(String filename) async {
    // Retrieve the documents directory
    final Directory? docsDir = await getApplicationDocumentsDirectory();
    if (docsDir == null) {
      throw Exception("Unable to retrieve local documents directory");
    }

    // Construct the file URL
    final Directory downloadDirectory = Directory('${docsDir.path}/downloads');
    final File storedFile = File('${downloadDirectory.path}/$filename');

    // Create the download directory if it doesn't exist
    if (!await downloadDirectory.exists()) {
      await downloadDirectory.create(recursive: true);
    }

    // Create the file if it doesn't exist and overwrite it empty if it does exist
    if (!await storedFile.exists()) {
      await storedFile.create();
    } else {
      await storedFile.writeAsBytes(
        [],
      ); // Overwrite the file with empty content
    }

    // Return the filePath
    return storedFile.uri.toFilePath();
  }

  bool isUtf8Text(Uint8List bytes) {
    try {
      utf8.decode(bytes, allowMalformed: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, String>? parseHeaders(dynamic args) {
    Map<String, String>? headers;

    if (args["headers"] != null && args["headers"] is Map) {
      headers = (args["headers"] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      print(headers);
    } else {
      headers = null;
    }
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.lightGreen,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Flutter Plugin Demo"),
          centerTitle: true,
          backgroundColor: Color(0xFFF6531E),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 35,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Expandable scrollable area for the result
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    _result != null && _result!.isNotEmpty
                        ? SingleChildScrollView(
                          child: Text(
                            _result!,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 16,
                              color: _responseTextColor,
                            ),
                          ),
                        )
                        : Container(),
              ),
            ),

            // Buttons Section
            if (relayUrlIsSet)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      color: Color(0xFFF6531E),
                      width: double.infinity,
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Test Calls',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: login,
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: getPatients,
                          child: const Text(
                            "Get Patients",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: kyc,
                          child: const Text(
                            "KYC",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    _progress == 0.0
                        ? Container(
                          color: Color(0xFFF6531E),
                          width: double.infinity,
                          child: const Align(
                            alignment: Alignment.center,
                            child: Text(
                              'File Streaming Calls',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                        : const Text(
                          'Uploading ...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF6531E),
                          ),
                        ),
                    _progress != 0.0
                        ? Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress, // Set progress value
                              minHeight: 10.0,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF6531E),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Display progress percentage
                            Text(
                              "${(_progress * 100).toStringAsFixed(1)}%", // Show percentage
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF6531E),
                              ),
                            ),
                          ],
                        )
                        : const SizedBox.shrink(), // Return an empty widget when _progress is 0.0
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await uploadFileStream('small');
                          },
                          child: const Text(
                            "1kb",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            await uploadFileStream('medium');
                          },
                          child: const Text(
                            "17mb",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            await uploadFileStream('large');
                          },
                          child: const Text(
                            "100mb",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await downloadFileStream();
                          },
                          child: const Text(
                            "Download Last",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      color: Color(0xFFF6531E),
                      width: double.infinity,
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Utility Method Calls',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await rePair();
                          },
                          child: const Text(
                            "Re-Pair",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await adjustRelaySettings();
                          },
                          child: const Text(
                            "Adjust Settings",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6531E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
