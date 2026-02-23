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

/* ---------------- UYGULAMA KÖKÜ (TEMA AYARI) ---------------- */

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

/* ---------------- ANA YAPI (ALT MENÜ VE POPUP) ---------------- */

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
    // İlk girişe özel popup kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOneTimeWelcomeDialog();
    });
  }

  void _showOneTimeWelcomeDialog() {
    bool hasShown = box.get('hasShownWelcomeFinal', defaultValue: false);
    if (!hasShown) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.red),
              SizedBox(width: 10),
              Text("Hoş Geldiniz"),
            ],
          ),
          content: const Text(
            "Uluslararası Alevi Vakfı mobil uygulamasına hoş geldiniz. Güncel haberler, duyurular ve hizmetlerimize buradan ulaşabilirsiniz.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                box.put('hasShownWelcomeFinal', true);
                Navigator.pop(context);
              },
              child: const Text("Uygulamaya Başla", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

/* ---------------- WEBVIEW (HARİTA HATASI GİZLEME) ---------------- */

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
    // Masaüstü modu Google Maps hatalarını minimize eder
      ..setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) {
            setState(() => isLoading = false);
            _applyCleanAndDarkJS(); // Haritayı gizleyen ve koyu temayı basan sihirli kod
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();

            // HARİTA HATASINI SESSİZCE ENGELLE (Dışarı atma, hatayı da gösterme)
            if (url.contains("maps.google") ||
                url.contains("googleusercontent.com") ||
                url.contains("maps.apple.com")) {
              log("Harita hatası veya linki sessizce engellendi.");
              return NavigationDecision.prevent;
            }

            // Vakıf dışı diğer her şeyi (Sosyal Medya vb) dış tarayıcıda aç
            if (!url.contains("alevi-vakfi.com")) {
              launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse("https://www.alevi-vakfi.com/"));
  }

  void _applyCleanAndDarkJS() {
    final isDark = Hive.box('settings').get('isDarkTheme', defaultValue: false);

    // JS: Iframe harita hatalarını komple siler, hatayı göstermez.
    String jsCode = """
      (function() {
        var style = document.createElement('style');
        style.innerHTML = 'iframe[src*="maps.google.com"], .google-maps, #map, [id*="map"], [class*="map"], .gm-err-container { display: none !important; }';
        document.head.appendChild(style);

        if ($isDark) {
          document.body.style.background = '#121212';
          document.body.style.color = 'white';
        }
      })();
    """;
    controller.runJavaScript(jsCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Uluslararası Alevi Vakfı"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.reload()),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

/* ---------------- DUYURULAR (NATIVE) ---------------- */

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [
      {"t": "Resmi Mobil Uygulamamız", "d": "Vakfımızın yeni iOS ve Android uygulaması artık yayında.", "date": "23.02.2026"},
      {"t": "Eğitim Bursu Başvuruları", "d": "Mart ayı burs dönemine dair detaylı bilgilendirme sitemizde.", "date": "21.02.2026"},
      {"t": "Vakıf Merkezi Lokması", "d": "Haftaya düzenlenecek lokma paylaşımına tüm canlar davetlidir.", "date": "18.02.2026"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Duyuru Merkezi")),
      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: list.length,
        itemBuilder: (context, i) => Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.campaign, color: Colors.white)),
            title: Text(list[i]['t']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(list[i]['d']!),
            trailing: Text(list[i]['date']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ),
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
      appBar: AppBar(title: const Text("Hakkımızda")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(Icons.volunteer_activism, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text("Uluslararası Alevi Vakfı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "İnancımızı, kültürümüzü ve değerlerimizi geleceğe taşımak adına yola çıkan vakfımız, toplumsal dayanışmayı güçlendirmeyi hedefler.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const Divider(),
            _infoItem(Icons.public, "Web", "alevi-vakfi.com"),
            _infoItem(Icons.email, "E-Posta", "info@alevi-vakfi.com"),
            _infoItem(Icons.location_on, "Merkez", "Frankfurt, Almanya"),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 15),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(val),
        ],
      ),
    );
  }
}

/* ---------------- AYARLAR VE TÜM SOSYAL MEDYALAR ---------------- */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
            child: Text("Bizi Takip Edin", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _socialTile(Icons.camera_alt, "Instagram", const Color(0xFFE4405F), "https://www.instagram.com/alevitischestiftung/"),
          _socialTile(Icons.facebook, "Facebook", const Color(0xFF1877F2), "https://www.facebook.com/alevivakfi/"),
          _socialTile(Icons.play_circle_fill, "YouTube", Colors.red, "https://www.youtube.com/@uadevakfi/videos"),
          _socialTile(Icons.alternate_email, "X / Twitter", Colors.black, "https://x.com/UADEVAKFI"),
          const Divider(),
          const Center(child: Padding(
            padding: EdgeInsets.all(30),
            child: Text("UADE VAKFI - Versiyon 1.0.14", style: TextStyle(color: Colors.grey)),
          )),
        ],
      ),
    );
  }

  Widget _socialTile(IconData icon, String title, Color color, String url) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _launch(url),
    );
  }
}
