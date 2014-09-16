part of ghbot;

void handleCommand(data) {
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

  if (!GHBot.enabled && command != "gh-enabled") {
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
        var token = args.length == 2 ? args[1] : GHBot.token;
        GHBot.registerHooks(gh_user, "${network}:${user}", chanid, token);
      });
      break;
    case "gh-status":
      require("command.status", () {

        github.apiStatus().then((status) {
          var state = status.status;

          var msg = "${fancyPrefix("GitHub")} Status: ";

          switch (state) {
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
    case "sync-channel":
      reply("${fancyPrefix("GitHub")} Syncing Channel");
      data['channel'] = target;
      handleTeamChannel(data);
      break;
    case "gh-limit":
    case "gh-limits":
      require("command.limits", () {
        github.rateLimit().then((limit) {
          reply("${fancyPrefix("GitHub")} Limit: ${limit.limit}, Remaining: ${limit.remaining}, Resets: ${friendlyDateTime(limit.resets)}");
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
            GHBot.enabled = !GHBot.enabled;
            if (GHBot.enabled) {
              reply("${fancyPrefix("GitHub")} Enabled");
            } else {
              reply("${fancyPrefix("GitHub")} Disabled");
            }
            break subcmd;
          case "status":
            if (GHBot.enabled) {
              reply("${fancyPrefix("GitHub")} Enabled");
            } else {
              reply("${fancyPrefix("GitHub")} Disabled");
            }
            break subcmd;
        }
      });

      break;
    case "gh-teams":

      require("command.teams", () {
        String org = config['github']['organization'];
        if (org == null) {
          reply("${fancyPrefix("GitHub Teams")} No Organization Configured");
          return;
        }

        github.teams(org).toList().then((teams) {
          var names = teams.map((team) => team.name);
          reply("${fancyPrefix("GitHub Teams")} ${names.join(", ")}");
        });

      });
      break;
    case "gh-members":

      require("command.members", () {
        if (args.length == 0) {
          reply("> Usage: gh-members <team>");
          return;
        }
        var org = config['github']['organization'];

        if (org == null) {
          reply("${fancyPrefix("GitHub Teams")} No Organization Configured");
          return;
        }

        var team = args.join(" ");

        github.teams(org).toList().then((teams) {
          var names = teams.map((it) => it.name);

          if (!names.contains(team)) {
            reply("${fancyPrefix("GitHub Teams")} No Such Team '${team}'");
            return;
          }

          var t = teams.firstWhere((it) => it.name == team);

          github.teamMembers(t.id).toList().then((members) {
            var memberNames = members.map((it) => it.login);

            reply("${fancyPrefix("GitHub Teams")} ${team}: ${memberNames.join(", ")}");
          }).catchError((e) {
            reply("${fancyPrefix("GitHub Teams")} Failed to get team members.");
          });
        }).catchError((e) {
          if (e is OrganizationNotFound) {
            reply("${fancyPrefix("GitHub Teams")} No Such Organization");
            return;
          }
        });
      });
      break;
    case "gh-stars":
      require("command.stars", () {
        if (args.length == 0 || args.length > 2) {
          reply("> Usage: gh-stars [user] <repository>");
          return;
        }

        var user = args.length == 2 ? args[0] : config['github']['organization'];
        var repo = args.length == 1 ? args[0] : args[1];
        
        var slug = new RepositorySlug(user, repo);
        
        github.repository(slug).then((repo) {
          var stars = repo.stargazersCount;
          
          reply("${fancyPrefix("GitHub")} Stars: ${stars}");
        }).catchError((e) {
          if (e is RepositoryNotFound) {
            reply("${fancyPrefix("GitHub")} Repository Not Found");
          }
        });
      });
      break;
  }
}
