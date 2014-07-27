library github;

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import "package:irc/irc.dart";

import 'package:polymorphic_bot/api.dart';

part 'github.dart';

APIConnector bot;

void main(List<String> args, port) {
  print("[GitHub] Loading Plugin");
  bot = new APIConnector(port);
  
  GitHub.initialize();

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
  GitHub.handle_issue(data);
  GitHub.handle_repo(data);
}

void handle_command(data) {
  var network = data['network'] as String;
  var user = data['from'] as String;
  var target = data['target'] as String;
  var command = data['command'] as String;
  var args = data['args'] as List<String>;
  
  void reply(String message) {
    bot.message(network, target, message);
  }
  
  var chanid = "${network}:${target}";

  switch (command) {
    case "gh-hooks":
      if (args.length > 2) {
        reply("> Usage: gh-hooks [user] [token]");
        return;
      }
      
      var gh_user = args.length > 0 ? args[0] : "DirectMyFile";
      var token = args.length == 2 ? args[1] : GitHub.token;
      GitHub.register_github_hooks(gh_user, "${network}:${user}", chanid, token);
      break;
    case "gh-status":
      http.get("https://status.github.com/api/status.json").then((response) {
        var json = JSON.decode(response.body);
        var msg = "${part_prefix("GitHub")} Status: ";
        
        switch (json['status']) {
          case "good":
            msg += "${Color.DARK_GREEN}Good${Color.RESET}";
            break;
          case "minor":
            msg += "${Color.YELLOW}Minor Problems${Color.RESET}";
            break;
          case "major":
            msg += "${Color.RESET}Major Problems${Color.RESET}";
            break;
        }
        
        reply(msg);
      });
      break;
    case "gh-limit":
    case "gh-limits":
      GitHub.get("https://api.github.com/").then((response) {
        var limit = response.headers["x-ratelimit-limit"];
        var remain = response.headers["x-ratelimit-remaining"];
        var reset = response.headers["x-ratelimit-reset"];
        var resets = new DateTime.fromMillisecondsSinceEpoch(int.parse(reset) * 1000);
        reply("${part_prefix("GitHub")} Limit: ${limit}, Remaining: ${remain}, Resets: ${resets}");
      });
      break;
    case "gh-enabled":
      if (args.length != 1) {
        reply("> Usage: gh-enabled <toggle/status>");
        return;
      }
      
      var cmd = args[0];
      
      if (!["toggle", "status"].contains(cmd)) {
        reply("> Usage: gh-enabled <toggle/status>");
        return;
      }
      
      switch (cmd) {
        case "toggle":
          GitHub.enabled = !GitHub.enabled;
          if (GitHub.enabled) {
            reply("${part_prefix("GitHub")} Enabled");
          } else {
            reply("${part_prefix("GitHub")} Disabled");
          }
          break;
        case "status":
          if (GitHub.enabled) {
            reply("${part_prefix("GitHub")} Enabled");
          } else {
            reply("${part_prefix("GitHub")} Disabled");
          }
          break;
      }
      
      break;
  }
}

HttpServer server;

void server_listen(int port) {
  runZoned(() {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer _server) {
      server = _server;
      connected = true;
      server.listen((HttpRequest request) {
        switch (request.uri.path) {
          case "/github":
            GitHub.handle_request(request);
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