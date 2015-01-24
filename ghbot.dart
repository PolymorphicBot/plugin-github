part of ghbot;

var connected = false;

Map<String, dynamic> config;

List<Map> joinQueue = [];

bool shouldHandleChanAdmin = false;

class GHBot {
  static String token = null;
  static bool enabled = true;
  static String organization;

  // GitHub IP range converted to regex
  static var IP_REGEX = new RegExp(r"192\.30\.25[2-5]\.[0-9]{1,3}");

  static var HOOK_URL = "http://titan.directcode.org:8020/github";

  static var STATUS_CI = {};

  static String getOrganization(String network, String channel) {
    if (config["github"].containsKey("organizations")) {
      var orgs = config["github"]["organizations"];
      if (orgs.containsKey("${network}:${channel}")) {
        return orgs["${network}:${channel}"];
      } else if (orgs.containsKey("${channel}")) {
        return orgs["${channel}"];
      }
    }

    return organization;
  }

  static List<String> events = [
    "push",
    "ping",
    "pull_request",
    "fork",
    "release",
    "issues",
    "commit_comment",
    "watch",
    "status",
    "team_add",
    "issue_comment",
    "gollum",
    "page_build",
    "public"
  ];

  static Future<http.Response> get(String url, {String api_token}) {
    if (api_token == null) {
      api_token = token;
    }

    return http.get(url,
        headers: {
      "Authorization": "token ${api_token}",
      "Accept": "application/vnd.github.v3+json"
    });
  }

  static Future<http.Response> post(String url, body, {String api_token}) {
    if (api_token == null) {
      api_token = token;
    }
    return http.post(url,
        headers: {
      "Authorization": "token ${api_token}",
      "Accept": "application/vnd.github.v3+json"
    },
        body: body);
  }

  static Future<String> shorten(String input) {
    return new HttpClient()
        .postUrl(Uri.parse("http://git.io/?url=${Uri.encodeComponent(input)}"))
        .then((HttpClientRequest request) {
      return request.close();
    }).then((HttpClientResponse response) {
      if (response.statusCode != 201) {
        return new Future.value(input);
      } else {
        return new Future.value(
            "http://git.io/${response.headers.value("Location").split("/").last}");
      }
    });
  }

  static String getRepoOwner(Map<String, dynamic> repo) {
    if (repo["owner"]["name"] != null) {
      return repo["owner"]["name"];
    } else {
      return repo["owner"]["login"];
    }
  }

