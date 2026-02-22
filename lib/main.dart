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
    log("HIVE INITIALIZATION ERROR: $e");
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
          theme: ThemeData(
            primarySwatch: Colors.red,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

/* ---------------- ANA SHELL (Navigasyon Yapısı) ---------------- */
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
          BottomNavigationBarItem(icon: Icon(Icons.volunteer_activism), label: "Hakkımızda"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}

/* ---------------- WEBVIEW (Google Maps Filtrelenmiş) ---------------- */
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
      // Google Maps'in iframe/embed zorlamasını aşmak için UserAgent
      ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) {
            setState(() => isLoading = false);
            _applyDarkTheme();
          },
          onNavigationRequest: (request) {
            // Google Maps veya dış link tespit edilirse uygulamadan çıkar
            if (!request.url.contains("alevi-vakfi.com") || request.url.contains("google.com/maps")) {
              _launchURL(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse("https://www.alevi-vakfi.com/"));
  }

  void _applyDarkTheme() {
    final isDark = box.get('isDarkTheme', defaultValue: false);
    if (!isDark) return;
    controller.runJavaScript("""
      (function() {
        var style = document.createElement('style');
        style.innerHTML = 'body, html { background: #121212 !important; color: white !important; } * { color: white !important; }';
        document.head.appendChild(style);
      })();
    """);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vakıf Web"), toolbarHeight: 0),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

/* ---------------- DUYURULAR (Native) ---------------- */
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      {"t": "Vakıf Mobil Uygulaması", "d": "Resmi iOS uygulamamız TestFlight ile denemelere açıldı.", "date": "23.02.2026"},
      {"t": "Burs Başvuruları Hakkında", "d": "Yeni dönem eğitim bursu başvuruları mart ayında başlayacaktır.", "date": "20.02.2026"},
      {"t": "Vakıf Toplantısı", "d": "Bu pazar günü vakıf merkezimizde genel bilgilendirme toplantısı yapılacaktır.", "date": "18.02.2026"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Duyurular")),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.campaign, color: Colors.red),
            title: Text(items[i]['t']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(items[i]['d']!),
            trailing: Text(items[i]['date']!, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

/* ---------------- HAKKIMIZDA (Native) ---------------- */
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hakkımızda")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.volunteer_activism, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text("Uluslararası Alevi Vakfı", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Vakfımız, Alevi inanç ve öğretisinin doğru temsil edilmesi, kültürel değerlerin korunması ve nesilden nesile aktarılması amacıyla kurulmuştur.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const Divider(height: 40),
            _infoRow(Icons.public, "Web", "www.alevi-vakfi.com"),
            _infoRow(Icons.email, "E-Posta", "info@alevi-vakfi.com"),
            _infoRow(Icons.location_city, "Merkez", "Frankfurt, Almanya"),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

/* ---------------- AYARLAR VE SOSYAL ---------------- */
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _launch(String url) async => await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Sosyal Medya", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFFE4405F)),
            title: const Text("Instagram"),
            onTap: () => _launch("https://www.instagram.com/alevitischestiftung/"),
          ),
          ListTile(
            leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
            title: const Text("Facebook"),
            onTap: () => _launch("https://www.facebook.com/alevivakfi"),
          ),
          const Divider(),
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text("Versiyon 1.0.14", style: TextStyle(color: Colors.grey)),
          )),
        ],
      ),
    );
  }
}
