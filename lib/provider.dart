import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 導入 HTTP 套件，用於網路請求
import 'dart:convert';                   // 導入 JSON 解碼器，用於處理 API 回應
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:audioplayers/audioplayers.dart';

/// 選中專輯/歌曲的狀態管理器
///
/// 主要功能：
/// - 管理當前選中的歌曲資訊
/// - 維護播放列表和當前播放位置
/// - 提供播放模式控制（順序、列表循環、單曲循環）
/// - 控制小播放器的顯示狀態
/// - 處理歌曲切換邏輯（上一首/下一首）
class SelectedAlbumProvider extends ChangeNotifier {
  // 當前選中的歌曲/專輯資訊
  Map<String, dynamic>? _selectedAlbum;
  String _isVisible = "";
  String? _selectedAlbumFileUrl; // 全局記錄選中歌曲ID
  Color? _nowColor;
  Map<String, dynamic>? _prefetch = {};
  PlayerState _playerState = PlayerState.stopped;
  List<Map<String, dynamic>> _originalPlaylist = []; // 用來保存「原始的、未被打亂的」播放列表
  bool _isShuffleMode = false;   // shuffle 狀態

  String? get selectedAlbumFileUrl => _selectedAlbumFileUrl;
  String? get isVisible => _isVisible;
  Color? get nowColor => _nowColor;
  Map<String, dynamic>? get prefetch => _prefetch;
  PlayerState get playerState => _playerState;
  bool get isShuffleMode => _isShuffleMode;

  // 重複選擇標記，用於識別用戶是否點擊了相同歌曲
  bool _isReselect = false;

  // 播放列表：存儲當前專輯或播放清單中的所有歌曲
  List<Map<String, dynamic>> _playlist = [];
  List<Map<String, dynamic>> _preplaylist = [];

  // 當前播放歌曲在播放列表中的索引位置
  int _currentIndex = -1;

  // 播放模式：
  // 0: 順序播放不循環
  // 1: 列表循環播放
  // 2: 單曲循環播放
  int _playMode = 0;
  int get playMode => _playMode;

  // 小播放器顯示控制標記
  bool _gestureDisplay = false;

  // === Getter 方法 ===
  Map<String, dynamic>? get selectedAlbum => _selectedAlbum;
  bool get isReselect => _isReselect;
  List<Map<String, dynamic>> get playlist => _playlist;
  List<Map<String, dynamic>> get preplaylist => _preplaylist;
  int get currentIndex => _currentIndex;
  bool get gestureDisplay => _gestureDisplay;

  // === 核心方法：選擇歌曲和更新播放列表 ===

