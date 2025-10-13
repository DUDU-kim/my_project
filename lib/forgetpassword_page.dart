import 'package:flutter/material.dart';
import 'package:my_project/verifycode_page.dart';
import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';//資料庫

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();
  String? _loginErrorMessage;
  bool _isLoading = false;
  final FocusNode _emailFocusNode = FocusNode();
  bool _isEmailFocused = false;

  // List users = [];
  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試
  // "http://localhost:90/Flutter_API"; //電腦測試

  // Future<void> _fetchUsers() async { //印網頁的內容
  //   var url = Uri.parse("$baseUrl/get_users.php");
  //   var response = await http.get(url);
  //   if (response.statusCode == 200) {
  //     setState(() {
  //       users = json.decode(response.body);
  //       users = [users.last];
  //       print(users);
  //     });
  //   }
  //   else{
  //     print("Failed to load users");
  //   }
  // }
  Future<String?> _forgetpasswordUser() async { //印vscode的內容(echo)
    var url = Uri.parse("$baseUrl/forgetpassword.php");
    var response = await http.post(url, body: {
      "email": _emailController.text,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(data['message']),
      //   ),
      // );
      // _fetchUsers();
      // print(data['message']);
      return data['message']; // 回傳訊息給外部判斷
    }
    else{
      print("Failed to add users");
      return null;
    }
  }

  Future<String?> _sendVerificationCode() async {
    var url = Uri.parse("$baseUrl/send_verification.php");
    var response = await http.post(url, body: {
      'email': _emailController.text,
      "verifycode": _verifyCodeController.text,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      // print(data['message']);
      return data['message']; // 回傳訊息給外部判斷
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
  }

  @override
  void dispose() { //用來在頁面被銷毀時釋放資源，避免記憶體洩漏。
    _emailFocusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('忘記密碼', style: TextStyle(color: Colors.white, fontSize: 20),),
        centerTitle: true,
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white), // 箭頭顏色
      ),
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Padding( //常用!
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) { //value == null || value.isEmpty綁定使用   也可controllers.any((controller) => controller.text.isEmpty)[其他頁面有用!]
                    return '請輸入資料!';
                  }
                  // 額外錯誤訊息（例如帳號錯）
                  if (_loginErrorMessage != null) {
                    return _loginErrorMessage;
                  }
                  //validator 規定:
                  //回傳 String（錯誤訊息） → 表示驗證失敗，表單會顯示錯誤。
                  //回傳 null → 表示驗證成功，此欄位沒錯誤。
                  return null;
                },
                focusNode: _emailFocusNode,
                cursorColor: Colors.cyan, // 輸入游標顏色
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '電子郵件',
                  labelStyle: TextStyle(color: Colors.grey), // 電子郵件標籤維持灰色
                  enabledBorder: OutlineInputBorder( // 未聚焦邊框
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder( // 聚焦邊框
                    borderSide: BorderSide(color: Colors.cyan, width: 2),
                  ),
                  floatingLabelStyle: TextStyle( // Label 聚焦顏色
                    color: _isEmailFocused ? Colors.cyan : Colors.grey, // 動態切換顏色
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red, // 錯誤文字紅色（預設）
                    fontSize: 13,
                    height: 2,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async { //若 _isloading = true, 則onPressed = null, 按鈕此時會自動變灰，無法點擊, 若為false, 執行 ()async
                    //很重要!!若第一次打錯顯示無效的帳戶,但下次打對,若沒刷新UI界面更新_loginErrorMessage的值,_loginErrorMessage會繼續等於無效的帳戶,所以要清空
                    setState(() {
                      _loginErrorMessage = null;
                      _isLoading = true; // 開始 loading
                    });

                    if (_formKey.currentState!.validate()) {
                      final result = await _forgetpasswordUser();
                      if (result == "無效的帳戶") {
                        setState(() {
                          _loginErrorMessage = "無效的帳戶";
                          _isLoading = false; // 停止 loading
                        });
                        _formKey.currentState!.validate(); // 再觸發一次 validator，顯示錯誤文字
                      }
                      else {
                        if (result == "有效的帳戶") {
                          final verify = await _sendVerificationCode();
                          setState(() {
                            _isLoading = false; // 停止 loading
                          });

                          if (verify == "驗證碼寄送成功") {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: Colors.grey[900], // 背景色
                                  title: Text(verify!, style: TextStyle(color: Colors.pink, fontSize: 20), textAlign: TextAlign.center), //Text函式要求字串不可空, verify!代表保證不為 null
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ResendVerifyCode(email: _emailController.text))); //到第二頁
                                          // _emailController.clear();
                                        },
                                        child: const Text("確定", style: TextStyle(color: Colors.white, fontSize: 15)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                          else if (verify!.split(':')[0] == "驗證碼寄送失敗") {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: Colors.grey[900], // 背景色
                                  title: Text('驗證碼寄送失敗', style: TextStyle(color: Colors.teal, fontSize: 20), textAlign: TextAlign.center), //Text函式要求字串不可空, verify!代表保證不為 null
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () async{
                                          Navigator.of(context).pop(); // 按下重傳後並關掉錯誤對話框
                                          setState(() {
                                            _isLoading = true; //對話框關掉後街進入重新loading狀態
                                          });

                                          final reverify = await _sendVerificationCode();
                                          setState(() {
                                            _isLoading = false;
                                          });

                                          // 再處理一次成功或失敗
                                          if (reverify == "驗證碼寄送成功") {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  backgroundColor: Colors.grey[900],
                                                  title: Text(
                                                    reverify!,
                                                    style: TextStyle(color: Colors.pink, fontSize: 20),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ResendVerifyCode(email: _emailController.text),));
                                                          // _emailController.clear();
                                                        },
                                                        child: const Text("確定", style: TextStyle(color: Colors.white, fontSize: 15)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                        },
                                        child: const Text("重傳", style: TextStyle(color: Colors.white, fontSize: 15)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        }
                      }
                    }
                    else { //因為按鈕一按, _isloading就為true, 所以必須在_formKey.currentState!.validate()不通過時將其設回false, 使其變回送出按鈕狀態
                      setState(() {
                        _isLoading = false; // 停止 loading，如果表單驗證失敗
                      });
                    }
                  },
                  child:_isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) : Text('下一步', style: TextStyle(color: Colors.pink),),
                ),
              ),
            ],
          ),
        )
      ),
    );
  }
}
