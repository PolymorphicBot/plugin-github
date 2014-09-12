part of ghbot;

void initialize() {
  bool first = true;
  var update = ([_]) {
    bot.config.then((c) {
      config = c;
      
      if (config['github'] == null) {
        GHBot.enabled = false;
        return;
      }
      GHBot.token = config["github"]["token"];
      
      if (config['github']['enabled'] == false) {
        GHBot.enabled = false;
      }
      
      if (first) {
        github = new GitHub(auth: new Authentication.withToken(GHBot.token));
        first = false;
      } else {
        github.auth = new Authentication.withToken(GHBot.token);
      }

      shouldHandleChanAdmin = true;

      while (joinQueue.isNotEmpty) {
        handleTeamChannel(joinQueue.removeAt(0));
      }
    });
  };
  new Timer.periodic(new Duration(seconds: 60), update);
  update();
}