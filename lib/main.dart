import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');
  await Hive.openBox('favorites');
  runApp(const MyApp());
}

/* ---------------- YARDIMCI FONKSİYONLAR ---------------- */

String fixEncoding(String text) {
  return text
      .replaceAll("&#8217;", "'")
      .replaceAll("&#8211;", "-")
      .replaceAll("&#8220;", "\"")
      .replaceAll("&#8221;", "\"")
      .replaceAll("&amp;", "&")
      .replaceAll("&nbsp;", " ")
      .replaceAll(RegExp(r'ngg_shortcode_\d+_placeholder'), '') // image_1771c2.png temizliği
      .trim();
}

/* ---------------- TEMA VE ANA YAPI ---------------- */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, box, widget) {
        final isDark = box.get('isDarkTheme', defaultValue: false);
        final isFirstRun = box.get('isFirstRun', defaultValue: true);

        return MaterialApp(
          title: 'Uluslararası Alevi Vakfı',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.red,
            appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.red),
          home: isFirstRun ? const OnboardingPage() : const MainShell(),
        );
      },
    );
  }
}

/* ---------------- MODERN ONBOARDING ---------------- */

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {"t": "Vakfımıza Hoş Geldiniz", "d": "İnancımızı ve kültürümüzü dijital dünyada birlikte yaşıyoruz.", "i": Icons.auto_awesome},
    {"t": "Duyuru ve Arama", "d": "En güncel haberleri arayın ve favorilerinize ekleyin.", "i": Icons.search},
    {"t": "Etkinlik Takvimi", "d": "Önemli günleri native takvimden takip edin.", "i": Icons.calendar_month},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (v) => setState(() => _currentPage = v),
            itemCount: _steps.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_steps[i]['i'], size: 100, color: Colors.red),
                  const SizedBox(height: 30),
                  Text(_steps[i]['t'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Text(_steps[i]['d'], style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: 20, right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 10, width: _currentPage == index ? 25 : 10,
                    decoration: BoxDecoration(color: _currentPage == index ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(5)),
                  )),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      if (_currentPage < _steps.length - 1) {
                        _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                      } else {
                        Hive.box('settings').put('isFirstRun', false);
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
                      }
                    },
                    child: Text(_currentPage == _steps.length - 1 ? "BAŞLAYALIM" : "İLERLE"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- ANA KABUK (VAKIF WEB TAM ORTADA) ---------------- */

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _pages = [
    const NewsPage(),     // Duyurular
    const FavoritesPage(),// Favoriler
    const WebViewPage(),  // TAM ORTA: Vakıf Web
    const EventsPage(),   // Takvim
    const SettingsPage(), // Ayarlar
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.campaign), label: "Duyurular"),
          NavigationDestination(icon: Icon(Icons.bookmark), label: "Favoriler"),
          NavigationDestination(icon: Icon(Icons.public), label: "Vakıf Web"), // Merkez
          NavigationDestination(icon: Icon(Icons.event), label: "Takvim"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}

/* ---------------- DUYURULAR (İÇERİK KONTROLLÜ) ---------------- */

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<dynamic> allPosts = [];
  List<dynamic> filteredPosts = [];
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();
  final favBox = Hive.box('favorites');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  bool hasContent(String html) {
    String cleanText = html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;|ngg_shortcode_\d+_placeholder'), '').trim();
    return cleanText.isNotEmpty && cleanText.length > 10;
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('https://www.alevi-vakfi.com/wp-json/wp/v2/posts?per_page=20'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        Hive.box('cache').put('news', data);
        if (mounted) setState(() { allPosts = data; filteredPosts = data; loading = false; });
        return;
      }
    } catch (_) {}
    setState(() {
      allPosts = Hive.box('cache').get('news', defaultValue: []);
      filteredPosts = allPosts;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VAKIF DUYURULARI"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => filteredPosts = allPosts.where((p) => fixEncoding(p['title']['rendered']).toLowerCase().contains(v.toLowerCase())).toList()),
              decoration: InputDecoration(
                hintText: "Duyurularda ara...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetch,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: filteredPosts.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, i) {
            final post = filteredPosts[i];
            final bool isFav = favBox.containsKey(post['id']);
            final bool clickable = hasContent(post['content']['rendered']);

            return ListTile(
              leading: CircleAvatar(backgroundColor: Colors.red, child: Icon(clickable ? Icons.article : Icons.info_outline, color: Colors.white)),
              title: Text(fixEncoding(post['title']['rendered']), style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border, color: Colors.red),
                    onPressed: () => setState(() { isFav ? favBox.delete(post['id']) : favBox.put(post['id'], post); }),
                  ),
                  if (clickable) const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
              onTap: clickable ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post))) : null,
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- HABER DETAY (KARAKTER FIX) ---------------- */

