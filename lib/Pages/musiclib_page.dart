import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:my_project/provider.dart';
import 'package:my_project/playlist_details_page.dart';

class MusicLibPage extends StatefulWidget {
  const MusicLibPage({super.key});

  @override
  State<MusicLibPage> createState() => _MusicLibPageState();
}

class _MusicLibPageState extends State<MusicLibPage> {
  File? _avatarImage;

  // 創建新播放清單的對話框
  Future<void> _showCreatePlaylistDialog(BuildContext providerContext) async {
    final TextEditingController textFieldController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('建立新播放清單', style: TextStyle(color: Colors.white, fontSize: 23)),
          content: TextField(
            controller: textFieldController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "請輸入播放清單名稱",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan),
              ),
            ),
            cursorColor: Colors.cyan, // 輸入游標顏色
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('確定', style: TextStyle(color: Colors.cyan)),
              onPressed: () async {
                final String playlistName = textFieldController.text;
                final result = await songsList(playlistName);
                Provider.of<MyPlaylistProvider>(providerContext, listen: false)
                    .createPlaylist(playlistName);
                Navigator.of(dialogContext).pop();
                if (result == "名稱已存在") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result!),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試
  Future<String?> songsList(String title) async{
    var url = Uri.parse("$baseUrl/songs_list.php");
    var response = await http.post(url, body: {
      "title": title,
    });
    if (response.statusCode == 200) {
      // print(keyword);
      var data = json.decode(response.body); //dart接收到的type是List<dynamic>;
      print("=====");
      print(data['message']);
      return data['message'];
    }
  }

  // 顯示重新命名對話框
  Future<void> _showRenamePlaylistDialog(String oldName, BuildContext providerContext) async {
    final TextEditingController textFieldController = TextEditingController();
    textFieldController.text = oldName; // 將舊名稱預填到輸入框中

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) { // dialogContext 只用來關閉對話框
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('重新命名播放清單', style: TextStyle(color: Colors.white, fontSize: 20)),
          content: TextField(
            controller: textFieldController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "請輸入新名稱",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
            ),
            cursorColor: Colors.cyan,
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 左右分散
              children: [
                TextButton(
                  child: Text('取消', style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: Text('確定', style: TextStyle(color: Colors.cyan)),
                  onPressed: () async {
                    final String newName = textFieldController.text;
                    final result = await renameSongsList(oldName, newName, "");
                    Provider.of<MyPlaylistProvider>(providerContext, listen: false)
                        .renamePlaylist(oldName, newName);
                    Navigator.of(dialogContext).pop();
                    if (result == "名稱已存在，無法重新命名") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result!),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // 顯示刪除對話框
  Future<void> _showDeletePlaylistDialog(String playlistName, BuildContext providerContext) async {

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) { // dialogContext 只用來關閉對話框
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 20),
              children: [
                const TextSpan(text: ' 確定'),
                TextSpan(
                  text: '  刪除',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold,), // 單獨紅色
                ),
                TextSpan(text: ' 「$playlistName」 ?\n\n'),
                TextSpan(
                  text: '(歌單裡的歌也會全部被刪除!)',
                  style: const TextStyle(color: Colors.white, fontSize: 16), // 單獨紅色
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 左右分散
              children: [
                TextButton(
                  child: const Text('取消', style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('確定', style: TextStyle(color: Colors.cyan)),
                  onPressed: () async {
                    await deleteSongsList(playlistName, "", "delete");
                    Provider.of<MyPlaylistProvider>(providerContext, listen: false)
                        .deletePlaylist(playlistName);
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<String?> renameSongsList(String title, String newTitle, String delete) async{
    var url = Uri.parse("$baseUrl/songs_list.php");
    var response = await http.post(url, body: {
      "title": title,
      "new_title": newTitle,
      "delete": delete,
    });
    if (response.statusCode == 200) {
      var data = json.decode(response.body); //dart接收到的type是List<dynamic>;
      print(data['message']);
      return data['message'];
    }
  }
  Future<String?> deleteSongsList(String title, String newTitle, String delete) async{
    var url = Uri.parse("$baseUrl/songs_list.php");
    var response = await http.post(url, body: {
      "title": title,
      "new_title": newTitle,
      "delete": delete,
    });
    if (response.statusCode == 200) {
      var data = json.decode(response.body); //dart接收到的type是List<dynamic>;
      print(data['message']);
      return data['message'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                title: Text('音樂庫', style: TextStyle(color: Colors.white)),
                titleSpacing: 0,
                iconTheme: IconThemeData(color: Colors.white),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  Builder(
                    builder: (buttonContext) { // 這個 buttonContext 是我們需要的
                      return IconButton(
                        icon: Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          // --- 將正確的 context 傳遞給對話框方法 ---
                          _showCreatePlaylistDialog(buttonContext);
                         },
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: Consumer2<SelectedAlbumProvider, MyPlaylistProvider>(
                  builder: (context, selectedProvider, playlistProvider, child) {
                    final playlists = playlistProvider.playlists.keys.toList();
                    final songnum = playlistProvider.songNumMap;

                    if (playlists.isEmpty) {
                      return Center(
                        child: Text('尚未建立播放清單', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    // 顯示播放清單列表
                    return ListView.builder(
                      padding: EdgeInsets.only(top: 5.0), // <-- 這裡可以調整上方距離
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        String playlistName = playlists[index];

                        // --- 使用 Stack 佈局 ---
                        return Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            // 底層：一個沒有 trailing 的 ListTile，負責顯示內容和處理點擊
                            ListTile(
                              leading: Icon(Icons.queue_music, color: Colors.grey),
                              title: Text(playlistName, style: TextStyle(color: Colors.white)),
                              subtitle: Text(
                                //updateSongsNum
                                '${songnum[playlistName] ?? 0} 首歌曲',
                                style: TextStyle(color: Colors.white70,
                                  fontSize: (screenWidth * 0.03).clamp(10.0, 12.0),
                                ),
                              ),
                              // 注意：trailing 設為 null 或直接不寫
                              onTap: () async {
                                await playlistProvider.fetchSongDetail(playlistName);
                                selectedProvider.getPlayList(playlistName);
                                // 點擊 ListTile 的其他區域，導航到詳情頁
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PlaylistDetailsPage(
                                      playlistName: playlistName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // 上層：使用 Positioned 精確控制按鈕位置
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.more_vert, color: Colors.grey),
                                color: Colors.grey[800],
                                onSelected: (String value) {
                                  if (value == 'delete') {
                                    _showDeletePlaylistDialog(playlistName, context);
                                    // Provider.of<MyPlaylistProvider>(context, listen: false)
                                    //     .deletePlaylist(playlistName);
                                  } else if (value == 'rename') {
                                    _showRenamePlaylistDialog(playlistName, context);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    height: 36,
                                    child: Text('重新命名', style: TextStyle(color: Colors.white)),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    height: 36,
                                    child: Text('移除', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
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
