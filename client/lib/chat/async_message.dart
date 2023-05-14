import 'package:minichat_client/chat_repo/chat_repo.dart';

enum AsyncMessageState {
  waiting,
  error,
  done;
}

class AsyncMessage {
  AsyncMessage(this.msg, {this.completionFuture})
      : state = completionFuture == null
            ? AsyncMessageState.done
            : AsyncMessageState.waiting {
    completionFuture
        ?.then((_) => state = AsyncMessageState.done)
        .catchError((_) => state = AsyncMessageState.error);
  }

  final Message msg;
  final Future<void>? completionFuture;
  AsyncMessageState state;
}
