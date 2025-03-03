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

import Flutter
import UIKit
import MteRelay

public class MteRelayClientPlugin: NSObject, FlutterPlugin, RelayResponseDelegate, RelayStreamDelegate, RelayStreamResponseDelegate, RelayStreamCompletionDelegate {
    
    // MARK:  Class Variables
    var streamingResult: FlutterResult!
    var outputStreams: [String: OutputStream] = [:]
    var count: Int = 0
    private var methodChannel: FlutterMethodChannel?
    private static let channelName = "mte_relay_client_plugin"
    private var relay: Relay!
    
    // MARK: Register MethodCannel
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MteRelayClientPlugin()
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }
    
    // MARK: RelayDelegates

    public func relayStreamResponse(data: Data?, response: URLResponse?, error: Error?) {

        var pluginError: String? = nil
        guard let relayResponse = response as? HTTPURLResponse else {
            pluginError = "Unable to cast response to HTTPURLResponse"
            let args: [String: Any] = [
                "success": false,
                "headers": nil as [String:String]?,
                "relayError": error?.localizedDescription,
                "pluginError": pluginError
            ]
            DispatchQueue.main.async {
                self.methodChannel?.invokeMethod("relayStreamResponse", arguments: args)
            }
            return
        }
        let success = (relayResponse.statusCode >= 200 && relayResponse.statusCode < 300)        
        var headers: [String: String] = [:]
        for (key, value) in relayResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString] = valueString
            } else {
                headers[key.description] = "\(value)" // Convert non-string values to string
            }
        }
                     
        let args: [String: Any] = [
            "success": success,
            "data": data,
            "headers": headers,
            "relayError": error?.localizedDescription,
            "pluginError": pluginError
        ]
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("relayStreamResponse", arguments: args)
        }
    }
    
    // Get requestBodySgtream from Flutter
    public func getRequestBodyStream(outputStream: OutputStream) -> Int {
        let streamID = UUID().uuidString
        outputStreams[streamID] = outputStream
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("getFileStream", arguments: streamID)
        }
        return count
    }
    
    public func relayResponse(success: Bool, responseStr: String, errorMessage: String?) {
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("relayResponseMessage", arguments: "Relay Response: \(success) \(responseStr) \(errorMessage ?? "")");
        }
    }
    
    public func streamCompletionPercentage(bytesCompleted: Double, totalBytes: Double) {
        let streamCompletionPercentage = (bytesCompleted/totalBytes)
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("streamCompletionPercentage", arguments: streamCompletionPercentage);
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initializeRelay":
            Task {
                do {
                    relay = try await Relay()
                    relay.relayResponseDelegate = self
                } catch {
                    result(FlutterError(code: "ERROR", message: "Relay not initialized", details: nil))
                }
            }
            result(nil) // No result needed for initialization
            
        case "relayDataTask":
            if let args = call.arguments as? [String: Any] {
                relayDataTask(args, result)
            } else {
                result(FlutterError(code: "ERROR", message: "Relay not initialized or invalid parameters", details: nil))
            }
        case "relayUploadFile":
            if let args = call.arguments as? [String: Any]{
                relay.relayStreamDelegate = self
                relay.relayStreamResponseDelegate = self
                relay.relayStreamCompletionDelegate = self
                streamingResult = result
                relayFileStreamUpload(args, result)
            } else {
                result(FlutterError(code: "ERROR", message: "Relay not initialized or invalid parameters", details: nil))
            }
        case "relayDownloadFile":
        print("Received Download request in Swift")
            if let args = call.arguments as? [String: Any] {
                relay.relayStreamResponseDelegate = self
                streamingResult = result
                relayFileStreamDownload(args, result)
            } else {
                result(FlutterError(code: "ERROR", message: "Relay not initialized or invalid parameters", details: nil))
            }
        case "rePair":
            if let args = call.arguments as? [String: Any] {
                rePair(args, result)
            } else {
                result(FlutterError(code: "ERROR", message: "Relay not initialized or invalid parameters", details: nil))
            }
        case "adjustRelaySettings":
            if let args = call.arguments as? [String: Any] {
                adjustRelaySettings(args, result)
            } else {
                result(FlutterError(code: "ERROR", message: "Relay not initialized or invalid parameters", details: nil))
            }
        case "writeToStream":
            if let args = call.arguments as? [String: Any] {
                writeToStream(arguments: args)
            }else {
                result(FlutterError(code: "ERROR", message: "Invalid parameters", details: nil))
            }
        case "closeStream":
            if let args = call.arguments as? [String: Any] {
                closeStream(arguments: args)
            }else {
                result(FlutterError(code: "ERROR", message: "Invalid parameters", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: Flutter Method Calls to Relay
    fileprivate func relayDataTask(_ args: [String: Any],
                                   _ result: @escaping FlutterResult) {
        guard let urlString = args["url"] as? String,
              let url = URL(string: urlString),
              let method = args["method"] as? String,
              let headers = args["headers"] as? [String: String],
              let headersToEncrypt = args["headersToEncrypt"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        // Safely handle `body` as optional
        let body = args["body"] as? String
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        
        // Set `httpBody` only if `body` exists and is non-empty
        if let body = body, !body.isEmpty {
            var bodyData = Data()

        if let decodedData = Data(base64Encoded: body) {
                bodyData = decodedData
            } else {
                bodyData = body.data(using: .utf8)!
            }

            request.httpBody = bodyData
        }
        Task {
            await relay.dataTask(with: request,
                                 headersToEncrypt: headersToEncrypt,
                                 completionHandler: { (data, response, error) in
                
                guard let relayResponse = response as? HTTPURLResponse else {
                    result(FlutterError(code: "RelayError", message: "Unable to cast response to HTTPURLResponse", details: nil))
                    return
                }
                
                var headers = relayResponse.allHeaderFields as! [String:String]
                
                if let error = error {
                    result([
                        "success": false,
                        "error": "Failed to fetch data",
                        "headers": headers
                    ])
                } else {
                    result([
                        "success": true,
                        "data": data,
                        "headers": headers
                    ])
                }
            })
        }
    }
    
    fileprivate func relayFileStreamUpload(_ args: [String: Any],
                                           _ result: @escaping FlutterResult) {
        guard let urlString = args["url"] as? String,
              let url = URL(string: urlString),
              let method = args["method"] as? String,
              let headers = args["headers"] as? [String: String],
              let headersToEncrypt = args["headersToEncrypt"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        Task {
            try relay.uploadFileStream(request: request, headersToEncrypt: headersToEncrypt)
        }
    }
    
    fileprivate func relayFileStreamDownload(_ args: [String: Any],
                                             _ result: @escaping FlutterResult) {
        guard let urlString = args["url"] as? String,
              let url = URL(string: urlString),
              let method = args["method"] as? String,
              let headers = args["headers"] as? [String: String],
              let headersToEncrypt = args["headersToEncrypt"] as? [String],
              let downloadlocation = args["downloadLocation"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        guard let encodedUrlString = downloadlocation.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let downloadUrl = URL(string: encodedUrlString) else {
            let message = "Invalid downloadUrl: \(downloadlocation)"
            result(FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil))
            return
        }
        Task {
            try relay.downloadFileStream(request: request, downloadUrl: downloadUrl, headersToEncrypt: headersToEncrypt)
        }
    }
    
    fileprivate func rePair(_ args: [String: Any],
                            _ result: @escaping FlutterResult) {
        print(args);
        guard let urlString = args["url"] as? String,
              let _ = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        Task {
            try await relay.rePairMte(relayServerUrlString: urlString) { success in
                Task {
                    if success == true {
                        result("Successfully Re-Paired with \(urlString)")
                    } else {
                        result(FlutterError(code: "Re-Pair Failed", message: "Unable to re-pair with \(urlString)", details: nil))
                    }
                }
            }
        }
    }
    
    fileprivate func adjustRelaySettings(_ args: [String: Any],
                                         _ result: @escaping FlutterResult) {
        var responseMessage = ""
        do {
            if let newStreamChunkSize = args["streamChunkSize"] as? Int,
               newStreamChunkSize != relay.getStreamChunkSizeSetting() {
                try relay.setStreamChunkSize(newStreamChunkSize)
                responseMessage = responseMessage + "\nRelaySetting.streamChunkSize adjusted to \(newStreamChunkSize) "
            }
            if let newPairPoolSize = args["pairPoolSize"] as? Int,
               newPairPoolSize != relay.getPairPoolSizeSetting() {
                try relay.setPairPoolSize(newPairPoolSize)
                responseMessage = responseMessage + "\nRelaySetting.pairPoolSize adjusted to \(newPairPoolSize) "
            }
            if let persistPairs = args["persistPairs"] as? Bool,
               persistPairs != relay.getPersistPairsSetting() {
                try relay.setPersistPairs(persistPairs)
                responseMessage = responseMessage + "/nRelaySetting.persistPairs adjusted to \(persistPairs) "
            }
            if !responseMessage.isEmpty {
                result(responseMessage)
            } else {
                result("No Relay Settings were changed based on arguments and existing RelaySettings")
            }
        } catch {
            result("Adjust RelaySettings Failed")
        }
    }
    
    func writeToStream(arguments: [String: Any]) {
        guard
            let streamID = arguments["streamID"] as? String,
            let data = arguments["data"] as? FlutterStandardTypedData,
            let outputStream = outputStreams[streamID]
        else {
            streamingResult("writeToStream received invalid arguments.")
            return
        }
        let bytes = [UInt8](data.data)
        writeToOutputStream(outputStream: outputStream, buffer: Data(bytes))
    }
    
    func closeStream(arguments: [String: Any]) {
        guard
            let streamID = arguments["streamID"] as? String
        else {
            streamingResult("writeToStream received invalid arguments.")
            return
        }
        if let stream = outputStreams[streamID] {
            stream.close()
            outputStreams.removeValue(forKey: streamID)
        }
    }
    
    func writeToOutputStream(outputStream: OutputStream, buffer: Data) {
        var bytesLeft = buffer.count
        var totalBytesWritten = 0
        
        // Wait until the stream has space available and write in chunks
        while bytesLeft > 0 {
            if outputStream.hasSpaceAvailable {
                // Calculate the range of data to write
                let range = totalBytesWritten..<totalBytesWritten + bytesLeft
                let chunk = buffer.subdata(in: range)
                
                // Write data to the output stream
                let bytesWritten = chunk.withUnsafeBytes {
                    outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: bytesLeft)
                }
                
                // Check for errors
                if bytesWritten < 0 {
                    if let streamError = outputStream.streamError {
                        streamingResult("Stream error: \(streamError.localizedDescription)")
                    }
                    break
                }
                
                // Update counters
                totalBytesWritten += bytesWritten
                bytesLeft -= bytesWritten
            } else {
                // Allow other events to process if the stream is not ready
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            }
        }
    }

    func isUtf8Text(_ data: Data) -> Bool {
    if let _ = String(data: data, encoding: .utf8) {
        return true
    }
    return false
}
}
