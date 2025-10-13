import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_project/resetpassword_page.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';//資料庫

class ResendVerifyCode extends StatelessWidget {
  final String email;//把傳進來的數用變數存起來
  const ResendVerifyCode({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: VerifyCodePage(email: email),
      ),
    );
  }
}

class VerifyCodePage extends StatefulWidget {
  String email;
  VerifyCodePage({super.key, required this.email});//接收forgetpassword_page的值

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _verifyCodeController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _otpCode = ""; // 用來接收使用者輸入的 6 碼
  String? _loginErrorMessage = "";
  int _secondsRemaining = 30;
  Timer? _timer;
  bool flag = false;
  bool _isLoading = false;
  bool _buttonlight = false;

  final String baseUrl = 'http://172.20.10.3/Flutter_API'; //實機測試

  Future<String?> _resendVerificationCode() async {
    var url = Uri.parse("$baseUrl/send_verification.php");
    var response = await http.post(url, body: {
      'email': _emailController.text,
      "verifycode": _verifyCodeController.text,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print(data['message']);
      return data['message']; // 回傳訊息給外部判斷
    }
  }

  Future<String?> _inputVerificationCode() async {//印vscode的內容(echo)
    var url = Uri.parse("$baseUrl/input_verification.php");
    var response = await http.post(url, body: {
      "verifycode": _otpCode,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print(data);
      print(data['message']);
      return data['message']; // 回傳訊息給外部判斷
    }
    else {
      print("Failed to add users");
      return null;
    }
  }

  _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel(); // 停止 timer 避免重複執行
        final result2 = await _inputVerificationCode();
        if (result2 == "驗證碼失效, 請重傳" || result2 == "驗證碼錯誤" || _verifyCodeController.text.isEmpty) {
          setState(() {
            flag = true;
            _loginErrorMessage = "驗證碼錯誤/失效, 請重傳";
            _buttonlight = true;
          });
        }
        // 如果有要啟用重傳按鈕，這邊處理
      }
    });
  }

  @override
  void initState() { //一進畫面就開始倒數
    super.initState();
    _startCountdown(); // 開始倒數
    print("Email: ${widget.email}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('驗證碼', style: TextStyle(color: Colors.white, fontSize: 20),),
        centerTitle: true,
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // 不顯示左上角箭頭
        // iconTheme: IconThemeData(color: Colors.white), // 箭頭顏色
      ),
      backgroundColor: Colors.black,
      body: Padding(
          padding: const EdgeInsets.all(10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PinCodeTextField(
                  appContext: context,
                  length: 6, // 六個空格
                  obscureText: false,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  controller: _pinCodeController,
                  onChanged: (value) async{ //value只回傳string
                    if (value.length == 6) {
                      _otpCode = value; //value接收pincode值
                      final result = await _inputVerificationCode(); // 呼叫發送驗證 API
                      if (result == "驗證碼正確") {
                        setState(() {
                          _loginErrorMessage = "";
                          _isLoading = true;
                        });
                        Future.delayed(Duration(seconds: 2), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Reset(email: widget.email)),
                          );
                        });
                      }
                      else if (result == "驗證碼錯誤") {
                        setState(() {
                          // flag = true;
                          _loginErrorMessage = "驗證碼錯誤";
                          // await Future.delayed(Duration(seconds: 1));
                          // flag = false;
                        });
                      }
                    }
                  },
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(5),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.grey[800],
                    selectedFillColor: Colors.grey[700],
                    // 依照錯誤與否變更外框顏色
                    activeColor: _loginErrorMessage == "" ?  Colors.teal : Colors.red,
                    selectedColor: _loginErrorMessage == "" ? Colors.white : Colors.red,
                    inactiveColor: _loginErrorMessage == "" ? Colors.grey : Colors.red,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(0),
                  child: flag ? Text(_loginErrorMessage!, style: TextStyle(color: Colors.red, fontSize: 12),) : Text('$_secondsRemaining 秒後失效', style: TextStyle(color: Colors.red, fontSize: 12),),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonlight == true ? Colors.green[500] : Colors.grey[800],
                      foregroundColor: _buttonlight == true ? Colors.white : Colors.grey[900], // 文字顏色
                      splashFactory: NoSplash.splashFactory, // 取消水波紋
                    ),
                    onPressed: _isLoading ? null : () async{ //_isLoading若為true, 則button就為null, 會不見, 被轉圈圈取代
                      _emailController.text = widget.email; //右邊前一頁傳過來的值(這樣寫才取的出值)
                      if (_buttonlight == true) {
                        setState(() {
                          _isLoading = true;
                        });
                        final result = await _resendVerificationCode();
                        if (result == "驗證碼寄送成功") {
                          setState(() {
                            _buttonlight = false;
                            _isLoading = false;
                            _loginErrorMessage = "重新輸入驗證碼";
                            _pinCodeController.clear();
                          });
                          setState(() {
                            _startCountdown();
                            flag = false;
                            _secondsRemaining = 30;
                          });
                          PinCodeTextField(
                            appContext: context,
                            length: 6, // 六個空格
                            obscureText: false,
                            animationType: AnimationType.fade,
                            keyboardType: TextInputType.number,
                            animationDuration: const Duration(milliseconds: 300),
                            enableActiveFill: true,
                            controller: _pinCodeController,
                            onChanged: (value) async{ //value只回傳string
                              if (value.length == 6) {
                                _otpCode = value; //value接收pincode值
                                final result = await _inputVerificationCode(); // 呼叫發送驗證 API
                                if (result == "驗證碼正確") {
                                  setState(() {
                                    _loginErrorMessage = "";
                                    _isLoading = true;
                                  });
                                  Future.delayed(Duration(seconds: 2), () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => Reset(email: widget.email)),
                                    );
                                  });
                                }
                                else if (result == "驗證碼錯誤") {
                                  setState(() {
                                    // flag = true;
                                    _loginErrorMessage = "驗證碼錯誤";
                                    // await Future.delayed(Duration(seconds: 1));
                                    // flag = false;
                                  });
                                }
                              }
                            },
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(5),
                              fieldHeight: 50,
                              fieldWidth: 40,
                              activeFillColor: Colors.white,
                              inactiveFillColor: Colors.grey[800],
                              selectedFillColor: Colors.grey[700],
                              // 依照錯誤與否變更外框顏色
                              activeColor: _loginErrorMessage == "" ?  Colors.teal : Colors.red,
                              selectedColor: _loginErrorMessage == "" ? Colors.white : Colors.red,
                              inactiveColor: _loginErrorMessage == "" ? Colors.grey : Colors.red,
                            ),
                          );
                      Padding(
                      padding: EdgeInsets.all(0),
                      child: flag ? Text(_loginErrorMessage!, style: TextStyle(color: Colors.red, fontSize: 12),) : Text('$_secondsRemaining 秒後失效', style: TextStyle(color: Colors.red, fontSize: 12),),
                      );
                        }
                      }
                      else {
                        _isLoading = false;
                      }
                    },
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) : Text('重傳'),
                    ),
                  ),
              ],
            ),
          )
      ),
    );
  }
}