  /// 選擇一首歌曲並可選地更新播放列表
  ///
  /// @param newAlbum 要選擇的新歌曲資訊
  /// @param newPlaylist 可選的新播放列表（例如用戶點擊了新專輯時傳入）
  ///
  /// 處理邏輯：
  /// 1. 如果提供了新播放列表，則更新本地播放列表
  /// 2. 檢查是否為重複點擊同一首歌
  /// 3. 更新當前歌曲資訊和播放索引
  /// 4. 確保小播放器處於可見狀態
  /// 5. 通知所有監聽者進行 UI 更新
  void selectAlbum({bool? isRepeat = true, Map<String, dynamic>? newAlbum,
    List<Map<String, dynamic>>? newPlaylist}) {
    // 步驟1: 更新播放列表（如果提供了新列表）
    if (newPlaylist != null && newPlaylist.isNotEmpty) {
      _preplaylist = _playlist;
      _playlist = newPlaylist;
      _originalPlaylist = List.from(newPlaylist); // 建立一個新的副本作為原始順序避免汙染

      // 如果用戶在進入新列表時，隨機模式是開啟的，則立即將新列表洗牌
      if (_isShuffleMode) {
        toggleShuffle(true, null); // 傳入 null context 因為這裡可能沒有
      }
    }

    // 步驟2: 檢查是否點擊相同歌曲
    // isRepeat == false: 尚未打開全螢幕播放器, 觸發"重複播放"
    if (isRepeat == false && _selectedAlbum?['file_url'] == newAlbum!['file_url']) {
      // 相同歌曲：設置重複選擇標記
      _isReselect = true;
    } else if (isRepeat == true && _selectedAlbum?['file_url'] == newAlbum!['file_url']) { //isRepeat == true: 打開全螢幕播放器, 不觸發"重複播放"
      _isReselect = false;
    } else {
      // 不同歌曲：更新歌曲資訊
      _selectedAlbum = newAlbum;
      // 步驟3: 在播放列表中定位當前歌曲的位置
      _isReselect = false;
    }

    // 步驟3: 在播放列表中定位當前歌曲的位置
    if (_playlist.isNotEmpty) {
      _currentIndex = _playlist.indexWhere((song) => song['file_url'] == newAlbum!['file_url']);
    } else {
      _currentIndex = -1;
    }

    // 存下選中歌曲 ID
    _selectedAlbumFileUrl = newAlbum!['file_url'];

    // 步驟4: 確保小播放器可見
    if (!_gestureDisplay) _gestureDisplay = true;

    // 步驟5: 通知 UI 更新
    notifyListeners();
  }

  /// 照片預取，讓切歌時照片可以快速出現（使用本地快取路徑）
  String? _currentPlaylistName;
  String? get currentPlaylistName => _currentPlaylistName;
  Future<void> prefetchImage(BuildContext context) async{
    // 內部通用方法：給路徑或 URL 生成 ImageProvider
    ImageProvider preload(dynamic pathOrUrl) {
      try {
        final file = File(pathOrUrl.toString()); // 指令 1: 准备好文件工具
        if (file.existsSync()) { // 指令 2: 去磁盘上【看一眼】文件在不在 (这是一个快速的元数据检查)
          return FileImage(file); // 指令 3: 返回一个【包含了文件路径的指令对象】
        } else {
          return NetworkImage(pathOrUrl.toString()); // 指令 4: 返回一个【包含了 URL 的指令对象】
        }
      } catch (e) {
        return NetworkImage(pathOrUrl.toString()); // 指令 5: 返回一个【包含了 URL 的指令对象】
      }
    }

    _currentPlaylistName = _selectedAlbum!['songs_list'];
    // 如果我们不知道當前的播放列表是什麼，就不進行预载
    if (_currentPlaylistName == null) return;

    // 預載前後歌曲圖片
    for (int offset in [-1, 1, 0]) { // [-1,...]:只會執行list裡的元素,且按照順序執行

      int idx = _currentIndex + offset;
      if (idx >= 0 && idx < _playlist.length) { // 要確保合法範圍
        // 格式："播放列表名稱_索引"
        final String cacheKey = "${_currentPlaylistName}_$idx";

        if (_prefetch?[cacheKey] == null) {
          var song = _playlist[idx];

          if (song['image_cache'] != null) {
            _prefetch?[cacheKey] = preload(song['image_cache']); //key: idx, value: image_cache

            precacheImage(_prefetch?[cacheKey], context).then((_) { // call這個fucntion後, 他會自己解碼(在底層)
              print("索引 key='$cacheKey' 的圖片预解碼完成。");
            }).catchError((e, s) {
              print("索引 key='$cacheKey' 的圖片预解碼失敗: $e");
            });
          }
        }
        if (_preplaylist != _playlist) {
          var song = _playlist[idx];

          if (song['image_cache'] != null) {
            _prefetch?[cacheKey] = preload(song['image_cache']); //key: idx, value: image_cache

            precacheImage(_prefetch?[cacheKey], context).then((_) { // call這個fucntion後, 他會自己解碼(在底層)
              print("索引 key='$cacheKey' 的圖片预解碼完成。");
            }).catchError((e, s) {
              print("索引 key='$cacheKey' 的圖片预解碼失敗: $e");
            });
          }
        }
      }
    }
  }


