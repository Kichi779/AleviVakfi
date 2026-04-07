import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- BİLDİRİM KURULUMU ---
final FlutterLocalNotificationsPlugin localNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// --- GLOBAL SABİTLER ---
const String kBaseUrl = 'https://www.alevi-vakfi.com';
const String kApiUrl = '$kBaseUrl/wp-json/wp/v2';
const Color kRed = Color(0xFFDD1616);
const Color kGold = Color(0xFFF9BF3B);

const Map<String, String> kImageHeaders = {
  "User-Agent":
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Accept":
  "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
  "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
  "Referer": "https://www.alevi-vakfi.com/",
  "Connection": "keep-alive",
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');
  await Hive.openBox('favorites');

  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings =
  InitializationSettings(android: androidInit, iOS: iosInit);
  await localNotificationsPlugin.initialize(initSettings);

  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("0e1426f3-843b-4e98-8fa2-87ee35839a88");
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint("OneSignal başlatılamadı: $e");
  }

  runApp(const MyApp());
}

/* ───────────── YARDIMCI FONKSİYONLAR ───────────── */

String fixEncoding(String text) {
  return text
      .replaceAll("&#8211;", "-")
      .replaceAll("&#8212;", "—")
      .replaceAll("&#8216;", "'")
      .replaceAll("&#8217;", "'")
      .replaceAll("&#8220;", '"')
      .replaceAll("&#8221;", '"')
      .replaceAll("&#8230;", "...")
      .replaceAll("&#038;", "&")
      .replaceAll("&#039;", "'")
      .replaceAll("&nbsp;", " ")
      .replaceAll("&amp;", "&")
      .replaceAll("&quot;", '"')
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">")
      .replaceAll("'", "'")
      .replaceAll("–", "-")
      .replaceAll("\u201c", '"')
      .replaceAll("\u201d", '"')
      .replaceAll(RegExp(r'ngg_shortcode_\d+_placeholder'), '')
      .trim();
}

String stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&[^;]+;'), ' ')
      .trim();
}

String smartImageUrl(String url) {
  if (url.isEmpty) return url;
  if (url.contains('wsrv.nl')) return url;
  final cleanUrl = url.replaceAll('https://', '').replaceAll('http://', '');
  return 'https://wsrv.nl/?url=$cleanUrl';
}

void openWebPage(BuildContext context, String url, String title) {
  if (url.startsWith('http')) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CustomWebViewPage(url: url, title: title)),
    );
  } else {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/* ───────────── WEBVIEW (UYGULAMA İÇİ TARAYICI) ───────────── */
class CustomWebViewPage extends StatefulWidget {
  final String url;
  final String title;
  const CustomWebViewPage({super.key, required this.url, required this.title});

  @override
  State<CustomWebViewPage> createState() => _CustomWebViewPageState();
}

class _CustomWebViewPageState extends State<CustomWebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: kRed)),
        ],
      ),
    );
  }
}

