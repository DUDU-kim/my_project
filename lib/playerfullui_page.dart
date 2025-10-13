import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async'; // 導入 Timer 所需的套件
import 'package:my_project/provider.dart';
import 'package:provider/provider.dart';

import 'music_visualizer.dart';

//buttomNavigator打開後UI
// 完整播放器 UI（直接用原本的 body 內容）
class PlayerFullUI extends StatefulWidget {
  final String audioUrl;
  final AudioPlayer audioPlayer;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<PlayerState> playerStateNotifier;
  final Color dominantColor;


  const PlayerFullUI({super.key, required this.audioUrl, required this.audioPlayer, required this.dominantColor,
    required this.durationNotifier, required this.positionNotifier, required this.playerStateNotifier});

  @override
  State<PlayerFullUI> createState() => _PlayerFullUI();
}
class _PlayerFullUI extends State<PlayerFullUI> {
  bool add = false;
  bool playControl = false;
  bool rightMode = false;
  int currentMode = 0; // 0 = 順序播放, 1 = 單曲循環, 2 = 隨機播放
  // --- 新增計時器變數 ---
  Timer? _fastForwardTimer;
  Timer? _rewindTimer;
  Set<String> _selectedFavorites = {}; // 存被選中的清單名稱
  Set<String> _tmpselectedFavorites = {}; // 存原被選中但後來要刪掉的清單名稱
  bool? _isSelected;
  bool flag = true;

