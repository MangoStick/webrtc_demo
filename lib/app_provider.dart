import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AppProvider with ChangeNotifier {
  var localRenderer = RTCVideoRenderer();
  var remoteRenderer = RTCVideoRenderer();

  setInit(stream, remote) {
    localRenderer = stream;
    remoteRenderer = remote;
    notifyListeners();
  }

  listeningRemote(stream) {
    remoteRenderer.srcObject = stream;
    notifyListeners();
  }

  removeRemote() {
    remoteRenderer.srcObject = null;
    notifyListeners();
  }

}