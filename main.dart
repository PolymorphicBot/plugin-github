import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:polymorphic_bot/api.dart';
import 'github.dart' as gh;

APIConnector bot;

void main(List<String> args, port) {
  print("[GitHub] Loading Plugin");
  bot = new APIConnector(port);
  
  gh.bot = bot;
  gh.GitHub.initialize();

  bot.handleEvent((data) {
    switch (data['event']) {
      case "command":
        handle_command(data);
        break;
      case "message":
        handle_message(data);
        break;
    }
  });
  
  bot.config.then((config) {
    server_listen(config['github']['port']);
  });
}

void handle_message(data) {
  gh.GitHub.handle_issue(data);
  gh.GitHub.handle_repo(data);
}

void handle_command(data) {
  void reply(String message) {
    bot.message(data['network'], data['target'], message);
  }

  switch (data["command"]) {
  }
}

HttpServer server;

void server_listen(int port) {
  runZoned(() {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer _server) {
      server = _server;
      gh.connected = true;
      server.listen((HttpRequest request) {
        switch (request.uri.path) {
          case "/github":
            gh.GitHub.handle_request(request);
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