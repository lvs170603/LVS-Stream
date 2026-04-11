import 'package:media_kit/media_kit.dart';
import 'package:media_kit/src/player/native/player/real.dart';

void main() {
  final player = Player();
  final nativePlayer = player.platform as NativePlayer;
  nativePlayer.setProperty('af', 'pan=mono|c0=0.5*c0+0.5*c1');
}
