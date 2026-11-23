// Reproduit exactement la pile du client : meme librairie, meme sequence.
//
// Usage :
//   dart run tool/test_ws.dart <hote:port> <conversationId> <jeton>
import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: dart run tool/test_ws.dart <hote:port> <id> <jeton>');
    exit(64);
  }

  final adresse = Uri.parse(
    'ws://${args[0]}/ws/conversations/${args[1]}/?token=${args[2]}',
  );
  stdout.writeln('-> $adresse');

  try {
    final canal = WebSocketChannel.connect(adresse);
    await canal.ready;
    stdout.writeln('ready OK');

    canal.stream.listen(
      (trame) => stdout.writeln('trame: $trame'),
      onError: (Object e) => stdout.writeln('onError: $e'),
      onDone: () => stdout.writeln('onDone, closeCode=${canal.closeCode} '
          'closeReason=${canal.closeReason}'),
    );

    await Future<void>.delayed(const Duration(seconds: 14));
    await canal.sink.close();
  } catch (erreur, pile) {
    stdout.writeln('ECHEC ${erreur.runtimeType}: $erreur');
    stdout.writeln(pile.toString().split('\n').take(4).join('\n'));
  }
  exit(0);
}
