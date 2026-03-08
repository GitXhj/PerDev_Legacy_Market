// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' hide State;
import 'package:uuid/uuid.dart';
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'home.dart';
import 'me.dart';
import 'search.dart';
import 'wp.dart';

const String _baseUrl = 'YOUR_API_BASE_URL_HERE';
const String _authApiUrl = '$_baseUrl/auth.php';
const String _carouselApiUrl = '$_baseUrl/getcarousel.php';
const String _appApiUrl = '$_baseUrl/pdapplist.php';
const String _miniProgramApiUrl = '$_baseUrl/pdwpr.php';
const String _searchApiUrl = '$_baseUrl/search.php';
const String _updateApiUrl = '$_baseUrl/update.php';

const String _clientAuthHeaderName = 'X-Client-Auth-Data';
const String _tokenHeaderName = 'Authorization';
const String _tokenHeaderPrefix = 'Bearer ';

const int _nonceLength = 12;

const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

final SecureRandom _secureRandom = FortunaRandom();
bool _isSecureRandomSeeded = false;

String _currentAppVersion = '1.0.0';

class CarouselItem {
  final String image;
  final String title;
  final String description;
  final String link;

  CarouselItem({
    required this.image,
    required this.title,
    required this.description,
    required this.link,
  });

  factory CarouselItem.fromJson(Map<String, dynamic> json) {
    return CarouselItem(
      image: json['image']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
    );
  }
}

class App {
  final String name;
  final String version;
  final String description;
  final String size;
  final String releaseDate;
  final String downloadUrl;
  final String icon;
  final String developer;

  App({
    required this.name,
    required this.version,
    required this.description,
    required this.size,
    required this.releaseDate,
    required this.downloadUrl,
    required this.icon,
    required this.developer,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    return App(
      name: json['name']?.toString() ?? '未知应用',
      version: json['version']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      releaseDate: json['releaseDate']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      developer: json['developer']?.toString() ?? '未知开发者',
    );
  }
}

class MiniProgram {
  final int id;
  final String name;
  final String icon;
  final String url;

  MiniProgram({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
  });

