import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatoo/helpers/date.dart';
import 'package:image_picker/image_picker.dart';


void main() {

  runApp( MyApp() );

}

final ThemeData iOSTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light
);

final ThemeData defaultTheme = ThemeData(
  primarySwatch: Colors.green,
  accentColor: Colors.orangeAccent[400]
);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if(user == null) {
   user = await googleSignIn.signInSilently();
  }
  
  if(user == null) {
    user = await googleSignIn.signIn();
  }

  if(await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;

    await auth.signInWithCredential(GoogleAuthProvider.getCredential(
        idToken: credentials.idToken, accessToken: credentials.accessToken
      )
    );
  }
}


_handleSubmitted(String text) async {

  await _ensureLoggedIn();
  _sendMessage(text: text);

}

void _sendMessage({String text, String imgUrl}) async {
  Firestore.instance.collection("messages").add(
    {
      "text" : text,
      "imgUrl" : imgUrl,
      "senderName" : googleSignIn.currentUser.displayName,
      "senderPhotoUrl" : googleSignIn.currentUser.photoUrl,
      "created_at" : DateTime.now().millisecondsSinceEpoch.toString()
    }
  );
}


class MyApp extends StatelessWidget {

    @override
    Widget build(BuildContext context){
      return MaterialApp(
        title: "Chat(oO) App",
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context).platform == TargetPlatform.iOS ?
        iOSTheme : defaultTheme,
        home: ChatScreen()
      );
    }

}




class ChatScreen extends StatefulWidget{
  @override
  _ChatScreenState createState() => _ChatScreenState();
}




class _ChatScreenState extends State<ChatScreen> {

    ScrollController _chatScrollController;
    String message = "";

    @override
    void initState(){
      /*
      _chatScrollController = ScrollController();
      _chatScrollController.addListener(_scrollListener);
      */
      super.initState();
    }

    /*
    _scrollListener() {
      if (_chatScrollController.offset >= _chatScrollController.position.maxScrollExtent &&
          !_chatScrollController.position.outOfRange) {
        setState(() {
          message = "reach the bottom";
        });
      }
      if (_chatScrollController.offset <= _chatScrollController.position.minScrollExtent &&
          !_chatScrollController.position.outOfRange) {
        setState(() {
          message = "reach the top";
        });
      }
    }
    */

    @override
    Widget build(BuildContext context){
      return SafeArea(
        bottom: false,
        top: false,
        child: Scaffold(
          appBar: AppBar(
            title: Text("Chat(oO) App"),
            centerTitle: true,
            elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
          ),
          body: Column(
            children: <Widget>[

              Expanded(
                child: StreamBuilder(
                  stream: Firestore.instance.collection("messages").orderBy('created_at', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    switch(snapshot.connectionState) {
                      case ConnectionState.none: 
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator()
                        );
                      default:
                        return ListView.builder(
                          controller: _chatScrollController,
                          reverse: true,
                          itemCount: snapshot.data.documents.length,
                          itemBuilder: (context, index) {
                            return ChatMessage(snapshot.data.documents[index].data);
                          }
                        );
                    }
                  }
                )
              ),

              Divider(height: 1.0),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor
                ),
                child: TextComposer()
              )
            ],
          )
        )
      );
    }

}

class TextComposer extends StatefulWidget{
  @override
  _TextComposerState createState() => _TextComposerState();
}
  
  
class _TextComposerState extends State<TextComposer> {

  bool _isComposing = false;
  final _textMessage = TextEditingController();

  void _reset() {
    _textMessage.text = "";
    setState((){
      _isComposing = false;
    });
  }

  @override
  void initState(){
    
    super.initState();
  }


  @override
  Widget build(BuildContext context){
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS ? 
          BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[200]))
          ) : 
        null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensureLoggedIn();
                  File imgFile = await ImagePicker.pickImage(source: ImageSource.camera, imageQuality: 85, maxHeight: 1200, maxWidth: 1200);

                  if(imgFile == null) return;

                  StorageUploadTask task = FirebaseStorage.instance.ref()
                    .child("photos")
                    .child(googleSignIn.currentUser.id.toString() + "-" +
                    DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);

                StorageTaskSnapshot taskSnapshot = await task.onComplete;

                String url = await taskSnapshot.ref.getDownloadURL();

                _sendMessage(imgUrl: url);

                },
              )
            ),
            Expanded(
              child: TextField(
                controller: _textMessage,
                decoration: InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                onChanged: (text) {
                  setState((){
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                },
              )
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS 
              ? CupertinoButton(
                  child: Text("Enviar"),
                  color: (_isComposing) ? Theme.of(context).accentColor : Colors.grey,
                  onPressed: () {
                    _handleSubmitted(_textMessage.text);
                    _reset();
                  }
                ) 
              : IconButton(
                    icon: Icon(Icons.send, color: (_isComposing) ? Theme.of(context).accentColor : Colors.grey),
                    color: (_isComposing) ? Theme.of(context).accentColor : Colors.grey,
                    onPressed: () {
                      _handleSubmitted(_textMessage.text);
                      _reset();
                    }
                  )
            )
          ],
        )
      )
    );

  }

  
}


class ChatMessage extends StatelessWidget {

  final Map<String, dynamic> data;

    ChatMessage(this.data);

    @override
    Widget build(BuildContext context){
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        child: Row(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(data["senderPhotoUrl"])
              )
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(data["senderName"],
                    style: Theme.of(context).textTheme.subhead
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: data["imgUrl"] != null 
                      ? Image.network(data["imgUrl"], width: 250.0)
                      : Text(data["text"])
                  ),

                  Text(formatDate(data["created_at"]), style: TextStyle(fontSize: 8.0))
                ],
              )
            )
          ],
        )
      );
    }

}