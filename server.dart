part of ghbot;

HttpServer server;

void startHookServer(int port) {
  runZoned(() {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer _server) {
      server = _server;
      connected = true;
      server.listen((HttpRequest request) {
        switch (request.uri.path) {
          case "/github":
            GHBot.handleHook(request);
            break;
          default:
            handle_unhandled_path(request);
        }
      });
    });
  }, onError: (err) {
    print("------------- HTTP Server Error --------------");
    print(err);
    print("----------------------------------------------");
  });
}

void handle_unhandled_path(HttpRequest request) {
  request.response
      ..statusCode = 404
      ..write(JSON.encode({
        "status": "failure",
        "error": "Not Found"
      }))
      ..close();
}