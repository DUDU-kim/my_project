import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_project/Pages/home_page.dart';
import 'package:my_project/Pages/search_page.dart';
import 'package:my_project/Pages/chat_page.dart';
import 'package:my_project/Pages/musiclib_page.dart';
import 'package:my_project/Pages/account_page.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:my_project/playerfullui_page.dart';

import 'package:my_project/provider.dart';
import 'package:provider/provider.dart';

import 'package:palette_generator/palette_generator.dart';


class DemoApp2 extends StatelessWidget {
  final String email;
  final String password;

  DemoApp2({super.key, required this.email, required this.password});

  @override
  Widget build(BuildContext context) {
    return AllPage(email: email, password: password);
  }
}

class AllPage extends StatefulWidget {
  final String email;
  final String password;

  AllPage({super.key, required this.email, required this.password});

  @override
  State<AllPage> createState() => _AllPage();
}

class _AllPage extends State<AllPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  // final pages = [HomePage(), SearchPage(), ChatPage(), MusicLibPage(), AccountPage()];
  File? _avatarImage;
  // 注意：初始的 audioUrl 僅作為備用
  String audioUrl = "";
  late AudioPlayer _audioPlayer;

  String? _imageSmall;
  String? _fileUrl; // 用於追蹤當前播放的 URL
  Color dominantColor = Colors.grey;

  bool _isLoading = false;

  late AnimationController _loadingAnimationController;

  late final ValueNotifier<Duration> _durationNotifier;
  late final ValueNotifier<Duration> _positionNotifier;
  late final ValueNotifier<PlayerState> _playerStateNotifier;   // 新增一個 Notifier 來儲存播放狀態


  Future<void> updatePalette() async { //自動匹配專輯背景色
    final albumProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
    final imageSmall = albumProvider.selectedAlbum?['image_small']; // 從 provider 獲取當前圖片 URL

    // 當 _imageSmall 為 null 時，直接返回，避免錯誤
    if (imageSmall == null) {
      if (mounted) {
        setState(() {
          dominantColor = Colors.grey.shade900; // 預設灰色
        });
      }
      return;
    }
    final PaletteGenerator paletteGenerator =
    await PaletteGenerator.fromImageProvider(
      NetworkImage(imageSmall),
      size: const Size(50, 50), // 取樣解析度，提高準確度
      maximumColorCount: 10, // 抓更多顏色
    );

    if (mounted) {
      setState(() {
        dominantColor = paletteGenerator.darkVibrantColor?.color // 先取「暗色」
            ?? paletteGenerator.lightVibrantColor?.color // 如果沒有，再取「淺鮮豔色」
            ?? paletteGenerator.dominantColor?.color // 如果還沒有，再取「最主要顏色」
            ?? Colors.grey.shade900; // 如果都沒有，使用灰色
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化 Notifier
    _durationNotifier = ValueNotifier(Duration.zero);
    _positionNotifier = ValueNotifier(Duration.zero);
    _playerStateNotifier = ValueNotifier(PlayerState.stopped);

    // 初始化動畫控制器
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
    // 使用 ..repeat() 來讓動畫無限循環播放
    // 它會在跑到終點後自動跳回起點並重播
      ..repeat(); // 我們不再需要手動的 addStatusListener

    playerInit();
  }

  void playOrPause() {
    // _audioPlayer.state → 目前播放器狀態
    // PlayerState.playing → 目前正在播放
    // 使用 Notifier 的值來確保與 UI 同步
    if (_playerStateNotifier.value == PlayerState.playing) { //如果播放器現在正在播放
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  void playerInit() {
    _audioPlayer = AudioPlayer();
    // 設定預設模式為播放完畢後釋放資源，也就是不循環。
    _audioPlayer.setReleaseMode(ReleaseMode.release); // 這裡通常是預設值，我們會在 onPlayerComplete 處理邏輯

    // 監聽「音樂總時長」變化事件
    _audioPlayer.onDurationChanged.listen((Duration d) {
      _durationNotifier.value = d;
    });
    // 監聽「當前播放位置」變化事件
    _audioPlayer.onPositionChanged.listen((Duration p) {
      _positionNotifier.value = p;
    });

    // 監聽「播放完成」事件
    _audioPlayer.onPlayerComplete.listen((event) {
      _positionNotifier.value = Duration.zero; // 重置播放位置
      // print("歌曲播放完成！"); // 調試信息

      final albumProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
      final currentPlayMode = albumProvider.playMode; // 獲取當前的播放模式
      // print("當前播放模式: $currentPlayMode"); // 調試信息

      switch (currentPlayMode) {
        case 0: // 順序播放 (播完即停)
        // 檢查是否是播放列表的最後一首歌
          if (albumProvider.currentIndex == albumProvider.playlist.length - 1) {
            // print("到達歌單最後一首，停止播放。");
            _audioPlayer.stop(); // 停止播放器
            _playerStateNotifier.value = PlayerState.stopped; // 更新狀態為停止
          } else {
            // 播放下一首
            // print("播放下一首歌曲。");
            albumProvider.playNext(); // 讓 Provider 處理切換到下一首歌的邏輯
          }
          break;
        case 1: // 列表循環播放
        // print("列表循環模式，播放下一首。");
          albumProvider.playNext(); // 讓 Provider 處理切換到下一首歌的邏輯 (內部會處理循環到第一首)
          break;
        case 2: // 單曲循環 (這個模式通常由 AudioPlayer.setReleaseMode(ReleaseMode.loop) 控制)
        // 如果設置了 ReleaseMode.loop，通常不會觸發 onPlayerComplete，
        // 但作為備用，如果因為某些原因觸發了，我們也可以確保它重新播放
        // print("單曲循環模式，重新播放當前歌曲。");
          _audioPlayer.seek(Duration.zero); // 回到開頭
          _audioPlayer.resume(); // 重新播放
          break;
      }
    });

    // 監聽播放器狀態的變化
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _playerStateNotifier.value = state;
      // 將最新的播放狀態同步給 Provider
      Provider.of<SelectedAlbumProvider>(context, listen: false).updatePlayerState(state);
    });
  }

  void _onItemClick(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _loadingAnimationController.dispose();
    _durationNotifier.dispose();
    _positionNotifier.dispose();
    _playerStateNotifier.dispose();
    super.dispose();
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
            Expanded( // 確保Navigator後底部導覽列還在
              child: IndexedStack( // 代替 pages[_currentIndex]
                index: _currentIndex,
                children: [
                  Navigator(  // 頁面順序不能亂
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => HomePage(),
                      );
                    },
                  ),
                  Navigator(
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => SearchPage(),
                      );
                    },
                  ),
                  Navigator(
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => ChatPage(),
                      );
                    },
                  ),
                  Navigator(
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => MusicLibPage(),
                      );
                    },
                  ),
                  Navigator(
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => AccountPage(),
                      );
                    },
                  ),
                ],
              ),
            ),

            Consumer<SelectedAlbumProvider>(
              builder: (context, albumProvider, child) {
                final selectedAlbum = albumProvider.selectedAlbum;
                final isNowVisible = albumProvider.gestureDisplay;

                final id = selectedAlbum?['id'];
                final title = selectedAlbum?['title'] ?? '歌曲';
                final artist = selectedAlbum?['artist'] ?? '藝人';
                final fileUrl = selectedAlbum?['file_url'];
                final music_cache = selectedAlbum?['music_cache']; // 已經下載到伺服器的fileUrl
                final coverUrl = selectedAlbum?['cover_url'];
                final imageSmall = selectedAlbum?['image_small'];
                final imageMedium = selectedAlbum?['image_medium'];

                // // 檢查是否是「重複點擊」事件
                if (albumProvider.isReselect) {
                  Future.microtask(() {
                    // 如果是，則執行「從頭重播」邏輯
                    print("--- 重複點擊，從頭播放 ---");
                    _audioPlayer.seek(Duration.zero).then((_) {
                      _audioPlayer.resume();
                    });

                    // 記得消費掉事件，避免重複觸發
                    albumProvider.consumeReselectEvent();
                  });
                }
                // 否則，才執行原本的「播放新歌」邏輯
                if (music_cache != null && music_cache != _fileUrl) { //在清單中按下歌曲了

                  Future.microtask(() { //當前同步程式碼執行完畢後，立即執行
                    if (mounted) {
                      setState(() {
                        _isLoading = true;
                        _fileUrl = music_cache;
                        _imageSmall = imageSmall;
                      });
                      // 我們不再需要手動啟動動畫，因為 repeat() 會讓它一直跑
                    }

                    _positionNotifier.value = Duration.zero;
                    _durationNotifier.value = Duration.zero;

                    // 設定新的音訊來源並播放(等fileUrl抓到再載入撥放,若放在playerInit函式,會造成一開始空值,但iniState又去執行他)
                    String musicFileName = _fileUrl?.split("http://172.20.10.3/Flutter_API/music_cache/")[1] as String; // 從資料庫或 API 取得的檔名
                    String encodedFileName = Uri.encodeComponent(musicFileName); //僅對檔名部分進行編碼
                    String url = "http://172.20.10.3/Flutter_API/music_cache/$encodedFileName";
                    _audioPlayer.setSourceUrl(url).then((_) {
                      _audioPlayer.play(UrlSource(url));
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }).catchError((error) {
                      if(mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    });
                    // 更新背景顏色
                    updatePalette();
                  });
                }

                // 直接使用 isNowVisible 來控制顯示，而不是修改 widget.display
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Visibility(
                          visible: isNowVisible, // 使用來自 Provider 的最新狀態, 代表visible=true(顯示)
                          child: GestureDetector(
                            onTap: () async {
                              // 只有當 _fileUrl 已經抓到真正歌曲時才可以打開
                              if (_isLoading == false && imageMedium != null) {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.black,
                                  isScrollControlled: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) {
                                    // 在點擊歌曲時，順便把完整資料存到 provider, 不塞資料, 全螢幕頁面做final selectedAlbum = selectedProvider.selectedAlbum;會是null
                                    // 進而觸發 if (selectedAlbum == null) return; // 沒有選中的歌曲就不操作
                                    // 導致勾選歌單時沒辦法變更狀態成打勾
                                    final album = {
                                      'id': selectedAlbum?['id'],
                                      "title": selectedAlbum?['title'],
                                      "artist": selectedAlbum?['artist'],
                                      "file_url": selectedAlbum?['file_url'],
                                      "cover_url": selectedAlbum?['cover_url'],
                                      "image_small": selectedAlbum?['image_small'],
                                      "image_medium": selectedAlbum?['image_medium'],
                                      'duration': selectedAlbum?['duration'],
                                      'music_cache': selectedAlbum?['music_cache'],
                                      'dominant_color': dominantColor,
                                    };
                                    // ⬇️ 延遲到 build 結束後再更新 provider
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      Provider.of<SelectedAlbumProvider>(context, listen: false)
                                          .selectAlbum(newAlbum: album);
                                    });

                                    return PlayerFullUI(
                                      audioUrl: _fileUrl!, //保證不null
                                      audioPlayer: _audioPlayer,
                                      durationNotifier: _durationNotifier,
                                      positionNotifier: _positionNotifier,
                                      playerStateNotifier: _playerStateNotifier, // 把播放狀態也傳過去
                                      dominantColor: dominantColor,
                                    );
                                  },
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: dominantColor.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.001),
                              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Row(
                                children: [
                                  SizedBox(width: screenWidth * 0.04),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageSmall == null ?
                                    Container(
                                      height: screenHeight * 0.06,
                                      width: screenWidth * 0.115,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      child: Icon(
                                        Icons.music_note,
                                        color: Colors.grey,
                                      ),
                                    )
                                        :
                                    Image.network(
                                      imageSmall,
                                      height: screenHeight * 0.06,
                                      width: screenWidth * 0.115,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.03),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: TextStyle(fontSize: (screenWidth * 0.03).clamp(8.0, 10.0), color: Colors.white)),
                                      Text(artist, style: TextStyle(fontSize: (screenWidth * 0.03).clamp(8.0, 10.0), color: Colors.white.withOpacity(0.6))),
                                    ],
                                  ),
                                  const Spacer(),
                                  ValueListenableBuilder<PlayerState>(
                                    valueListenable: _playerStateNotifier,
                                    builder: (context, playerState, child) {
                                      final isPlaying = playerState == PlayerState.playing;
                                      return IconButton(
                                        onPressed: () {
                                          if (_isLoading == false) {
                                            playOrPause();
                                          }
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isPlaying ? Icons.pause : Icons.play_arrow,
                                        ),
                                        color: Colors.white,
                                        iconSize: screenHeight * 0.04,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Visibility(
                      visible: isNowVisible,
                      child: SizedBox(
                        width: screenWidth * 0.87,
                        height: 1,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 底層：永遠顯示的 Slider
                            ValueListenableBuilder<Duration>(
                              valueListenable: _positionNotifier,
                              builder: (context, position, _) {
                                final duration = _durationNotifier.value;
                                return SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 1,
                                    thumbShape: SliderComponentShape.noThumb,
                                    overlayShape: SliderComponentShape.noThumb,
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                                    disabledActiveTrackColor: Colors.transparent,
                                    disabledInactiveTrackColor: Colors.white.withOpacity(0.3),
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble()),
                                    min: 0.0,
                                    // 如果 duration 的秒數大於 0，就使用它，否則先暫時用 1.0 作為最大值
                                    max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                                    onChanged: _isLoading ? null : (value) async {
                                      await _audioPlayer.seek(Duration(seconds: value.toInt()));
                                    },
                                  ),
                                );
                              },
                            ),
                            // 上層：用 AnimatedBuilder 根據動畫控制器的值來繪製進度條
                            if (_isLoading)
                              AnimatedBuilder(
                                animation: _loadingAnimationController,
                                builder: (context, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      // value 來自我們的動畫控制器
                                      value: _loadingAnimationController.value,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                                      backgroundColor: Colors.transparent,
                                      minHeight: 1,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    isNowVisible ? SizedBox(height: 1) : SizedBox(),
                    BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.black,
                      items: const <BottomNavigationBarItem>[
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
                        BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜尋'),
                        BottomNavigationBarItem(icon: Icon(Icons.message_sharp), label: '交流'),
                        BottomNavigationBarItem(icon: Icon(Icons.library_music_sharp), label: '音樂庫'),
                        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: '我的'),
                      ],
                      currentIndex: _currentIndex,
                      selectedItemColor: Colors.white,
                      unselectedItemColor: Colors.grey,
                      onTap: _onItemClick,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}