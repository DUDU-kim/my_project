import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_project/provider.dart';

import 'music_visualizer.dart';
import 'package:audioplayers/audioplayers.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final String playlistName;

  PlaylistDetailsPage({super.key, required this.playlistName});

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPage();
}

class _PlaylistDetailsPage extends State<PlaylistDetailsPage> {
  List<dynamic>? detail;


  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.playlistName, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Consumer2<MyPlaylistProvider, SelectedAlbumProvider>(
        builder: (context, myPlaylistProvider, selectedProvider, child) {
          detail = myPlaylistProvider.songsDetail;

          // 根據播放清單名稱，獲取對應的歌曲列表
          // print(fetchSongDetail);
          // --- 處理歌單為空的情況 ---
          if (detail!.isEmpty) {
            return Center(
              child: Text(
                '這個播放清單還沒有歌曲',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // --- 歌單不為空時，顯示歌曲列表 ---
          return ListView.builder(
            itemCount: detail?.length,
            itemBuilder: (context, index) {
              var song = detail?[index];

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

              final String? currentlyPlayingId = selectedProvider.selectedAlbumFileUrl; // 2.再用這個去看有沒有跟(song相同的file_url),有就變色
              final bool isSelected = currentlyPlayingId == song["file_url"];

              // 從 Provider 獲取全局的播放狀態
              final PlayerState currentPlayerState = selectedProvider.playerState;
              // 判斷是否【正在播放】(選中 且 狀態為 playing)
              final bool isActuallyPlaying = isSelected && (currentPlayerState == PlayerState.playing);

              return Stack(
                alignment: Alignment.centerRight,
                children: [
                  ListTile(
                    leading:ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: image_small != null
                          ? Image.network(image_small, width: 50, height: 50, fit: BoxFit.cover)
                          : Container(
                        width: 40,
                        height: 40,
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
                      final album = { // 可以直接 newAlbum: song 即可, 但若有額外加一些東西就可以這樣寫
                        'songs_list': songs_list,
                        'id': id,
                        "title": title,
                        "artist": artist,
                        "file_url": file_url,
                        'music_cache': music_cache,
                        "cover_url": image_small,
                        "image_small": image_small,
                        "image_medium": image_medium,
                        'dominant_color': dominantColor,
                        'duration': duration,
                      };
                      // 抓addState
                      myPlaylistProvider.updateAddState(title, isNetWork: true);

                      // 傳整個歌單的歌的所有資料給 Provider，確保下一首/上一首能用
                      selectedProvider.selectAlbum(isRepeat: false, newAlbum: album, newPlaylist: detail!.cast<Map<String, dynamic>>());
                      unawaited(selectedProvider.prefetchImage(context));
                      // selectedProvider.prefetchImage(context); //必要!, 讓第一首被點到的歌馬上載入上下首
                      selectedProvider.getPlayList(widget.playlistName);
                    },
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(Icons.more_horiz, color: Colors.grey),
                      color: Colors.grey[800],
                      onSelected: (String value) async {
                        if (value == 'delete') {
                          final myProvider = Provider.of<MyPlaylistProvider>(context, listen: false); // 在detail!.removeAt(index)執行前先抓出provider, 以免刪除最後一個時,
                          // UI介面沒東西(歌)了, 導致await不到東西

                          // 先從本地列表移除 UI
                          setState(() {
                            detail!.removeAt(index);
                          });
                          // 前頁從資料庫撈出來的color是TEXT, 要再轉回color,再塞入removeSongFromPlaylist
                          String colorString = song['dominant_color'];
                          Color color = Color(int.parse(colorString));
                          song['dominant_color'] = color;

                          // 再更新 Provider 與資料庫
                          await myProvider.removeSongFromPlaylist(
                              song['songs_list'], song, false);
                          myProvider.updateAddState(song['title'], isNetWork : true);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'delete',
                          height: 36,
                          child: Text('移除', style: TextStyle(color: Colors.red)),
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
    );
  }
}
