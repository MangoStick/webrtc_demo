import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:webrtc_demo/app_provider.dart';

final roomName = "prem";
final userId = "123";

// void main() {
//   runApp(MyApp());
// }

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MyApp(),
    ),
  );
}


class MyApp extends StatefulWidget{
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>{
  late final IO.Socket socket;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? pc;

  @override
  void initState() {
    init();
    super.initState();
  }

  Future init() async{

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await connectSocket();
    await joinRoom();
    setting();
    // WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  setting() {
    context.read<AppProvider>().setInit(_localRenderer, _remoteRenderer);
  }


  Future connectSocket() async{
    // socket = IO.io('http://localhost:3000', IO.OptionBuilder().setTransports(['websocket']).build());
    socket = IO.io('https://ic-rtc-server.herokuapp.com', IO.OptionBuilder().setTransports(['websocket']).build());
    socket.onConnect((data) => print('연결 완료 !'));

    socket.on('joined', (data){
      _sendOffer();
    });


    socket.on('offer', (data) async{
      data = jsonDecode(data);
      await _gotOffer(RTCSessionDescription(data['sdp'], data['type']));
      await _sendAnswer();
    });


    socket.on('answer', (data){
      data = jsonDecode(data);
      _gotAnswer(RTCSessionDescription(data['sdp'], data['type']));
    });


    socket.on('ice', (data){
      data = jsonDecode(data);
      _gotIce(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
    });

    socket.on('disconnected', (data){
      if (data == userId) {
        context.read<AppProvider>().removeRemote();
        // _remoteRenderer.srcObject = null;
        // WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
      }
    });
  }

  Future joinRoom() async{
    final config = {
      'iceServers': [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final sdpConstraints = {
      'mandatory':{
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional':[]
    };

    pc = await createPeerConnection(config, sdpConstraints);


    final mediaConstraints = {
      'audio':true,
      'video':{
        'facingMode':'user'
      }
    };

    _localStream = await Helper.openCamera(mediaConstraints);

    _localStream!.getTracks().forEach((track) {
      pc!.addTrack(track, _localStream!);
    });

    _localRenderer.srcObject = _localStream;

    pc!.onIceCandidate = (ice) {
      _sendIce(ice);
    };

    pc!.onAddStream = (stream){
      context.read<AppProvider>().listeningRemote(stream);
      // _remoteRenderer.srcObject = stream;
      // WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    };

    socket.emit('join', jsonEncode({"room":roomName, "userId": userId}));
  }

  Future _sendOffer() async{
    print('send offer');
    var offer = await pc!.createOffer();
    pc!.setLocalDescription(offer);
    var offerData = offer.toMap();
    offerData['room'] = roomName;
    // socket.emit('offer', jsonEncode(offer.toMap()));
    socket.emit('offer', jsonEncode(offerData));
  }

  Future _gotOffer(RTCSessionDescription offer) async{
    print('got offer');
    pc!.setRemoteDescription(offer);
  }
  Future _sendAnswer() async{
    print('send answer');
    var answer = await pc!.createAnswer();
    pc!.setLocalDescription(answer);

    var answerData = answer.toMap();
    answerData['room'] = roomName;

    socket.emit('answer', jsonEncode(answerData));
  }

  Future _gotAnswer(RTCSessionDescription answer) async{
    print('got answer');
    pc!.setRemoteDescription(answer);
  }

  Future _sendIce(RTCIceCandidate ice) async{
    var iceData = ice.toMap();
    iceData['room'] = roomName;
    socket.emit('ice', jsonEncode(iceData));
  }
  Future _gotIce(RTCIceCandidate ice) async{
    pc!.addCandidate(ice);
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Container(
            child: Column(
              children: [
                // Flexible(
                //   child: RTCVideoView(
                //     _localRenderer,
                //     objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                //     filterQuality: FilterQuality.medium, 
                //     mirror: true,
                //   ),
                // ),
                // Flexible(
                //   child: RTCVideoView(
                //     _remoteRenderer,
                //     objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                //     filterQuality: FilterQuality.medium,
                //   ),
                // ),
                Flexible(
                  child: RTCVideoView(
                    context.watch<AppProvider>().localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    filterQuality: FilterQuality.medium, 
                    mirror: true,
                  ),
                ),
                context.watch<AppProvider>().remoteRenderer.srcObject != null ? 
                Flexible(
                  child: RTCVideoView(
                    context.watch<AppProvider>().remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    filterQuality: FilterQuality.medium,
                  ),
                ) : Container()
              ], 
            ), 
          ), 
        ), 
      ), 
    );
  }
}