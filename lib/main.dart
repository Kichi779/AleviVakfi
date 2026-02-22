import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  runApp(const MyApp());
}

/* ---------------- APP ROOT ---------------- */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainShell(),
    );
  }
}

/* ---------------- MAIN SHELL ---------------- */

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  final pages = const [
    WebHomePage(),
    AnnouncementsPage(),
    AboutPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: "Duyurular"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Hakkımızda"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}

/* ---------------- WEBVIEW HOME ---------------- */

class WebHomePage extends StatefulWidget {
  const WebHomePage({super.key});

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  late final WebViewController _controller;
  bool loading = true;

  static const homeUrl = "https://www.alevi-vakfi.com/";

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);

            // 🔗 External linkleri Safari’ye gönder (crash önler)
            if (!uri.host.contains("alevi-vakfi.com")) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => loading = false);
            await _injectDarkModeIfNeeded();
          },
        ),
      );

    // iOS güvenli başlatma
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadRequest(Uri.parse(homeUrl));
    });
  }

  Future<void> _injectDarkModeIfNeeded() async {
    final dark = Hive.box('settings').get('dark', defaultValue: false);
    if (!dark) return;

    await _controller.runJavaScript("""
      document.body.style.backgroundColor = '#121212';
      document.body.style.color = '#ffffff';
    """);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/* ---------------- ANNOUNCEMENTS ---------------- */

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Duyurular")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Bu bölüm uygulamaya özel native içeriktir.\n\n"
          "• Vakıf duyuruları\n"
          "• Etkinlik bildirimleri\n"
          "• Resmi açıklamalar",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/* ---------------- ABOUT ---------------- */

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hakkımızda")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Uluslararası Alevi Vakfı resmi mobil uygulamasıdır.\n\n"
          "Bu uygulama, vakıf faaliyetleri hakkında bilgi vermek "
          "ve toplulukla iletişimi güçlendirmek amacıyla geliştirilmiştir.",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/* ---------------- SETTINGS ---------------- */

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final box = Hive.box('settings');

  @override
  Widget build(BuildContext context) {
    final dark = box.get('dark', defaultValue: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: SwitchListTile(
        title: const Text("Koyu Tema"),
        value: dark,
        onChanged: (v) {
          box.put('dark', v);
          setState(() {});
        },
      ),
    );
  }
}// rebuild 