  void getPlayList(String playlist) {
    _isVisible = playlist;
    notifyListeners();
  }

  // 處理隨機播放的切換邏輯
  void toggleShuffle(bool? forceState, BuildContext? context) {
    // 如果呼叫時有傳 forceState (true 或 false) → 就直接套用 forceState。
    // 如果 forceState == null → 代表沒指定，就切換 _isShuffleMode 的值（true ↔ false）
    _isShuffleMode = forceState ?? !_isShuffleMode;
    if (_originalPlaylist.isEmpty) return;

    final currentSong = _selectedAlbum;
    if (currentSong == null) return;

    // 【1. 救援圖片】
    // 在改變任何東西之前，先根據當前的索引，計算出快取的 Key
    final String oldCacheKey = "${_currentPlaylistName}_${_currentIndex}";
    // 從快取 Map 中把這張圖片先複製出來
    final dynamic rescuedImage = _prefetch?[oldCacheKey];

    // (這部分的排序邏輯保持不變)
    if (_isShuffleMode) {
      // 開啟隨機
      print("🔀 已切換為隨機播放模式");
      List<Map<String, dynamic>> tempList = List.from(_originalPlaylist);
      tempList.removeWhere((song) => song['file_url'] == currentSong['file_url']);
      tempList.shuffle();
      _playlist = [currentSong, ...tempList]; // 洗完牌再把當前歌曲放在第一個
      _currentIndex = 0; // 索引更新為 0
    } else {
      // 關閉隨機
      print("▶️ 已恢復為順序播放模式");
      _playlist = List.from(_originalPlaylist);
      _currentIndex = _playlist.indexWhere((song) => song['file_url'] == currentSong['file_url']); // 索引更新為它在有序列表中的位置(即原歌單索引)
    }

    // 如果有 context，才執行快取操作
    if (context != null) {
      // 【2. 清空所有舊快取】
      // 因為我們已經把需要的圖片救援出來了，所以可以放心清空
      _prefetch?.clear();

      // 【3. 放回圖片】
      // 如果我們成功救援出圖片
      if (rescuedImage != null) {
        // 根據【更新後】的索引，計算出【新的】Key
        final String newCacheKey = "${_currentPlaylistName}_${_currentIndex}";
        // 把圖片用新的 Key 放回到剛被清空的快取裡
        _prefetch?[newCacheKey] = rescuedImage;
      }

      // 【4. 預載其他圖片】
      // 這時 prefetchImage 會發現當前歌曲的快取已經存在，
      // 它只會去下載上一首和下一首，完美避免閃爍。
      unawaited(prefetchImage(context));
    }

    // 最後通知 UI 更新
    notifyListeners();
  }

  // === 播放控制方法：實現歌曲切換邏輯 ===
  /// 播放下一首歌曲
  void playNext() {
    if (_playlist.isEmpty || _currentIndex == -1) return;

    // 使用 switch 語句來清晰地處理不同的播放模式
    switch (_playMode) {
      case 0: // 模式 0: 播放到列表末尾就停止
      // 檢查當前是否【還不是】最後一首歌
        if (_currentIndex < _playlist.length - 1) {
          // 如果不是，就正常播放下一首
          _currentIndex++;
        } else {
          // 如果【已經是】最後一首歌了，且隨機播放狀態關閉，Provider 不再更新索引。
          // audioPlayer 會因為 ReleaseMode.stop 而自然停止播放，完美達成目標。
          // 在隨機模式下，這意味著所有歌曲都播放過一遍後停止。
          // 在有序模式下，這意味著播放到歌單末尾後停止。
          return; // 直接退出方法
          // 如果【已經是】最後一首歌了，且隨機播放狀態開啟，則由以下來更新新的歌曲
          // _currentIndex = _playlist.indexWhere((song) => song['file_url'] == currentSong['file_url']);
        }
        break;

      case 1: // 模式 1: 列表循環 (無限播放)
      // 使用取模運算子 (%) 來實現無縫循環。
      // 當播放到列表末尾時，下一個索引會自動變回 0。
      // 在隨機模式下，這就是無限隨機播放。
      // 在有序模式下，這就是歌單循環播放。
        _currentIndex = (_currentIndex + 1) % _playlist.length;
        break;

      case 2: // 模式 2: 單曲循環
      // Provider 不需要做任何事情。
      // audioplayers 套件的 ReleaseMode.loop 會在底層自動重播同一首歌曲。
      // 我們只需要確保不改變 _currentIndex 即可。
        return; // 直接退出方法
    }
    // 單曲循環模式不變
    // case 2: break;

    _selectedAlbum = _playlist[_currentIndex];
    _isReselect = false;
    _selectedAlbumFileUrl = _selectedAlbum?['file_url'];
    notifyListeners();
  }

