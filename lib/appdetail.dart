import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:perdev/main.dart';

class AppDetailPage extends StatelessWidget {
  final App app;

  const AppDetailPage({super.key, required this.app});

  Future<void> _launchDownloadUrl(BuildContext context) async {
    try {
      // 先请求API增加下载量
      bool success = await ApiService.incrementLaunchCount('app', app.name);
      if (success) {
        debugPrint('应用下载量已增加: ${app.name}');
      } else {
        debugPrint('增加下载量失败: ${app.name}');
      }
    } catch (e) {
      debugPrint('增加下载量请求出错: $e');
    }

    // 然后跳转到下载链接
    try {
      final uri = Uri.parse(app.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开下载链接: ${app.downloadUrl}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开下载链接时出错: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Expressive Large App Bar
          SliverAppBar.large(
            expandedHeight: 280,
            stretch: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface.withOpacity(0.5),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred Background Image
                  CachedNetworkImage(
                    imageUrl: app.icon,
                    fit: BoxFit.cover,
                    cacheManager: LXFCachedNetworkImageManager(),
                  ),
                  // Blur Effect
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: colorScheme.surface.withOpacity(0.8),
                    ),
                  ),
                  // Centered Icon
                  Center(
                    child: Hero(
                      tag: 'app_icon_${app.name}',
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: CachedNetworkImage(
                            imageUrl: app.icon,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            cacheManager: LXFCachedNetworkImageManager(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Developer
                  Text(
                    app.name,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.developer,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => _launchDownloadUrl(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text("立即下载 / Install"),
                      style: FilledButton.styleFrom(
                        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Info Grid (Stats)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(context, "版本", app.version, Icons.verified_outlined),
                        _buildVerticalDivider(context),
                        _buildInfoItem(context, "大小", app.size.isEmpty ? "未知" : app.size, Icons.data_usage),
                        _buildVerticalDivider(context),
                        _buildInfoItem(context, "日期", app.releaseDate.isEmpty ? "近期" : app.releaseDate, Icons.calendar_today_outlined),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Description Section
                  Text(
                    "应用介绍",
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    app.description.isNotEmpty ? app.description : "暂无详细介绍。",
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