/* ───────────── HAMBURGER MENÜ (DRAWER) ───────────── */
// Sadece HomePage'de kullanılır.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kRed,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, 'ANA SAYFA',
                      onTap: () => Navigator.pop(context)),
                  _buildExpansionTile(context, 'KURUMSAL', [
                    _drawerSubItem(
                      context,
                      'KURUCU ÜYELER & VAKIF SENEDİ',
                      'https://www.alevi-vakfi.com/kurucu-uyeler/',
                    ),
                    _drawerSubItem(
                      context,
                      'BAKIŞ AÇIMIZ',
                      'https://www.alevi-vakfi.com/bakis-acimiz/',
                    ),
                    _drawerSubItem(
                      context,
                      'ÜYELİK FORMU',
                      'https://www.alevi-vakfi.com/uyelik-basvuru-formu/',
                    ),
                    _drawerSubItem(
                      context,
                      'TANITIM BROŞÜRÜ',
                      'https://www.alevi-vakfi.com/tanitim-brosurumuz/',
                    ),
                    _drawerSubItem(
                      context,
                      '12 Soruda UADE Vakfı',
                      'https://www.alevi-vakfi.com/12-soruda-uade-vakfi/',
                    ),
                    _drawerSubItem(
                      context,
                      'Basında Vakfımız',
                      'https://www.alevi-vakfi.com/basinda-vakfimiz/',
                    ),
                  ]),
                  _buildExpansionTile(context, 'PROJELER', [
                    _drawerSubItem(
                      context,
                      'Biten Araştırma Projeleri',
                      'https://www.alevi-vakfi.com/kategori/arastirma-destekleri/',
                    ),
                    _drawerSubItem(
                      context,
                      'Biten Dayanışma Projeleri',
                      'https://www.alevi-vakfi.com/kategori/dayanisma-projeleri/',
                    ),
                    _drawerSubItem(
                      context,
                      'Biten Eğitim Destekleri',
                      'https://www.alevi-vakfi.com/kategori/egitim-destekleri/',
                    ),
                  ]),
                  _buildExpansionTile(context, 'BURSLAR', [
                    _drawerSubItem(
                      context,
                      'Burs Başvuru Formu',
                      'https://www.alevi-vakfi.com/burs-basvuru-formu-1/',
                    ),
                    _drawerSubItem(
                      context,
                      'Burs Bekleyenler',
                      'https://www.alevi-vakfi.com/burs-bekleyenler/',
                    ),
                    _drawerSubItem(
                      context,
                      'Burs Vermek İstiyorum',
                      'https://www.alevi-vakfi.com/burs-vermek-istiyorum/',
                    ),
                    _drawerSubItem(
                      context,
                      'Öğrenci Belgesi Gönderme Formu',
                      'https://www.alevi-vakfi.com/ogrenci-belgesi-gonderme-formu/',
                    ),
                  ]),
                  _drawerItem(context, 'ARŞİV', onTap: () {
                    Navigator.pop(context);
                    openWebPage(
                      context,
                      'https://www.alevi-vakfi.com/kategori/arsiv/',
                      'Arşiv',
                    );
                  }),
                  _drawerItem(context, 'İLETİŞİM', onTap: () {
                    Navigator.pop(context);
                    openWebPage(
                      context,
                      'https://www.alevi-vakfi.com/iletisim/',
                      'İletişim',
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title,
      {required VoidCallback onTap}) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15)),
      onTap: onTap,
    );
  }

  Widget _buildExpansionTile(
      BuildContext context, String title, List<Widget> children) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        children: children,
      ),
    );
  }

  Widget _drawerSubItem(BuildContext context, String title, String url) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text('- $title',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        openWebPage(context, url, title);
      },
    );
  }
}

/* ───────────── API SERVİSİ ───────────── */