  static void handleHook(HttpRequest request) {
    if (!connected) {
      request.response.statusCode = 500;
      request.response.write(JSON.encode({"error": "Bot is not connected"}));
      request.response.close();
      return;
    }

    if (!enabled) {
      request.response.statusCode = 200;
      request.response.write(JSON.encode({"error": "GitHub is not enabled."}));
      request.response.close();
      return;
    }

    if (request.method != "POST") {
      request.response.write(JSON.encode(
          {"status": "failure", "error": "Only POST is Supported"}));
      request.response.close();
      return;
    }
    
    var address = request.connectionInfo.remoteAddress.address;

    if (!IP_REGEX.hasMatch(address) && address != "127.0.0.1") {
      print("$address was rejected from the server");
      request.response
        ..statusCode = 403
        ..close();
      return;
    }

    var handled = true;

    request.transform(UTF8.decoder).join("").then((String data) {
      var json = JSON.decoder.convert(data);

      var repoName;

      if (json["repository"] != null) {
        var name = getRepoName(json["repository"]);

        var names = config["github"]["names"];

        if (names != null && names.containsKey(name)) {
          repoName = names[name];
        } else {
          if (getRepoOwner(json["repository"]) != "DirectMyFile") {
            repoName = name;
          } else {
            repoName = json["repository"]["name"];
          }
        }
      }

      void message(String msg, [bool prefix = true]) {
        var m = "";

        if (prefix) {
          m += "[${Color.BLUE}${repoName}${Color.RESET}] ";
        }

        m += msg;

        for (var chan in channelsFor(repoName)) {
          bot.sendMessage(networkOf(chan), channelOf(chan), m);
        }
      }

      switch (request.headers.value('X-GitHub-Event')) {
        case "ping":
          message("[${Color.BLUE}GitHub${Color.RESET}] ${json["zen"]}", false);
          break;
        case "push":
          var refRegex = new RegExp(r"refs/(heads|tags)/(.*)$");
          var branchName = "";
          var tagName = "";
          var isBranch = false;
          var isTag = false;
          if (refRegex.hasMatch(json["ref"])) {
            var match = refRegex.firstMatch(json["ref"]);
            var _type = match.group(1);
            var type = ({"heads": "branch", "tags": "tag"}[_type]);
            if (type == "branch") {
              isBranch = true;
              branchName = match.group(2);
            } else if (type == "tag") {
              isTag = true;
              tagName = match.group(2);
            }
          }
          if (json["commits"] != null && json["commits"].length != 0) {
            if (json['repository']['fork']) break;
            var pusher = json['pusher']['name'];
            var commit_size = json['commits'].length;

            GHBot.shorten(json["compare"]).then((compareUrl) {
              var committer = "${Color.OLIVE}$pusher${Color.RESET}";
              var commit = "commit${commit_size > 1 ? "s" : ""}";
              var branch =
                  "${Color.DARK_GREEN}${json['ref'].split("/")[2]}${Color.RESET}";

              var url = "${Color.PURPLE}${compareUrl}${Color.RESET}";
              message(
                  "$committer pushed ${Color.DARK_GREEN}$commit_size${Color.RESET} $commit to $branch - $url");

              int tracker = 0;
              for (var commit in json['commits']) {
                tracker++;
                if (tracker > 5) break;
                committer =
                    "${Color.OLIVE}${commit['committer']['name']}${Color.RESET}";
                var sha =
                    "${Color.DARK_GREEN}${commit['id'].substring(0, 7)}${Color.RESET}";
                message("$committer $sha - ${commit['message']}");
              }
            });
          } else if (isTag) {
            if (json['repository']['fork']) break;
            String out = "";
            if (json['pusher'] != null) {
              out +=
                  "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} tagged ";
            } else {
              out += "Tagged ";
            }
            out +=
                "${Color.DARK_GREEN}${json['head_commit']['id'].substring(0, 7)}${Color.RESET} as ";
            out += "${Color.DARK_GREEN}${tagName}${Color.RESET}";
            message(out);
          } else if (isBranch) {
            if (json['repository']['fork']) break;
            String out = "";
            if (json["deleted"]) {
              if (json["pusher"] != null) {
                out +=
                    "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} deleted branch ";
              } else {
                out += "Deleted branch";
              }
            } else {
              if (json["pusher"] != null) {
                out +=
                    "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} created branch ";
              } else {
                out += "Created branch";
              }
            }

            out += "${Color.DARK_GREEN}${branchName}${Color.RESET}";

            var longUrl = "";

            if (json["head_commit"] == null) {
              longUrl = json["compare"];
            } else {
              longUrl = json["head_commit"]["url"];
            }

            GHBot.shorten(longUrl).then((url) {
              out += " - ${Color.PURPLE}${url}${Color.RESET}";
              message(out);
            });
          }
          break;

        case "issues":
          var action = json["action"];
          var by = json["sender"]["login"];
          var issueId = json["issue"]["number"];
          var issueName = json["issue"]["title"];
          var issueUrl = json["issue"]["html_url"];
          GHBot.shorten(issueUrl).then((url) {
            message(
                "${Color.OLIVE}${by}${Color.RESET} ${action} the issue '${issueName}' (${issueId}) - ${url}");
          });
          break;

        case "release":
          var action = json["action"];
          var author = json["sender"]["login"];
          var name = json["release"]["name"];
          GHBot.shorten(json["release"]["html_url"]).then((url) {
            message(
                "${Color.OLIVE}${author}${Color.RESET} ${action} the release '${name}' - ${url}");
          });
          break;

        case "fork":
          var forkee = json["forkee"];
          GHBot.shorten(forkee["html_url"]).then((url) {
            message(
                "${Color.OLIVE}${getRepoOwner(forkee)}${Color.RESET} created a fork at ${forkee["full_name"]} - ${url}");
          });
          break;
        case "commit_comment":
          var who = json["sender"]["login"];
          var commit_id = json["comment"]["commit_id"].substring(0, 10);
          message(
              "${Color.OLIVE}${who}${Color.RESET} commented on commit ${commit_id}");
          break;
        case "issue_comment":
          var issue = json["issue"];
          var sender = json["sender"];
          var action = json["action"];

          if (action == "created") {
            message(
                "${Color.OLIVE}${sender["login"]}${Color.RESET} commented on issue #${issue["number"]}");
          }

          break;
        case "watch":
          var who = json["sender"]["login"];
          message("${Color.OLIVE}${who}${Color.RESET} starred the repository");
          break;
        case "page_build":
          var build = json["build"];
          var who = build["pusher"]["login"];
          var msg = "";
          if (build["error"]["message"] != null) {
            msg +=
                "${Color.OLIVE}${who}${Color.RESET} Page Build Failed (Message: ${build["error"]["message"]})";
            message(msg);
          }
          break;
        case "gollum":
          var who = json["sender"]["login"];
          var pages = json["pages"];
          for (var page in pages) {
            var name = page["title"];
            var type = page["action"];
            var summary = page["summary"];
            var msg =
                "${Color.OLIVE}${who}${Color.RESET} ${type} '${name}' on the wiki";
            if (summary != null) {
              msg += " (${msg})";
            }
            message(msg);
          }
          break;

        case "pull_request":
          var who = json["sender"]["login"];
          var pr = json["pull_request"];
          var number = json["number"];

          var action = json["action"];

          if (["opened", "reopened", "closed"].contains(action)) {
            GHBot.shorten(pr["html_url"]).then((url) {
              message(
                  "${Color.OLIVE}${who}${Color.RESET} ${action} a Pull Request (#${number}) - ${url}");
            });
          }

          break;

        case "public":
          var repo = json["repository"];
          GHBot.shorten(repo["html_url"]).then((url) {
            message(
                "${json["sender"]["login"]} made the repository public: ${url}");
          });
          break;

        case "status":
          var msg = "";
          var status = json["state"];
          var targetUrl = json["target_url"];

          if (status == "pending" && STATUS_CI[targetUrl] == null) {
            STATUS_CI[targetUrl] = "pending";
          } else if (STATUS_CI[targetUrl] != null &&
              STATUS_CI[targetUrl] == "pending" &&
              status == "pending") {
            return;
          } else if (STATUS_CI[targetUrl] == "pending" && status == "success" ||
              status == "failure") {
            STATUS_CI.remove(targetUrl);
          }

          if (status == "pending") {
            status = "${Color.DARK_GRAY}Pending${Color.RESET}.";
          } else if (status == "success") {
            status = "${Color.DARK_GREEN}Success${Color.RESET}.";
          } else {
            status = "${Color.RED}Failure${Color.RESET}.";
          }
          msg += status;
          msg += " ";
          msg += json["description"];
          msg += " - ";
          googleShorten(json["target_url"]).then((url) {
            msg += "${Color.MAGENTA}${url}${Color.RESET}";
            message(msg);
          });
          break;

        case "team_add":
          var added_user = false;
          var team = json["team"];
          var msg = "";
          if (json["user"] != null) {
            added_user = true;
            msg +=
                "${Color.OLIVE}${json["sender"]["login"]}${Color.RESET} has added ";
            msg +=
                "${Color.OLIVE}${json["user"]["login"]}${Color.RESET} to the '${team["name"]}' team.";
            message(msg);
          }
          break;

        default:
          handled = false;
          break;
      }

      request.response.write(JSON.encode({
        "status": "success",
        "information": {
          "repo_name": repoName,
          "channels": channelsFor(repoName),
          "handled": handled
        }
      }));
      request.response.close();
    });
  }

