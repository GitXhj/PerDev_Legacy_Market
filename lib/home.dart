// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:perdev/main.dart';
import 'package:perdev/appdetail.dart';
import 'package:perdev/rankinglist.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<CarouselItem>> _carouselItemsFuture;
  late Future<List<App>> _youMightLikeAppsFuture;
  late Future<List<LeaderboardItem>> _discoverMiniProgramsFuture;
  late Future<List<LeaderboardItem>> _leaderboardAppsDayFuture;
  late Future<List<LeaderboardItem>> _leaderboardMiniProgramsDayFuture;

  final PageController _carouselController = PageController();
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  void _fetchData() {
    _carouselItemsFuture = ApiService.fetchCarouselItems();
    _youMightLikeAppsFuture = ApiService.fetchRandomApps(5);
    _discoverMiniProgramsFuture = ApiService.fetchLeaderboard('wp', 'month');
    _leaderboardAppsDayFuture = ApiService.fetchLeaderboard('app', 'day');
    _leaderboardMiniProgramsDayFuture = ApiService.fetchLeaderboard('wp', 'day');
  }

  void _refreshYouMightLikeApps() {
    setState(() {
      _youMightLikeAppsFuture = ApiService.fetchRandomApps(5);
    });
  }

  void _refreshDiscoverMiniPrograms() {
    setState(() {
      _discoverMiniProgramsFuture = ApiService.fetchLeaderboard('wp', 'month');
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildLargeTopAppBar(),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCarouselSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, '猜你喜欢', _refreshYouMightLikeApps,
                  actionText: '刷新'),
              _buildHorizontalAppList(_youMightLikeAppsFuture),
              const SizedBox(height: 32),
              _buildSectionTitle(context, '发现更多小程序',
                  _refreshDiscoverMiniPrograms,
                  actionText: '刷新'),
              _buildHorizontalMiniProgramList(_discoverMiniProgramsFuture),
              const SizedBox(height: 32),
              _buildSectionTitle(context, '今日排行榜', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RankingListPage(),
                  ),
                );
              }),
              _buildTodayLeaderboardSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeTopAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      snap: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
        centerTitle: false,
        title: Text(
          'PerDev',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            Navigator.pushNamed(context, '/search');
          },
          tooltip: '搜索',
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            // Notification logic
          },
          tooltip: '通知',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCarouselSection() {
    return FutureBuilder<List<CarouselItem>>(
      future: _carouselItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCarouselShimmer();
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text('加载轮播图失败: ${snapshot.error}')),
                  ],
                ),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        } else {
          final items = snapshot.data!;
          return _buildMaterial3Carousel(items);
        }
      },
    );
  }

  Widget _buildMaterial3Carousel(List<CarouselItem> items) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildCarouselItem(context, items[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (items.length > 1) _buildCarouselIndicator(items.length),
      ],
    );
  }

  Widget _buildCarouselIndicator(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentCarouselIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentCarouselIndex == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(BuildContext context, CarouselItem item) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (item.link.isNotEmpty) {
            try {
              final uri = Uri.parse(item.link);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                debugPrint('无法打开链接: ${item.link}');
              }
            } catch (e) {
              debugPrint('链接打开失败: $e');
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.image,
              fit: BoxFit.cover,
              cacheManager: LXFCachedNetworkImageManager(),
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '图片加载失败',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.title.isNotEmpty)
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                  ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (item.link.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '点击查看',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title,
      VoidCallback? onActionTap,
      {String actionText = '查看更多'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          if (onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionText,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalAppList(Future<List<App>> future,
      {bool isHero = false}) {
    return FutureBuilder<List<App>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHorizontalShimmerList(isApp: true);
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('加载应用失败: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('暂无应用数据'),
          );
        } else {
          final apps = snapshot.data!;
          return SizedBox(
            height: isHero ? 200 : 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: AppCard(app: app, isHero: isHero && index == 0),
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildHorizontalMiniProgramList(
      Future<List<LeaderboardItem>> future) {
    return FutureBuilder<List<LeaderboardItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHorizontalShimmerList(isApp: false);
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('加载小程序失败: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('暂无小程序数据'),
          );
        } else {
          final miniPrograms = snapshot.data!
              .where((item) => item.details is MiniProgram)
              .map((item) => item.details as MiniProgram)
              .toList();
          return SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: miniPrograms.length,
              itemBuilder: (context, index) {
                final mp = miniPrograms[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: MiniProgramCard(miniProgram: mp),
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildHorizontalShimmerList({required bool isApp}) {
    return SizedBox(
      height: isApp ? 180 : 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: isApp ? 140 : 120,
              height: isApp ? 180 : 160,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayLeaderboardSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildTodayLeaderboard('应用日榜', _leaderboardAppsDayFuture),
          const SizedBox(height: 24),
          _buildTodayLeaderboard('小程序日榜', _leaderboardMiniProgramsDayFuture),
        ],
      ),
    );
  }

  Widget _buildTodayLeaderboard(String title, Future<List<LeaderboardItem>> future) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        FutureBuilder<List<LeaderboardItem>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLeaderboardShimmer(3);
            } else if (snapshot.hasError) {
              return Text('加载排行榜失败: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('暂无排行榜数据');
            } else {
              final items = snapshot.data!.take(3).toList();
              return Column(
                children: items.asMap().entries.map((entry) {
                  return _buildCompactLeaderboardItem(context, entry.value, entry.key + 1);
                }).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCompactLeaderboardItem(BuildContext context, LeaderboardItem item, int rank) {
    String iconUrl = '';
    String name = item.name;
    String subtitle = '';
    
    if (item.details is App) {
      iconUrl = (item.details as App).icon;
      subtitle = (item.details as App).developer;
    } else if (item.details is MiniProgram) {
      iconUrl = (item.details as MiniProgram).icon;
      subtitle = '${item.count} 次启动';
    }

    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber.shade700;
        break;
      case 2:
        rankColor = Colors.grey.shade500;
        break;
      case 3:
        rankColor = Colors.brown.shade400;
        break;
      default:
        rankColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
        ),
        title: Text(
          name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: iconUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            cacheManager: LXFCachedNetworkImageManager(),
            placeholder: (context, url) => Container(color: Colors.grey[200]),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 48),
          ),
        ),
        onTap: () {
          if (item.details is App) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppDetailPage(app: item.details as App),
              ),
            );
          } else if (item.details is MiniProgram) {
            Navigator.pushNamed(context, '/miniProgramViewer', arguments: item.details);
          }
        },
      ),
    );
  }

  Widget _buildLeaderboardShimmer(int count) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          count,
          (index) => Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final App app;
  final bool isHero;

  const AppCard({super.key, required this.app, this.isHero = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppDetailPage(app: app),
            ),
          );
        },
        child: SizedBox(
          width: isHero ? 180 : 140,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: isHero ? 'app_icon_${app.name}' : 'app_icon_${app.name}_list',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: app.icon,
                      width: isHero ? 80 : 64,
                      height: isHero ? 80 : 64,
                      fit: BoxFit.cover,
                      cacheManager: LXFCachedNetworkImageManager(),
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  app.developer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppDetailPage(app: app),
                        ),
                      );
                    },
                    child: const Text('安装'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MiniProgramCard extends StatelessWidget {
  final MiniProgram miniProgram;

  const MiniProgramCard({super.key, required this.miniProgram});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/miniProgramViewer', arguments: miniProgram);
        },
        child: SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'mp_icon_${miniProgram.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: miniProgram.icon,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      cacheManager: LXFCachedNetworkImageManager(),
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  miniProgram.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/miniProgramViewer', arguments: miniProgram);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}