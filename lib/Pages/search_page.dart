import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';//跳出上傳圖片視窗
import 'dart:io';//跳出上傳圖片視窗
import '../account_test_page.dart';

import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';

import 'package:my_project/provider.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String keyword = ""; //搜尋的關鍵字
  bool isFocused = false;

  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試

  List<Map<String, dynamic>> albums = [];
  File? _avatarImage;
  // 按鈕資料
  final buttonData = [
    {"title": "音樂", "color": Colors.pink, "image": "assets/num/1.png"},
    {"title": "Podcast", "color": Colors.teal[700], "image": "assets/num/2.png"},
    {"title": "現場活動", "color": Colors.purple[500], "image": "assets/num/1.png"},
    {"title": "專為你打造", "color": Colors.purple[200], "image": "assets/num/2.png"},
    {"title": "最新發行", "color": Colors.green[500], "image": "assets/num/1.png"},
    {"title": "華語流行", "color": Colors.blue[900], "image": "assets/num/2.png"},
    {"title": "流行樂", "color": Colors.blue[500], "image": "assets/num/1.png"},
    {"title": "韓國流行樂", "color": Colors.redAccent, "image": "assets/num/2.png"},
    {"title": "嘻哈樂", "color": Colors.blue[500], "image": "assets/num/1.png"},
    {"title": "排行榜", "color": Colors.purple[200], "image": "assets/num/2.png"},
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        isFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() { //用來在頁面被銷毀時釋放資源，避免記憶體洩漏。
    _searchFocusNode.dispose();
    super.dispose();
  }


  Future<void> searchAlbums(String keyword) async{
    if (keyword.isEmpty) { //列表空時,只顯示背景為黑的列表
      setState(() => albums = []);
      return;
    }
    var url = Uri.parse("$baseUrl/searchmusic.php");
    var response = await http.post(url, body: {
      "keyword": keyword,
    });
    if (response.statusCode == 200) {
      // print(keyword);
      setState(() {
        final List<dynamic> data = json.decode(response.body); //dart接收到的type是List<dynamic>
        albums = data.map((e) => Map<String, dynamic>.from(e)).toList();//須明確轉換成Map<String, dynamic>讓dart知道
        print(albums);
      });
    }
  }

  void cancelSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      keyword = "";
      albums = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法的開頭先取得螢幕寬度
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    // print("--- 畫面刷新 ---");
    // print("螢幕寬度 (screenWidth): $screenWidth");
    // print("螢幕高度 (screenHeight): $screenHeight");
    // print("-----------------");
    return Consumer2<SelectedAlbumProvider, MyPlaylistProvider>(
        builder: (context, albumProvider, myPlaylistProvider, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: SafeArea(
            top: false,
            bottom: true,
            child: Column( // 2. 建立一個統一的、從上到下的佈局
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: Text("搜尋", style: TextStyle(color: Colors.white)),
                  titleSpacing: 0,
                  iconTheme: IconThemeData(color: Colors.white),
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  actions: [
                    // Builder(
                    //   builder: (buttonContext) { // 這個 buttonContext 是我們需要的
                    //     return IconButton(
                    //       icon: Icon(Icons.add, color: Colors.white),
                    //       onPressed: () {
                    //         // --- 將正確的 context 傳遞給對話框方法 ---
                    //       },
                    //     );
                    //   },
                    // ),
                  ],
                ),
                // ---- 搜尋框 (始終顯示) ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: screenHeight * 0.08,
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            cursorColor: Colors.cyan,
                            onChanged: (value) {
                              // onChanged 裡面不需要 setState，因為 focusNode 的 listener 已經處理了
                              keyword = value;
                              searchAlbums(value);
                            },
                            style: TextStyle(color: Colors.white, fontSize: (screenWidth * 0.03).clamp(13.0, 15.0)),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              suffixIcon: isFocused
                                  ? TextButton(
                                onPressed: cancelSearch,
                                child: Text(
                                  "取消",
                                  style: TextStyle(color: Colors.cyan, fontSize: (screenWidth * 0.03).clamp(13.0, 15.0)),
                                ),
                              )
                                  : null,
                              labelText: "想聽甚麼?",
                              labelStyle: TextStyle(color: Colors.grey, fontSize: (screenWidth * 0.03).clamp(13.0, 15.0)),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.cyan, width: 2),
                              ),
                              floatingLabelStyle: TextStyle(
                                color: isFocused ? Colors.cyan : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- 內容區域 (根據 isFocused 顯示不同內容) ----
                Expanded(
                  //用 Stack 將「瀏覽」和「搜尋結果」兩個視圖疊加起來，再用 Visibility Widget 根據 isFocused 狀態來決定哪一個可見
                  child: Stack( // 3. 使用 Stack 來疊加 "瀏覽全部" 和 "搜尋結果"
                    children: [
                      // ---- "瀏覽全部" 視圖 (未聚焦時顯示) ----
                      Visibility(
                        visible: !isFocused, // 4. 使用 Visibility 控制顯示，而不是重建整個佈局
                        // maintainState: true, // 如果希望保留滾動位置，可以打開這個
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: screenHeight * 0.01),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: const Text('瀏覽全部', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'MicrosoftJhengHei', fontWeight: FontWeight.bold,),),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  children: [
                                    // 用for迴圈排版
                                    for (int i = 0; i < buttonData.length; i += 2)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: screenHeight * 0.02), //按鈕上下的間距
                                        child: Row(
                                          children: [
                                            // ---- 第一個按鈕(左邊) ----
                                            Expanded( //最外圍Padding的EdgeInsets.symmetric(horizontal: 10)讓螢幕一開始就左右平均各縮小10px,
                                              //接著用Expanded讓第一個按鈕往右填滿(因為外圍包Row),
                                              //下方程式碼又塞一個SizedBox(height: screenWidth * 0.04, //左右按鈕的間距),
                                              //再放第二個按鈕也是往右填滿,導致即使不用控制按鈕本身寬度,也能剛好平均分配
                                              child: SizedBox(
                                                height: screenHeight * 0.13, //按鈕本身的高度, 大概90px左右
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: buttonData[i]["color"] as Color?,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountTestPage()));
                                                  },
                                                  child: Stack(
                                                    children: [
                                                      Positioned(
                                                        //這個定位的基準，不是整個螢幕的寬高，而是按鈕本身的尺寸。
                                                        //因為沒有寫按鈕寬度,所以直接拿螢幕寬度來用
                                                        //原按鈕大概90px, top: 8px, 所以8/90 ≈ (0.08)9%
                                                        left: screenWidth * 0.04,
                                                        top: screenHeight * 0.13 * 0.1,
                                                        child: Text(
                                                          buttonData[i]["title"] as String,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            // 使用 .clamp() 函式，確保字體大小在 12.0 到 15.0 之間
                                                            //screenWidth * 0.035.clamp(12.0, 15.0),這要寫會錯,dart中"."的優限度大於"*", 算完會高達 4680 像素的字體，太大！
                                                            fontSize: (screenWidth * 0.035).clamp(12.0, 15.0), //原為12px, 螢幕寬度為392, 所以12/392 ≈ 0.03
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        //即使0也要寫, 不寫會預設null
                                                        right: 0,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Transform.rotate(
                                                          angle: 0.2,
                                                          child: Image.asset(
                                                            buttonData[i]["image"] as String,
                                                            width: screenWidth * 0.12,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),

                                            SizedBox(
                                              width: screenWidth * 0.04, //左右按鈕的間距
                                            ),

                                            // ---- 第二個按鈕(右邊,如果存在) ----
                                            Expanded(
                                              child: (i + 1 < buttonData.length)
                                                  ? SizedBox(
                                                height: screenHeight * 0.13, //按鈕本身的高度, 大概90px左右
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: buttonData[i + 1]["color"] as Color?,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountTestPage()));
                                                  },
                                                  child: Stack(
                                                    children: [
                                                      Positioned(
                                                        //這個定位的基準，不是整個螢幕的寬高，而是按鈕本身的尺寸。
                                                        //因為沒有寫按鈕寬度,所以直接拿螢幕寬度來用
                                                        //原按鈕大概90px(screenHeight * 0.13), top: 8px, 所以8/90 ≈ (0.08)9%
                                                        left: screenWidth * 0.04,
                                                        top: screenHeight * 0.13 * 0.1,
                                                        child: Text(
                                                          buttonData[i + 1]["title"] as String,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            // 使用 .clamp() 函式，確保字體大小在 12.0 到 15.0 之間
                                                            //screenWidth * 0.035.clamp(12.0, 15.0),這要寫會錯,dart中"."的優限度大於"*", 算完會高達 4680 像素的字體，太大！
                                                            fontSize: (screenWidth * 0.035).clamp(12.0, 15.0), //原為12px, 螢幕寬度為392, 所以12/392 ≈ 0.03
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        //即使0也要寫, 不寫會預設null
                                                        right: 0,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Transform.rotate(
                                                          angle: 0.2,
                                                          child: Image.asset(
                                                            buttonData[i + 1]["image"] as String,
                                                            width: screenWidth * 0.12,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                                  : const SizedBox(), // 如果是奇數個按鈕(即右邊有按鈕不存在)，用空SizedBox佔位
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- "搜尋結果" 視圖 (聚焦且有結果時顯示) ----
                      Visibility(
                        visible: isFocused,
                        child: Container(
                          color: Colors.black, // 給一個背景色，避免透出底下的按鈕
                          child: albums.isEmpty
                              ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                '想聽什麼歌呢?',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          )
                              :
                          ListView.builder(
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              var album = albums[index];

                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8), // 調整圓角大小
                                  child: Image.network(
                                    album["image_small"]!,
                                    width: screenWidth * 0.15,
                                    height: screenHeight * 0.08,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  album["title"]!,
                                  style: TextStyle(
                                    color: albumProvider.selectedAlbumFileUrl == album["file_url"] ? Colors.cyan : Colors.white,
                                  ),
                                ),
                                subtitle: Text('藝人：${album["artist"]!}',
                                    style: TextStyle(color: Colors.grey, fontSize: (screenWidth * 0.03).clamp(8.0, 10.0))),
                                onTap: () {
                                  final selectedProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
                                  selectedProvider.getPlayList("搜尋 「 ${album["title"]} 」");
                                  final onlyOneSong = [{ // 可以直接 newAlbum: song 即可, 但若有額外加一些東西就可以這樣寫
                                    'id': album["id"],
                                    "title": album["title"],
                                    "artist": album["artist"],
                                    "file_url": album["file_url"],
                                    'music_cache': album["music_cache"],
                                    "cover_url": album["id"],
                                    "image_small": album["image_small"],
                                    "image_medium": album["image_medium"],
                                    'duration': album["duration"],
                                  }];
                                  // 更新全域狀態
                                  // Provider.of<T>(context, listen: false) 用於觸發一個動作，而不需監聽後續變化
                                  //這行程式碼會去 Widget Tree(provider.dart) 中尋找 SelectedAlbumProvider 的實例
                                  //listen: false: 這是一個非常重要的參數。因為我們在 onTap 裡只想「觸發一個動作」（更新數據），而不需要因為數據更新而「重建」這個 ListTile 本身，所以設為 false 可以避免不必要的重建，提升效能。
                                  Provider.of<SelectedAlbumProvider>(context, listen: false).selectAlbum(isRepeat: false, newAlbum: album, newPlaylist: onlyOneSong.cast<Map<String, dynamic>>());
                                  //album有 => id, title, artist, file_url, cover_url, duration, upload_time, image_small, image_medium, music_cache
                                  Provider.of<MyPlaylistProvider>(context, listen: false).updateAddState(album["title"], isNetWork : true);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    );
  }
}

