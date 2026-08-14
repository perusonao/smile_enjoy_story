// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:smile_enjoy_story/game/game.dart';

void main(List<String> args) {
  final seed = int.parse(args[0]);
  final state = GameEngine.newGame(seed: seed);
  File(args[1]).writeAsStringSync(jsonEncode(state.toJson()));
}
