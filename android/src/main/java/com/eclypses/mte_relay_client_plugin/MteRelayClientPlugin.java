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

package com.eclypses.mte_relay_client_plugin;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import com.android.volley.AuthFailureError;
import com.android.volley.Request;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.android.volley.VolleyError;
import com.android.volley.toolbox.JsonArrayRequest;
import com.android.volley.toolbox.JsonObjectRequest;
import com.android.volley.toolbox.StringRequest;
import com.mte.relay.Relay;
import com.mte.relay.RelayDataTaskListener;
import com.mte.relay.RelayFileRequestProperties;
import com.mte.relay.RelayResponseListener;
import com.mte.relay.RelayStreamCallback;
import com.mte.relay.RelayStreamCompletionCallback;
import com.mte.relay.RelayStreamResponseListener;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.OutputStream;
import java.io.PipedOutputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public class MteRelayClientPlugin implements FlutterPlugin, MethodCallHandler {
  private Context context;
  private MethodChannel methodChannel;
  private Relay relay;
  private final Map<String, OutputStream> outputStreams = new HashMap<>();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    this.context = flutterPluginBinding.getApplicationContext();
    methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mte_relay_client_plugin");
    methodChannel.setMethodCallHandler(this);
  }

  // RELAY CALLBACKS
  RelayResponseListener relayResponseListener = (success, message) -> relayResponse(success, message, null);

  private void relayResponse(boolean success, String responseStr, String errorMessage) {
    String resultMessage = "Relay Response: " + success + " " + responseStr + " " + (errorMessage != null ? errorMessage : "");

    new Handler(Looper.getMainLooper()).post(() -> {
      if (methodChannel != null) {
        methodChannel.invokeMethod("relayResponseMessage", resultMessage);
      }
    });
  }

  private void relayStreamResponseMethod(boolean success,
                                         String responseStr,
                                         String errorMessage,
                                         Map<String, List<String>> responseHeaders) {

    Map<String, Object> args = new HashMap<>();
    args.put("success", success);
    args.put("data", responseStr.getBytes(StandardCharsets.UTF_8));
    args.put("headers", responseHeaders);
    args.put("relayError", errorMessage);
    args.put("pluginError", null);

    new Handler(Looper.getMainLooper()).post(() -> {
      if (methodChannel != null) {
        methodChannel.invokeMethod("relayStreamResponse", args);
      }
    });
  }

  RelayStreamResponseListener listener = this::relayStreamResponseMethod;

  RelayStreamCallback relayStreamCallback = new RelayStreamCallback() {
    @Override
    public void getRequestBodyStream(PipedOutputStream outputStream) {
      String streamID = UUID.randomUUID().toString();
      outputStreams.put(streamID, outputStream);

      // Run the invokeMethod call on the main thread
      new Handler(Looper.getMainLooper()).post(() -> {
        if (methodChannel != null) {
          methodChannel.invokeMethod("getFileStream", streamID);
        }
      });
    }
  };

  RelayStreamCompletionCallback relayStreamCompletionCallback = new RelayStreamCompletionCallback() {
    @Override
    public void onProgressUpdate(int bytesCompleted, int totalBytes) {
      double streamCompletionPercentage = ((double) bytesCompleted / totalBytes);

      new Handler(Looper.getMainLooper()).post(() -> {
        if (methodChannel != null) {
          methodChannel.invokeMethod("streamCompletionPercentage", streamCompletionPercentage);
        }
      });
    }
  };

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {

      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;

      case "initializeRelay":
        relay = Relay.getInstance(context, relayResponseListener);
        break;

      case "relayDataTask":
        try {
          Map<String, Object> args = ensureArgumentsMap(call.arguments);
          relayDataTask(args, result);
        } catch (IllegalArgumentException e) {
          result.error("INVALID_ARGUMENTS", e.getMessage(), null);
        }
        break;

      case "relayUploadFile":
        Map<String, Object> uploadArgs = ensureArgumentsMap(call.arguments);
        relayFileStreamUpload(uploadArgs, result);
        break;

      case "relayDownloadFile":
        Map<String, Object> downloadArgs = ensureArgumentsMap(call.arguments);
        relayFileStreamDownload(downloadArgs, result);
        break;

      case "rePair":
        try {
          Map<String, Object> rePairArgs = ensureArgumentsMap(call.arguments);
          rePair(rePairArgs, result);
        } catch (IllegalArgumentException e) {
          result.error("INVALID_ARGUMENTS", e.getMessage(), null);
        }
        break;

      case "adjustRelaySettings":
        try {
          Map<String, Object> adjustRelayArgs = ensureArgumentsMap(call.arguments);
          adjustRelaySettings(adjustRelayArgs);
        } catch (IllegalArgumentException e) {
          result.error("INVALID_ARGUMENTS", e.getMessage(), null);
        }
        break;

      case "writeToStream":
        try {
          Map<String, Object> writeToStreamArgs = ensureArgumentsMap(call.arguments);
          writeToStream(writeToStreamArgs, result);
        } catch (IllegalArgumentException e) {
          result.error("INVALID_ARGUMENTS", e.getMessage(), null);
        }
        break;

      case "closeStream":
        try {
          Map<String, Object> closeStreamArgs = ensureArgumentsMap(call.arguments);
          closeStream(closeStreamArgs, result);
        } catch (IllegalArgumentException e) {
          result.error("INVALID_ARGUMENTS", e.getMessage(), null);
        }
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  // CALL TO NATIVE METHODS

  @SuppressWarnings("unchecked")
  private void relayFileStreamUpload(Map<String, Object> args, MethodChannel.Result result) {
    String[] headersToEncrypt = new String[0];
    try {
      String urlString = (String) args.get("url");
      String pathnamePrefix = (String) args.get("pathnamePrefix");
      String methodString = (String) args.get("method");
      Map<String, String> headers = (Map<String, String>) args.get("headers");
      List<String> headersToEncryptList = (List<String>) args.get("headersToEncrypt");
      if (headersToEncryptList != null) {
        headersToEncrypt = headersToEncryptList.toArray(new String[0]);
      }

      if (urlString == null || methodString == null || headers == null) {
        result.error("INVALID_ARGUMENTS", "Invalid arguments", null);
        return;
      }
      if (!methodString.equals("POST")) {
        relayResponse(
                false,
                "\nError Code 418",
                "Currently, only POST requests for streamed file uploads are supported."
        );
      }

      URL url = new URL(urlString);
      String protocol = url.getProtocol();
      String authority = url.getAuthority();
      String route = url.getPath();
      String host = protocol + "://" + authority;

      RelayFileRequestProperties reqProperties = new RelayFileRequestProperties(
              host,
              headers,
              headersToEncrypt,
              relayStreamCallback);

      relay.uploadFile(
              reqProperties,
              route,
              pathnamePrefix,
              listener,
              (i, i1) -> relayStreamCompletionCallback.onProgressUpdate(i, i1));

    } catch (Exception e) {
      result.error("", e.getMessage(), null);
    }
  }

  @SuppressWarnings("unchecked")
  private void relayFileStreamDownload(Map<String, Object> args, MethodChannel.Result result) {
    String[] headersToEncrypt = new String[0];
    try {
      String urlString = (String) args.get("url");
      String pathnamePrefix = (String) args.get("pathnamePrefix");
      String methodString = (String) args.get("method");
      Map<String, String> headers = (Map<String, String>) args.get("headers");
      List<String> headersToEncryptList = (List<String>) args.get("headersToEncrypt");
      if (headersToEncryptList != null) {
        headersToEncrypt = headersToEncryptList.toArray(new String[0]);
      }
      String downloadLocation = (String) args.get("downloadLocation");

      if (urlString == null || methodString == null || headers == null || downloadLocation == null) {
        result.error("INVALID_ARGUMENTS", "Invalid arguments", null);
        return;
      }

      URL url = new URL(urlString);
      String protocol = url.getProtocol();
      String authority = url.getAuthority();
      String route = url.getPath();
      String host = protocol + "://" + authority;

      RelayFileRequestProperties reqProperties = new RelayFileRequestProperties(
              host,
              route,
              downloadLocation,
              headers,
              headersToEncrypt);

      relay.downloadFile(
              reqProperties,
              pathnamePrefix,
              listener);

    } catch (Exception e) {
      result.error("", e.getMessage(), null);
    }
  }

  @SuppressWarnings("unchecked")
  private void relayDataTask(Map<String, Object> args, MethodChannel.Result result) {
    final Map<String, Object> resultMap = new HashMap<>();
    VolleyRequestListener listener = new VolleyRequestListener() {

      @Override
      public void onError(String message, Map<String, List<String>> responseHeaders) {
        resultMap.put("success", false);
        resultMap.put("data", null);
        resultMap.put("headers", responseHeaders);
        result.success(resultMap);
      }

      @Override
      public void onJsonResponse(JSONObject response, Map<String, List<String>> responseHeaders) {
        resultMap.put("success", true);
        resultMap.put("data", response.toString().getBytes(StandardCharsets.UTF_8));
        resultMap.put("headers", responseHeaders);
        result.success(resultMap);
      }

      @Override
      public void onJsonArrayResponse(JSONArray response, Map<String, String> responseHeaders) {
        resultMap.put("success", true);
        resultMap.put("data", response.toString().getBytes(StandardCharsets.UTF_8));
        resultMap.put("headers", responseHeaders);
        result.success(resultMap);
      }

      @Override
      public void onStringResponse(String response, Map<String, String> responseHeaders) {
        resultMap.put("success", true);
        resultMap.put("data", response.getBytes(StandardCharsets.UTF_8));
        resultMap.put("headers", responseHeaders);
        result.success(resultMap);
      }
    };

    String[] headersToEncrypt = new String[0];
    try {
      String urlString = (String) args.get("url");
      String pathnamePrefix = (String) args.get("pathnamePrefix");
      String methodString = (String) args.get("method");
      Map<String, String> headers = (Map<String, String>) args.get("headers");
      String body = (String) args.get("body");
      List<String> headersToEncryptList = (List<String>) args.get("headersToEncrypt");
      if (headersToEncryptList != null) {
        headersToEncrypt = headersToEncryptList.toArray(new String[0]);
      }
      Set<String> methodsRequiringBody = new HashSet<>(Set.of("POST", "PUT", "PATCH"));
      if (urlString == null ||
              methodString == null ||
              headers == null ||
              (methodsRequiringBody.contains(methodString) && body == null)) {
        result.error("INVALID_ARGUMENTS", "Invalid arguments", null);
        return;
      }

      // Check for Base64 Encoding on body if it exists
      String bodyStr = null;
      if (body != null && !body.isEmpty()) {
        try {
          byte[] decodedBytes = Base64.getDecoder().decode(body);
          bodyStr = new String(decodedBytes, StandardCharsets.UTF_8);
        } catch (IllegalArgumentException e) {
          bodyStr = body;
        }
      }

      int method = getRequestMethod(methodString);

      Request<?> request = createRequest(bodyStr, method, urlString, listener, headers);
      sendToRelay(request, headersToEncrypt, pathnamePrefix, listener);
    } catch (Exception e) {
      resultMap.put("success", false);
      resultMap.put("data", e.getMessage().getBytes(StandardCharsets.UTF_8));
      resultMap.put("headers", null);
      result.success(resultMap);
    }
  }

  private void writeToStream(Map<String, Object> args, MethodChannel.Result result) {
    String streamID = (String) args.get("streamID");
    byte[] data = (byte[]) args.get("data");
    OutputStream outputStream = outputStreams.get(streamID);

    if (streamID == null || data == null || outputStream == null) {
      relayStreamResponseMethod(
              false,
              "",
              "writeToStream received invalid arguments.",
              null);
      return;
    }
    writeToOutputStream(outputStream, data);
  }

  private void closeStream(Map<String, Object> args, MethodChannel.Result result) {

    String streamID = (String) args.get("streamID");
    if (streamID == null) {
      relayStreamResponseMethod(
              false,
              "",
              "closeStream received invalid arguments.",
              null);
      return;
    }

    OutputStream outputStream = outputStreams.remove(streamID);
    if (outputStream != null) {
      try {
        outputStream.close(); // Ensure it is closed
      } catch (IOException e) {
        relayStreamResponseMethod(
                false,
                null,
                "closeStream Exception: " + e.getMessage(),
                null);
      }
    }
  }

  private void rePair(Map<String, Object> args, MethodChannel.Result result) {
    String urlString = (String) args.get("url");
    relay.rePairWithRelayServer(urlString);
  }

  private void adjustRelaySettings(Map<String, Object> args) {
    String serverUrl = null;
    int newStreamChunkSize = 0;
    int newPairPoolSize = 0;
    Boolean persistPairs = false;

    try {
      if (args.containsKey("serverUrl")) {
        Object serverUrlObj = args.get("serverUrl");
        if (serverUrlObj instanceof String) {
          serverUrl = (String) serverUrlObj;
        }
      }
      if (args.containsKey("streamChunkSize")) {
        Object streamChunkSizeObj = args.get("streamChunkSize");
        if (streamChunkSizeObj instanceof Integer) {
          newStreamChunkSize = (Integer) streamChunkSizeObj;
        }
      }
      if (args.containsKey("pairPoolSize")) {
        Object pairPoolSizeObj = args.get("pairPoolSize");
        if (pairPoolSizeObj instanceof Integer) {
          newPairPoolSize = (Integer) pairPoolSizeObj;
        }
      }

      if (args.containsKey("persistPairs")) {
        Object persistPairsObj = args.get("persistPairs");
        if (persistPairsObj instanceof Boolean) {
          persistPairs = (Boolean) persistPairsObj;
        }
      }
      String responseMessage = relay.adjustRelaySettings(serverUrl,
              newStreamChunkSize,
              newPairPoolSize,
              persistPairs);
      relayResponse(
              true,
              responseMessage,
              null
      );
    } catch (Exception e) {
      relayResponse(
              false,
              "\nAdjust RelaySettings Failed",
              "Error: " + e.getMessage()
      );
    }
  }

  private <T> void sendToRelay(Request<T> request, String[] headerArray, String pathnamePrefix, VolleyRequestListener listener) {
    relay.addToMteRequestQueue(request, headerArray, pathnamePrefix, new RelayDataTaskListener() {
      @Override
      public void onError(String message, Map<String, List<String>> responseHeaders) {
        listener.onError(message, responseHeaders);
      }

      @Override
      public void onResponse(byte[] responseBytes, Map<String, List<String>> responseHeaders) {
        try {
          String jsonString = new String(responseBytes);

          if (jsonString.trim().startsWith("{")) {
            JSONObject jsonObject = new JSONObject(jsonString);
            listener.onJsonResponse(jsonObject, responseHeaders);
          } else if (jsonString.trim().startsWith("[")) {
            JSONArray jsonArray = new JSONArray(jsonString);
            listener.onJsonArrayResponse(jsonArray, null);
          } else {
            listener.onError("Response Byte[] contains INVALID JSON", responseHeaders);
          }
        } catch (JSONException e) {
          listener.onError(e.getMessage(), responseHeaders);
        }
      }

      @Override
      public void onResponse(JSONObject responseJson, Map<String, List<String>> responseHeaders) {
        listener.onJsonResponse(responseJson, responseHeaders);
      }
    });
  }

  // UTILITY METHODS

  @NonNull
  private Request<?> createRequest(String body, int method, String urlString, VolleyRequestListener listener, Map<String, String> headers) throws JSONException {
    Request<?> request;
    if (body == null || body.isEmpty()) {
      // Handle null or empty body (create a JSON request with null body)
      request = new JsonObjectRequest(
              method,
              urlString,
              null,
              response -> listener.onJsonResponse(response, null),
              error -> listener.onError(error.toString(), null)) {

        @Override
        public Map<String, String> getHeaders() throws AuthFailureError {
          return headers;
        }
      };
    } else {
      String trimmedBody = body.trim();
      if (trimmedBody.startsWith("{")) {
        request = new JsonObjectRequest(
                method,
                urlString,
                new JSONObject(trimmedBody),
                response -> listener.onJsonResponse(response, null),
                error -> listener.onError(error.toString(), null)) {

          @Override
          public Map<String, String> getHeaders() throws AuthFailureError {
            return headers;
          }
        };
      } else if (trimmedBody.startsWith("[")) {
        request = new JsonArrayRequest(
                method,
                urlString,
                new JSONArray(trimmedBody),
                response -> listener.onJsonArrayResponse(response, null),
                error -> listener.onError(error.toString(), null)) {

          @Override
          public Map<String, String> getHeaders() throws AuthFailureError {
            return headers;
          }
        };
      } else {
        request = new StringRequest(
                method,
                urlString,
                response -> listener.onStringResponse(response, null),
                error -> {
                  String errorMessage = getVolleyErrorString(error);
                  listener.onError(errorMessage, null);
                }) {
          @Override
          public byte[] getBody() {
            return body.getBytes(StandardCharsets.UTF_8);
          }
          @Override
          public Map<String, String> getHeaders() throws AuthFailureError {
            return headers;
          }
        };
      }
    }
    return request;
  }

  private void writeToOutputStream(OutputStream outputStream, byte[] buffer) {
    int totalBytesWritten = 0;
    try {
      while (totalBytesWritten < buffer.length) {
        int bytesToWrite = buffer.length - totalBytesWritten;
        outputStream.write(buffer, totalBytesWritten, bytesToWrite);
        totalBytesWritten += bytesToWrite;
      }
    } catch (IOException e) {
      relayStreamResponseMethod(
              false,
              null,
              e.getMessage(),
              null);
    }
  }

  private String getVolleyErrorString(VolleyError error) {
    if (error.networkResponse != null && error.networkResponse.data != null) {
      try {
        // Attempt to parse error response data as a string
        return new String(error.networkResponse.data, StandardCharsets.UTF_8);
      } catch (Exception e) {
        return "Error parsing error response: " + e.getMessage();
      }
    } else if (error.getMessage() != null) {
      return error.getMessage();
    } else {
      return "Unknown error occurred";
    }
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> ensureArgumentsMap(Object arguments) {
    if (arguments instanceof Map) {
      try {
        return (Map<String, Object>) arguments; // Suppressed internally
      } catch (ClassCastException e) {
        throw new IllegalArgumentException("Invalid argument map structure", e);
      }
    } else {
      throw new IllegalArgumentException("Expected arguments of type Map<String, Object>");
    }
  }

  public static int getRequestMethod(String method) {
    switch (method.toUpperCase()) {
      case "GET":
        return Request.Method.GET;
      case "POST":
        return Request.Method.POST;
      case "PUT":
        return Request.Method.PUT;
      case "DELETE":
        return Request.Method.DELETE;
      case "HEAD":
        return Request.Method.HEAD;
      case "OPTIONS":
        return Request.Method.OPTIONS;
      case "TRACE":
        return Request.Method.TRACE;
      case "PATCH":
        return Request.Method.PATCH;
      default:
        throw new IllegalArgumentException("Invalid HTTP method: " + method);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    this.context = null;
    methodChannel.setMethodCallHandler(null);
  }

  public Context getContext() {
    return context;
  }
}
