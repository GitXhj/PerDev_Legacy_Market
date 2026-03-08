// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _userApiBaseUrl = 'YOUR_USER_API_BASE_URL_HERE';
const String _loginWebUrl = 'YOUR_LOGIN_WEB_URL_HERE';
const String _getUserInfoUrl = '$_userApiBaseUrl/user.php';

const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

class User {
  final int id;
  final String username;
  final String email;
  final String avatar;
  final String signature;
  final int coins;
  final int experience;
  final int level;
  final bool isReviewer;
  final String title;
  final String? vipUntil;
  final bool isVip;
  final String createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.signature,
    required this.coins,
    required this.experience,
    required this.level,
    required this.isReviewer,
    required this.title,
    this.vipUntil,
    required this.isVip,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      signature: json['signature']?.toString() ?? '',
      coins: int.tryParse(json['coins']?.toString() ?? '0') ?? 0,
      experience: int.tryParse(json['experience']?.toString() ?? '0') ?? 0,
      level: int.tryParse(json['level']?.toString() ?? '0') ?? 0,
      isReviewer: json['is_reviewer'] == true || json['is_reviewer'] == 1,
      title: json['title']?.toString() ?? '',
      vipUntil: json['vip_until']?.toString(),
      isVip: json['is_vip'] == true || json['is_vip'] == 1,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class UserApiService {
  static Future<User?> getUserInfo() async {
    try {
      final token = await _secureStorage.read(key: 'user_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(_getUserInfoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (responseBody['success'] == true && responseBody['data'] != null) {
          return User.fromJson(responseBody['data']);
        }
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
    return null;
  }

  static Future<void> saveLoginInfo(String token, User user) async {
    await _secureStorage.write(key: 'user_token', value: token);
    await _secureStorage.write(key: 'user_info', value: jsonEncode(user.toJson()));
  }

  static Future<void> clearLoginInfo() async {
    await _secureStorage.delete(key: 'user_token');
    await _secureStorage.delete(key: 'user_info');
  }

  static Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: 'user_token');
    return token != null;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('PerDevApp/1.0.0 (Flutter WebView)')
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleWebMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_loginWebUrl));
  }

  void _handleWebMessage(JavaScriptMessage message) async {
    try {
      final Map<String, dynamic> data = jsonDecode(message.message);
      
      if (data['type'] == 'login_success') {
        final String token = data['token'];
        final Map<String, dynamic> userJson = data['user'];
        final User user = User.fromJson(userJson);
        
        await UserApiService.saveLoginInfo(token, user);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('欢迎回来，${user.username}！'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          Navigator.pop(context, true);
        }
      } else if (data['type'] == 'login_error') {
        final String errorMessage = data['message'] ?? '登录失败';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('处理Web消息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '登录/注册',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasError)
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                _initializeWebView();
              },
              tooltip: '重新加载',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            _buildErrorView()
          else
            WebViewWidget(controller: _webViewController),
          if (_isLoading) _buildLoadingView(),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '正在加载登录页面...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '网络连接失败',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请检查您的网络连接并重试',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  _initializeWebView();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension UserExtension on User {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'signature': signature,
      'coins': coins,
      'experience': experience,
      'level': level,
      'is_reviewer': isReviewer,
      'title': title,
      'vip_until': vipUntil,
      'is_vip': isVip,
      'created_at': createdAt,
    };
  }
}
