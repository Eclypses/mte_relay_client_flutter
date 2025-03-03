<center>
<img src="Eclypses.png" style="width:50%;"/>
</center>

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:50px;" >
MteRelay Client Flutter Plugin </div>
<br><br>

### This Flutter plugin provides plug-and-play MTE integration for iOS/Swift and Android/Java Flutter applications, allowing quick integration with very minimal code changes. This Client Plugin requires a corresponding MteRelay Server API to receive the encoded requests and relay them onto the original API. 
<br><br>

## Overview 
When you have integrated this Plugin into your Flutter application and have set up and configured the corresponding MteRelay Server API, your client application will make its network calls just as before except that they are now routed through the MteRelay plugin. 

There, the Request is inspected and the relevant information captured. The MteRelay mobile client checks for a corresponding MteRelay Server and if not found, returns an error. However, if the server IS found, a new request is created, the original data is encoded with MTE and sent to the MteRelay server where is it decoded. 

From there, the original request is sent on to the original destination API. Any response will follow the same path in reverse.
<br>

This project is a starting point for a Flutter [plug-in package](https://flutter.dev/to/develop-plugins), a specialized Eclypses MteRelay Client package that includes platform-specific implementation code for Android and iOS. To be useful, this Plugin requires licensed access to an MteRelay server instance. 

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

<br><br>
## Add MteRelay Client Flutter Plugin to your application:
- Confirm set-up of corresponding MteRelay API to receive the requests from your application, where they will be decoded and relayed on to the original destination API.
- Add this [Mte-Relay-Client-Flutter](https://github.com/Eclypses/mte_relay_client_flutter.git) -  [HowTo](https://docs.flutter.dev/packages-and-plugins/using-packages). 
  - Currently, this MteRelay Client Flutter Plugin is not published on pub.dev so add this plugin by editing your pubspec.yaml file as shown here. (Indenting is critical!)
``` dart
dependencies:
    flutter:
        sdk: flutter
    mte_relay_client_plugin:
        git:
            url: https://github.com/Eclypses/mte_relay_client_flutter.git
```
- In a terminal at the root directory of the project, run Flutter pub get. This should install the MteRelay Client Plugin to your project. 
- In the file where you expect to maintain the reference to the MteRelay plugin, import it. 
```dart
import 'package:mte_relay_client_plugin/mte_relay_client_plugin.dart';
```
- Create a class-level variable to store the reference to the plugin.
```dart
final _mteRelayClientPlugin = MteRelayClientPlugin();   
```
- Then, when the class is instantiated, set up the Relay Callbacks and initialize the Relay.

```dart
@override
  void initState() {
    super.initState();

      // Listen for responses from the plugin
      _mteRelayClientPlugin.relayResponseStream.listen((message) {
          // Deal appropriately with response message 
      });

      // These 3 callbacks are only necessary for file streaming uploads and downloads
      _mteRelayClientPlugin.relayStreamResponseStream.listen((args) {

      // Deal appropriately with response args. Here is some sample code
      bool success = args['success'] as bool;
      Uint8List? data = args['data'] as Uint8List?;
      String? relayError = args["relayError"] as String?;
      String? pluginError = args["pluginError"] as String?;

      Map<String, String>? headers;
      if (args["headers"] != null && args["headers"] is Map) {
          headers = (args["headers"] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
      );
      } else {
        headers = null;
      }

      if (data != null) {
        try {
          final dynamic jsonObject = json.decode(utf8.decode(data));
          String formattedJson = JsonEncoder.withIndent(
            '  ',
          ).convert(jsonObject);
        } catch (e) {
          // Deal with Exception appropriately
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
      await _mteRelayClientPlugin.initializeRelay();
      responseMessage = "Relay Initialized";
    } on PlatformException {
      responseMessage = 'Failed to initialize Relay.';
    }
    // Deal appropriately with response message
  }
```

5. Create arguments and make call to Plugin method
```dart
// This is a sample POST request
Future<void> login() async {
    String urlWithPath = "<relayServerUrl>/api/login";
    final body = jsonEncode({"email": "email.com", "password": "password!"});
    try {
      final dynamic args = {
        'url': urlWithPath,
        'method': 'POST',
        'headers': {'Content-Type': 'application/json'},
        'headersToEncrypt': headersToEncrypt, // Any headers you wish to be encrypted. Content-Type is always encrypted, if it exists.
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

      final dynamic jsonObject = json.decode(utf8.decode(result.data));
     // Deal appropriately with JSON Data
    } on PlatformException {
      // Deal appropriately with PlatformException
    } catch (error) {
      // Deal appropriately with error
    }
  }

// Sample FileStream Upload (See Example project in this plugin for more information)
Future<void> uploadFileStream(String filesize) async {
  File file = await getFileToUpload(filesize);
  String filename = file.path.split(Platform.pathSeparator).last;

  String urlWithPath = "$relayServerUrl/<path>";
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
  // FileStream upload response will be returned via the relayStreamResponse callback above 
}

 // Sample FileStream download. (See Example project for more information)
Future<void> downloadFileStream() async {
  final urlEncodedFilename = Uri.encodeComponent(<lastUpload>);
  final downloadLocation = await getDownloadUrl(lastUpload);
  print("Download Location:\n$downloadLocation");
  String urlWithPath =
      "$relayServerUrl/<path>/$urlEncodedFilename";
  try {
    final arguments = {
      'url': urlWithPath,
      'method': 'GET',
      'headers': {'Content-Type': 'application/json'},
      'headersToEncrypt': headersToEncrypt,
      'downloadLocation': downloadLocation,
    };
    String result = await _mteRelayClientPlugin.relayDownloadFile(arguments);
    // FileStream download response will be returned via the relayStreamResponse callback above 
  } catch (error) {
    // Deal with Exception appropriately
  }
}
// If a network call through MteRelay fails due to a MteRelay issue, an automatic RePair/Retry will occur one time. This method provides a manual way to rePair is necessary.
  Future<void> rePair() async {
    String result = "";
    try {
      final dynamic args = {'url': relayServerUrl};
      result = await _mteRelayClientPlugin.rePair(args);

     // Deal with result appropriately
    } catch (error) {
      // Deal with Exception appropriately
    }
  }

// If the current MteRelay defaults are not appropriate for your needs, they can be adjusted using the following method. An automatic RePair is included so that future transmissions during this session will use the updated settings. 
// If you wish to alway use settings different than the defaults, simply call this method just after initializeRelay call above.
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

      // Deal with result appropriately
    } catch (error) {
      // Deal with Exception appropriately
    }
  }
```

<div style="page-break-after: always; break-after: page;"></div>

# Contact Eclypses

<p align="center" style="font-weight: bold; font-size: 20pt;">Email: <a href="mailto:info@eclypses.com">info@eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 20pt;">Web: <a href="https://www.eclypses.com">www.eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 20pt;">Chat with us: <a href="https://developers.eclypses.com/dashboard">Developer Portal</a></p>
<p style="font-size: 8pt; margin-bottom: 0; margin: 100px 24px 30px 24px; " >
<b>All trademarks of Eclypses Inc.</b> may not be used without Eclypses Inc.'s prior written consent. No license for any use thereof has been granted without express written consent. Any unauthorized use thereof may violate copyright laws, trademark laws, privacy and publicity laws and communications regulations and statutes. The names, images and likeness of the Eclypses logo, along with all representations thereof, are valuable intellectual property assets of Eclypses, Inc. Accordingly, no party or parties, without the prior written consent of Eclypses, Inc., (which may be withheld in Eclypses' sole discretion), use or permit the use of any of the Eclypses trademarked names or logos of Eclypses, Inc. for any purpose other than as part of the address for the Premises, or use or permit the use of, for any purpose whatsoever, any image or rendering of, or any design based on, the exterior appearance or profile of the Eclypses trademarks and or logo(s).
</p>