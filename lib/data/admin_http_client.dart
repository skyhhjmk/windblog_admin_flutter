import 'package:http/http.dart' as http;

import 'admin_http_client_stub.dart'
    if (dart.library.io) 'admin_http_client_io.dart'
    as platform;

http.Client createAdminHttpClient() {
  return platform.createAdminHttpClient();
}
