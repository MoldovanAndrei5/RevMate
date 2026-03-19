import 'package:http/http.dart' as http;

class ApiClient {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get headers {
    final headers = {
      "Content-Type": "application/json",
    };

    if (_token != null) {
      headers["Authorization"] = "Bearer $_token";
    }

    return headers;
  }

  static Future<http.Response> get(Uri url) {
    return http.get(url, headers: headers);
  }

  static Future<http.Response> post(Uri url, {Object? body}) {
    return http.post(url, headers: headers, body: body);
  }

  static Future<http.Response> put(Uri url, {Object? body}) {
    return http.put(url, headers: headers, body: body);
  }

  static Future<http.Response> delete(Uri url) {
    return http.delete(url, headers: headers);
  }
}