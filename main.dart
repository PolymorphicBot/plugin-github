library ghbot;

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import "package:irc/client.dart";
import 'package:github/server.dart';
import 'package:github/dates.dart';

import 'package:quiver/async.dart';
import 'package:polymorphic_bot/api.dart';

part 'ghbot.dart';
part 'commands.dart';
part 'server.dart';
part 'chan_admin.dart';
part 'init.dart';

BotConnector bot;

GitHub github;

void main(List<String> args, port) {
  initGitHub();
  
  print("[GitHub] Loading Plugin");
  bot = new BotConnector(port);
  
  sleep(new Duration(seconds: 1));
  initialize();
  var sub;
  sub = bot.handleEvent((data) {
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
      case "shutdown":
        print("[GitHub] Shutting Down");
        server.close(force: true);
        github.dispose();
        sub.cancel();
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