  static List<String> channelsFor(String repo_id) {
    var ghConf = config["github"];
    if (ghConf["channels"] != null && ghConf["channels"].containsKey(repo_id)) {
      var chans = ghConf["channels"][repo_id];
      if (chans is String) {
        chans = [chans];
      }
      return chans;
    } else {
      return ghConf["default_channels"];
    }
  }

  static String networkOf(String input) {
    return input.split(":")[0];
  }

  static String channelOf(String input) {
    return input.split(":")[1];
  }

  static String getRepoName(Map<String, dynamic> repo) {
    if (repo["full_name"] != null) {
      return repo["full_name"];
    } else {
      return "${repo["owner"]["name"]}/${repo["name"]}";
    }
  }

  static RegExp ISSUE_REGEX = new RegExp(
      r"(?:.*)(?:https?)\:\/\/github\.com\/(.*)\/(.*)\/issues\/([0-9]+)(?:.*)");

  static void handleIssue(data) {
    var message = data['message'];
    var target = data['target'];
    var from = data['from'];
    var network = data['network'];

    void reply(String msg) {
      bot.sendMessage(network, target, msg);
    }

    void require(String permission, void handle()) {
      bot.checkPermission((it) => handle(), network, target, from, permission);
    }

    if (ISSUE_REGEX.hasMatch(message)) {
      if (!enabled) {
        return;
      }

      require("info.issue", () {
        for (var match in ISSUE_REGEX.allMatches(message)) {
          var url =
              "https://api.github.com/repos/${match[1]}/${match[2]}/issues/${match[3]}";
          GHBot.get(url).then((http.Response response) {
            if (response.statusCode != 200) {
              var repo = match[1] + "/" + match[2];
              reply(
                  "${fancyPrefix("GitHub Issues")} Failed to fetch issue information (repo: ${repo}, issue: ${match[3]})");
            } else {
              var json = JSON.decode(response.body);
              var msg = "${fancyPrefix("GitHub Issues")} ";

              msg +=
                  "Issue #${json["number"]} '${json["title"]}' by ${json["user"]["login"]}";
              reply(msg);
              msg = "${fancyPrefix("GitHub Issues")} ";

              if (json["asignee"] != null) {
                msg += "assigned to: ${json["assignee"]["login"]}, ";
              }

              msg += "status: ${json["state"]}";

              if (json["milestone"] != null) {
                msg += ", milestone: ${json["milestone"]["title"]}";
              }

              reply(msg);
            }
          });
        }
      });
    }
  }

