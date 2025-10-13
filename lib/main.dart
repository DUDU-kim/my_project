import 'package:flutter/material.dart';
import 'package:my_project/Pages/all_page.dart';
import 'package:my_project/signup_page.dart';
import 'package:my_project/forgetpassword_page.dart';
import 'package:shared_preferences/shared_preferences.dart';//記住密碼

import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';//資料庫

import 'package:provider/provider.dart';
import 'package:my_project/provider.dart';


//它會去找「上層最近的 Navigator」來執行跳頁行為。
//而 Navigator 是由 MaterialApp 自動建立的。
//如果沒有用 MaterialApp，就會找不到 Navigator，造成錯誤。
//所以Navigator、Scaffold、AppBar、ThemeData 等 Material 設計元件，必須在 MaterialApp 的上下文中才能正常工作。
void main() {
  runApp(
    // 1. 使用 MultiProvider 将所有“全局共享”的 Provider 放在最顶层
    MultiProvider(
      providers: [
        // MyPlaylistProvider 需要在登录后和主页中使用，所以是全局的
        ChangeNotifierProvider(create: (context) => MyPlaylistProvider()),
        ChangeNotifierProvider(create: (context) => SelectedAlbumProvider()),
        // 如果未来有其他需要跨页面共享的 Provider，也放在这里
      ],
      // 2. 在 Provider 之下，创建 App 唯一的一个 MaterialApp
      child: MaterialApp(
        // 3. 在这里设置全局深色主题，彻底解决闪烁问题
        theme: ThemeData(
          // 关键：将路由转场时的底层“画布”颜色设为黑色
          canvasColor: Colors.black,
          // 推荐：将 App 整体风格设为深色，这会自动调整文字、图标等的默认颜色
          brightness: Brightness.dark,
          // 您可以把无水波纹效果也设为全局
          splashFactory: NoSplash.splashFactory,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              // --- 使用 resolveWith 来根据状态返回不同颜色 ---
              backgroundColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                  // 1. 检查按钮是否处于“禁用”状态
                  if (states.contains(MaterialState.disabled)) {
                    // 如果是禁用状态（也就是正在 loading），
                    // 返回一个完全透明的颜色，让按钮“消失”
                    return Colors.transparent;
                  }
                  // 2. 对于所有其他状态（正常、按下等），
                  // 返回您想要的原始按钮背景色
                  return Colors.white; // 假设您想要的原始背景色是白色
                },
              ),

              // --- 其他样式保持不变 ---
              // foregroundColor: MaterialStateProperty.all(Colors.red),
              elevation: MaterialStateProperty.all(0),
              // (可选) 确保禁用时没有边框阴影
              shadowColor: MaterialStateProperty.all(Colors.transparent),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        // App 的起始页面是登录页
        home: const DemoApp(),
      ),
    ),
  );
}

class FirstPage extends StatelessWidget { //被導過來的頁面要有StatelessWidget
  final bool reset;
  const FirstPage({super.key, this.reset = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: DemoApp(reset: reset),
      ),
    );
  }
}

//登入畫面
class DemoApp extends StatefulWidget {
  final bool reset;
  const DemoApp({super.key, this.reset = false});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final TextEditingController _emailController = TextEditingController();//擷取文字,且第二字首要大寫(關鍵字)
  final TextEditingController _passwordController = TextEditingController();
  int count = 0;
  bool _obscure = true; // 記錄是否遮蔽密碼
  bool _rememberMe = false; //是否記住密碼
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  // --- 新增一個狀態來控制載入動畫 ---
  bool _isLoggingIn = false;

  List users = [];
  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試
  // "http://localhost:90/Flutter_API"; //電腦測試

