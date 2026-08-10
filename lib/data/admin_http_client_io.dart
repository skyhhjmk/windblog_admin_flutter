import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

http.Client createAdminHttpClient() {
  final inner = HttpClient()..idleTimeout = const Duration(minutes: 10);
  return http_io.IOClient(inner);
}
