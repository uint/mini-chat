import 'dart:convert';
import 'dart:typed_data';

abstract class ClientFrame {
  Uint8List encode(int id);
}

class ClientLoginFrame extends ClientFrame {
  ClientLoginFrame(this.handle);

  final String handle;

  @override
  Uint8List encode(int id) {
    return Uint8List.fromList([id, 0, ...encodeStr(handle)]);
  }
}

class ClientMsgFrame extends ClientFrame {
  ClientMsgFrame(this.msg);

  final String msg;

  @override
  Uint8List encode(int id) {
    return Uint8List.fromList([id, 1, ...encodeStr(msg)]);
  }
}

Uint8List encodeStr(String str) {
  var lenBytes = encodeUint32(str.length);
  var strBytes = utf8.encode(str);

  return Uint8List.fromList([...lenBytes, ...strBytes]);
}

Uint8List encodeUint32(int n) {
  var bytes = Uint8List(4);
  bytes.buffer.asByteData().setUint32(0, n, Endian.little);
  return bytes;
}
