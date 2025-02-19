import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart'; // Используем пакет для воспроизведения аудио

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordPress Tabs',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TabbedInterface(),
    );
  }
}

class TabbedInterface extends StatefulWidget {
  @override
  _TabbedInterfaceState createState() => _TabbedInterfaceState();
}

class _TabbedInterfaceState extends State<TabbedInterface>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WordPress Categories'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              } else if (value == 'contacts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ContactsScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Настройки'),
              ),
              const PopupMenuItem<String>(
                value: 'contacts',
                child: Text('Контакты'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Аудио'),
            Tab(text: 'Видео'),
            Tab(text: 'Книги'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategoryPosts(categoryId: 5, categoryName: 'Аудио'), // ID категории Аудио
          CategoryPosts(categoryId: 6, categoryName: 'Видео'), // ID категории Видео
          CategoryPosts(categoryId: 3, categoryName: 'Книги'), // ID категории Книги
        ],
      ),
    );
  }
}

class CategoryPosts extends StatelessWidget {
  final int categoryId;
  final String categoryName;

  const CategoryPosts({required this.categoryId, required this.categoryName});

  Future<List<dynamic>> fetchPosts(int categoryId) async {
    final response = await http.get(Uri.parse(
        'https://umapalata.ru/wp-json/wp/v2/posts?categories=$categoryId'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Future<String?> getFeaturedImageUrl(int mediaId) async {
    if (mediaId == 0) return null;

    final response = await http.get(Uri.parse(
        'https://umapalata.ru/wp-json/wp/v2/media/$mediaId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['source_url'] ?? data['guid']['rendered'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchPosts(categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No posts available in $categoryName'));
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final post = snapshot.data![index];
              final featuredMediaId = post['featured_media'];

              return Card(
                margin: EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () async {
                    try {
                      if (post['featured_media'] == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Нет изображения для этого поста')),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailScreen(post: post),
                        ),
                      );
                    } catch (e) {
                      print('Error opening post detail: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка при открытии деталей поста')),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Изображение
                      if (featuredMediaId != 0)
                        FutureBuilder<String?>(
                          future: getFeaturedImageUrl(featuredMediaId),
                          builder: (context, imageSnapshot) {
                            if (imageSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                              );
                            } else if (imageSnapshot.hasData &&
                                imageSnapshot.data != null) {
                              return Image.network(
                                imageSnapshot.data!,
                                height: 200,
                                fit: BoxFit.cover,
                              );
                            } else {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                              );
                            }
                          },
                        ),
                      // Заголовок поста
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          post['title']['rendered'],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final dynamic post;

  const PostDetailScreen({required this.post});

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void playAudio(String audioUrl) async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(audioUrl));
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final content = post['content']['rendered'];
    final audioUrl = _extractAudioUrl(content);

    return Scaffold(
      appBar: AppBar(
        title: Text(post['title']['rendered']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            FutureBuilder<String?>(
              future: getFeaturedImageUrl(post['featured_media']),
              builder: (context, imageSnapshot) {
                if (imageSnapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                  );
                } else if (imageSnapshot.hasData && imageSnapshot.data != null) {
                  return Image.network(
                    imageSnapshot.data!,
                    height: 200,
                    fit: BoxFit.cover,
                  );
                } else {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                  );
                }
              },
            ),
            SizedBox(height: 16),
            // Заголовок поста
            Text(
              post['title']['rendered'],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Управление аудио
            if (audioUrl != null)
              ElevatedButton(
                onPressed: () => playAudio(audioUrl),
                child: Text(isPlaying ? 'Pause' : 'Play'),
              ),
          ],
        ),
      ),
    );
  }

  String? _extractAudioUrl(String content) {
    final regex = RegExp(r'https?://[^\s<>"]+\.mp3'); // Ищем только ссылки на MP3
    final match = regex.firstMatch(content);
    return match?.group(0);
  }

  Future<String?> getFeaturedImageUrl(int mediaId) async {
    if (mediaId == 0) return null;

    final response = await http.get(Uri.parse(
        'https://umapalata.ru/wp-json/wp/v2/media/$mediaId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['source_url'] ?? data['guid']['rendered'];
    }
    return null;
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки'),
      ),
      body: Center(
        child: Text(
          'Экран настроек',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Контакты'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Свяжитесь с нами:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _launchURL('https://t.me/your_telegram_channel'),
              icon: Icon(Icons.chat),
              label: Text('Telegram-канал'),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _launchURL('https://www.youtube.com/your_youtube_channel'),
              icon: Icon(Icons.video_library),
              label: Text('YouTube-канал'),
            ),
          ],
        ),
      ),
    );
  }
}