  // playOrPause 保持不變，直接操作 widget.audioPlayer
  void playOrPause() {
    if (widget.audioPlayer.state == PlayerState.playing) {
      widget.audioPlayer.pause();
    } else {
      widget.audioPlayer.resume();
    }
    // 不再需要 setState((){})，因為 ValueListenableBuilder 會自動更新
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // --- 新增 dispose 方法來釋放計時器 ---
  @override
  void dispose() {
    _fastForwardTimer?.cancel();
    _rewindTimer?.cancel();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法的開頭先取得螢幕寬度
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    // print("--- 畫面刷新 ---");
    // print("螢幕寬度 (screenWidth): $screenWidth");
    // print("螢幕高度 (screenHeight): $screenHeight");
    return Consumer2<SelectedAlbumProvider, MyPlaylistProvider>(
        builder: (context, albumProvider, myPlaylistProvider, child) {
          add = myPlaylistProvider.addState;
          final bool isShuffleOn = albumProvider.isShuffleMode;

          final String cacheKey = "${albumProvider.currentPlaylistName}_${albumProvider.currentIndex}"; // 生成唯一的緩存圖片key
          final ImageProvider? preFetch = albumProvider.prefetch?[cacheKey];
          final String? imageMedium = albumProvider.selectedAlbum?['image_medium'];
          final String? colorString = albumProvider.selectedAlbum?['dominant_color'];
          final Color bgColor = (colorString != null && colorString.isNotEmpty)
              ? Color(int.parse(colorString))
              : widget.dominantColor;
          final title = albumProvider.selectedAlbum?['title'];
          final artist = albumProvider.selectedAlbum?['artist'];

          return Scaffold(
            backgroundColor: bgColor.withOpacity(0.6),
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: screenHeight * 0.04,
                    left: screenWidth * 0.03,
                    child: IconButton(
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 40),
                      onPressed: () async {
                        if (albumProvider.selectedAlbum!['songs_list'] != albumProvider.isVisible!) {
                          unawaited(myPlaylistProvider.fetchSongDetail(albumProvider.isVisible!));
                        } else {
                          unawaited(myPlaylistProvider.fetchSongDetail(albumProvider.selectedAlbum!['songs_list']));
                        }
                        Navigator.pop(context); // 收起 BottomSheet，縮小回小播放器
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment(0, -0.85), // x=0 是水平中間, y=-0.85 是靠上
                    child: Text(
                      albumProvider.isVisible!,
                      style: TextStyle(
                        fontSize: (screenWidth * 0.03).clamp(12.0, 14.0),
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.05,
                    left: screenWidth * 0.81,
                    child: IconButton(
                      icon: Icon(Icons.view_day_outlined, color: Colors.white, size: 25),
                      onPressed: () async{
                        final albumProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
                        final currentPlaylist = albumProvider.playlist;
                        final currentIndex = albumProvider.currentIndex;

                        if (currentPlaylist.isEmpty || currentIndex == -1) return;


                        final List<Map<String, dynamic>> displaySongs = [];

                        // 1. 決定我們要顯示多少首歌曲 (最多5首，或列表總長度)
                        final int songCountToShow = (currentPlaylist.length < 5) ? currentPlaylist.length : 5;

                        // 2. 從當前歌曲開始，循環取出指定數量的歌曲
                        for (int i = 0; i < songCountToShow; i++) {
                          // 使用取模運算 (%) 來安全地處理列表循環
                          final int songIndex = (currentIndex + i) % currentPlaylist.length;
                          displaySongs.add(currentPlaylist[songIndex]);
                        }

                        showModalBottomSheet(
                          isScrollControlled: true,
                          context: context,
                          builder: (BuildContext modalContext) {
                              return StatefulBuilder(
                                  builder: (context, setModalState) {
                                    return SizedBox(
                                      height: screenHeight * 0.6,
                                      child: Column(
                                        children: [
                                          Container(
                                            color: Colors.grey[900],
                                            child: Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(modalContext);
                                                  },
                                                  child: Text(
                                                    '取消',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: (screenWidth * 0.03).clamp(12.0, 14.0),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: screenWidth * 0.65),
                                                Text(
                                                  '佇列',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: (screenWidth * 0.03).clamp(12.0, 14.0),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Consumer2<MyPlaylistProvider, SelectedAlbumProvider>(
                                              builder: (context, myPlaylistProvider, selectedProvider, child) {

                                                return ListView.builder(
                                                  itemCount: displaySongs.length,
                                                  itemBuilder: (context, index) {

                                                    final song = displaySongs[index];
                                                    // print(song);
                                                    final id = song['id']; // 1.整個歌單的歌曲id
                                                    final songs_list = song['songs_list'];
                                                    final title = song['title'];
                                                    final artist = song['artist'];
                                                    final file_url = song['file_url'];
                                                    final music_cache = song['music_cache']; //music_cache(file_url)
                                                    final image_small = song['image_small']; //image_small(cover_url)
                                                    final image_medium = song['image_medium'];
                                                    final dominantColor = song['dominant_color'];
                                                    final duration = song['duration'];

                                                    String? currentlyPlayingId = selectedProvider.selectedAlbumFileUrl; // 2.再用這個去看有沒有跟(song相同的file_url),有就變色
                                                    bool isSelected = currentlyPlayingId == song["file_url"];

                                                    // 從 Provider 獲取全局的播放狀態
                                                    final PlayerState currentPlayerState = selectedProvider.playerState;
                                                    // 判斷是否【正在播放】(選中 且 狀態為 playing)
                                                    bool isActuallyPlaying = isSelected && (currentPlayerState == PlayerState.playing);

                                                    return Stack(
                                                      alignment: Alignment.centerRight,
                                                      children: [
                                                        ListTile(
                                                          leading:ClipRRect(
                                                            borderRadius: BorderRadius.circular(4.0),
                                                            child: image_small != null
                                                                ? Image.network(image_small, width: 50, height: 50, fit: BoxFit.cover)
                                                                : Container(
                                                              width: 50,
                                                              height: 50,
                                                              color: Colors.grey.shade800,
                                                              child: Icon(Icons.music_note, color: Colors.white70),
                                                            ),
                                                          ),
                                                          title: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              if (isSelected)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(right: 8.0),
                                                                  // 直接创建 MusicVisualizer，它会一直播放动画
                                                                  child: MusicVisualizer(isPlaying: isActuallyPlaying),
                                                                ),
                                                              Expanded(
                                                                  child: Text(
                                                                    title,
                                                                    style: TextStyle(
                                                                      color: currentlyPlayingId == song["file_url"] ? Colors.cyan : Colors.white,
                                                                      fontSize: (screenWidth * 0.03).clamp(15.0, 17.0),
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  )
                                                              )
                                                            ],
                                                          ),
                                                          subtitle: Text(artist, style: TextStyle(color: Colors.grey, fontSize: (screenWidth * 0.03).clamp(12.0, 14.0),)),
                                                          onTap: () {
                                                            final album = {
                                                              "songs_list": songs_list,
                                                              "id": id,
                                                              "title": title,
                                                              "artist": artist,
                                                              "file_url": file_url,
                                                              "music_cache": music_cache,
                                                              "cover_url": image_small,
                                                              "image_small": image_small,
                                                              "image_medium": image_medium,
                                                              'dominant_color': dominantColor,
                                                              "duration": duration,
                                                            };
                                                            selectedProvider.selectAlbum(isRepeat: false, newAlbum: album);
                                                            unawaited(selectedProvider.prefetchImage(context));
                                                          },
                                                        ),
                                                        Positioned(
                                                          right: 0,
                                                          top: 0,
                                                          bottom: 0,
                                                          child: Stack(
                                                            alignment: Alignment.center,
                                                            children: [
                                                              // 外框圈圈
                                                              if (isSelected)
                                                                Container(
                                                                  width: 45, // 比 iconSize 稍大一點
                                                                  height: 45,
                                                                  decoration: BoxDecoration(
                                                                    shape: BoxShape.circle,
                                                                    border: Border.all(color: Colors.cyan, width: 2),
                                                                  ),
                                                                ),
                                                              // 按鈕
                                                              IconButton(
                                                                onPressed: isSelected ? playOrPause : () {}, // do-nothing
                                                                icon: Icon(
                                                                  isActuallyPlaying ? Icons.pause : Icons.play_arrow,
                                                                  color: Colors.white,
                                                                ),
                                                                iconSize: 40,
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
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                              );
                           }
                        );
                      },
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.15),
                      //歌曲信息
                      Container(
                        width: screenWidth * 0.86,
                        height: screenHeight * 0.45,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(screenWidth * 0.001), // 內邊距也使用比例(音符圖片大小)
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10), // 圓角也可以稍微調整
                          // 我們不再需要指定 Image 的尺寸，因為它會被外層的 Container 限制住
                          child: () {
                            print(preFetch);
                            if (preFetch != null) {
                              // 直接用快取的本地檔案(切歌時的圖片直接從本地取)
                              print("1");
                              return Image(
                                image: preFetch,
                                fit: BoxFit.cover,
                              );
                            } else if (imageMedium != null && imageMedium.isNotEmpty) {
                              print("2");
                              // 沒有快取就用網路圖片
                              return Image.network(
                                imageMedium,
                                fit: BoxFit.cover,
                              );
                            } else {
                              // 都沒有 → 放預設圖
                              return Container(
                                color: Colors.grey.shade800,
                                child: Icon(Icons.music_note, color: Colors.white70),
                              );
                            }
                          }(),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.06), // 間距也使用螢幕高度的比例
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06), // 用對稱的 padding 取代單邊
                        child: Row(
                          children: [
                            SizedBox(width: screenWidth * 0.001),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontSize: (screenWidth * 0.03).clamp(16.0, 18.0), fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 1),
                                Text(artist, style: TextStyle(fontSize: (screenWidth * 0.03).clamp(12.0, 14.0), color: Colors.white70)),
                              ],
                            ),
                            // Spacer(), // 使用 Spacer 自動填滿中間的所有空間, 插入一個「可伸縮的空白區域」
                            const Spacer(),
                            IconButton(
                              padding: EdgeInsets.zero, // 移除内边距
                              constraints: const BoxConstraints(), // 移除最小尺寸约束
                              icon: Icon(
                                add ? Icons.check_circle : Icons.add_circle_outline,
                                size: screenWidth * 0.08,
                              ),
                              color: add ? Colors.cyan : Colors.white,
                              onPressed: () async{
                                final myPlaylistProvider = Provider.of<MyPlaylistProvider>(context, listen: false);
                                // 打開 modal 前，先抓一次資料庫
                                final fetchsonglist = await myPlaylistProvider.fetchSongList();
                                _selectedFavorites.clear(); // 每次打開先清空，避免殘留
                                if (fetchsonglist != null && fetchsonglist.isNotEmpty) {
                                  for (var song in fetchsonglist) {
                                    if ((title == song['title']) && (artist == song['artist'])) { // (小撥放器前)選的歌曲的title == (全螢幕)加入清單的歌曲的title 才要勾
                                      _selectedFavorites.add(song['songs_list']); // 直接把資料庫回傳的清單加進已選
                                    }
                                  }
                                  flag = false;
                                }

                                showModalBottomSheet(
                                  isScrollControlled: true,
                                  context: context,
                                  builder: (BuildContext modalContext) { // 注意改名為 modalContext
                                    return StatefulBuilder(
                                      builder: (context, setModalState) {
                                        return SizedBox(
                                          height: screenHeight * 0.6,
                                          child: Column(
                                            children: [
                                              Container(
                                                color: Colors.grey[900],
                                                child: Row(
                                                  children: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(modalContext);
                                                      },
                                                      child: Text(
                                                        '取消',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: (screenWidth * 0.03).clamp(10.0, 12.0),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: screenWidth * 0.12),
                                                    Text(
                                                      '新增至撥放清單',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: (screenWidth * 0.03).clamp(13.0, 15.0),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Consumer2<MyPlaylistProvider, SelectedAlbumProvider>(
                                                  builder: (context, myPlaylistProvider, selectedProvider, child) {
                                                    final selectedAlbum = selectedProvider.selectedAlbum;
                                                    final playlists = myPlaylistProvider.playlists.keys.toList(); // [歌單1, 歌單2, 歌單3, 歌單4, 歌單5]
                                                    final songnum = myPlaylistProvider.songNumMap;

                                                    return ListView.builder(
                                                      itemCount: playlists.length,
                                                      itemBuilder: (context, index) {
                                                        String playlistName = playlists[index]; // 把每個ListTile的index內容都印出來 周杰倫、郭靜、嚴藝丹、李聖傑、BY2 [都是String]
                                                        return Stack(
                                                          alignment: Alignment.centerRight,
                                                          children: [
                                                            ListTile(
                                                              leading: Icon(Icons.queue_music, color: Colors.grey),
                                                              title: Text(
                                                                playlistName,
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: (screenWidth * 0.03).clamp(13.0, 15.0),
                                                                ),
                                                              ),
                                                              subtitle: Text(
                                                                '${songnum[playlistName] ?? 0} 首歌曲', // 實際歌曲數量
                                                                style: TextStyle(
                                                                  color: Colors.white70,
                                                                  fontSize: (screenWidth * 0.03).clamp(10.0, 12.0),
                                                                ),
                                                              ),
                                                            ),
                                                            Positioned(
                                                              right: 0,
                                                              top: 0,
                                                              bottom: 0,
                                                              child: IconButton(
                                                                icon: _selectedFavorites.contains(playlistName)
                                                                    ? Icon(Icons.check_circle, color: Colors.cyan)
                                                                    : Icon(Icons.circle_outlined, color: Colors.white),
                                                                onPressed: () async {
                                                                  if (selectedAlbum == null) return; // 沒有選中的歌曲就不操作

                                                                  setModalState(() {
                                                                    if (_selectedFavorites.contains(playlistName)) {
                                                                      _tmpselectedFavorites.add(playlistName);
                                                                      _selectedFavorites.remove(playlistName); // 如果已選 → 取消選取
                                                                      _isSelected = false;
                                                                      flag = true;
                                                                      // _selectedFavorites.remove(playlistName); //return false
                                                                      print("remove");
                                                                    } else {
                                                                      _tmpselectedFavorites.clear();
                                                                      _selectedFavorites.add(playlistName); // 如果未選 → 加入選取
                                                                      _isSelected = true;
                                                                      flag = true;
                                                                      // _selectedFavorites.add(playlistName); //return false
                                                                      print("add");
                                                                    }
                                                                  });

                                                                  // print 調試
                                                                  print('當前選中的清單: $_selectedFavorites');
                                                                  myPlaylistProvider.currentAddState(_selectedFavorites);
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.cyan,
                                                  splashFactory: NoSplash.splashFactory, // 取消水波紋
                                                ),
                                                //回傳bool值到資料庫
                                                onPressed: () {
                                                  final myPlaylistProvider = Provider.of<MyPlaylistProvider>(context, listen: false); // [周杰倫, 郭靜, 嚴藝丹, 李聖傑, BY2]
                                                  final selectedProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
                                                  if (flag == true) {
                                                    setModalState(() {
                                                      if (_isSelected == true) {
                                                        for (var playlistName in _selectedFavorites) { //遍歷剛剛所選到的所有歌單
                                                          // 複製一份 map，避免直接修改參考
                                                          final updatedAlbum = Map<String, dynamic>.from(selectedProvider.selectedAlbum!);

                                                          // 加一個新的 key/value
                                                          if (playControl) { // 有點擊上一首/下一首按扭, 不更新會導致上/下一首的color是上/下一首的
                                                            Color colorString = Color(int.parse(albumProvider.selectedAlbum!['dominant_color'])); // String -> Color
                                                            updatedAlbum['dominant_color'] = colorString;
                                                          } else {
                                                            updatedAlbum['dominant_color'] = widget.dominantColor; // 或任何值
                                                          }

                                                          // 更新回 provider
                                                          selectedProvider.selectAlbum(newAlbum: updatedAlbum);
                                                          myPlaylistProvider.addSongToPlaylist(playlistName, updatedAlbum, _isSelected!); // 用當前選中的歌曲
                                                        }
                                                      }
                                                      else {
                                                        for (var playlistName in _tmpselectedFavorites) {
                                                          // 複製一份 map，避免直接修改參考
                                                          final updatedAlbum = Map<String, dynamic>.from(selectedProvider.selectedAlbum!);

                                                          // 加一個新的 key/value
                                                          if (playControl) { // 有點擊上一首/下一首按扭
                                                            Color colorString = Color(int.parse(albumProvider.selectedAlbum!['dominant_color']));
                                                            updatedAlbum['dominant_color'] = colorString;
                                                          } else {
                                                            updatedAlbum['dominant_color'] = widget.dominantColor; // 或任何值
                                                          }

                                                          // 更新回 provider
                                                          selectedProvider.selectAlbum(newAlbum: updatedAlbum);
                                                          myPlaylistProvider.removeSongFromPlaylist(playlistName, updatedAlbum, _isSelected!); // 用當前選中的歌曲
                                                        }
                                                      }
                                                    });
                                                    add = myPlaylistProvider.addState;
                                                    Navigator.pop(modalContext);
                                                  }
                                                  else {
                                                    add = myPlaylistProvider.addState;
                                                    Navigator.pop(modalContext);
                                                  }
                                                },
                                                child: Text(
                                                  '完成',
                                                  style: TextStyle(color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03), // 間距也使用螢幕高度的比例
                      //音樂控制
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.053),
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: widget.positionNotifier,
                          builder: (context, position, child) {
                            final duration = widget.durationNotifier.value;
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: screenWidth * 0.015),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: screenWidth * 0.01),
                              ),
                              child: Slider(
                                onChanged: (value) async {
                                  await widget.audioPlayer.seek(Duration(seconds: value.toInt()));
                                },
                                // 使用 Math.min 確保 value 不會超過 duration
                                value: min(position.inSeconds.toDouble(), duration.inSeconds.toDouble()).clamp(0.0, duration.inSeconds.toDouble()),
                                min: 0,
                                // 如果 duration 的秒數大於 0，就使用它，否則先暫時用 1.0 作為最大值
                                max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                                inactiveColor: Colors.grey,
                                activeColor: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01), // 間距也使用螢幕高度的比例
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
                        child: Row(
                          children: [
                            ValueListenableBuilder<Duration>(
                              valueListenable: widget.positionNotifier,
                              builder: (context, position, child) {
                                final duration = widget.durationNotifier.value;
                                final displayPosition = position > duration ? duration : position;
                                return Text(
                                    formatDuration(displayPosition),
                                    style: TextStyle(fontSize: (screenWidth * 0.08).clamp(10.0, 13.0), color: Colors.white)
                                );
                              },
                            ),
                            Spacer(),
                            ValueListenableBuilder<Duration>(
                              valueListenable: widget.durationNotifier,
                              builder: (context, duration, child) {
                                return Text(
                                    formatDuration(duration),
                                    style: TextStyle(fontSize: (screenWidth * 0.08).clamp(10.0, 13.0), color: Colors.white)
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05), // 間距也使用螢幕高度的比例
                      //音樂控制按鈕
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01), // 用對稱的 padding 取代單邊,
                        child: Row(
                          // spaceAround: 每個元件左右兩側的空間相等。
                          // spaceEvenly: 每個元件之間的間距完全相等。
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                final albumProvider = Provider.of<SelectedAlbumProvider>(context, listen: false);
                                albumProvider.toggleShuffle(null, context); // 傳入 null 表示切換狀態
                              },
                              icon: Icon(Icons.shuffle),
                              color: isShuffleOn ? Colors.cyan : Colors.white,
                              iconSize: 30,
                            ),
                            // --- 倒退/上一首按鈕 (使用 GestureDetector) ---
                            GestureDetector(
                              // 單擊事件：播放上一首
                              onTap: () {
                                //非隨機模式
                                albumProvider.playPrevious(); // 一定要在前,先改變currentindex的值
                                unawaited(albumProvider.prefetchImage(context));
                                setState(() {
                                  playControl = true;
                                });
                                //隨機模式(上一首也是隨機,不是按歌單順序)
                              },
                              // 長按開始事件
                              onLongPressStart: (_) {
                                // 啟動一個週期性計時器，可以調整觸發頻率
                                _rewindTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
                                  final currentPosition = widget.positionNotifier.value;
                                  final newPosition = currentPosition - const Duration(seconds: 10); // 每次倒退 10 秒

                                  // 確保倒退後的位置不會是負數
                                  if (!newPosition.isNegative) {
                                    widget.audioPlayer.seek(newPosition);
                                  } else {
                                    // 如果倒退會超過開頭，就直接跳到開頭並停止計時器
                                    widget.audioPlayer.seek(Duration.zero);
                                    _rewindTimer?.cancel();
                                  }
                                });
                              },
                              // 長按結束事件 (手指抬起)
                              onLongPressEnd: (_) {
                                // 非常重要：取消計時器
                                _rewindTimer?.cancel();
                              },
                              // 長按取消事件 (例如手指在按住時滑出元件範圍)
                              onLongPressCancel: () {
                                _rewindTimer?.cancel();
                              },
                              child: Icon(
                                Icons.skip_previous, // 使用更符合語義的圖示
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            Container( //更新播放/暫停按鈕
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: ValueListenableBuilder<PlayerState>(
                                valueListenable: widget.playerStateNotifier,
                                builder: (context, playerState, child) {
                                  final isPlaying = playerState == PlayerState.playing;
                                  return IconButton(
                                    onPressed: playOrPause,
                                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                                    color: bgColor,
                                    iconSize: 40,
                                  );
                                },
                              ),
                            ),
                            // --- 快轉/下一首按鈕 (使用 GestureDetector) ---
                            GestureDetector(
                              // 單擊事件：播放下一首
                              onTap: () {
                                //非隨機模式
                                albumProvider.playNext(); // 一定要在前,先改變currentindex的值
                                unawaited(albumProvider.prefetchImage(context));
                                setState(() {
                                  playControl = true;
                                });
                                //隨機模式(上一首也是隨機,不是按歌單順序)
                              },
                              // 長按開始事件
                              onLongPressStart: (_) {
                                _fastForwardTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) { // 可以調整觸發頻率
                                  final currentPosition = widget.positionNotifier.value;
                                  final duration = widget.durationNotifier.value;
                                  final newPosition = currentPosition + const Duration(seconds: 10); // 每次快轉 10 秒

                                  // 確保快轉後的位置不會超過總長度
                                  if (newPosition < duration) {
                                    widget.audioPlayer.seek(newPosition);
                                  } else {
                                    // 如果快轉會超過總長度，就直接跳到結尾
                                    widget.audioPlayer.seek(duration);
                                    _fastForwardTimer?.cancel(); // 到達結尾後停止計時器
                                  }
                                });
                              },
                              // 長按結束事件 (手指抬起)
                              onLongPressEnd: (_) {
                                // 非常重要：取消計時器
                                _fastForwardTimer?.cancel();
                              },
                              // 長按取消事件 (例如手指在按住時滑出元件範圍)
                              onLongPressCancel: () {
                                _fastForwardTimer?.cancel();
                              },
                              child: Icon(
                                Icons.skip_next, // 使用更符合語義的圖示
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            IconButton( //切換撥放模式
                              onPressed: () {
                                final preMode = albumProvider.playMode;
                                currentMode = (preMode + 1) % 3; // 循環切換 0→1→2→0
                                print("Mode : $preMode");

                                // 1. 先更新 Provider 中的模式
                                albumProvider.setPlayMode(currentMode);

                                // --- 解決模式0的情況下歌曲播放完畢,再點選模式1時沒反應的問題 ---
                                final currentPlayerState = widget.playerStateNotifier.value; // 取得當下播放狀態
                                final isAtLastSong = albumProvider.currentIndex >= albumProvider.playlist.length - 1;

                                // 檢查是否滿足特定條件：
                                // - 播放器處於「停止」或「完成」狀態
                                // - 並且我們正處於播放列表的最後一首歌
                                // - 並且模式 = 1
                                if ((currentPlayerState == PlayerState.stopped || currentPlayerState == PlayerState.completed) && isAtLastSong && currentMode == 1) {
                                  print("播放器已停止於列表末端，現切換至循環模式，自動播放下一首。");
                                  // 手動觸發播放下一首歌。Provider 中的 playNext() 方法會根據
                                  // 新的循環模式 (mode 1) 自動跳回播放列表的第一首歌。
                                  albumProvider.playNext();
                                }

                                // 根據 playMode 的新值來設定播放器的行為
                                switch (currentMode) {
                                  case 0: // 顺序播放 (不循還)
                                  // 播完就停
                                    widget.audioPlayer.setReleaseMode(ReleaseMode.stop);
                                    print("currentMode : $currentMode");
                                    break;
                                  case 1: // 列表循還
                                  // 同样设置为 ReleaseMode.release。
                                  // 您需要另外的逻辑 (在 AllPage.dart 中) 来处理“播放下一首”。
                                    widget.audioPlayer.setReleaseMode(ReleaseMode.stop);
                                    print("currentMode : $currentMode");
                                    break;
                                  case 2: // 單曲循還
                                    widget.audioPlayer.setReleaseMode(ReleaseMode.loop);
                                    print("currentMode : $currentMode");
                                    break;
                                }
                              },
                              icon: Icon(albumProvider.playMode == 0 ? Icons.repeat : albumProvider.playMode == 1 ? Icons.repeat : Icons.repeat_one),
                              color: albumProvider.playMode == 0 ? Colors.white : albumProvider.playMode == 1 ? Colors.cyan : Colors.cyan,
                              iconSize: 30,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
    });
  }
}