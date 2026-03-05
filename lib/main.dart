import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';

// --- YENİ EKLENEN NATIVE PAKETLER ---
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- ONESIGNAL PAKETİ ---
import 'package:onesignal_flutter/onesignal_flutter.dart';

// --- BİLDİRİM KURULUMU (Yerel Hatırlatıcılar İçin) ---
final FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive Veritabanı Başlatma
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');
  await Hive.openBox('favorites');

  // Yerel Bildirim Başlatma (Takvim hatırlatıcıları için)
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true
  );
  const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await localNotificationsPlugin.initialize(initSettings);

  // --- ONESIGNAL BAŞLATMA KODLARI ---
  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    // Kendi OneSignal App ID'n
    OneSignal.initialize("0e1426f3-843b-4e98-8fa2-87ee35839a88");
    // Uygulama açıldığında bildirim izni iste
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint("OneSignal başlatılamadı: $e");
  }

  runApp(const MyApp());
}

/* ---------------- YARDIMCI FONKSİYONLAR ---------------- */

String fixEncoding(String text) {
  return text
      .replaceAll("’", "'")
      .replaceAll("–", "-")
      .replaceAll("“", "\"")
      .replaceAll("”", "\"")
      .replaceAll("&", "&")
      .replaceAll(" ", " ")
      .replaceAll(RegExp(r'ngg_shortcode_\d+_placeholder'), '')
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
  int _currentIndex = 2; // Başlangıçta WebView açılsın (Tam Merkez)

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Apple için konum izinleri
  }

  void _requestPermissions() async {
    try {
      // Bildirim iznini artık OneSignal main() içinde alıyor. Sadece konumu alıyoruz.
      await Geolocator.requestPermission();
    } catch(e) {
      debugPrint("İzin hatası: $e");
    }
  }

  final _pages = [
    const NewsPage(),          // 0: Duyurular
    const CemeviFinderPage(),  // 1: Cemevi Bulucu (Native Harita)
    const WebViewPage(),       // 2: VAKIF WEB (Merkezde)
    const EventsPage(),        // 3: Etkinlik Takvimi (Native Hatırlatıcı)
    const SettingsPage(),      // 4: Ayarlar
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
          NavigationDestination(icon: Icon(Icons.map), label: "Cemevi"),
          NavigationDestination(icon: Icon(Icons.public, size: 30, color: Colors.red), label: "Vakıf Web"),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: "Takvim"),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
          )
        ],
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

/* ---------------- HABER DETAY ---------------- */

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
    final String link = widget.post['link'] ?? "https://www.alevi-vakfi.com/";

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
            icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() {
              isFav ? favBox.delete(widget.post['id']) : favBox.put(widget.post['id'], widget.post);
            })
        ),
        Builder(
          builder: (BuildContext shareContext) {
            return IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                final RenderBox? box = shareContext.findRenderObject() as RenderBox?;
                Share.share(
                  "$title\n\n$link",
                  sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                );
              },
            );
          },
        ),
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

/* ---------------- CEMEVİ BULUCU (NATIVE HARİTA) ---------------- */

class CemeviFinderPage extends StatefulWidget {
  const CemeviFinderPage({super.key});
  @override
  State<CemeviFinderPage> createState() => _CemeviFinderPageState();
}

class _CemeviFinderPageState extends State<CemeviFinderPage> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(51.1657, 10.4515); // Almanya Merkez

  final List<Map<String, dynamic>> cemevleri = [
    {"ad": "Berlin Cemevi", "lat": 52.5200, "lng": 13.4050},
    {"ad": "Köln Cemevi", "lat": 50.9375, "lng": 6.9603},
    {"ad": "Frankfurt Cemevi", "lat": 50.1109, "lng": 8.6821},
    {"ad": "Stuttgart Cemevi", "lat": 48.7758, "lng": 9.1829},
  ];

  Future<void> _findMe() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    Position position = await Geolocator.getCurrentPosition();
    setState(() => _center = LatLng(position.latitude, position.longitude));
    _mapController.move(_center, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YAKINDAKİ CEMEVLERİ")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _center, initialZoom: 6.0),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.alevivakfi.app'),
          MarkerLayer(
            markers: cemevleri.map((c) => Marker(
              point: LatLng(c['lat'], c['lng']), width: 50, height: 50,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c['ad'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.directions),
                                label: const Text("Yol Tarifi Al"),
                                onPressed: () {
                                  final url = "https://www.google.com/maps/search/?api=1&query=${c['lat']},${c['lng']}";
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                            )
                          ],
                        ),
                      )
                  );
                },
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            )).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.red, foregroundColor: Colors.white, onPressed: _findMe, child: const Icon(Icons.my_location)),
    );
  }
}

/* ---------------- ETKİNLİK TAKVİMİ (NATIVE TABLE CALENDAR) ---------------- */

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, List<Map<String, String>>> _events = {
    DateTime.utc(2026, 3, 20): [{"title": "Nevruz Bayramı Kutlaması", "desc": "Nevruz cemi ve lokma paylaşımı."}],
    DateTime.utc(2026, 4, 15): [{"title": "Kültür Paneli", "desc": "Alevi kültürü üzerine panel düzenlenecektir."}],
    DateTime.utc(2026, 5, 6): [{"title": "Hıdırellez Etkinliği", "desc": "Baharı hep birlikte karşılıyoruz."}],
  };

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _setReminder(String eventName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('event_id', 'Etkinlikler', importance: Importance.max, priority: Priority.high);
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await localNotificationsPlugin.show(0, "Hatırlatıcı Kuruldu!", "$eventName için bildirim alacaksınız.", platformDetails);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cihazınıza hatırlatıcı kuruldu.")));
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(title: const Text("ETKİNLİK TAKVİMİ")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) { setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }); },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selectedEvents.length,
              itemBuilder: (context, i) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.event, color: Colors.red),
                  title: Text(selectedEvents[i]['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(selectedEvents[i]['desc']!),
                  trailing: IconButton(icon: const Icon(Icons.alarm_add, color: Colors.blue), onPressed: () => _setReminder(selectedEvents[i]['title']!)),
                ),
              ),
            ),
          )
        ],
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
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.red),
            title: const Text("Anlık Bildirimler (Push)"),
            subtitle: const Text("Yeni içerikler eklendiğinde haber ver"),
            trailing: Switch(value: true, onChanged: (val) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bildirim tercihleri güncellendi.")));
            }),
          ),
          ListTile(
            leading: const Icon(Icons.bookmarks, color: Colors.red),
            title: const Text("Kaydedilen İçerikler"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
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
