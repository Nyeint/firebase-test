import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:shalpoe_bgz/data/constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMethods{
  uploadUserInfo(userMap){
    print("DatabaseMethods  $userMap");
    FirebaseFirestore.instance.collection('users').doc(userMap['uid'])
        .set(userMap).catchError((e){
      print("Register to Firebase");
      print(e.toString());
    });
  }

  updateUserInfo(uid,name,searchKeyWords,profileText,profileColor){
    FirebaseFirestore.instance.collection('users').doc(uid).update(<String,dynamic>{
      "name":name,
      "searchKeyWords":searchKeyWords,
      "profileText":profileText,
      "profileColor":profileColor
    });
  }

  Future<String> operateChatList({required String myID,required String yourID,required String yourName,required String yourProfileText,required String yourProfileColor,required String chatRoomId}) async{
    List myChatList=[];
    List yourChatList=[];

    var ss=FirebaseFirestore.instance.collection("users")
        .where("uid",isEqualTo: myID)
        .get().then((QuerySnapshot value){
      value.docs.forEach((element) async {
        if(element['chatList'].contains(yourID)==false)
        {
          //add to myChatList
          myChatList=element['chatList'];
          myChatList.add(yourID);
          FirebaseFirestore.instance.collection('users').doc(element.id).update({"chatList":myChatList});

          //add to chatList of other people
          FirebaseFirestore.instance.collection("users")
              .where("uid",isEqualTo: yourID)
              .get().then((QuerySnapshot value){
            value.docs.forEach((element2) {
              yourChatList=element2['chatList'];
              yourChatList.add(myID);
              FirebaseFirestore.instance.collection('users').doc(element2.id).update({"chatList":yourChatList});
            });
          });

          //add info to chatRoom
          List<String> users=[myID,yourID];
          Map<String,dynamic> chatRoomMap={
            "users" : users,
            "chatroomId" : chatRoomId,
            "time": Timestamp.now().millisecondsSinceEpoch
          };
          FirebaseFirestore.instance.collection("ChatRoom")
              .doc(chatRoomId).set(chatRoomMap).catchError((e){
          });

          //send a wave message
          Map<String,dynamic> messageMap={
            "message":'👋🏻',
            "sendBy":myID,
            "time": Timestamp.now().millisecondsSinceEpoch
          };
          FirebaseFirestore.instance
              .collection("ChatRoom")
              .doc(chatRoomId)
              .collection("chats")
              .add(messageMap).catchError((e){
            print(e.toString());
          });
          FirebaseFirestore.instance.collection("ChatRoom")
              .doc(chatRoomId).update(<String,dynamic>{
            "time":messageMap['time']
          });
          Constants.chatCount=Constants.chatCount-1;

          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setInt('chatCount', Constants.chatCount);

          FormData formData=new FormData.fromMap({
            'points':prefs.getInt('points'),
            'chatCount':prefs.getInt('chatCount')
          });
          try{
            Dio dio=new Dio();
            int? id=prefs.getInt('id');
            await dio.post("${Constants.apiLink}/account/$id",data: formData);
          }
          on DioError catch(e){
            print("OK ERROR!! $e");
          }
        }
      });
      return 'finish';
    });
    return ss;
  }

  addConversationMessages(String chatRoomId,messageMap,messageMapInfo) {
    FirebaseFirestore.instance
        .collection("ChatRoom")
        .doc(chatRoomId)
        .collection("chats")
        .add(messageMap).catchError((e){
      print(e.toString());
    });

    FirebaseFirestore.instance.collection("ChatRoom")
        .doc(chatRoomId).update(messageMapInfo);
  }

  getConversationMessages(String chatRoomId) async{
    return await FirebaseFirestore.instance.collection("ChatRoom")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("time",descending: true)
        .snapshots();
  }

  Future<List> getChatRooms(String myID) async{
    QuerySnapshot snapshotData= await FirebaseFirestore.instance
        .collection("ChatRoom")
        .where("users",arrayContains: myID)
        .orderBy("time",descending:true)
        .get();
    var dataList=[];
    var count=0;
    for(var snapshot in snapshotData.docs){
      //lastMessage
      var lastMessage=FirebaseFirestore.instance
          .collection("ChatRoom")
          .doc(snapshot['chatroomId'])
          .collection('chats')
          .orderBy("time",descending: false)
          .get().then((value){
        return value.docs.last['message'].toString();
      });
      var user1=snapshot['users'][0];
      var user2=snapshot['users'][1];
      var yourId=user1==myID?user2:user1;

      var profileInfo =FirebaseFirestore.instance.collection("users").where("uid",isEqualTo: yourId).get().then((value){
        return [value.docs.first['name'],value.docs.first['profileText'],value.docs.first['profileColor'],];
      });
      var profileArray={
        'chatRoomId':snapshot['chatroomId'],
        'lastMessage':lastMessage,
        'profileInfo':profileInfo
      };
      dataList.add(profileArray);
      count=count+1;
      if(count==snapshotData.docs.length){
        return dataList;
      }
      // return dataList;
    }
    return [];
  }

  Future<String> getTest(String myID) async{
    QuerySnapshot snapshotData= await FirebaseFirestore.instance
        .collection("ChatRoom")
        .where("users",arrayContains: myID)
        .orderBy("time",descending:true)
        .get();
    for(var snapshot in snapshotData.docs){
      var lastMessage=FirebaseFirestore.instance
          .collection("ChatRoom")
          .doc(snapshot['chatroomId'])
          .collection('chats')
          .orderBy("time",descending: false)
          .get().then((value){
        return value.docs.last['message'].toString();
      });
      return lastMessage;
    }
    return 'nono';
  }

  Future<String> getLastMessage(String chatRoomId) async{
    QuerySnapshot snapshot= await
    FirebaseFirestore.instance
        .collection("ChatRoom")
        .doc(chatRoomId)
        .collection('chats')
        .orderBy("time",descending: false)
        .get();

    try{
      String ss=snapshot.docs.last['message'].toString();
      return snapshot.docs.last['message'].toString();
    }catch(error){
      return "No Element";
    }
  }

  deleteCollection(String chatRoomId,String collectionId)async{
    return  await FirebaseFirestore.instance.collection("ChatRoom").doc(chatRoomId).collection("chats").doc(collectionId)
        .delete().then((value) {
      print("OK DELETED!!");
    });
  }

  deleteByTimePeriod() async{
    await FirebaseFirestore.instance.collection("ChatRoom").get().then((value) {
      value.docs.forEach((element) {
        FirebaseFirestore.instance.collection("ChatRoom").doc(element.id).collection("chats").get().then((value){
          value.docs.forEach((element1) {
            FirebaseFirestore.instance.collection("ChatRoom").doc(element.id).collection("chats").doc(element1.id).get().then((value){
              var hey1=DateTime.parse("2021-12-07 23:59:59Z");
              if(value['time']<hey1.millisecondsSinceEpoch){
                print(value['message']);
                FirebaseFirestore.instance.collection("ChatRoom").doc(element.id).collection("chats").doc(element1.id)
                    .delete();
              }
            });
          });
        });
      });
    });
  }

  Future<List> getUserProfile(String id)async{
    QuerySnapshot snapshot =await FirebaseFirestore.instance.collection("users").where("uid",isEqualTo: id).get();
    try{
      return [snapshot.docs.first['name'].toString(),snapshot.docs.first['profileText'].toString(),snapshot.docs.first['profileColor'].toString()];
    }
    catch(error){
      return ['error','error'];
    }
  }
}