class PostDetailPage extends StatefulWidget {
  final dynamic post;
  const PostDetailPage({super.key, required this.post});
  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final favBox = Hive.box('favorites');
  bool get isFav => favBox.containsKey(widget.post['id']);

  @override
  Widget build(BuildContext context) {
    final String title = fixEncoding(widget.post['title']['rendered']);
    final String content = fixEncoding(widget.post['content']['rendered']);

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border), onPressed: () => setState(() { isFav ? favBox.delete(widget.post['id']) : favBox.put(widget.post['id'], widget.post); })),
        IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share("$title\n\n${widget.post['link']}")),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            HtmlWidget(content, textStyle: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/* ---------------- ETKİNLİK TAKVİMİ (KARANLIK MOD FIX) ---------------- */

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  final List<Map<String, String>> events = const [
    {"date": "20 Mart 2026", "title": "Nevruz Bayramı Kutlaması", "desc": "Nevruz cemi ve lokma paylaşımı."},
    {"date": "15 Nisan 2026", "title": "Kültür Paneli", "desc": "Alevi kültürü üzerine panel düzenlenecektir."},
    {"date": "06 Mayıs 2026", "title": "Hıdırellez Etkinliği", "desc": "Baharı hep birlikte karşılıyoruz."},
  ];

  @override
  Widget build(BuildContext context) {
    // Koyu temada metin rengini otomatik belirlemesi için renk atamalarını kaldırdık
    return Scaffold(
      appBar: AppBar(title: const Text("ETKİNLİK TAKVİMİ")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.event, color: Colors.red),
            title: Text(events[i]['date']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(events[i]['title']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Siyah renk zorlaması kaldırıldı
                Text(events[i]['desc']!), // Gri renk zorlaması kaldırıldı
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- FAVORİLER, WEB VE AYARLAR ---------------- */

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('favorites');
    return Scaffold(
      appBar: AppBar(title: const Text("KAYDEDİLENLER")),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          final items = b.values.toList();
          if (items.isEmpty) return const Center(child: Text("Henüz bir içerik kaydetmediniz."));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.red),
              title: Text(fixEncoding(items[i]['title']['rendered'])),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: items[i]))),
            ),
          );
        },
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController c;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => setState(() => _loading = false)))
      ..loadRequest(Uri.parse("https://www.alevi-vakfi.com/"));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VAKIF WEB PORTAL"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => c.reload())]),
      body: Stack(children: [WebViewWidget(controller: c), if (_loading) const Center(child: CircularProgressIndicator())]),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AYARLAR")),
      body: ListView(
        children: [
          ValueListenableBuilder(
            valueListenable: Hive.box('settings').listenable(),
            builder: (context, b, _) => SwitchListTile(
              title: const Text("Koyu Tema"), secondary: const Icon(Icons.dark_mode),
              value: b.get('isDarkTheme', defaultValue: false), onChanged: (v) => b.put('isDarkTheme', v),
            ),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text("Sosyal Medya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _social(Icons.camera_alt, "Instagram", "https://www.instagram.com/alevitischestiftung/"),
          _social(Icons.facebook, "Facebook", "https://www.facebook.com/alevivakfi/"),
          _social(Icons.play_circle_fill, "YouTube", "https://www.youtube.com/@uadevakfi/videos"),
          _social(Icons.alternate_email, "X (Twitter)", "https://x.com/UADEVAKFI"),
          const Divider(),
          ListTile(leading: const Icon(Icons.mail), title: const Text("Bize Ulaşın"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
        ],
      ),
    );
  }

  Widget _social(IconData icon, String title, String url) {
    return ListTile(leading: Icon(icon, color: Colors.red), title: Text(title), onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
  }
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("İLETİŞİM")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(Icons.mail_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: "Ad Soyad", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: "Mesaj", border: OutlineInputBorder()), maxLines: 4),
            const SizedBox(height: 20),
            ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mesajınız iletildi."))); }, child: const Text("GÖNDER")),
          ],
        ),
      ),
    );
  }
}
