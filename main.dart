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
      case "bot-join":
        handle_team_chan(data);
        break;
      case "join":
        handle_team_chan(data);
        break;
    }
  });
  
  bot.config.then((config) {
    server_listen(config['github']['port']);
  });
}

Map<String, Object> get chan_admin_conf {
  if (config['github']['channel_admin'] != null) {
    return config['github']['channel_admin'];
  } else {
    return null;
  }
}

Future<Map<String, Object>> chan_info(String network, String channel) {
  return bot.get("channel", { "network": network, "channel": channel });
}

void handle_team_chan(data) {
  if (!GitHub.enabled) {
    return;
  }
  var conf = chan_admin_conf;
  var id = data['network'] + ":" + data['channel'];
  if (conf != null && conf['in'].contains(id)) {
    if (!conf['enabled']) return;
    sleep(new Duration(seconds: 2));
    chan_info(data['network'], data['channel']).then((chan_info) {
      GitHub.team_members("https://api.github.com/teams/${conf['ops_team']}").then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member['login']) ? config['github']['users'][member['login']] : member['login'];
          if (!chan_info['ops'].map((it) => it.toLowerCase()).contains(name.toLowerCase())) {
            sendRaw(data['network'], "MODE ${data['channel']} +o ${name}");
          }
        }
      });
      GitHub.team_members("https://api.github.com/teams/${conf['voices_team']}").then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member['login']) ? config['github']['users'][member['login']] : member['login'];
          if (!chan_info['voices'].map((it) => it.toLowerCase()).contains(name.toLowerCase())) {
            sendRaw(data['network'], "MODE ${data['channel']} +v ${name}");
          }
        }
      });
    });
  }
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
  
  if (!GitHub.enabled && command != "gh-enabled") {
    return;
  }

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
    case "gh-teams":
      var org = config['github']['organization'];
      if (org == null) {
        reply("${part_prefix("GitHub Teams")} No Organization Configured");
        return;
      }
      GitHub.teams(org).then((teams) {
        var names = teams.map((team) => team['name']);
        reply("${part_prefix("GitHub Teams")} ${names.join(", ")}");
      });
      break;
    case "gh-members":
      if (args.length != 1) {
        reply("> Usage: gh-members <team>");
        return;
      }
      var org = config['github']['organization'];
      
      if (org == null) {
        reply("${part_prefix("GitHub Teams")} No Organization Configured");
        return;
      }
      
      var team = args[0];
      GitHub.teams(org).then((teams) {
        if (teams == null) {
          reply("${part_prefix("GitHub Teams")} Failed to get team.");
          return;
        }
        
        var teamz = {};
        
        teams.forEach((team) {
          teamz[team['name']] = team;
        });
        
        if (!teamz.containsKey(team)) {
          reply("${part_prefix("GitHub Teams")} No Such Team '${team}'");
          return;
        }
        
        GitHub.team_members(teamz[team]['url']).then((members) {
          if (members == null) {
            reply("${part_prefix("GitHub Teams")} Failed to get team members.");
            return;
          }
          var names = members.map((member) => member['login']);
          reply("${part_prefix("GitHub Teams")} ${team}: ${names.join(", ")}");
        });
      });
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