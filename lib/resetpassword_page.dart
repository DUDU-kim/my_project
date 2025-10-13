import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';
import 'main.dart';//資料庫

class Reset extends StatelessWidget {
  final String email;//把傳進來的數用變數存起來
  const Reset({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ResetPasswordCodePage(email: email),
      ),
    );
  }
}

class ResetPasswordCodePage extends StatefulWidget {
  String email;
  ResetPasswordCodePage({super.key,  required this.email});//接收forgetpassword_page的值

  @override
  State<ResetPasswordCodePage> createState() => _ResetPasswordCodePage();
}

class _ResetPasswordCodePage extends State<ResetPasswordCodePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _NewPasswordController = TextEditingController();
  final TextEditingController _CheckNewPasswordController = TextEditingController();
  String? _loginErrorMessage = "應該沒被看到吧";
  bool _isLoading = false;
  bool _word = false;
  final FocusNode _NewPasswordFocusNode = FocusNode();
  final FocusNode _CheckNewPasswordFocusNode = FocusNode();
  bool _isNewPasswordFocused = false;
  bool _isCheckNewPasswordFocused = false;

  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試
  // "http://localhost:90/Flutter_API"; //電腦測試


  Future<String?> ResetPassword() async { //印vscode的內容(echo)
    var url = Uri.parse("$baseUrl/resetpassword.php");
    var response = await http.post(url, body: {
      "email": _emailController.text,
      "newpassword": _NewPasswordController.text,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print(data);

      print(data['message']);
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
    _NewPasswordFocusNode.addListener(() {
      setState(() {
        _isNewPasswordFocused = _NewPasswordFocusNode.hasFocus;
      });
    });

    _CheckNewPasswordFocusNode.addListener(() {
      setState(() {
        _isCheckNewPasswordFocused = _CheckNewPasswordFocusNode.hasFocus;
      });
    });
  }



  @override
  void dispose() { //用來在頁面被銷毀時釋放資源，避免記憶體洩漏。
    _NewPasswordFocusNode.dispose();
    _CheckNewPasswordFocusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('重設密碼', style: TextStyle(color: Colors.white, fontSize: 20),),
          centerTitle: true,
          backgroundColor: Colors.black,
          automaticallyImplyLeading: false, // 不顯示左上角箭頭
          // iconTheme: IconThemeData(color: Colors.white), // 箭頭顏色
        ),
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      focusNode: _NewPasswordFocusNode,
                      cursorColor: Colors.cyan, // 輸入游標顏色
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _NewPasswordController,
                      decoration: InputDecoration(
                        labelText: "新密碼",
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
                          color: _isNewPasswordFocused ? Colors.cyan : Colors.grey, // 動態切換顏色
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      focusNode: _CheckNewPasswordFocusNode,
                      cursorColor: Colors.cyan, // 輸入游標顏色
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _CheckNewPasswordController,
                      decoration: InputDecoration(
                        labelText: "確認新密碼",
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
                          color: _isCheckNewPasswordFocused ? Colors.cyan : Colors.grey, // 動態切換顏色
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top : 10),
                          child: _word ? Text(_loginErrorMessage!, style: TextStyle(color: Colors.red, fontSize: 13)) : Text(_loginErrorMessage!, style: TextStyle(color: Colors.black, fontSize: 13))
                      ),
                      Padding(
                          padding: const EdgeInsets.only(top : 10, left : 105),
                          child: ElevatedButton(
                              onPressed: () {
                                List<TextEditingController> controllers = [
                                  _NewPasswordController,
                                  _CheckNewPasswordController,
                                ];
                                if (_NewPasswordController.text.isEmpty) {
                                  setState(() {
                                    _word = true;
                                    _loginErrorMessage = "請先輸入新密碼";
                                  });
                                }
                                if (_NewPasswordController.text.isNotEmpty) {
                                  _CheckNewPasswordController.text = _NewPasswordController.text;
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                splashFactory: NoSplash.splashFactory, // 取消水波紋
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5), // 圓角 5，比較方
                                ),
                                backgroundColor: Colors.white, // 背景色
                              ),
                              child: Text("同上"!, style: TextStyle(color: Colors.grey, fontSize: 13)))
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          splashFactory: NoSplash.splashFactory, // 取消水波紋
                        ),
                        onPressed:  _isLoading ? null : ()async{
                          _emailController.text = widget.email;
                          List<TextEditingController> controllers = [
                            _NewPasswordController,
                            _CheckNewPasswordController,
                          ];
                          if (controllers.any((controller) => controller.text.isEmpty)) {
                            setState(() {
                              _word = true;
                              _loginErrorMessage = "尚未輸入新密碼";
                            });
                          }
                          if ((_NewPasswordController.text == _CheckNewPasswordController.text) && controllers.any((controller) => controller.text.isNotEmpty)) {
                            final result = await ResetPassword();
                            if (result == "重設成功") {
                              setState(() {
                                _isLoading = true;
                              });

                              Future.delayed(Duration(seconds: 2), () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors.grey[900],
                                        // 背景色
                                        title: Text(result!, style: TextStyle(
                                            color: Colors.pink, fontSize: 20),
                                            textAlign: TextAlign.center),
                                        //Text函式要求字串不可空, verify!代表保證不為 null
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment
                                              .center,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(builder: (context) => FirstPage(reset: true))); //到第二頁
                                              },
                                              child: const Text("回首頁", style: TextStyle(color: Colors.white, fontSize: 15)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                );
                              });
                            }
                          }

                        },
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) : Text('確定', style: TextStyle(color: Colors.pink, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ),
    );
  }
}