  /// 播放上一首歌曲
  // 0: 順序播放不循環（播完最後一首就停止）
  // 1: 列表循環播放（播完最後一首後回到第一首）
  // 2: 單曲循環播放（重複播放當前歌曲）
  void playPrevious() {
    if (_playlist.isEmpty || _currentIndex == -1) return;

    // 使用 switch 語句來清晰地處理不同的播放模式
    switch (_playMode) {
      case 0: // 模式 0: 播放到列表開頭就停止
      // 檢查當前是否【還不是】第一首歌
        if (_currentIndex > 0) {
          // 如果不是，就正常播放上一首
          _currentIndex--;
        } else {
          // 如果【已經是】第一首歌了，則不進行任何操作
          return; // 直接退出方法
        }
        break;

      case 1: // 模式 1: 列表循環
      // 使用取模運算子 (%) 的一個小技巧來處理負數情況，實現無縫循環
      // (currentIndex - 1 + playlist.length) 確保結果永遠是正數
        _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
        break;

      case 2: // 模式 2: 單曲循環
      // 按上一首時不應該有任何反應
        return; // 直接退出方法
    }

    _selectedAlbum = _playlist[_currentIndex];
    _isReselect = false;
    _selectedAlbumFileUrl = _selectedAlbum?['file_url'];
    notifyListeners();
  }

  // === 播放模式控制 ===
  /// 設定播放模式
  ///
  /// @param mode 播放模式值（0-2）
  ///   0: 順序播放不循環
  ///   1: 列表循環播放
  ///   2: 單曲循環播放
  void setPlayMode(int mode) {
    if (mode >= 0 && mode <= 2) {
      _playMode = mode;
      notifyListeners();
    }
  }

  // === 輔助方法 ===

  /// 消費重複選擇事件
  ///
  /// 用途：在處理完重複選擇邏輯後，清除重複選擇標記
  /// 避免重複選擇狀態持續存在影響後續操作
  void consumeReselectEvent() {
    if (_isReselect) {
      _isReselect = false;
    }
  }

  void updatePlayerState(PlayerState newState) {
    if (_playerState != newState) {
      _playerState = newState;
      notifyListeners();
    }
  }
}

/// 用戶播放清單管理器
///
/// 主要功能：
/// - 管理用戶建立的所有播放清單
/// - 提供播放清單的增刪改查操作
/// - 與後端 API 同步播放清單資料
/// - 支援「我的最愛」等特殊播放清單功能
///
/// 資料結構：
/// - 使用 Map<String, List<Map<String, dynamic>>> 存儲
/// - Key: 播放清單名稱
/// - Value: 該播放清單包含的歌曲列表
class MyPlaylistProvider with ChangeNotifier {
  // 播放清單存儲容器
  // 結構：{ "播放清單名稱": [歌曲1, 歌曲2, ...], ... }
  final Map<String, List<Map<String, dynamic>>> _playlists = {};
  late Set<String> _currentSelected = {};


