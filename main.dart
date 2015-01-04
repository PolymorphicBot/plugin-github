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
Plugin plugin;
GitHub github;

void main(List<String> args, Plugin myPlugin) {
  plugin = myPlugin;
  initGitHub();
  
  print("[GitHub] Loading Plugin");
  bot = plugin.getBot();
  
  sleep(new Duration(seconds: 1));
  initialize();
  
  plugin.on("command").listen(handleCommand);
  plugin.on("message").listen(handleMessage);
  plugin.on("join").listen((data) {
    if (shouldHandleChanAdmin) {
      handleTeamChannel(data);
    } else {
      joinQueue.add(data);
    }
  });
  
  plugin.onShutdown(() {
    print("[GitHub] Shutting Down");
    server.close(force: true);
    github.dispose();
  });
  
  bot.config.then((config) {
    if (config['github'] != null) {
      startHookServer(config['github']['port']);      
    }
  });
}

void sendRaw(String network, String line) {
  bot.sendRawLine(network, line);
}

void handleMessage(data) {
  GHBot.handleIssue(data);
  GHBot.handleRepository(data);
}
