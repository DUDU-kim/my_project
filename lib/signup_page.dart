import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'main.dart';
import 'package:http/http.dart' as http; //資料庫
import 'dart:convert';//資料庫

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}
class _SignUpState extends State<SignUp> {
  bool _obscure = true; // 記錄是否遮蔽
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  List users = [];
  final String baseUrl = 'http://172.20.10.3/Flutter_API';//實機測試
  // "http://localhost:90/Flutter_API"; //電腦測試

  Future<void> _fetchUsers() async {
    var url = Uri.parse("$baseUrl/get_users.php");
    var response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
          users = json.decode(response.body);
          users = [users.last];
          print(users);
      });
    } //抓到註冊的資料後在網頁這樣存[{"users_id":"1","username":"abc","sex":"男","height":"0.0"...}]
    else{
      print("Failed to load users");
    }
  }
  Future<String?> _insertUser() async {
    var url = Uri.parse("$baseUrl/insert_user.php");
    var response = await http.post(url, body: {
      "name": _nameController.text, //"name"要與insert_user.php裡的$_POST['name']名稱一致
      "email": _emailController.text,
      "password": _passwordController.text
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message']),
          duration: Duration(seconds: 1),
        ),
      );
      _fetchUsers();
      return data['message']; // 回傳訊息給外部判斷
    }
    else{
      print("Failed to add users");
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('註冊', style: TextStyle(color: Colors.white, fontSize: 20),),
        centerTitle: true,
        backgroundColor: Colors.black,
        // 不要加 automaticallyImplyLeading: false，這樣箭頭才會自動出現
        iconTheme: IconThemeData(color: Colors.white), // 箭頭顏色
      ),
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
          child: SingleChildScrollView(
            // padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      decoration: const InputDecoration(labelText: "姓名", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "電子郵件", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: "密碼",
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() { //只能在StatefulWidget(如果畫面中有物件因操作會變動都用這個)下寫在裡面, StatelessWidget就要外面額外寫void method
                              _obscure = !_obscure;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // 按鈕區域與上面分開
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: () async{
                            List<TextEditingController> controllers = [
                              _nameController,
                              _emailController,
                              _passwordController,
                            ];
                            if (controllers.any((controller) => controller.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('註冊失敗'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              return;// ❗阻止繼續執行註冊流程,不執行下面的程式碼了
                            }

                            _insertUser();
                            // 清除欄位
                            await Future.delayed(Duration(seconds: 2));

                            Navigator.push(context, MaterialPageRoute(builder: (context) => DemoApp())); //到第二頁
                            _nameController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                            },
                          child: const Text('確定', style: TextStyle(color: Colors.red, fontSize: 20),),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              )
          )
      ),
    );
  }
}