  static RegExp REPO_REGEX = new RegExp(
      r"(?:.*)(?:https?)\:\/\/github\.com\/([A-Za-z0-9\-\.\_\(\)]+)\/([A-Za-z0-9\-\.\_\(\)]+)(?:\/?)(?:.*)");

  static void handleRepository(data) {
    var message = data['message'];
    var target = data['target'];
    var from = data['from'];
    var network = data['network'];

    void require(String permission, void handle()) {
      bot.checkPermission((it) => handle(), network, target, from, permission);
    }

    void reply(String msg) {
      bot.sendMessage(network, target, msg);
    }

    if (REPO_REGEX.hasMatch(message)) {
      if (!enabled) {
        return;
      }

      require("info.repository", () {
        for (var match in REPO_REGEX.allMatches(message)) {
          var it = match[0];

          var user = match[1];
          
          if (user == "blog") return;
          
          var repo = match[2];

          var uar = "${user}/${repo}";

          var rest = it
              .substring(it.indexOf(uar) + uar.length)
              .replaceAll(r"/", "");

          if (rest != "") {
            return;
          }

          var url = "https://api.github.com/repos/${uar}";

          GHBot.get(url).then((response) {
            if (response.statusCode != 200) {
              if (response.statusCode == 404) {
                reply(
                    "${fancyPrefix("GitHub")} Repository does not exist: ${uar}");
              } else {
                reply(
                    "${fancyPrefix("GitHub")} Failed to get repository information (code: ${response.statusCode})");
              }
              return;
            }
            var json = JSON.decode(response.body);
            var description = json["description"];
            var subscribers = json["subscribers_count"];
            var stars = json["stargazers_count"];
            var forks = json["forks_count"];
            var open_issues = json["open_issues_count"];
            var language = json["language"] == null ? "none" : json["language"];
            var default_branch = json["default_branch"];
            var msg = "${fancyPrefix("GitHub")} ";

            if (description != null && description.isNotEmpty) {
              msg += "${description}";
              reply(msg);
            }

            msg =
                "${fancyPrefix("GitHub")} ${subscribers} subscribers, ${stars} stars, ${forks} forks, ${open_issues} open issues";
            reply(msg);

            msg =
                "${fancyPrefix("GitHub")} Language: ${language}, Default Branch: ${default_branch}";
            reply(msg);
          });
        }
      });
    }
  }

  static Future<List<Map<String, Object>>> teams(String organization) {
    return get("https://api.github.com/orgs/${organization}/teams").then(
        (response) {
      if (response.statusCode != 200) {
        return null;
      }
      return JSON.decode(response.body);
    });
  }

  static Future<List<Map<String, Object>>> teamMembers(String url) {
    return get("${url}/members").then((response) {
      if (response.statusCode != 200) {
        return null;
      }
      return JSON.decode(response.body);
    });
  }
}

Future<String> googleShorten(String longUrl) {
  var input = JSON.encode({"longUrl": longUrl});

  return http
      .post(
          "https://www.googleapis.com/urlshortener/v1/url?key=AIzaSyBNTRakVvRuGHn6AVIhPXE_B3foJDOxmBU",
          headers: {"Content-Type": ContentType.JSON.toString()}, body: input)
      .then((http.Response response) {
    Map<String, Object> resp = JSON.decoder.convert(response.body);
    return new Future.value(resp["id"]);
  });
}

String fancyPrefix(String name) {
  return "[${Color.BLUE}${name}${Color.RESET}]";
}
