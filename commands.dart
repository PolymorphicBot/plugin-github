part of ghbot;

@Command("gh-status", permission: "command.status")
void statusCommand(CommandEvent event) {
  github.misc.getApiStatus().then((status) {
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
        msg += "${Color.RED}Major Problems${Color.RESET}";
        break;
    }

    event.reply(msg);
  });
}

@Command("sync-channel", permission: "command.sync-channel")
void syncChannelCommand(CommandEvent event) {
  event.reply("${fancyPrefix("GitHub")} Syncing Channel");

  syncTeamChannel(event.network, event.channel);
}

@Command("gh-limit", permission: "command.limit")
void limitCommand(CommandEvent event) {
  github.misc.getRateLimit().then((limit) {
    event.reply("${fancyPrefix("GitHub")} Limit: ${limit.limit}, Remaining: ${limit.remaining}, Resets: ${friendlyDateTime(limit.resets)}");
  });
}

@Command("gh-members", permission: "command.members")
void membersCommand(CommandEvent event) {
  if (event.args.length == 0) {
    event.reply("> Usage: gh-members <team>");
    return;
  }

  var org = GHBot.getOrganization(event.network, event.channel);

  if (org == null) {
    event.reply("${fancyPrefix("GitHub Teams")} No Organization Configured");
    return;
  }

  var team = event.args.join(" ");

  github.organizations.listTeams(org).toList().then((teams) {
    var names = teams.map((it) => it.name);

    if (!names.contains(team)) {
      event.reply("${fancyPrefix("GitHub Teams")} No Such Team '${team}'");
      return;
    }

    var t = teams.firstWhere((it) => it.name == team);

    github.organizations.listTeamMembers(t.id).toList().then((members) {
      var memberNames = members.map((it) => it.login);

      event.reply("${fancyPrefix("GitHub Teams")} ${team}: ${memberNames.join(", ")}");
    }).catchError((e) {
      event.reply("${fancyPrefix("GitHub Teams")} Failed to get team members.");
    });
  }).catchError((e) {
    if (e is OrganizationNotFound) {
      event.reply("${fancyPrefix("GitHub Teams")} No Such Organization");
      return;
    }
  });
}

@Command("gh-enabled", permission: "command.enabled")
void enabledCommand(CommandEvent event) {
  if (event.args.length != 1) {
    event.reply("> Usage: gh-enabled <toggle/status>");
    return;
  }

  var cmd = event.args[0];

  if (!["toggle", "status"].contains(cmd)) {
    event.reply("> Usage: gh-enabled <toggle/status>");
    return;
  }

  switch (cmd) {
    case "toggle":
      GHBot.enabled = !GHBot.enabled;
      if (GHBot.enabled) {
        event.reply("${fancyPrefix("GitHub")} Enabled");
      } else {
        event.reply("${fancyPrefix("GitHub")} Disabled");
      }
      break;
    case "status":
      if (GHBot.enabled) {
        event.reply("${fancyPrefix("GitHub")} Enabled");
      } else {
        event.reply("${fancyPrefix("GitHub")} Disabled");
      }
      break;
  }
}

@Command("gh-teams", permission: "command.teams")
void teamsCommand(CommandEvent event) {
  var org = GHBot.getOrganization(event.network, event.channel);

  if (org == null) {
    event.reply("${fancyPrefix("GitHub Teams")} No Organization Configured");
    return;
  }

  github.organizations.listTeams(org).toList().then((teams) {
    var names = teams.map((team) => team.name);
    event.reply("${fancyPrefix("GitHub Teams")} ${names.join(", ")}");
  });
}

@Command("gh-stars", permission: "command.stars")
void starsCommand(CommandEvent event) {
  if (event.args.length == 0 || event.args.length > 2) {
    event.reply("> Usage: gh-stars [user] <repository>");
    return;
  }

  var user = event.args.length == 2 ? event.args[0] : GHBot.getOrganization(event.network, event.channel);
var repo = event.args.length == 1 ? event.args[0] : event.args[1];

  var slug = new RepositorySlug(user, repo);

  github.repositories.getRepository(slug).then((repo) {
    var stars = repo.stargazersCount;

    event.reply("${fancyPrefix("GitHub")} Stars: ${stars}");
  }).catchError((e) {
    if (e is RepositoryNotFound) {
      event.reply("${fancyPrefix("GitHub")} Repository Not Found");
    }
  });
}

