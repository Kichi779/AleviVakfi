import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
          theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: const MainShell(),
        );
      },
    );
  }
}

/* ---------------- ANA YAPI (Apple Onayı İçin Şart) ---------------- */
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final pages = [
    const WebViewPage(),
    const AnnouncementsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.language), label: "Vakıf Web"),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: "Duyurular"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}

/* ---------------- WEBVIEW SAYFASI (Google Maps Hatası Giderildi) ---------------- */
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;
  final box = Hive.box('settings');

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
    // 🔥 Google Maps Hatasını Engellemek İçin UserAgent Şart
      ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) {
            setState(() => isLoading = false);
            _injectDarkJS();
          },
          onNavigationRequest: (request) {
            if (!request.url.contains("alevi-vakfi.com")) {
              launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse("https://www.alevi-vakfi.com/"));
  }

  void _injectDarkJS() {
    final isDark = box.get('isDarkTheme', defaultValue: false);
    if (!isDark) return;

    controller.runJavaScript("""
      (function() {
        var s = document.createElement('style');
        s.innerHTML = 'body, html { background: #121212 !important; color: white !important; } * { background-color: transparent !important; color: white !important; }';
        document.head.appendChild(s);
      })();
    """);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vakıf Web Sitesi"), toolbarHeight: 0),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

/* ---------------- DUYURULAR (Apple'ı İkna Eden Kısım) ---------------- */
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"t": "Vakıf Uygulamamız Yayında!", "d": "Resmi iOS ve Android uygulamamız üzerinden artık bize daha yakınsınız.", "date": "23.02.2026"},
      {"t": "Alevi Vakfı Eğitim Bursları", "d": "Yeni dönem burs başvuruları yakında uygulama üzerinden başlayacaktır.", "date": "20.02.2026"},
      {"t": "Birlik ve Beraberlik Buluşması", "d": "Haftaya düzenlenecek olan vakıf yemeğine tüm canlar davetlidir.", "date": "15.02.2026"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Duyurular")),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.red),
            title: Text(items[i]['t']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(items[i]['d']!),
            trailing: Text(items[i]['date']!),
          ),
        ),
      ),
    );
  }
}

/* ---------------- AYARLAR VE SOSYAL BUTONLAR ---------------- */
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _launch(String url) async => await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar ve Sosyal Medya")),
      body: SingleChildScrollView(
        child: Column(
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Bizi Takip Edin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _socialIcon(Icons.facebook, const Color(0xFF1877F2), () => _launch("https://www.facebook.com/alevivakfi")),
                _socialIcon(Icons.camera_alt, const Color(0xFFE4405F), () => _launch("https://www.instagram.com/alevitischestiftung/")),
                _socialIcon(Icons.play_arrow, Colors.red, () => _launch("https://www.youtube.com/@uadevakfi/videos")),
                _socialIcon(Icons.alternate_email, Colors.black, () => _launch("https://x.com/UADEVAKFI")),
              ],
            ),
            const SizedBox(height: 40),
            const Text("Versiyon 1.0.13", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}