library ghbot;

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import "package:irc/irc.dart";
import 'package:github/server.dart';
import 'package:github/dates.dart';

import 'package:polymorphic_bot/api.dart';

part 'ghbot.dart';
part 'commands.dart';
part 'server.dart';
part 'chan_admin.dart';
part 'init.dart';

APIConnector bot;

GitHub github;

void main(List<String> args, port) {
  initGitHub();
  
  print("[GitHub] Loading Plugin");
  bot = new APIConnector(port);
  
  sleep(new Duration(seconds: 1));
  initialize();
  
  bot.handleEvent((data) {
    switch (data['event']) {
      case "command":
        handleCommand(data);
        break;
      case "message":
        handleMessage(data);
        break;
      case "bot-join":
      case "join":
        if (shouldHandleChanAdmin) {
          handleTeamChannel(data);
        } else {
          joinQueue.add(data);
        }
        break;
    }
  });
  
  bot.config.then((config) {
    if (config['github'] != null) {
      startHookServer(config['github']['port']);      
    }
  });
}

void sendRaw(String network, String line) {
  bot.send("raw", {
    "network": network,
    "line": line
  });
}

void handleMessage(data) {
  GHBot.handleIssue(data);
  GHBot.handleRepository(data);
}