  Future<void> _fetchUsers() async { //印網頁的內容
    var url = Uri.parse("$baseUrl/get_users.php");
    var response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        users = json.decode(response.body);
        users = [users.last];
      });
    }
    else{
      print("Failed to load users");
    }
  }
  Future<String?> _loginUser() async { //印vscode的內容(echo)
    var url = Uri.parse("$baseUrl/login.php");
    var response = await http.post(url, body: {
      "email": _emailController.text,
      "password": _passwordController.text
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      // print(data);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(data['message']),
      //   ),
      // );
      _fetchUsers();
      // print(data['message']);
      return data['message']; // 回傳訊息給外部判斷
    }
    else{
      print("Failed to add users");
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });

    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });

    if (widget.reset) {
      _emailController.text = "";
      _passwordController.text = "";
      _rememberMe = false;
      _clearLoginInfo();
    } else {
      _loadLoginInfo();
    }
  }

  @override
  void dispose() { //用來在頁面被銷毀時釋放資源，避免記憶體洩漏。
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  // 啟動時只讀帳密
  void _loadLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');
    String? savedPassword = prefs.getString('password');

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }


  void _saveLoginInfo(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    print(email);
    print(password);
    await prefs.setString('email', email); //字典的儲存方式
    await prefs.setString('password', password);
  }
  void _clearLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
  }


  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        backgroundColor: Colors.black,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea( //可以應付各種型號
          child: SingleChildScrollView(
            // padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  const FittedBox( //內部的 Widget（例如文字）在空間不足時自動縮小以「塞得下」而不報錯或溢出。
                    fit: BoxFit.scaleDown, // 只縮小不放大
                    child: Text(
                      'ILoveMusic',
                      style: TextStyle(color: Colors.cyan, fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      focusNode: _emailFocusNode,
                      cursorColor: Colors.cyan, // 輸入游標顏色
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "電子郵件",
                        labelStyle: TextStyle(color: Colors.grey), // 未聚焦時 Label 顏色
                        // hintText: '輸入你的 Email',
                        // hintStyle: TextStyle(color: Colors.grey), // Hint 顏色
                        enabledBorder: OutlineInputBorder( // 未聚焦邊框
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder( // 聚焦邊框
                          borderSide: BorderSide(color: Colors.cyan, width: 2),
                        ),
                        floatingLabelStyle: TextStyle( // Label 聚焦顏色
                          color: _isEmailFocused ? Colors.cyan : Colors.grey, // 動態切換顏色
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      focusNode: _passwordFocusNode,
                      cursorColor: Colors.cyan, // 輸入游標顏色
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: "密碼",
                        labelStyle: TextStyle(color: Colors.grey),
                        // hintText: '輸入你的 Email',
                        // hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan, width: 2),
                        ),
                        floatingLabelStyle: TextStyle(
                          color: _isPasswordFocused ? Colors.cyan : Colors.grey, // 動態切換顏色
                        ),
                        suffixIcon: IconButton( // suffixIcon 文字放右側圖示
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: _obscure ? Colors.grey : Colors.cyan, // 這裡決定顏色
                          ),
                          onPressed: () {
                            setState(() { //只能在StatefulWidget(如果畫面中有物件因操作會變動都用這個)下寫在裡面, StatelessWidget就要外面額外寫void method
                              _obscure = !_obscure;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30), // 按鈕區域與上面分開
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _clearLoginInfo();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SignUp()));//到第二頁
                          _emailController.clear();
                          _passwordController.clear();
                          setState(() {
                            _rememberMe = false;
                          });
                        },
                        child: const Text('註冊', style: TextStyle(color: Colors.red, fontSize: 20),),
                      ),
                      const SizedBox(width: 10), // 按鈕間隔
                      ElevatedButton(
                        onPressed: _isLoggingIn ? null : () async { // 載入中禁止再次點擊
                          // --- 檢查欄位是否為空 (這部分邏輯不變) ---
                          List<TextEditingController> controllers = [
                            _emailController,
                            _passwordController,
                          ];
                          if (controllers.any((controller) => controller.text.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('登入失敗'), duration: Duration(seconds: 1)),
                            );
                            return;
                          }

                          // 2. 執行登入驗證
                          final result = await _loginUser();
                          try {

                            // --- 開始執行登入與預載入流程 ---
                            setState(() {
                              _isLoggingIn = true; // 1. 立刻將按鈕變成轉圈狀態
                            });
                            await Future.delayed(Duration(seconds: 2));

                            if (result == '登入成功') {
                              // 3. 登入成功後，預先載入播放清單資料
                              //    使用 Provider.of 來安全地獲取在 main.dart 註冊的實例
                              await Provider.of<MyPlaylistProvider>(context, listen: false)
                                  .fetchAndSetPlaylists();
                              Provider.of<MyPlaylistProvider>(context, listen: false)
                                  .updateSongsNum();

                              // 4. 所有資料都準備好後，才進行跳轉
                              if (mounted) { // 確保頁面還在，避免非同步錯誤
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DemoApp2(email: _emailController.text, password: _passwordController.text)));
                              }
                            } else {
                              if (result == "尚未註冊/登入失敗") {
                                _emailController.clear();
                                _passwordController.clear();
                                setState(() => _rememberMe = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('尚未註冊/登入失敗'), duration: Duration(seconds: 1)),
                                );
                              }
                              if (result == '密碼錯誤') {
                                _passwordController.clear();
                                setState(() => _rememberMe = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('密碼錯誤'), duration: Duration(seconds: 1)),
                                );
                              }
                            }
                          } catch (e) {
                            // 處理可能發生的網路錯誤等
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('發生錯誤: $e'), duration: Duration(seconds: 1)),
                            );
                          } finally {
                            // 5. 無論成功或失敗，最後都要結束轉圈狀態
                            //    使用 mounted 檢查是好習慣，防止頁面已銷毀還呼叫 setState
                            if (mounted) {
                              setState(() {
                                _isLoggingIn = false;
                              });
                            }
                          }
                        },
                        child: _isLoggingIn ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,),) : Text('登入', style: TextStyle(color: Colors.red, fontSize: 20)),
                      ),

                      Checkbox(
                        value: _rememberMe,
                        activeColor: Colors.cyan, // 勾勾顏色
                        onChanged: (bool? rememberMe) async{
                          final result = await _loginUser();
                          List<TextEditingController> controllers = [
                            _emailController,
                            _passwordController,
                          ];
                          setState(() {
                            _rememberMe = rememberMe!;
                            if (controllers.any((controller) => controller.text.isEmpty && (_rememberMe == true))) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('請先輸入帳戶'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              _rememberMe = false;
                              return;
                            }
                            else {
                              if (_rememberMe){
                                if (result == "登入成功") {
                                  _saveLoginInfo(_emailController.text, _passwordController.text); //只有這組帳密室對的,才該被記住!, 其他錯的都不要記
                                }
                              }
                              else{
                                _clearLoginInfo();
                              }
                            }

                          });
                        },
                      ),
                      const Text('記住密碼', style: TextStyle(fontSize: 15, color: Colors.grey),),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 210, top: 20), // 跟上方物件間隔 20
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ForgetPasswordPage()));
                        _emailController.clear();
                        _passwordController.clear();
                        setState(() {
                          _rememberMe = false;
                        });
                      },
                      child: const Text('忘記密碼?', style: TextStyle(fontSize: 15, color: Colors.pink, decoration: TextDecoration.underline, decorationThickness: 2, decorationColor: Colors.pink)),
                    ),
                  ),
                ],
              )
          )
      ),
    );
  }
}