  // === Getter 方法 ===

  /// 獲取所有播放清單的只讀訪問
  Map<String, List<Map<String, dynamic>>> get playlists => _playlists;
  Set<String> get currentSelected => _currentSelected;

  // === 網路同步方法 ===

  /// 從後端資料庫獲取並設定播放清單
  ///
  /// API 流程：
  /// 1. 發送 GET 請求到後端 PHP 接口
  /// 2. 解析 JSON 回應獲取播放清單名稱列表
  /// 3. 清空本地資料並重建播放清單結構
  /// 4. 通知 UI 更新
  ///
  /// 錯誤處理：
  /// - HTTP 錯誤：記錄狀態碼
  /// - 網路錯誤：記錄異常資訊
  /// - 不會中斷 App 運行，僅輸出錯誤日誌
  Future<void> fetchAndSetPlaylists() async {
    // 構建 API 請求 URL
    final url = Uri.parse('http://172.20.10.3/Flutter_API/get_playlist.php');

    try {
      // 發送 HTTP GET 請求
      final response = await http.get(url);

      // 檢查 HTTP 狀態碼
      if (response.statusCode == 200) {
        // 解析 JSON 回應
        final decodedData = json.decode(response.body);

        // 驗證 API 回應格式和狀態
        if (decodedData['status'] == 'success' && decodedData['data'] != null) {
          final List<dynamic> playlistNames = decodedData['data'];
          print(playlistNames); // 調試：輸出獲取到的播放清單名稱

          // 清空現有播放清單，以資料庫資料為準
          _playlists.clear();

          // 重建播放清單結構
          for (var name in playlistNames) {
            // 為每個播放清單名稱建立空的歌曲列表
            _playlists[name.toString()] = []; //{歌單1: [], 歌單2: [], 歌單3: [], 歌單4: [], 歌單5: []}
          }

          print("成功從資料庫獲取播放清單: $_playlists");

          // 關鍵：通知所有監聽的 UI 組件進行更新
          notifyListeners();
        }
      } else {
        // 處理 HTTP 錯誤狀態碼
        print('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      // 處理網路連接錯誤或其他異常
      print('獲取播放清單失敗: $error');
    }
  }

  // === 播放清單管理方法 ===

  /// 建立新的空播放清單
  ///
  /// @param name 播放清單名稱
  ///
  /// 驗證邏輯：
  /// - 名稱不能為空（去除首尾空白後）
  /// - 名稱不能與現有播放清單重複
  /// - 驗證失敗時輸出錯誤訊息並返回
  void createPlaylist(String name) {
    print(name); // 調試：輸出要建立的播放清單名稱

    // 輸入驗證：檢查名稱是否有效
    if (name
        .trim()
        .isEmpty || _playlists.containsKey(name.trim())) {
      // 名稱無效或已存在，輸出錯誤訊息
      // 未來可以改為顯示用戶友好的錯誤對話框
      print("播放清單名稱無效或已存在");
      return;
    }

    // 建立新播放清單（初始為空列表）
    _playlists[name.trim()] = [];
    print("已創建播放清單: $name");

    // 通知 UI 更新播放清單列表顯示
    notifyListeners();
  }

  // === 播放清單編輯方法 ===

  /// 刪除指定的播放清單
  ///
  /// @param name 要刪除的播放清單名稱
  ///
  /// 安全考量：
  /// - 可以添加保護邏輯，防止刪除重要的預設播放清單
  /// - 例如：不允許刪除「我的最愛」或最後一個播放清單
  void deletePlaylist(String name) {
    // 執行刪除操作
    _playlists.remove(name);
    print("已刪除播放清單: $name");

    // 通知 UI 更新播放清單列表
    notifyListeners();
  }

  /// 重新命名播放清單
  ///
  /// @param oldName 原播放清單名稱
  /// @param newName 新播放清單名稱
  ///
  /// 驗證邏輯：
  /// 1. 新名稱不能為空
  /// 2. 新舊名稱不能相同
  /// 3. 新名稱不能與其他播放清單重複
  /// 4. 原播放清單必須存在
  ///
  /// 實作策略：
  /// - 重建整個 Map 以保持正確的順序
  /// - 避免直接修改 Map 的 key（Dart 不支援）
  void renamePlaylist(String oldName, String newName) async{
    final trimmedNewName = newName.trim();

    // 步驟1-3: 驗證新名稱的有效性
    if (trimmedNewName.isEmpty || oldName == trimmedNewName ||
        _playlists.containsKey(trimmedNewName)) {
      print("無法重新命名：名稱無效或已存在");
      return;
    }

    // 步驟4: 驗證原播放清單是否存在
    if (!_playlists.containsKey(oldName)) {
      print("無法重新命名：找不到原始播放清單");
      return;
    }

    // 重建策略：建立新的 Map 並保持原有順序
    final Map<String, List<Map<String, dynamic>>> newPlaylists = {};

    // 遍歷原 Map，重建時替換目標 key
    _playlists.forEach((key, value) {
      if (key == oldName) {
        // 找到目標播放清單 → 使用新名稱作為 key
        newPlaylists[trimmedNewName] = value;
      } else {
        // 其他播放清單 → 保持原樣
        newPlaylists[key] = value;
      }
    });

    // 用重建的 Map 替換原有資料
    _playlists.clear();
    _playlists.addAll(newPlaylists);

    notifyListeners();

    final String baseUrl = 'http://172.20.10.3/Flutter_API'; //實機測試
    Future<void> renameSqlPlaylist(String oldName, String newName) async { // 把歌曲所存進的歌單名稱改掉(sql裡的) //songs_in_list
      final url = Uri.parse("$baseUrl/renamesqlplaylist.php");

      var response = await http.post(url, body: {
        'oldPlaylistName': oldName,
        'newPlaylistName': newName
      });

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print(data);
      }
    }
    await renameSqlPlaylist(oldName, newName);
  }

  // 更新資料庫的歌單裡的歌曲數目
  final String baseUrl = 'http://172.20.10.3/Flutter_API'; //實機測試
  Map<String, int> _songNumMap = {}; //前面有 _ → 表示私有，只能在這個 class 裡用
  Map<String, int> get songNumMap => _songNumMap; //建立一個 getter，外部可以用 myProvider.songNumMap 讀取這個 Map。
  Future<Map<String, int>> updateSongsNum() async {
    final url = Uri.parse("$baseUrl/updatesongsnum.php");

    var response = await http.get(url);
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      // print(data); //[{title: 歌單1, songs_num: 0}, {title: 歌單2, songs_num: 1}, {title: 歌單3, songs_num: 1}, {title: 歌單4, songs_num: 1}, {title: 歌單5, songs_num: 0}]
      Map<String, int> songsMap = {
        for (var item in data) item['title']: item['songs_num'] as int //{歌單1: 3首, 歌單2: 1, 歌單3: 1, 歌單4: 1, 歌單5: 0}
      };
      // print(data);
      _songNumMap = songsMap;
      return _songNumMap; //到這裡 _songNumMap 的值財卻時被改變 因為他是用getter
    }
    notifyListeners();
    // 如果 data 是空的，也回傳一個空 Map
    return {};
  }
  // 更新add狀態
  bool _add = false;
  bool get addState => _add;
  Future<bool> updateAddState(String title, {bool isNetWork = false}) async { //{bool isNetWork = false} 預設false寫法
    if (isNetWork) {
      // 如果 true 就走資料庫更新
      final url = Uri.parse("$baseUrl/updateaddstate.php");
      var response = await http.post(url, body: {'title': title});
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        _add = data; // 確保不為空
      } else {
        _add = false;
      }
    } else {
      _add = _currentSelected.isNotEmpty;
      // _add = _playlists.values.any(
      //       (songs) => songs.any((song) => song['title'] == title),
      // );
      // print(_playlists.values);
    }
    notifyListeners();
    return _add;
  }

  void currentAddState(Set<String> current) {
    _currentSelected = current;
  }

  Future<List<dynamic>?> fetchSongList() async { //php那邊會回傳List
    final url = Uri.parse("$baseUrl/fetch_songlist.php");

    var response = await http.get(url);
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data;
    }
  }
  //將歌曲添加到指定播放清單
  Future<void> addSongToPlaylist(String playlistName, Map<String, dynamic> song, bool isSelected) async {
    // song有 => id, title, artist, file_url, cover_url, duration, upload_time, image_small, image_medium, music_cache
    // music_cache直接存音樂檔案(file_url)在伺服器
    if (!_playlists.containsKey(playlistName)) {
      _playlists[playlistName] = []; // 如果歌單不存在，先建立
    }
    _playlists[playlistName]!.add(song); // 不管新舊歌單，都要加歌    updateAddState(song['title'], isNetWork : false);
    updateAddState(song['title'], isNetWork : false);
    // notifyListeners();
    // 先快取 image_medium
    File file = await DefaultCacheManager().getSingleFile(song['image_medium']);
    song['image_cache'] = file.path;
    await songListOperateAndDetail(playlistName, song['title'], song['artist'], song['file_url'], song['music_cache'], song['image_small'], song['image_medium'], song['image_cache'], song['dominant_color'], song['duration'], isSelected);
    await updateSongsNum();
    // await fetchSongDetail(playlistName);
    notifyListeners();
  }

  //從播放清單移除歌曲
  Future<void> removeSongFromPlaylist(String playlistName, Map<String, dynamic> song, bool isSelected) async {

    if (_playlists.containsKey(playlistName)) {
      //(s) => s['music_cache'] == song['music_cache'] 的意思是：
      //找出歌單裡所有 music_cache 欄位與傳入 song 相同的歌曲，然後刪除它。
      _playlists[playlistName]!
          .removeWhere((s) => s['title'] == song['title']);
    }
    updateAddState(song['title'], isNetWork : false);
    // notifyListeners();
    File file = await DefaultCacheManager().getSingleFile(song['image_medium']);
    song['image_cache'] = file.path;
    await songListOperateAndDetail(playlistName, song['title'], song['artist'], song['file_url'], song['music_cache'], song['image_small'], song['image_medium'], song['image_cache'], song['dominant_color'], song['duration'], isSelected);
    await updateSongsNum();
    // await fetchSongDetail(playlistName);
    notifyListeners();
  }
  Future<void> songListOperateAndDetail(String playlistName, String title, String artist, String file_url, String music_cache, String cover_url, String image_medium, String image_cache, Color color, int duration, bool isSelected) async {
    final url = Uri.parse("$baseUrl/songs_to_list_operate.php");

    var response = await http.post(url, body: {
      'playlistName': playlistName,
      'title': title,
      'artist': artist,
      'file_url': file_url,
      'music_cache': music_cache,
      'image_small': cover_url,
      'image_medium': image_medium,
      'image_cache': image_cache,
      'dominant_color': color.value.toString(),
      'duration': duration.toString(),
      'isSelected': isSelected ? '1' : '0', // 把布林轉字串
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print(data['message']);
    }
  }
  // 更新歌單裡歌曲當前狀態(數量)
  List<dynamic> _songsDetail = [];
  List<dynamic> get songsDetail => _songsDetail;
  Future<List<dynamic>?> fetchSongDetail(String playlistName) async {
    final url = Uri.parse("$baseUrl/fetch_songdetail.php");

    var response = await http.post(url, body: {
      'playlistName': playlistName,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      _songsDetail = data;
      notifyListeners();
      return data;
    }

    return [];
  }
}

