// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'login.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _isLoggedIn = false;
  User? _currentUser;
  final int _unreadUpdatesCount = 3;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await UserApiService.isLoggedIn();
    if (isLoggedIn) {
      final user = await UserApiService.getUserInfo();
      if (mounted) {
        setState(() {
          _isLoggedIn = user != null;
          _currentUser = user;
        });
      }
    }
  }

  Future<void> _handleLoginLogout() async {
    if (_isLoggedIn) {
      // 退出登录
      await UserApiService.clearLoginInfo();
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已退出登录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // 跳转到登录页面
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      
      // 如果登录成功，刷新页面状态
      if (result == true) {
        _checkLoginStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildSmallTopAppBar(),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildUserProfileSection(context),
              const SizedBox(height: 24),
              _buildFeatureList(context),
              const SizedBox(height: 24),
              _buildActionButton(context),
              const SizedBox(height: 80), // 底部留白，防止被导航栏遮挡
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTopAppBar() {
    return SliverAppBar(
      pinned: true,
      centerTitle: true,
      title: Text(
        '我的',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            debugPrint('点击设置');
          },
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoggedIn ? null : _handleLoginLogout,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _currentUser?.avatar.isNotEmpty == true
                    ? ClipOval(
                        child: Image.network(
                          _currentUser!.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_circle,
                              size: 90,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.account_circle,
                        size: 90,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.onPrimaryContainer,
                    Theme.of(context).colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  _isLoggedIn 
                      ? '欢迎回来，${_currentUser?.username ?? '用户'}！' 
                      : '欢迎来到PerDev！',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // 颜色会被ShaderMask覆盖
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoggedIn 
                    ? (_currentUser?.signature.isNotEmpty == true 
                        ? _currentUser!.signature 
                        : '点击查看个人资料')
                    : '点击登录/注册',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isLoggedIn && _currentUser != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildAchievementChip(context, '金币: ${_currentUser!.coins}', Icons.monetization_on),
                    _buildAchievementChip(context, 'Lv.${_currentUser!.level}', Icons.star),
                    _buildAchievementChip(context, '经验: ${_currentUser!.experience}', Icons.trending_up),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildAchievementChip(context, '已安装应用: 10个', Icons.apps),
                    _buildAchievementChip(context, '收藏: 5个', Icons.star),
                    _buildAchievementChip(context, '启动: 100次', Icons.play_arrow),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementChip(
      BuildContext context, String text, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text(text),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildFeatureListItem(
            context,
            Icons.download_for_offline_outlined,
            '我的下载',
            trailingWidget: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('我的下载'),
          ),
          _buildFeatureListItem(
            context,
            Icons.system_update_alt_outlined,
            '应用更新',
            trailingWidget: _unreadUpdatesCount > 0
                ? Chip(
                    label: Text('$_unreadUpdatesCount'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('应用更新'),
          ),
          _buildFeatureListItem(
            context,
            Icons.star_border_outlined,
            '我的收藏',
            trailingWidget: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('我的收藏'),
          ),
          _buildFeatureListItem(
            context,
            Icons.history_outlined,
            '浏览历史',
            trailingWidget: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('浏览历史'),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildFeatureListItem(
            context,
            Icons.help_outline,
            '帮助与反馈',
            trailingWidget: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('帮助与反馈'),
          ),
          _buildFeatureListItem(
            context,
            Icons.info_outline,
            '关于PerDev',
            trailingWidget: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () => debugPrint('关于PerDev'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureListItem(
      BuildContext context, IconData icon, String title,
      {Widget? trailingWidget, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (trailingWidget != null) trailingWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: OutlinedButton(
        onPressed: _handleLoginLogout,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          foregroundColor: Theme.of(context).colorScheme.primary,
          textStyle: Theme.of(context).textTheme.titleMedium,
        ),
        child: Text(_isLoggedIn ? '退出登录' : '登录/注册'),
      ),
    );
  }
}
