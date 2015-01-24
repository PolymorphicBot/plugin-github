part of ghbot;

Future<Map<String, Object>> getChannelInfo(String network, String channel) {
  return plugin.callMethod("getChannel", {
    "network": network,
    "channel": channel
  });
}

String getUserName(String name) {
  var mapping = config["github"]["users"];

  if (mapping != null && mapping.containsKey(name)) {
    return mapping[name];
  } else {
    return name;
  }
}

void syncTeamChannel(String network, String channel) {
  if (!GHBot.enabled) {
    return;
  }

  Map<String, dynamic> conf = config['github']['channel_admin'];

  if (conf == null) {
    return;
  }

  var id = "${network}:${channel}";
  List<Map<String, dynamic>> channels = conf["channels"];
  if (!conf['enabled']) return;

  if (!channels.any((it) => it["network"] == network && it["channel"] == channel)) {
    return;
  }

  var c = channels.firstWhere((it) => it["network"] == network && it["channel"] == channel);
  
  if (c["enabled"] == false) {
    return;
  }
  
  var opsTeam = c["ops_team"];
  var voicesTeam = c["voices_team"];
  
  bot.getChannel(network, channel).then((info) {
    github.organizations.listTeamMembers(opsTeam).toList().then((members) {
      for (var member in members) {
        var name = getUserName(member.login).toLowerCase();
        var ops = info.ops.map((it) => it.toLowerCase());
        var members = info.members.map((it) => it.toLowerCase());

        if (!ops.contains(name) && members.contains(name)) {
          bot.op(network, channel, name);
        }
      }
    });

    github.organizations.listTeamMembers(voicesTeam).toList().then((members) {
      for (var member in members) {
        var name = getUserName(member.login).toLowerCase();
        var voices = info.voices.map((it) => it.toLowerCase());
        var members = info.members.map((it) => it.toLowerCase());

        if (!voices.contains(name) && members.contains(name)) {
          bot.voice(network, channel, name);
        }
      }
    });
  });
}
