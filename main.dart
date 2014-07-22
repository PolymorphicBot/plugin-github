import 'package:plugins/plugin.dart';
import 'dart:isolate';

Receiver recv;

void main(List<String> args, SendPort port) {
  print("[GitHub] Loading");
  recv = new Receiver(port);

  recv.listen((data) {
    if (data["event"] == "command") {
      handle_command(data);
    }
  });
}

void handle_command(data) {
  void reply(String message) {
    recv.send({
      "network": data["network"],
      "target": data["target"],
      "command": "message",
      "message": message
    });
  }

  switch (data["command"]) {
  }
}