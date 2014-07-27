library github;

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import "package:irc/irc.dart";

import 'package:polymorphic_bot/api.dart';

part 'github.dart';
part 'commands.dart';
part 'server.dart';
part 'chan_admin.dart';

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
      case "bot-join":
      case "join":
        handle_team_chan(data);
        break;
    }
  });
  
  bot.config.then((config) {
    if (config['github'] != null) {
      server_listen(config['github']['port']);      
    }
  });
}

void sendRaw(String network, String line) {
  bot.send("raw", {
    "network": network,
    "line": line
  });
}

void handle_message(data) {
  GitHub.handle_issue(data);
  GitHub.handle_repo(data);
}
