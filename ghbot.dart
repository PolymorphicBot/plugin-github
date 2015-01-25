part of ghbot;

var connected = false;

Map<String, dynamic> config;

List<Map> joinQueue = [];

bool shouldHandleChanAdmin = false;

class GHBot {
  static String token = null;
  static bool enabled = true;
  static String organization;

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

  static List<String> events = ["push", "ping", "pull_request", "fork", "release", "issues", "commit_comment", "watch", "status", "team_add", "issue_comment", "gollum", "page_build", "public"];

  static Future<http.Response> get(String url, {String api_token}) {
    if (api_token == null) {
      api_token = token;
    }

    return http.get(url, headers: {
      "Authorization": "token ${api_token}",
      "Accept": "application/vnd.github.v3+json"
    });
  }

  static Future<http.Response> post(String url, body, {String api_token}) {
    if (api_token == null) {
      api_token = token;
    }
    return http.post(url, headers: {
      "Authorization": "token ${api_token}",
      "Accept": "application/vnd.github.v3+json"
    }, body: body);
  }

  static Future<String> shorten(String input) {
    return new HttpClient().postUrl(Uri.parse("http://git.io/?url=${Uri.encodeComponent(input)}")).then((HttpClientRequest request) {
      return request.close();
    }).then((HttpClientResponse response) {
      if (response.statusCode != 201) {
        return new Future.value(input);
      } else {
        return new Future.value("http://git.io/${response.headers.value("Location").split("/").last}");
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
      request.response.write(JSON.encode({
        "error": "Bot is not connected"
      }));
      request.response.close();
      return;
    }

    if (!enabled) {
      request.response.statusCode = 200;
      request.response.write(JSON.encode({
        "error": "GitHub is not enabled."
      }));
      request.response.close();
      return;
    }

    if (request.method != "POST") {
      request.response.write(JSON.encode({
        "status": "failure",
        "error": "Only POST is Supported"
      }));
      request.response.close();
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
            var type = ({
              "heads": "branch",
              "tags": "tag"
            }[_type]);
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
              var branch = "${Color.DARK_GREEN}${json['ref'].split("/")[2]}${Color.RESET}";

              var url = "${Color.PURPLE}${compareUrl}${Color.RESET}";
              message("$committer pushed ${Color.DARK_GREEN}$commit_size${Color.RESET} $commit to $branch - $url");

              int tracker = 0;
              for (var commit in json['commits']) {
                tracker++;
                if (tracker > 5) break;
                committer = "${Color.OLIVE}${commit['committer']['name']}${Color.RESET}";
                var sha = "${Color.DARK_GREEN}${commit['id'].substring(0, 7)}${Color.RESET}";
                message("$committer $sha - ${commit['message']}");
              }
            });
          } else if (isTag) {
            if (json['repository']['fork']) break;
            String out = "";
            if (json['pusher'] != null) {
              out += "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} tagged ";
            } else {
              out += "Tagged ";
            }
            out += "${Color.DARK_GREEN}${json['head_commit']['id'].substring(0, 7)}${Color.RESET} as ";
            out += "${Color.DARK_GREEN}${tagName}${Color.RESET}";
            message(out);
          } else if (isBranch) {
            if (json['repository']['fork']) break;
            String out = "";
            if (json["deleted"]) {
              if (json["pusher"] != null) {
                out += "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} deleted branch ";
              } else {
                out += "Deleted branch";
              }
            } else {
              if (json["pusher"] != null) {
                out += "${Color.OLIVE}${json["pusher"]["name"]}${Color.RESET} created branch ";
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
            message("${Color.OLIVE}${by}${Color.RESET} ${action} the issue '${issueName}' (${issueId}) - ${url}");
          });
          break;

        case "release":
          var action = json["action"];
          var author = json["sender"]["login"];
          var name = json["release"]["name"];
          GHBot.shorten(json["release"]["html_url"]).then((url) {
            message("${Color.OLIVE}${author}${Color.RESET} ${action} the release '${name}' - ${url}");
          });
          break;

        case "fork":
          var forkee = json["forkee"];
          GHBot.shorten(forkee["html_url"]).then((url) {
            message("${Color.OLIVE}${getRepoOwner(forkee)}${Color.RESET} created a fork at ${forkee["full_name"]} - ${url}");
          });
          break;
        case "commit_comment":
          var who = json["sender"]["login"];
          var commit_id = json["comment"]["commit_id"].substring(0, 10);
          message("${Color.OLIVE}${who}${Color.RESET} commented on commit ${commit_id}");
          break;
        case "issue_comment":
          var issue = json["issue"];
          var sender = json["sender"];
          var action = json["action"];

          if (action == "created") {
            message("${Color.OLIVE}${sender["login"]}${Color.RESET} commented on issue #${issue["number"]}");
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
            msg += "${Color.OLIVE}${who}${Color.RESET} Page Build Failed (Message: ${build["error"]["message"]})";
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
            var msg = "${Color.OLIVE}${who}${Color.RESET} ${type} '${name}' on the wiki";
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
              message("${Color.OLIVE}${who}${Color.RESET} ${action} a Pull Request (#${number}) - ${url}");
            });
          }

