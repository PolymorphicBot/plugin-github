library ghbot;

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import "package:irc/client.dart" show Color;
import 'package:github/server.dart';
import 'package:github/dates.dart';

import 'package:polymorphic_bot/api.dart';

part 'ghbot.dart';
part 'commands.dart';
part 'chan_admin.dart';
part 'init.dart';

@BotInstance()
BotConnector bot;

@PluginInstance()
Plugin plugin;

GitHub github;

void main(List<String> args, port) {
  polymorphic(args, port);
}

@Start()
void start() {
  connected = true;

  initGitHub();
  bot = plugin.getBot();

  print("[GitHub] Loading Plugin");

  sleep(new Duration(seconds: 1));
  initialize();

  plugin.onShutdown(() {
    print("[GitHub] Shutting Down");
    github.dispose();
  });

  plugin.createHttpRouter().then((router) {
    router.addRoute("/hook", (request) {
      GHBot.handleHook(request);
    });
  });
}

void sendRaw(String network, String line) {
  bot.sendRawLine(network, line);
}

@OnMessage()
void handleMessage(MessageEvent event) {
  GHBot.handleIssue(event);
  GHBot.handlePullRequest(event);
  GHBot.handleRepository(event);
  GHBot.handleGist(event);
}
