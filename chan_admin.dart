part of ghbot;

Future<Map<String, Object>> getChannelInfo(String network, String channel) {
  return plugin.callMethod("getChannel", {
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
    getChannelInfo(data['network'], data['channel']).then((chanInfo) {
      github.organizations.listTeamMembers(conf['ops_team']).toList().then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member.login) ? config['github']['users'][member.login] : member.login;
          if (!chanInfo['ops'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chanInfo['members'].contains(name) || chanInfo['voices'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +o ${name}");
          }
        }
      });
      
      github.organizations.listTeamMembers(conf['voices_team']).toList().then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member.login) ? config['github']['users'][member.login] : member.login;
          if (!chanInfo['voices'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chanInfo['members'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +v ${name}");
          }
        }
      });
    });
  }
}