          break;

        case "public":
          var repo = json["repository"];
          GHBot.shorten(repo["html_url"]).then((url) {
            message("${json["sender"]["login"]} made the repository public: ${url}");
          });
          break;

        case "status":
          var msg = "";
          var status = json["state"];
          var targetUrl = json["target_url"];

          if (status == "pending" && STATUS_CI[targetUrl] == null) {
            STATUS_CI[targetUrl] = "pending";
          } else if (STATUS_CI[targetUrl] != null && STATUS_CI[targetUrl] == "pending" && status == "pending") {
            return;
          } else if (STATUS_CI[targetUrl] == "pending" && status == "success" || status == "failure") {
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
            msg += "${Color.OLIVE}${json["sender"]["login"]}${Color.RESET} has added ";
            msg += "${Color.OLIVE}${json["user"]["login"]}${Color.RESET} to the '${team["name"]}' team.";
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

  static List<String> channelsFor(String id) {
    var ghConf = config["github"];
    if (ghConf["channels"] != null && ghConf["channels"].containsKey(id)) {
      var chans = ghConf["channels"][id];
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

  static RegExp ISSUE_REGEX = new RegExp(r"(?:.*)(?:https?)\:\/\/github\.com\/(.*)\/(.*)\/issues\/([0-9]+)(?:.*)");
  static RegExp PR_REGEX = new RegExp(r"(?:.*)(?:https?)\:\/\/github\.com\/(.*)\/(.*)\/pull\/([0-9]+)(?:.*)");


  static void handleIssue(MessageEvent event) {
    var message = event.message;
    var target = event.target;
    var from = event.from;
    var network = event.network;

    if (!ISSUE_REGEX.hasMatch(message) || !enabled) {
      return;
    }

    for (var match in ISSUE_REGEX.allMatches(message)) {
      var url = "https://api.github.com/repos/${match[1]}/${match[2]}/issues/${match[3]}";
      var slug = new RepositorySlug(match[1], match[2]);
      var id = int.parse(match[3]);

      github.issues.get(slug, id).then((issue) {
        event.reply("${fancyPrefix('GitHub Issues')} Issue #${issue.number} '${issue.title}' by ${issue.user.login}");
        event.reply("${fancyPrefix('GitHub Issues')} Created: ${friendlyDateTime(issue.createdAt)}");

        var msg = "${fancyPrefix('GitHub Issues')} ";

        if (issue.assignee != null) {
          msg += "assigned to: ${issue.assignee.login}, ";
        }

        msg += "status: ${issue.state}";

        if (issue.milestone != null) {
          msg += ", milestone: ${issue.milestone.title}";
        }
        event.reply(msg);
        
        if (issue.closedAt != null) {
          var offset = offsetTimezone(issue.closedAt);
          event.reply("${fancyPrefix('GitHub Issues')} Closed By: ${issue.closedBy.login} on ${friendlyDateTime(offset)}");
        }
      }).catchError((e) {
        if (e is NotFound) {
          event.reply("${fancyPrefix("GitHub Issues")} Issue Not Found");
        } else {
          event.reply("${fancyPrefix("GitHub Issues")} Failed to fetch issue information");
        }
      });
    }
  }

  static RegExp REPO_REGEX = new RegExp(r"(?:.*)(?:https?)\:\/\/github\.com\/([A-Za-z0-9\-\.\_\(\)]+)\/([A-Za-z0-9\-\.\_\(\)]+)(?:\/?)(?:.*)");

  static void handleRepository(MessageEvent event) {
    var message = event.message;
    var target = event.target;
    var from = event.from;
    var network = event.network;

    if (!REPO_REGEX.hasMatch(message) || !enabled) {
      return;
    }

    for (var match in REPO_REGEX.allMatches(message)) {
      var it = match[0];
      var user = match[1];
      if (user == "blog") return;
      var repo = match[2];
      var uar = "${user}/${repo}";
      var rest = it.substring(it.indexOf(uar) + uar.length).replaceAll(r"/", "");
      if (rest != "") {
        return;
      }

      github.repositories.getRepository(new RepositorySlug(user, repo)).then((repo) {
        if (repo.description != null && repo.description.isNotEmpty) {
          event.reply("${fancyPrefix("GitHub")} ${repo.description}");
        }

        event.reply("${fancyPrefix("GitHub")} ${repo.subscribersCount} subscribers, ${repo.stargazersCount} stars, ${repo.forksCount} forks, ${repo.openIssuesCount} open issues");
        event.reply("${fancyPrefix("GitHub")} Language: ${repo.language}, Default Branch: ${repo.defaultBranch}");
      }).catchError((e) {
        if (e is NotFound || e is RepositoryNotFound) {
          event.reply("${fancyPrefix("GitHub")} Repository does not exist: ${uar}");
        }
      });
    }
  }

  static void handlePullRequest(MessageEvent event) {
    if (!PR_REGEX.hasMatch(event.message) || !enabled) {
      return;
    }

    var matches = PR_REGEX.allMatches(event.message);

    try {
      for (var match in matches) {
        var user = match[1];
        var repo = match[2];
        var id = int.parse(match[3]);

        github.pullRequests.get(new RepositorySlug(user, repo), id).then((pr) {
          event.reply("${fancyPrefix('GitHub Pull Requests')} '${pr.title}' by ${pr.user.login}");
          var offsetCreated = offsetTimezone(pr.createdAt);
          event.reply("${fancyPrefix('GitHub Pull Requests')} Status: ${pr.state}, Created: ${friendlyDateTime(offsetCreated)}");
          event.reply("${fancyPrefix('GitHub Pull Requests')} Additions: ${pr.additionsCount}, Deletions: ${pr.deletionsCount}");
          
          if (pr.merged) {
            var offset = offsetTimezone(pr.mergedAt);
            event.reply("${fancyPrefix('GitHub Pull Requests')} Merged By: ${pr.mergedBy.login} on ${friendlyDateTime(offset)}");
          } else {
            event.reply("${fancyPrefix('GitHub Pull Requests')} Can be Merged: ${pr.mergeable}");
          }
        }).catchError((e) {
          if (e is NotFound) {
            event.reply("${fancyPrefix('GitHub')} Issue Not Found");
          }
        });
      }
    } catch (e) {
    }
  }

  static Future<List<Map<String, Object>>> teams(String organization) {
    return get("https://api.github.com/orgs/${organization}/teams").then((response) {
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
  var input = JSON.encode({
    "longUrl": longUrl
  });

  return http.post("https://www.googleapis.com/urlshortener/v1/url?key=AIzaSyBNTRakVvRuGHn6AVIhPXE_B3foJDOxmBU", headers: {
    "Content-Type": ContentType.JSON.toString()
  }, body: input).then((http.Response response) {
    Map<String, Object> resp = JSON.decoder.convert(response.body);
    return new Future.value(resp["id"]);
  });
}

String fancyPrefix(String name) {
  return "[${Color.BLUE}${name}${Color.RESET}]";
}