  factory MiniProgram.fromJson(Map<String, dynamic> json) {
    return MiniProgram(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '未知小程序',
      icon: json['icon']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class LeaderboardItem {
  final String name;
  final int count;
  final dynamic details;

  LeaderboardItem({
    required this.name,
    required this.count,
    required this.details,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    dynamic details;
    try {
      if (json['details'] != null && json['details'] is Map) {
        final Map<String, dynamic> detailMap = json['details'];
        if (detailMap.containsKey('version') || detailMap.containsKey('developer')) {
          details = App.fromJson(detailMap);
        } else {
          details = MiniProgram.fromJson(detailMap);
        }
      }
    } catch (e) {
      flutter_material.debugPrint('解析排行榜详情失败: $e');
    }

    return LeaderboardItem(
      name: json['name']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      details: details,
    );
  }
}

class UpdateInfo {
  final String name;
  final String version;
  final String description;
  final String size;
  final String releaseDate;
  final String downloadUrl;
  final String icon;
  final String developer;

  UpdateInfo({
    required this.name,
    required this.version,
    required this.description,
    required this.size,
    required this.releaseDate,
    required this.downloadUrl,
    required this.icon,
    required this.developer,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      releaseDate: json['releaseDate']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      developer: json['developer']?.toString() ?? '',
    );
  }

  int compareVersion(String otherVersion) {
    try {
      final currentParts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final otherParts = otherVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < max(currentParts.length, otherParts.length); i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final other = i < otherParts.length ? otherParts[i] : 0;

        if (current < other) return -1;
        if (current > other) return 1;
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    (context ??= SecurityContext.defaultContext)
        .allowLegacyUnsafeRenegotiation = true;
    return super.createHttpClient(context);
  }
}

class LXFCachedNetworkImageManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData';

  static final LXFCachedNetworkImageManager _instance =
      LXFCachedNetworkImageManager._();

  factory LXFCachedNetworkImageManager() {
    return _instance;
  }

  LXFCachedNetworkImageManager._()
      : super(
          Config(
            key,
            fileService: HttpFileService(
              httpClient: IOClient(
                HttpClient(
                  context: (SecurityContext.defaultContext
                    ..allowLegacyUnsafeRenegotiation = true),
                ),
              ),
            ),
          ),
        );
}

void _seedSecureRandom() {
  if (!_isSecureRandomSeeded) {
    final Uint8List seed = Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
    _secureRandom.seed(KeyParameter(seed));
    _isSecureRandomSeeded = true;
  }
}

Future<String> getInstallationId() async {
  String? installationId = await _secureStorage.read(key: 'installation_id');
  if (installationId == null) {
    installationId = const Uuid().v4();
    await _secureStorage.write(key: 'installation_id', value: installationId);
  }
  return installationId;
}

Future<String?> authenticateClient() async {
  _seedSecureRandom();

  String? secretKeyBase64 =
      await _secureStorage.read(key: 'chacha20_poly1305_key');
  if (secretKeyBase64 == null) {
    flutter_material.debugPrint('错误: ChaCha20-Poly1305 密钥未在安全存储中找到。');
    return null;
  }
  final Uint8List secretKey = base64Decode(secretKeyBase64);

  if (secretKey.length != 32) {
    flutter_material.debugPrint('错误: 密钥长度无效。');
    return null;
  }

  try {
    final String installationId = await getInstallationId();
    final int clientTimestamp =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final String plaintext = '$clientTimestamp-$installationId';
    final Uint8List plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final Uint8List nonce = _secureRandom.nextBytes(_nonceLength);

    final AEADCipher cipher = AEADCipher('ChaCha20-Poly1305');

    cipher.init(
      true,
      AEADParameters(
        KeyParameter(secretKey),
        128,
        nonce,
        Uint8List(0),
      ),
    );

    final Uint8List ciphertextWithTag = cipher.process(plaintextBytes);

    final String encodedCiphertext = base64Encode(ciphertextWithTag);
    final String encodedNonce = base64Encode(nonce);

    final String authHeaderValue = '$encodedCiphertext.$encodedNonce';
    final response = await http.post(
      Uri.parse(_authApiUrl),
      headers: {
        'Content-Type': 'application/json',
        _clientAuthHeaderName: authHeaderValue,
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['status'] == 'success') {
        final String? token = responseBody['token'];
        if (token != null) {
          await _secureStorage.write(key: 'auth_token', value: token);
          return token;
        }
      }
    }
    return null;
  } catch (e) {
    flutter_material.debugPrint('认证错误: $e');
    return null;
  }
}

extension AeadCipherProcessExt on AEADCipher {
  Uint8List process(Uint8List plaintextBytes) {
    final out = Uint8List(plaintextBytes.length + 16);
    final len = processBytes(plaintextBytes, 0, plaintextBytes.length, out, 0);
    final finalLen = doFinal(out, len);
    return out.sublist(0, len + finalLen);
  }
}

Future<http.Response?> makeAuthenticatedApiCall(String url,
    {Map<String, dynamic>? body, String method = 'GET'}) async {
  String? authToken = await _secureStorage.read(key: 'auth_token');

  if (authToken == null) {
    authToken = await authenticateClient();
    if (authToken == null) return null;
  }

  Map<String, String> headers = {
    'Content-Type': 'application/json',
    _tokenHeaderName: '$_tokenHeaderPrefix$authToken',
  };

  try {
    http.Response response;
    final uri = Uri.parse(url);

    if (method.toUpperCase() == 'POST') {
      response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    } else if (method.toUpperCase() == 'PUT') {
      response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
    } else if (method.toUpperCase() == 'DELETE') {
      response = await http.delete(uri, headers: headers, body: jsonEncode(body ?? {}));
    } else {
      response = await http.get(uri, headers: headers);
    }

    if (response.statusCode == 200) {
      return response;
    } else if (response.statusCode == 401) {
      await _secureStorage.delete(key: 'auth_token');
      authToken = await authenticateClient();
      if (authToken != null) {
        headers[_tokenHeaderName] = '$_tokenHeaderPrefix$authToken';
        if (method.toUpperCase() == 'POST') {
          response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        } else if (method.toUpperCase() == 'PUT') {
          response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
        } else if (method.toUpperCase() == 'DELETE') {
          response = await http.delete(uri, headers: headers, body: jsonEncode(body ?? {}));
        } else {
          response = await http.get(uri, headers: headers);
        }
        if (response.statusCode == 200) return response;
      }
      return null;
    } else {
      return null;
    }
  } catch (e) {
    flutter_material.debugPrint('API调用错误: $e');
    return null;
  }
}

class ApiService {
  static Future<List<CarouselItem>> fetchCarouselItems() async {
    try {
      final response = await makeAuthenticatedApiCall(_carouselApiUrl);
      if (response != null && response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => CarouselItem.fromJson(json)).toList();
      }
    } catch (e) {
      flutter_material.debugPrint('获取轮播图失败: $e');
    }
    return [];
  }

  static Future<List<App>> fetchRandomApps(int count) async {
    try {
      final response = await makeAuthenticatedApiCall('$_appApiUrl?random=$count');
      if (response != null && response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => App.fromJson(json)).toList();
      }
    } catch (e) {
      flutter_material.debugPrint('获取随机应用失败: $e');
    }
    return [];
  }

  static Future<List<App>> fetchPagedApps(int page) async {
    try {
      final response = await makeAuthenticatedApiCall('$_appApiUrl?page=$page');
      if (response != null && response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => App.fromJson(json)).toList();
      }
    } catch (e) {
      flutter_material.debugPrint('获取应用列表失败: $e');
    }
    return [];
  }

  static Future<List<LeaderboardItem>> fetchLeaderboard(
      String type, String period) async {
    try {
      String url;
      if (type == 'app') {
        url = '$_miniProgramApiUrl?app_$period';
      } else {
        url = '$_miniProgramApiUrl?wp_$period';
      }

      final response = await makeAuthenticatedApiCall(url);
      if (response != null && response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          return (jsonResponse['data'] as List)
              .map((json) => LeaderboardItem.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      flutter_material.debugPrint('获取排行榜失败: $e');
    }
    return [];
  }

  static Future<bool> incrementLaunchCount(String type, String name) async {
    try {
      String url;
      if (type == 'app') {
        url = '$_miniProgramApiUrl?app=$name';
      } else {
        url = '$_miniProgramApiUrl?wp=$name';
      }
      final response = await makeAuthenticatedApiCall(url);
      return response != null && response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> search(
      String query, String type, int page) async {
    try {
      String url;
      if (type == 'app') {
        url = '$_searchApiUrl?q=$query&page=$page';
      } else {
        url = '$_searchApiUrl?wp=$query&page=$page';
      }
      
      final response = await makeAuthenticatedApiCall(Uri.encodeFull(url));
      
      if (response != null && response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> rawData = body['data'] ?? [];
        List<dynamic> parsedData = [];

        if (type == 'app') {
          parsedData = rawData.map((json) => App.fromJson(json)).toList();
        } else {
          parsedData = rawData.map((json) => MiniProgram.fromJson(json)).toList();
        }

        return {
          'data': parsedData,
          'totalPages': body['totalPages'] ?? 1,
          'totalItems': body['totalItems'] ?? 0,
        };
      }
    } catch (e) {
      flutter_material.debugPrint('搜索出错: $e');
    }
    return {'data': [], 'totalItems': 0, 'totalPages': 0, 'currentPage': 0};
  }

  static Future<UpdateInfo?> fetchLatestUpdate() async {
    try {
      final response = await makeAuthenticatedApiCall(_updateApiUrl);
      if (response != null && response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonList.isNotEmpty) {
          return UpdateInfo.fromJson(jsonList.first);
        }
      }
    } catch (e) {
      flutter_material.debugPrint('检查更新失败: $e');
    }
    return null;
  }
}

Future<void> _initializeSecureStorage() async {
  String? existingKey = await _secureStorage.read(key: 'chacha20_poly1305_key');
  if (existingKey == null) {
    flutter_material.debugPrint('请配置加密密钥');
  }
}

Future<void> main() async {
  flutter_material.WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await _initializeSecureStorage();

  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  _currentAppVersion = packageInfo.version;
  flutter_material.debugPrint('当前应用版本: $_currentAppVersion');

  flutter_material.runApp(const MyApp());
}

class MyApp extends flutter_material.StatefulWidget {
  const MyApp({super.key});

  @override
  flutter_material.State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends flutter_material.State<MyApp> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _authFailed = false;
  UpdateInfo? _latestUpdate;

  final List<flutter_material.Widget> _pages = <flutter_material.Widget>[
    const HomePage(),
    const MePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAuthAndCheckForUpdates();
  }

  Future<void> _initializeAuthAndCheckForUpdates() async {
    final String? token = await authenticateClient();
    if (token == null) {
      if (mounted) {
        setState(() {
          _authFailed = true;
          _isLoading = false;
        });
      }
      return;
    }

    final latestUpdate = await ApiService.fetchLatestUpdate();
    if (latestUpdate != null &&
        latestUpdate.compareVersion(_currentAppVersion) > 0) {
        
      bool forceUpdate = false;
      try {
        final currentVersionParts = _currentAppVersion.split('.').map(int.parse).toList();
        final latestVersionParts = latestUpdate.version.split('.').map(int.parse).toList();
        
        if (latestVersionParts.isNotEmpty && currentVersionParts.isNotEmpty) {
           if (latestVersionParts[0] > currentVersionParts[0] + 3) {
             forceUpdate = true;
           }
        }
      } catch(e) {
        // ignore
      }

      if (forceUpdate) {
        if (mounted) {
          setState(() {
            _latestUpdate = latestUpdate;
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  flutter_material.Widget build(flutter_material.BuildContext context) {
    if (_isLoading) {
      return flutter_material.MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: flutter_material.ThemeData(
          colorSchemeSeed: flutter_material.Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const flutter_material.Scaffold(
          body: flutter_material.Center(child: flutter_material.CircularProgressIndicator()),
        ),
      );
    }

    if (_authFailed) {
      return flutter_material.MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: flutter_material.ThemeData(
          colorSchemeSeed: flutter_material.Colors.deepPurple,
          useMaterial3: true,
        ),
        home: flutter_material.Scaffold(
          body: flutter_material.Center(
            child: flutter_material.Column(
              mainAxisAlignment: flutter_material.MainAxisAlignment.center,
              children: [
                flutter_material.Icon(flutter_material.Icons.error_outline, size: 64, color: flutter_material.Colors.redAccent),
                const flutter_material.SizedBox(height: 16),
                flutter_material.Text(
                  '认证失败',
                  style: flutter_material.Theme.of(context).textTheme.headlineSmall,
                ),
                const flutter_material.SizedBox(height: 8),
                const flutter_material.Text('检查你的网络连接或寻求帮助'),
                const flutter_material.SizedBox(height: 24),
                flutter_material.ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _authFailed = false;
                    });
                    _initializeAuthAndCheckForUpdates();
                  },
                  icon: const flutter_material.Icon(flutter_material.Icons.refresh),
                  label: const flutter_material.Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_latestUpdate != null) {
      return flutter_material.MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: flutter_material.ThemeData(
          colorSchemeSeed: flutter_material.Colors.deepPurple,
          useMaterial3: true,
        ),
        home: flutter_material.Scaffold(
          body: flutter_material.Center(
            child: flutter_material.Padding(
              padding: const flutter_material.EdgeInsets.all(24.0),
              child: flutter_material.Column(
                mainAxisAlignment: flutter_material.MainAxisAlignment.center,
                children: [
                  flutter_material.Icon(flutter_material.Icons.system_update_alt, size: 80, color: flutter_material.Theme.of(context).colorScheme.primary),
                  const flutter_material.SizedBox(height: 24),
                  flutter_material.Text(
                    '发现新版本: ${_latestUpdate!.version}',
                    style: flutter_material.Theme.of(context).textTheme.headlineSmall,
                    textAlign: flutter_material.TextAlign.center,
                  ),
                  const flutter_material.SizedBox(height: 16),
                  flutter_material.Text(
                    '当前版本: $_currentAppVersion\n\n${_latestUpdate!.description}',
                    textAlign: flutter_material.TextAlign.center,
                    style: flutter_material.Theme.of(context).textTheme.bodyLarge,
                  ),
                  const flutter_material.SizedBox(height: 32),
                  flutter_material.FilledButton.icon(
                    onPressed: () {
                      flutter_material.debugPrint('前往下载: ${_latestUpdate!.downloadUrl}');
                    },
                    icon: const flutter_material.Icon(flutter_material.Icons.download),
                    label: const flutter_material.Text('立即更新'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return flutter_material.MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PerDev',
      theme: flutter_material.ThemeData(
        colorSchemeSeed: flutter_material.Colors.deepPurple,
        useMaterial3: true,
        fontFamily: 'NotoSansSC',
      ),
      home: flutter_material.Scaffold(
        extendBody: true,
        body: _pages[_selectedIndex],
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
      routes: {
        '/search': (context) => const SearchPage(),
        '/miniProgramViewer': (context) => const MiniProgramViewerPage(),
      },
    );
  }

  flutter_material.Widget _buildBottomNavigationBar(flutter_material.BuildContext context) {
    return flutter_material.NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      elevation: 8,
      indicatorColor: flutter_material.Theme.of(context).colorScheme.primaryContainer,
      destinations: const <flutter_material.NavigationDestination>[
        flutter_material.NavigationDestination(
          selectedIcon: flutter_material.Icon(flutter_material.Icons.storefront),
          icon: flutter_material.Icon(flutter_material.Icons.storefront_outlined),
          label: '市集',
        ),
        flutter_material.NavigationDestination(
          selectedIcon: flutter_material.Icon(flutter_material.Icons.person),
          icon: flutter_material.Icon(flutter_material.Icons.person_outlined),
          label: '我的',
        ),
      ],
    );
  }
}