class ApiService {
  static Future<List<dynamic>> getPosts({
    int perPage = 20,
    String? categories,
    String? search,
  }) async {
    try {
      String url = '$kApiUrl/posts?per_page=$perPage&_embed=true';
      if (categories != null) url += '&categories=$categories';
      if (search != null) url += '&search=${Uri.encodeComponent(search)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (e) {
      debugPrint('API hatası: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getPages({int perPage = 10}) async {
    try {
      final res = await http
          .get(Uri.parse('$kApiUrl/pages?per_page=$perPage&_embed=true'));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      debugPrint('Pages API hatası: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getCategories() async {
    try {
      final res =
      await http.get(Uri.parse('$kApiUrl/categories?per_page=100'));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      debugPrint('Kategori API hatası: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getPostById(int id) async {
    try {
      final res =
      await http.get(Uri.parse('$kApiUrl/posts/$id?_embed=true'));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      debugPrint('Post API hatası: $e');
    }
    return null;
  }

  static String? getFeaturedImage(dynamic post) {
    try {
      final embedded = post['_embedded'];
      if (embedded != null) {
        final media = embedded['wp:featuredmedia'];
        if (media != null && media.isNotEmpty) {
          return smartImageUrl(media[0]['source_url']);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getCategoryIdBySlug(String slug) async {
    try {
      final res =
      await http.get(Uri.parse('$kApiUrl/categories?slug=$slug'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data.isNotEmpty) return data[0]['id'].toString();
      }
    } catch (_) {}
    return null;
  }
}

/* ───────────── TEMA ───────────── */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, box, _) {
        final isDark = box.get('isDarkTheme', defaultValue: false);
        final isFirstRun = box.get('isFirstRun', defaultValue: true);
        return MaterialApp(
          title: 'Uluslararası Alevi Vakfı',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: kRed,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: kRed,
          ),
          home: isFirstRun ? const OnboardingPage() : const MainShell(),
        );
      },
    );
  }
}

/* ───────────── ONBOARDING ───────────── */

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      "t": "Vakfımıza Hoş Geldiniz",
      "d": "İnancımızı ve kültürümüzü dijital dünyada birlikte yaşıyoruz.",
      "i": Icons.auto_awesome,
    },
    {
      "t": "Güncel Haberler",
      "d":
      "En güncel duyuruları okuyun, favorilerinize ekleyin ve paylaşın.",
      "i": Icons.article_outlined,
    },
    {
      "t": "Etkinlik Takvimi",
      "d":
      "Önemli günleri native takvimden takip edin, hatırlatıcı kurun.",
      "i": Icons.calendar_month,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kRed.withOpacity(0.08), Colors.white],
              ),
            ),
          ),
          PageView.builder(
            controller: _controller,
            onPageChanged: (v) => setState(() => _currentPage = v),
            itemCount: _steps.length,
            itemBuilder: (context, i) => Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: kRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_steps[i]['i'], size: 70, color: kRed),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _steps[i]['t'],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _steps[i]['d'],
                    style:
                    TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin:
                      const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 28 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? kRed
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () {
                      if (_currentPage < _steps.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Hive.box('settings').put('isFirstRun', false);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MainShell()),
                        );
                      }
                    },
                    child: Text(
                      _currentPage == _steps.length - 1
                          ? "BAŞLAYALIM"
                          : "İLERLE",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
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

/* ───────────── ANA KABUK ───────────── */

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  void _requestPermissions() async {
    try {
      await Geolocator.requestPermission();
    } catch (e) {
      debugPrint("İzin hatası: $e");
    }
  }

  final _pages = [
    const HomePage(),
    const NewsPage(),
    const CemeviFinderPage(),
    const EventsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Ana Sayfa",
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: "Duyurular",
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: "Cemevi",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: "Takvim",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: "Ayarlar",
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   ANA SAYFA
   ═══════════════════════════════════════════════════ */

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _sliderPosts = [];
  List<dynamic> _haberler = [];
  List<dynamic> _dayanisma = [];
  List<dynamic> _arastirma = [];
  List<dynamic> _videolar = [];
  List<dynamic> _fotolar = [];

  bool _loading = true;
  String? _error;

  String? _catHaberler;
  String? _catDayanisma;
  String? _catArastirma;
  String? _catVideo;
  String? _catFoto;

  @override
  void initState() {
    super.initState();
    _dusmaniTani();
    _loadAll();
  }

  void _dusmaniTani() async {
    try {
      final res = await http.get(
        Uri.parse(
            "https://www.alevi-vakfi.com/wp-content/uploads/2023/02/depremTR.jpg"),
        headers: kImageHeaders,
      );
      debugPrint(
          "\n================ DÜŞMANI TANI RAPORU ================");
      debugPrint(
          "HTTP DURUM KODU (403 mü?): ${res.statusCode}");
      String body = res.body.length > 500
          ? res.body.substring(0, 500)
          : res.body;
      debugPrint("SUNUCUDAN GELEN ENGELLEME MESAJI:\n$body");
      debugPrint(
          "=====================================================\n");
    } catch (e) {
      debugPrint("Düşmanı Tanı Hatası: $e");
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _catHaberler =
      await ApiService.getCategoryIdBySlug('bizden-haberler');
      _catDayanisma =
      await ApiService.getCategoryIdBySlug('dayanisma-projeleri');
      _catArastirma =
      await ApiService.getCategoryIdBySlug('arastirma-destekleri');
      _catVideo = await ApiService.getCategoryIdBySlug('videolar');
      _catFoto = await ApiService.getCategoryIdBySlug('foto-galeri');

      final results = await Future.wait([
        ApiService.getPosts(perPage: 5),
        ApiService.getPosts(perPage: 3, categories: _catHaberler),
        ApiService.getPosts(perPage: 6, categories: _catDayanisma),
        ApiService.getPosts(perPage: 3, categories: _catArastirma),
        ApiService.getPosts(perPage: 4, categories: _catVideo),
        ApiService.getPosts(perPage: 4, categories: _catFoto),
      ]);

      if (mounted) {
        setState(() {
          _sliderPosts = results[0];
          _haberler = results[1];
          _dayanisma = results[2];
          _arastirma = results[3];
          _videolar = results[4];
          _fotolar = results[5];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Drawer sadece HomePage'de tanımlı
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: smartImageUrl(
                'https://www.alevi-vakfi.com/wp-content/uploads/2025/10/alevi-vakfi-Almanya.jpg'),
            height: 36,
            fit: BoxFit.contain,
            httpHeaders: kImageHeaders,
            errorWidget: (_, __, ___) =>
            const Icon(Icons.verified, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kRed),
            SizedBox(height: 16),
            Text('İçerikler yükleniyor...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off,
                size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Bağlantı kurulamadı'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_sliderPosts.isNotEmpty)
                _HeroSlider(posts: _sliderPosts),
              _DonationBanner(),
              _SectionHeader(
                  title: "ÇALIŞMA ALANLARIMIZ", color: kGold),
              _WorkAreasGrid(),
              _SectionHeader(
                  title: "BİZDEN HABERLER", color: kRed),
              if (_haberler.isEmpty)
                _EmptySection()
              else
                _PostsRow(posts: _haberler),
              _SectionHeader(
                  title: "TAMAMLANAN DAYANIŞMA PROJELERİ",
                  color: kRed),
              if (_dayanisma.isEmpty)
                _EmptySection()
              else
                _PostsGrid(posts: _dayanisma),
              _SectionHeader(
                  title: "TAMAMLANAN ARAŞTIRMA PROJELERİ",
                  color: kRed),
              if (_arastirma.isEmpty)
                _EmptySection()
              else
                _PostsRow(posts: _arastirma),
              _SectionHeader(
                  title: "İNTERNET SİTELERİMİZ", color: kGold),
              _WebsitesSlider(),
              _SectionHeader(
                  title: "VİDEO & GALERİMİZ", color: kRed),
              if (_videolar.isEmpty)
                _EmptySection()
              else
                _PostsRow(posts: _videolar),
              _SectionHeader(
                  title: "FOTOĞRAF & GALERİMİZ", color: kRed),
              if (_fotolar.isEmpty)
                _EmptySection()
              else
                _PostsRow(posts: _fotolar),
              _SocialMediaBar(),
              _Footer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── HERO SLIDER ── */
class _HeroSlider extends StatefulWidget {
  final List<dynamic> posts;
  const _HeroSlider({required this.posts});
  @override
  State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> {
  final PageController _ctrl = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    final next = (_current + 1) % widget.posts.length;
    _ctrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (v) => setState(() => _current = v),
            itemCount: widget.posts.length,
            itemBuilder: (_, i) {
              final post = widget.posts[i];
              final imgUrl = ApiService.getFeaturedImage(post);
              final title =
              fixEncoding(post['title']['rendered']);
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PostDetailPage(post: post)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgUrl != null)
                      CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        httpHeaders: kImageHeaders,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(
                            color: kRed.withOpacity(0.2)),
                      )
                    else
                      Container(color: kRed.withOpacity(0.15)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 60,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                            )
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: kRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '→ detaylar',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              children: List.generate(
                widget.posts.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin:
                  const EdgeInsets.symmetric(horizontal: 2),
                  width: _current == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── BAĞIŞ BANNER ── */
// Bağış sayfası harici tarayıcıda açılır (WebView değil)
class _DonationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('$kBaseUrl/bagis-sayfasi/'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        margin:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kRed, Color(0xFFB71C1C)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: kRed.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Araştırma, Eğitim ve Dayanışma Fonuna Bağış Yapmak ister misiniz?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'BAĞIŞ »»',
                style: TextStyle(
                  color: kRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── BÖLÜM BAŞLIĞI ── */
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── ÇALIŞMA ALANLARI GRID ── */
class _WorkAreasGrid extends StatelessWidget {
  final _areas = const [
    {
      'title': 'Araştırma',
      'url': '$kBaseUrl/arastirma-calisma-grubu/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2021/01/arastirma-360x245.jpg',
      'icon': Icons.science_outlined,
    },
    {
      'title': 'Dayanışma',
      'url': '$kBaseUrl/dayanisma-calisma-grubu/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2018/01/a4-360x245.jpg',
      'icon': Icons.handshake_outlined,
    },
    {
      'title': 'Eğitim',
      'url': '$kBaseUrl/egitim-calisma-grubu/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2022/09/bbb-341x245.jpg',
      'icon': Icons.school_outlined,
    },
    {
      'title': 'Sosyal Medya',
      'url': '$kBaseUrl/sosyal-medya-platformlari/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2020/10/s-media-360x245.jpg',
      'icon': Icons.share_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
        ),
        itemCount: _areas.length,
        itemBuilder: (context, i) {
          final area = _areas[i];
          return GestureDetector(
            onTap: () => openWebPage(
                context,
                area['url'] as String,
                area['title'] as String),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                    smartImageUrl(area['img'] as String),
                    fit: BoxFit.cover,
                    httpHeaders: kImageHeaders,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey[200]),
                    errorWidget: (_, __, ___) => Container(
                        color: kRed.withOpacity(0.1)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Text(
                      area['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ── POST'LAR YATAY SCROLL ── */
class _PostsRow extends StatelessWidget {
  final List<dynamic> posts;
  const _PostsRow({required this.posts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: posts.length,
        itemBuilder: (_, i) => _PostCard(post: posts[i]),
      ),
    );
  }
}

/* ── POST KART ── */
class _PostCard extends StatelessWidget {
  final dynamic post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final imgUrl = ApiService.getFeaturedImage(post);
    final title = fixEncoding(post['title']['rendered']);
    final date = post['date'] != null
        ? post['date'].toString().substring(0, 10)
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PostDetailPage(post: post)),
      ),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: imgUrl != null
                    ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  httpHeaders: kImageHeaders,
                  placeholder: (_, __) =>
                      Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                      color: kRed.withOpacity(0.1)),
                )
                    : Container(
                  color: kRed.withOpacity(0.1),
                  child: const Icon(Icons.article,
                      color: kRed, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── POST'LAR 2'li GRID ── */
class _PostsGrid extends StatelessWidget {
  final List<dynamic> posts;
  const _PostsGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: posts.length > 6 ? 6 : posts.length,
        itemBuilder: (_, i) {
          final post = posts[i];
          final imgUrl = ApiService.getFeaturedImage(post);
          final title = fixEncoding(post['title']['rendered']);
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PostDetailPage(post: post)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null)
                    CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      httpHeaders: kImageHeaders,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[200]),
                    )
                  else
                    Container(color: kRed.withOpacity(0.1)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ── İNTERNET SİTELERİ ── */
class _WebsitesSlider extends StatelessWidget {
  final _sites = const [
    {
      'title': 'Alevi Portal',
      'url': '$kBaseUrl/alevi-portal/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2021/01/alevi_portal-270x200.jpg',
    },
    {
      'title': 'Alevi Hafıza',
      'url': '$kBaseUrl/alevi-hafiza/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2021/01/alevi_hafiza-270x200.jpg',
    },
    {
      'title': 'Alevi Bilgileri',
      'url': '$kBaseUrl/alevi-bilgileri-web-sitesi/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2021/01/alevi_bilgileri-270x200.jpg',
    },
    {
      'title': 'Alevi Takvimi',
      'url': '$kBaseUrl/alevi-takvimi/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2025/10/WEB-LOGO-uade-1.jpg',
    },
    {
      'title': 'Alevi Kitap Net',
      'url': '$kBaseUrl/alevi-kitap-net/',
      'img':
      'https://www.alevi-vakfi.com/wp-content/uploads/2022/03/alevi-KItap-1-270x200.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sites.length,
        itemBuilder: (_, i) {
          final site = _sites[i];
          return GestureDetector(
            onTap: () =>
                openWebPage(context, site['url']!, site['title']!),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: smartImageUrl(site['img']!),
                        fit: BoxFit.cover,
                        httpHeaders: kImageHeaders,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(
                            color: kRed.withOpacity(0.1)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      site['title']!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ── SOSYAL MEDYA ── */
class _SocialMediaBar extends StatelessWidget {
  final _socials = const [
    {
      'title': 'Facebook',
      'icon': Icons.facebook,
      'url': 'https://www.facebook.com/alevivakfi/',
      'color': Color(0xFF1877F2),
    },
    {
      'title': 'Instagram',
      'icon': Icons.camera_alt,
      'url': 'https://www.instagram.com/alevitischestiftung/',
      'color': Color(0xFFE4405F),
    },
    {
      'title': 'YouTube',
      'icon': Icons.play_circle_filled,
      'url': 'https://www.youtube.com/@uadevakfi/videos',
      'color': Color(0xFFFF0000),
    },
    {
      'title': 'X / Twitter',
      'icon': Icons.alternate_email,
      'url': 'https://x.com/UADEVAKFI',
      'color': Color(0xFF000000),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'SOSYAL MEDYA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _socials.map((s) {
              return GestureDetector(
                onTap: () => openWebPage(context,
                    s['url'] as String, s['title'] as String),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                        (s['color'] as Color).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: s['color'] as Color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['title'] as String,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/* ── FOOTER ── */
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İLETİŞİM',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _footerRow(Icons.location_on,
              'Herforder Str. 46 D 33602 Bielefeld'),
          _footerRow(Icons.phone, '+49 521 329 70 90'),
          _footerRow(Icons.fax, '+49 521 329 70 919'),
          _footerRow(Icons.email, 'post@alevi-vakfi.org'),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'ULUSLARARASI ALEVİ VAKFI\nResmi Mobil Uygulaması',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: kGold, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
              const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── BOŞ BÖLÜM ── */
class _EmptySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'İçerik yüklenemedi',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   DUYURULAR SAYFASI
   ═══════════════════════════════════════════════════ */

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<dynamic> allPosts = [];
  List<dynamic> filteredPosts = [];
  bool loading = true;
  final TextEditingController _searchController =
  TextEditingController();
  final favBox = Hive.box('favorites');

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  bool hasContent(String html) {
    String cleanText = html
        .replaceAll(
        RegExp(
            r'<[^>]*>|&[^;]+;|ngg_shortcode_\d+_placeholder'),
        '')
        .trim();
    return cleanText.isNotEmpty && cleanText.length > 10;
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      _page = 1;
      _hasMore = true;
    });
    try {
      final res = await http.get(
        Uri.parse(
            '$kApiUrl/posts?per_page=20&_embed=true&page=1'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        Hive.box('cache').put('news', data);
        final totalPages =
            int.tryParse(res.headers['x-wp-totalpages'] ?? '1') ??
                1;
        if (mounted) {
          setState(() {
            allPosts = data;
            filteredPosts = data;
            loading = false;
            _hasMore = _page < totalPages;
          });
        }
        return;
      }
    } catch (_) {}
    setState(() {
      allPosts =
          Hive.box('cache').get('news', defaultValue: []);
      filteredPosts = allPosts;
      loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await http.get(
        Uri.parse(
            '$kApiUrl/posts?per_page=20&_embed=true&page=$_page'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final totalPages =
            int.tryParse(res.headers['x-wp-totalpages'] ?? '1') ??
                1;
        if (mounted) {
          setState(() {
            allPosts.addAll(data);
            filteredPosts = allPosts;
            _hasMore = _page < totalPages;
            _loadingMore = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NewsPage'de drawer YOK
      appBar: AppBar(
        title: const Text("VAKIF DUYURULARI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FavoritesPage()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                filteredPosts = v.isEmpty
                    ? allPosts
                    : allPosts
                    .where((p) => fixEncoding(
                    p['title']['rendered'])
                    .toLowerCase()
                    .contains(v.toLowerCase()))
                    .toList();
              }),
              decoration: InputDecoration(
                hintText: "Duyurularda ara...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(
          child: CircularProgressIndicator(color: kRed))
          : RefreshIndicator(
        onRefresh: _fetch,
        child: ListView.separated(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: filteredPosts.length +
              (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) =>
          const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == filteredPosts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                      color: kRed),
                ),
              );
            }
            final post = filteredPosts[i];
            final bool isFav =
            favBox.containsKey(post['id']);
            final bool clickable =
            hasContent(post['content']['rendered']);
            final imgUrl =
            ApiService.getFeaturedImage(post);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: imgUrl != null
                      ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    httpHeaders: kImageHeaders,
                    placeholder: (_, __) => Container(
                        color: Colors.grey[200]),
                    errorWidget: (_, __, ___) =>
                        Container(
                          color: kRed.withOpacity(0.1),
                          child: const Icon(Icons.article,
                              color: kRed),
                        ),
                  )
                      : Container(
                    color: kRed.withOpacity(0.1),
                    child: const Icon(Icons.article,
                        color: kRed),
                  ),
                ),
              ),
              title: Text(
                fixEncoding(post['title']['rendered']),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: post['date'] != null
                  ? Text(
                post['date']
                    .toString()
                    .substring(0, 10),
                style:
                const TextStyle(fontSize: 11),
              )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: kRed,
                      size: 20,
                    ),
                    onPressed: () => setState(() {
                      isFav
                          ? favBox.delete(post['id'])
                          : favBox.put(
                          post['id'], post);
                    }),
                  ),
                  if (clickable)
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey),
                ],
              ),
              onTap: clickable
                  ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PostDetailPage(post: post)),
              )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   HABER DETAY
   ═══════════════════════════════════════════════════ */

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
    final String title =
    fixEncoding(widget.post['title']['rendered']);
    final String content =
    fixEncoding(widget.post['content']['rendered']);
    final String link = widget.post['link'] ?? kBaseUrl;
    final imgUrl = ApiService.getFeaturedImage(widget.post);
    final date = widget.post['date'] != null
        ? widget.post['date'].toString().substring(0, 10)
        : '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title:
        const Text("DETAY", style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
                isFav ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() {
              isFav
                  ? favBox.delete(widget.post['id'])
                  : favBox.put(widget.post['id'], widget.post);
            }),
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                final box =
                ctx.findRenderObject() as RenderBox?;
                Share.share(
                  "$title\n\n$link",
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) &
                  box.size
                      : null,
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imgUrl != null)
              CachedNetworkImage(
                imageUrl: imgUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                httpHeaders: kImageHeaders,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                        color: kRed)),
                errorWidget: (_, __, ___) => Container(
                  color: kRed.withOpacity(0.1),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          color: kRed, size: 50),
                      SizedBox(height: 8),
                      Text("Görsel yüklenemedi",
                          style: TextStyle(color: kRed)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty) ...[
                    Text(
                      date,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const Divider(height: 30),
                  HtmlWidget(
                    content,
                    textStyle:
                    const TextStyle(fontSize: 15, height: 1.6),
                    onTapUrl: (url) async {
                      openWebPage(context, url, 'Detay');
                      return true;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   ARAMA SAYFASI
   ═══════════════════════════════════════════════════ */

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<dynamic> _results = [];
  bool _loading = false;
  final _ctrl = TextEditingController();

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.getPosts(perPage: 20, search: q);
    if (mounted) {
      setState(() {
        _results = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ara...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.length >= 3) _search(v);
          },
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: kRed))
          : _results.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search,
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
                'Aramak için yazmaya başlayın'),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final post = _results[i];
          final imgUrl =
          ApiService.getFeaturedImage(post);
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 50,
                height: 50,
                child: imgUrl != null
                    ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  httpHeaders: kImageHeaders,
                )
                    : Container(
                  color: kRed.withOpacity(0.1),
                  child: const Icon(Icons.article,
                      color: kRed, size: 20),
                ),
              ),
            ),
            title: Text(
              fixEncoding(post['title']['rendered']),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PostDetailPage(post: post)),
            ),
          );
        },
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   CEMEVİ BULUCU
   ═══════════════════════════════════════════════════ */

class CemeviFinderPage extends StatefulWidget {
  const CemeviFinderPage({super.key});
  @override
  State<CemeviFinderPage> createState() =>
      _CemeviFinderPageState();
}

class _CemeviFinderPageState extends State<CemeviFinderPage> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(51.1657, 10.4515);

  final List<Map<String, dynamic>> cemevleri = [
    {
      "ad": "UADE Merkez Ofisi - Bielefeld",
      "lat": 52.0303,
      "lng": 8.5325,
      "adres": "Herforder Str. 46 D 33602 Bielefeld"
    },
    {
      "ad": "Berlin Cemevi",
      "lat": 52.5200,
      "lng": 13.4050,
      "adres": "Berlin, Almanya"
    },
    {
      "ad": "Köln Cemevi",
      "lat": 50.9375,
      "lng": 6.9603,
      "adres": "Köln, Almanya"
    },
    {
      "ad": "Frankfurt Cemevi",
      "lat": 50.1109,
      "lng": 8.6821,
      "adres": "Frankfurt, Almanya"
    },
    {
      "ad": "Stuttgart Cemevi",
      "lat": 48.7758,
      "lng": 9.1829,
      "adres": "Stuttgart, Almanya"
    },
    {
      "ad": "Münih Cemevi",
      "lat": 48.1351,
      "lng": 11.5820,
      "adres": "Münih, Almanya"
    },
    {
      "ad": "Hamburg Cemevi",
      "lat": 53.5511,
      "lng": 10.0000,
      "adres": "Hamburg, Almanya"
    },
    {
      "ad": "Dortmund Cemevi",
      "lat": 51.5136,
      "lng": 7.4653,
      "adres": "Dortmund, Almanya"
    },
  ];

  Future<void> _findMe() async {
    bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission perm =
    await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() =>
      _center = LatLng(position.latitude, position.longitude));
      _mapController.move(_center, 12.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CemeviFinderPage'de drawer YOK
      appBar: AppBar(
        title: const Text("YAKINDAKİ CEMEVLERİ",
            style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _showList(),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 6.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.alevivakfi.app',
          ),
          MarkerLayer(
            markers: cemevleri
                .map(
                  (c) => Marker(
                point: LatLng(c['lat'], c['lng']),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showDetail(c),
                  child: const Icon(Icons.location_on,
                      color: kRed, size: 40),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        onPressed: _findMe,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.location_on, color: kRed, size: 40),
            const SizedBox(height: 8),
            Text(
              c['ad'],
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              c['adres'],
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.directions),
                label: const Text("Yol Tarifi Al"),
                onPressed: () {
                  final url =
                      "https://www.google.com/maps/search/?api=1&query=${c['lat']},${c['lng']}";
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, ctrl) => ListView.separated(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          itemCount: cemevleri.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) {
            final c = cemevleri[i];
            return ListTile(
              leading:
              const Icon(Icons.location_on, color: kRed),
              title: Text(c['ad'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold)),
              subtitle: Text(c['adres']),
              onTap: () {
                Navigator.pop(context);
                _mapController.move(
                    LatLng(c['lat'], c['lng']), 14.0);
                Future.delayed(const Duration(milliseconds: 300),
                        () => _showDetail(c));
              },
            );
          },
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   ETKİNLİK TAKVİMİ
   ═══════════════════════════════════════════════════ */

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, List<Map<String, String>>> _events = {
    DateTime.utc(2026, 3, 20): [
      {
        "title": "Nevruz Bayramı Kutlaması",
        "desc": "Nevruz cemi ve lokma paylaşımı."
      }
    ],
    DateTime.utc(2026, 4, 15): [
      {
        "title": "Kültür Paneli",
        "desc":
        "Alevi kültürü üzerine panel düzenlenecektir."
      }
    ],
    DateTime.utc(2026, 5, 6): [
      {
        "title": "Hıdırellez Etkinliği",
        "desc": "Baharı hep birlikte karşılıyoruz."
      }
    ],
    DateTime.utc(2026, 12, 16): [
      {
        "title": "6. Kuruluş Yılı",
        "desc": "UADE'nin kuruluşunun 6. yıl dönümü etkinliği."
      }
    ],
  };

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[
    DateTime.utc(day.year, day.month, day.day)] ??
        [];
  }

  void _setReminder(String eventName) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'event_id',
      'Etkinlikler',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails();
    const NotificationDetails platformDetails =
    NotificationDetails(
        android: androidDetails, iOS: iosDetails);

    await localNotificationsPlugin.show(
      0,
      "Hatırlatıcı Kuruldu!",
      "$eventName için bildirim alacaksınız.",
      platformDetails,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "\"$eventName\" için hatırlatıcı kuruldu."),
          backgroundColor: kRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
    _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      // EventsPage'de drawer YOK
      appBar: AppBar(title: const Text("ETKİNLİK TAKVİMİ")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            locale: 'tr_TR',
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: kRed,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: kRed,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: kGold,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(),
          if (selectedEvents.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available,
                        size: 50, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text(
                      'Bu gün için etkinlik yok',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: selectedEvents.length,
                itemBuilder: (_, i) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child:
                      const Icon(Icons.event, color: kRed),
                    ),
                    title: Text(
                      selectedEvents[i]['title']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                    Text(selectedEvents[i]['desc']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.alarm_add,
                          color: Colors.blue),
                      onPressed: () => _setReminder(
                          selectedEvents[i]['title']!),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   FAVORİLER
   ═══════════════════════════════════════════════════ */

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('favorites');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("KAYDEDİLENLER"),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          final items = b.values.toList();
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text(
                    'Henüz bir içerik kaydetmediniz.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final post = items[i];
              final imgUrl = ApiService.getFeaturedImage(post);
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: imgUrl != null
                        ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      httpHeaders: kImageHeaders,
                    )
                        : Container(
                      color: kRed.withOpacity(0.1),
                      child: const Icon(Icons.bookmark,
                          color: kRed),
                    ),
                  ),
                ),
                title: Text(
                  fixEncoding(post['title']['rendered']),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  onPressed: () => b.delete(post['id']),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PostDetailPage(post: post)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════
   AYARLAR
   ═══════════════════════════════════════════════════ */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SettingsPage'de drawer YOK
      appBar: AppBar(title: const Text("AYARLAR")),
      body: ListView(
        children: [
          ValueListenableBuilder(
            valueListenable:
            Hive.box('settings').listenable(),
            builder: (context, b, _) => SwitchListTile(
              title: const Text("Koyu Tema"),
              secondary: const Icon(Icons.dark_mode),
              value: b.get('isDarkTheme', defaultValue: false),
              activeColor: kRed,
              onChanged: (v) => b.put('isDarkTheme', v),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active,
                color: kRed),
            title: const Text("Anlık Bildirimler (Push)"),
            subtitle: const Text(
                "Yeni içerikler eklendiğinde haber ver"),
            trailing: Switch(
              value: true,
              activeColor: kRed,
              onChanged: (val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          "Bildirim tercihleri güncellendi.")),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmarks, color: kRed),
            title: const Text("Kaydedilen İçerikler"),
            trailing:
            const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FavoritesPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail, color: kRed),
            title: const Text("Bize Ulaşın"),
            trailing:
            const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ContactPage()),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              "SOSYAL MEDYA",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          _social(context, Icons.camera_alt, "Instagram",
              "https://www.instagram.com/alevitischestiftung/"),
          _social(context, Icons.facebook, "Facebook",
              "https://www.facebook.com/alevivakfi/"),
          _social(context, Icons.play_circle_fill, "YouTube",
              "https://www.youtube.com/@uadevakfi/videos"),
          _social(context, Icons.alternate_email, "X (Twitter)",
              "https://x.com/UADEVAKFI"),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              "WEB SİTEMİZ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language, color: kRed),
            title: const Text("alevi-vakfi.com"),
            subtitle: const Text("Uygulama içinde aç"),
            trailing:
            const Icon(Icons.open_in_new, size: 16),
            onTap: () =>
                openWebPage(context, kBaseUrl, 'Web Sitemiz'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                "ULUSLARARASI ALEVİ VAKFI\nResmi Mobil Uygulaması v2.0",
                textAlign: TextAlign.center,
                style:
                TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _social(BuildContext context, IconData icon,
      String title, String url) {
    return ListTile(
      leading: Icon(icon, color: kRed),
      title: Text(title),
      trailing:
      const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => openWebPage(context, url, title),
    );
  }
}

/* ═══════════════════════════════════════════════════
   İLETİŞİM
   ═══════════════════════════════════════════════════ */

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("İLETİŞİM"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.location_on,
                      color: kRed, size: 30),
                  const SizedBox(height: 8),
                  const Text(
                    'Herforder Str. 46 D 33602 Bielefeld',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text('+49 521 329 70 90',
                      style: TextStyle(color: Colors.grey)),
                  const Text('post@alevi-vakfi.org',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Ad Soyad",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "E-posta",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: "Mesajınız",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Mesajınız iletildi. Teşekkürler!"),
                      backgroundColor: kRed,
                    ),
                  );
                  _nameCtrl.clear();
                  _emailCtrl.clear();
                  _msgCtrl.clear();
                },
                child: const Text(
                  "GÖNDER",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
