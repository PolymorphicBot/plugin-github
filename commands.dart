part of github;

void handle_command(data) {
  var network = data['network'] as String;
  var user = data['from'] as String;
  var target = data['target'] as String;
  var command = data['command'] as String;
  var args = data['args'] as List<String>;

  void reply(String message) {
    bot.message(network, target, message);
  }

  void require(String permission, void handle()) {
    bot.permission((it) => handle(), network, target, user, permission);
  }

  var chanid = "${network}:${target}";

  if (!GitHub.enabled && command != "gh-enabled") {
    return;
  }

  switch (command) {
    case "gh-hooks":
      require("command.hooks", () {
        if (args.length > 2) {
          reply("> Usage: gh-hooks [user] [token]");
          return;
        }

        var gh_user = args.length > 0 ? args[0] : "DirectMyFile";
        var token = args.length == 2 ? args[1] : GitHub.token;
        GitHub.register_github_hooks(gh_user, "${network}:${user}", chanid, token);
      });
      break;
    case "gh-status":
      require("command.status", () {
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
      });
      break;
    case "gh-limit":
    case "gh-limits":
      require("command.limits", () {
        GitHub.get("https://api.github.com/").then((response) {
          var limit = response.headers["x-ratelimit-limit"];
          var remain = response.headers["x-ratelimit-remaining"];
          var reset = response.headers["x-ratelimit-reset"];
          var resets = new DateTime.fromMillisecondsSinceEpoch(int.parse(reset) * 1000);
          reply("${part_prefix("GitHub")} Limit: ${limit}, Remaining: ${remain}, Resets: ${resets}");
        });
      });
      break;
    case "gh-enabled":

      require("command.enabled", () {
        if (args.length != 1) {
          reply("> Usage: gh-enabled <toggle/status>");
          return;
        }

        var cmd = args[0];

        if (!["toggle", "status"].contains(cmd)) {
          reply("> Usage: gh-enabled <toggle/status>");
          return;
        }

        subcmd: switch (cmd) {
          case "toggle":
            GitHub.enabled = !GitHub.enabled;
            if (GitHub.enabled) {
              reply("${part_prefix("GitHub")} Enabled");
            } else {
              reply("${part_prefix("GitHub")} Disabled");
            }
            break subcmd;
          case "status":
            if (GitHub.enabled) {
              reply("${part_prefix("GitHub")} Enabled");
            } else {
              reply("${part_prefix("GitHub")} Disabled");
            }
            break subcmd;
        }
      });

      break;
    case "gh-teams":

      require("command.teams", () {
        var org = config['github']['organization'];
        if (org == null) {
          reply("${part_prefix("GitHub Teams")} No Organization Configured");
          return;
        }
        GitHub.teams(org).then((teams) {
          var names = teams.map((team) => team['name']);
          reply("${part_prefix("GitHub Teams")} ${names.join(", ")}");
        });
      });
      break;
    case "gh-members":

      require("command.members", () {
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
      });
      break;
  }
}
