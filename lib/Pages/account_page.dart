import 'package:flutter/material.dart';
import '../account_test_page.dart';

class AccountPage extends StatefulWidget {
  AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPage();
}

class _AccountPage extends State<AccountPage> {
  final mydata = ['帳戶', '數據節省模式與離線模式', '重播', '內容與顯示', '隱私權與社交', '媒體音質/畫質', '通知', 'App與裝置', '關於'];

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
                title: Text('我的', style: TextStyle(color: Colors.white)),
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
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: mydata.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, // 保持水平邊距
                        vertical: 0,   //
                      ),
                      // 1. 左侧的標籤文字
                      title: Text(
                        mydata[index],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (screenWidth * 0.03).clamp(12.0, 14.0),
                        ),
                      ),

                      // 2. 右侧的箭頭圖標
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 16,
                      ),

                      // 3. 整片點擊事件
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AccountTestPage()));
                        // 在这里执行您的逻辑，例如跳转到新页面
                        // Navigator.push(...);
                      },
                    );
                  },
                )
              )
            ],
          )
      ),
    );
  }
}