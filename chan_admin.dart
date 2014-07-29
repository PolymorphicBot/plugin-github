part of github;

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
  var id = (data['network'] + ":" + data['channel']) as String;
  if (conf != null && conf['in'].contains(id)) {
    if (!conf['enabled']) return;
    sleep(new Duration(seconds: 2));
    chan_info(data['network'], data['channel']).then((chan_info) {
      GitHub.team_members("https://api.github.com/teams/${conf['ops_team']}").then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member['login']) ? config['github']['users'][member['login']] : member['login'];
          if (!chan_info['ops'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chan_info['members'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +o ${name}");
          }
        }
      });
      GitHub.team_members("https://api.github.com/teams/${conf['voices_team']}").then((members) {
        for (var member in members) {
          var name = config['github']['users'].containsKey(member['login']) ? config['github']['users'][member['login']] : member['login'];
          if (!chan_info['voices'].map((it) => it.toLowerCase()).contains(name.toLowerCase()) && chan_info['members'].contains(name)) {
            sendRaw(data['network'], "MODE ${data['channel']} +v ${name}");
          }
        }
      });
    });
  }
}