part of ghbot;

Future<Map<String, Object>> getChannelInfo(String network, String channel) {
  return bot.get("channel", {
    "network": network,
    "channel": channel
  });
}

void handleTeamChannel(data) {
  if (!GHBot.enabled) {
    return;
  }

  var conf = config['github']['channel_admin'];
  var id = (data['network'] + ":" + data['channel']) as String;
  if (conf != null && conf['in'].contains(id)) {
    if (!conf['enabled']) return;
    getChannelInfo(data['network'], data['channel']).then((chan_info) {
      github.teamMembers(conf['ops_team']).toList().then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member.login) ? config['github']['users'][member.login] : member.login;
          if (!chan_info['ops'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chan_info['members'].contains(name) || chan_info['voices'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +o ${name}");
          }
        }
      });
      
      github.teamMembers(conf['voices_team']).toList().then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member.login) ? config['github']['users'][member.login] : member.login;
          if (!chan_info['voices'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chan_info['members'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +v ${name}");
          }
        }
      });
    });
  }
}
