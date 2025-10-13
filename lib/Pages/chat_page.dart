import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  File? _avatarImage;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                title: Text('交流區', style: TextStyle(color: Colors.white)),
                titleSpacing: 0,
                iconTheme: IconThemeData(color: Colors.white),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                // actions: [
                //   Builder(
                //     builder: (buttonContext) { // 這個 buttonContext 是我們需要的
                //       return IconButton(
                //         icon: Icon(Icons.add, color: Colors.white),
                //         onPressed: () {
                //           // --- 將正確的 context 傳遞給對話框方法 ---
                //           _showCreatePlaylistDialog(buttonContext);
                //         },
                //       );
                //     },
                //   ),
                // ],
              ),
              Expanded(
                  child: Center(
                    child: Text('交流區'),
                  )
              )
            ],
          )
      ),
      drawer: Drawer(
        // Drawer 內容維持不變...
        child: Container(
          color: Colors.grey[900],
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.grey[850]),
                accountName: Text('老師你可能要稍微躲一下', style: TextStyle(fontSize: (screenWidth * 0.03).clamp(18.0, 20.0), color: Colors.grey)),
                accountEmail: Text("檢視個人檔案", style: TextStyle(fontSize: (screenWidth * 0.03).clamp(8.0, 10.0), color: Colors.grey)),
                currentAccountPicture: GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedImage != null) {
                      if (mounted) {
                        setState(() {
                          _avatarImage = File(pickedImage.path);
                        });
                      }
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.white70,
                    backgroundImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                    child: _avatarImage == null ? Icon(Icons.person, color: Colors.black) : null,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: Colors.white),
                title: Text('設定', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: Colors.white),
                title: Text('歷史紀錄', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}