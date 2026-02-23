import 'dart:developer';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    await Hive.openBox('settings');
  } catch (e) {
    log("HIVE ERROR: $e");
  }
  runApp(const MyApp());
}

/* ---------------- UYGULAMA KÖKÜ (TEMA) ---------------- */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, box, widget) {
        final isDark = box.get('isDarkTheme', defaultValue: false);
        return MaterialApp(
          title: 'Uluslararası Alevi Vakfı',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.red,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
                centerTitle: true,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white
            ),
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: const MainShell(),
        );
      },
    );
  }
}

/* ---------------- ANA YAPI (NAVİGASYON VE POPUP) ---------------- */

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final box = Hive.box('settings');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWelcomeDialog());
  }

  void _checkWelcomeDialog() {
    bool hasShown = box.get('welcome_final_v14', defaultValue: false);
    if (!hasShown) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Hoş Geldiniz"),
          content: const Text("Vakfımızın dijital dünyasına hoş geldiniz! Bu uygulama üzerinden güncel duyurularımızı takip edebilir, etkinliklerimizden haberdar olabilir ve web sitemizdeki tüm içeriklere anında ulaşabilirsiniz. Her şey elinizin altında!"),
          actions: [
            TextButton(
              onPressed: () {
                box.put('welcome_final_v14', true);
                Navigator.pop(context);
              },
              child: const Text("Hemen Başla", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  final pages = [
    const WebViewPage(),
    const AnnouncementsPage(),
    const AboutPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.language), label: "Vakıf Web"),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: "Duyurular"),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: "Hakkımızda"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}

/* ---------------- WEBVIEW (GELİŞMİŞ ANTİ-CHROME FIX) ---------------- */

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
    // 🔥 Masaüstü kimliği ile haritanın "App Intent" (Chrome'u açma) tetiklemesini durduruyoruz.
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => isLoading = true);
            _preCleanMaps(); // Sayfa render edilmeden haritayı gizle
          },
          onPageFinished: (_) {
            setState(() => isLoading = false);
            _applyStyles();
          },
          onNavigationRequest: (req) {
            final url = req.url.toLowerCase();
            // Google Maps ve Chrome tetikleyicilerini daha gitmeden ENGELLER.
            if (url.contains("maps.google") || url.contains("googleusercontent.com") || url.contains("gstatic.com")) {
              return NavigationDecision.prevent;
            }
            // Sitemiz dışındaki her şeyi dışarıda aç.
            if (!url.contains("alevi-vakfi.com")) {
              launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse("https://www.alevi-vakfi.com/"));
  }

  void _preCleanMaps() {
    controller.runJavaScript("""
      var s = document.createElement('style');
      s.innerHTML = 'iframe[src*="maps"], .google-maps, #map, [id*="map"], .gm-err-container { display: none !important; visibility: hidden !important; height: 0 !important; }';
      document.head.appendChild(s);
    """);
  }

  void _applyStyles() {
    final isDark = Hive.box('settings').get('isDarkTheme', defaultValue: false);
    if (isDark) {
      controller.runJavaScript("document.body.style.background = '#121212'; document.body.style.color = 'white';");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UADE VAKFI"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.reload())]),
      body: Stack(children: [WebViewWidget(controller: controller), if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.red))]),
    );
  }
}

/* ---------------- DUYURULAR (WORDPRESS API İLE CANLI ÇEKİM) ---------------- */

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  // WordPress'teki son 15 haberi çeker
  Future<List<dynamic>> fetchPosts() async {
    final response = await http.get(Uri.parse('https://www.alevi-vakfi.com/wp-json/wp/v2/posts?per_page=15&_embed'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Veri çekilemedi');
  }

  // HTML kodlarını metne dönüştürür
  String parseHtml(String? html) {
    if (html == null) return "";
    return html
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8217;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canlı Duyurular")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));
          if (snapshot.hasError) return Center(child: Text("Haberler yüklenemedi: ${snapshot.error}"));

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, i) {
                final post = snapshot.data![i];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.newspaper, color: Colors.white)),
                    title: Text(parseHtml(post['title']['rendered']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(parseHtml(post['excerpt']['rendered']), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => launchUrl(Uri.parse(post['link']), mode: LaunchMode.externalApplication),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/* ---------------- HAKKIMIZDA (NATIVE) ---------------- */

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vakfımız")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism, size: 80, color: Colors.red),
            SizedBox(height: 20),
            Text("Uluslararası Alevi Vakfı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Padding(
              padding: EdgeInsets.all(30),
              child: Text("Vakfımız, inancımızı ve kültürümüzü koruyarak gelecek nesillere aktarmayı ilke edinmiştir.", textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- AYARLAR VE SOSYAL MEDYA ---------------- */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: ListView(
        children: [
          ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, box, widget) {
              final isDark = box.get('isDarkTheme', defaultValue: false);
              return SwitchListTile(
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                title: const Text("Koyu Tema"),
                value: isDark,
                onChanged: (v) => box.put('isDarkTheme', v),
              );
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text("Sosyal Medya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _social(Icons.camera_alt, "Instagram", "https://www.instagram.com/alevitischestiftung/"),
          _social(Icons.facebook, "Facebook", "https://www.facebook.com/alevivakfi/"),
          _social(Icons.play_circle_fill, "YouTube", "https://www.youtube.com/@uadevakfi/videos"),
          _social(Icons.alternate_email, "X (Twitter)", "https://x.com/UADEVAKFI"),
          const Divider(),
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text("v1.0.16"))),
        ],
      ),
    );
  }

  Widget _social(IconData icon, String title, String url) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(title),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
