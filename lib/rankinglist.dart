import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:perdev/main.dart';
import 'package:perdev/appdetail.dart';

class RankingListPage extends StatefulWidget {
  const RankingListPage({super.key});

  @override
  State<RankingListPage> createState() => _RankingListPageState();
}

class _RankingListPageState extends State<RankingListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'day';
  
  final List<String> _periods = ['day', 'week', 'month', 'total'];
  final Map<String, String> _periodNames = {
    'day': '日榜',
    'week': '周榜',
    'month': '月榜',
    'total': '总榜',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '应用排行'),
            Tab(text: '小程序排行'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardList('app'),
                _buildLeaderboardList('wp'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: _periods.map((period) {
            return ButtonSegment<String>(
              value: period,
              label: Text(_periodNames[period]!),
            );
          }).toList(),
          selected: <String>{_selectedPeriod},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedPeriod = newSelection.first;
            });
          },
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(String type) {
    return FutureBuilder<List<LeaderboardItem>>(
      key: ValueKey('${type}_$_selectedPeriod'),
      future: ApiService.fetchLeaderboard(type, _selectedPeriod),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList();
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  '暂无排行榜数据',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        } else {
          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildRankingItem(context, items[index], index + 1);
            },
          );
        }
      },
    );
  }

  Widget _buildRankingItem(BuildContext context, LeaderboardItem item, int rank) {
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
    Widget rankWidget;
    
    if (rank <= 3) {
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
      
      rankWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: rankColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else {
      rankWidget = Container(
        width: 40,
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: rank <= 3 ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: rankWidget,
        title: Text(
          name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: iconUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheManager: LXFCachedNetworkImageManager(),
         placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 56),
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

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
