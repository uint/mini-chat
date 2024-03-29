import 'dart:typed_data';
import 'dart:convert';

abstract class ServerFrame {
  factory ServerFrame.decode(Uint8List bytes) {
    var msgId = bytes[0];
    var remaining = bytes.sublist(1);

    switch (msgId) {
      case 0:
        return ServerFrameOkay.decode(remaining);
      case 1:
        return ServerFrameErr.decode(remaining);
      case 2:
        return ServerFrameBroadcast.decode(remaining);
      case 3:
        return ServerFramePresent.decode(remaining);
      case 4:
        return ServerFrameLogin.decode(remaining);
      case 5:
        return ServerFrameLogout.decode(remaining);
      default:
        throw "unknown message";
    }
  }
}

class ServerFrameOkay implements ServerFrame {
  late int id;

  ServerFrameOkay(this.id);

  ServerFrameOkay.decode(Uint8List bytes) {
    if (bytes.length != 1) {
      throw "invalid okay frame";
    }
    id = bytes[0];
  }

  @override
  bool operator ==(covariant ServerFrameOkay other) => id == other.id;

  @override
  int get hashCode =>
      id; // probably no reason to add the overhead of hashing this?
}

class ServerFrameErr implements ServerFrame {
  late int id;
  late String msg;

  ServerFrameErr(this.id, this.msg);

  ServerFrameErr.decode(Uint8List bytes) {
    if (bytes.length < 5) {
      throw "error frame too short";
    }

    id = bytes[0];

    var msgLen = decodeUint32(bytes.sublist(1, 5));
    var expectedByteLen = msgLen + 5;

    if (bytes.length != expectedByteLen) {
      throw "error frame: expected length $expectedByteLen, got ${bytes.length}";
    }

    msg = utf8.decode(bytes.sublist(5));
  }

  @override
  bool operator ==(covariant ServerFrameErr other) =>
      id == other.id && msg == other.msg;

  @override
  int get hashCode => Object.hash(id, msg);
}

class ServerFrameBroadcast implements ServerFrame {
  late String user;
  late String msg;

  ServerFrameBroadcast(this.user, this.msg);

  ServerFrameBroadcast.decode(Uint8List bytes) {
    if (bytes.length < 4) {
      throw "invalid broadcast frame";
    }

    var userBytesLen = decodeUint32(bytes.sublist(0, 4));

    if (bytes.length < userBytesLen + 4) {
      throw "invalid broadcast frame";
    }

    var secondStringIx = userBytesLen +
        4; // the start of the second string, length prefix included

    user = utf8.decode(bytes.sublist(4, secondStringIx));

    if (bytes.length < secondStringIx + 4) {
      throw "invalid broadcast frame";
    }

    var msgBytesLen =
        decodeUint32(bytes.sublist(secondStringIx, secondStringIx + 4));

    if (bytes.length != secondStringIx + 4 + msgBytesLen) {
      throw "invalid broadcast frame";
    }

    msg = utf8.decode(bytes.sublist(secondStringIx + 4));
  }

  @override
  bool operator ==(covariant ServerFrameBroadcast other) =>
      user == other.user && msg == other.msg;

  @override
  int get hashCode => Object.hash(user, msg);
}

class ServerFramePresent implements ServerFrame {
  late String handle;

  ServerFramePresent(this.handle);

  ServerFramePresent.decode(Uint8List bytes) {
    if (bytes.length < 4) {
      throw "present frame too short";
    }

    var msgLen = decodeUint32(bytes.sublist(0, 4));
    var expectedByteLen = msgLen + 4;

    if (bytes.length != expectedByteLen) {
      throw "present frame: expected length $expectedByteLen, got ${bytes.length}";
    }

    handle = utf8.decode(bytes.sublist(4));
  }

  @override
  bool operator ==(covariant ServerFramePresent other) =>
      handle == other.handle;

  @override
  int get hashCode => handle.hashCode;
}

class ServerFrameLogin implements ServerFrame {
  late String handle;

  ServerFrameLogin(this.handle);

  ServerFrameLogin.decode(Uint8List bytes) {
    if (bytes.length < 4) {
      throw "login frame too short";
    }

    var msgLen = decodeUint32(bytes.sublist(0, 4));
    var expectedByteLen = msgLen + 4;

    if (bytes.length != expectedByteLen) {
      throw "login frame: expected length $expectedByteLen, got ${bytes.length}";
    }

    handle = utf8.decode(bytes.sublist(4));
  }

  @override
  bool operator ==(covariant ServerFrameLogin other) => handle == other.handle;

  @override
  int get hashCode => handle.hashCode;
}

class ServerFrameLogout implements ServerFrame {
  late String handle;

  ServerFrameLogout(this.handle);

  ServerFrameLogout.decode(Uint8List bytes) {
    if (bytes.length < 4) {
      throw "logout frame too short";
    }

    var msgLen = decodeUint32(bytes.sublist(0, 4));
    var expectedByteLen = msgLen + 4;

    if (bytes.length != expectedByteLen) {
      throw "logout frame: expected length $expectedByteLen, got ${bytes.length}";
    }

    handle = utf8.decode(bytes.sublist(4));
  }

  @override
  bool operator ==(covariant ServerFrameLogout other) => handle == other.handle;

  @override
  int get hashCode => handle.hashCode;
}

int decodeUint32(Uint8List list) {
  var bytes = list.buffer.asByteData();
  return bytes.getUint32(0, Endian.little);
}
