import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:perdev/main.dart';
import 'package:perdev/appdetail.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';
  String _searchType = 'app';
  List<dynamic> _searchResults = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoading) {
      _loadMoreResults();
    }
  }

  void _performSearch({bool isNewSearch = true}) async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    if (isNewSearch) {
      _currentPage = 1;
      _searchResults = [];
      _hasMore = true;
    } else if (!_hasMore) {
      return;
    }

    setState(() {
      _isLoading = true;
      _currentQuery = _searchController.text;
    });

    try {
      final response = await ApiService.search(
          _currentQuery, _searchType, _currentPage);
      final List<dynamic> newItems = response['data'] ?? [];
      final int totalPages = response['totalPages'] ?? 1;

      if (mounted) {
        setState(() {
          _searchResults.addAll(newItems);
          _totalPages = totalPages;
          _currentPage++;
          _hasMore = _currentPage <= _totalPages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('搜索失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜索失败，请稍后再试。')),
        );
      }
    }
  }

  void _loadMoreResults() {
    if (_hasMore && !_isLoading) {
      _performSearch(isNewSearch: false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _currentQuery = '';
      _hasMore = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索应用或小程序',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {});
          },
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('应用'),
                  selected: _searchType == 'app',
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _searchType = 'app';
                        _performSearch();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('小程序'),
                  selected: _searchType == 'wp',
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _searchType = 'wp';
                        _performSearch();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && _searchResults.isEmpty) {
      return _buildShimmerGrid();
    } else if (_searchResults.isEmpty && _currentQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied_outlined, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '没有找到相关结果',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请尝试其他关键词或调整筛选条件。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_searchResults.isEmpty && _currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '开始搜索',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '输入关键词查找应用或小程序。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _searchResults.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return _buildLoadingIndicator();
        }
        final item = _searchResults[index];
        if (item is App) {
          return SearchAppCard(app: item);
        } else if (item is MiniProgram) {
          return SearchMiniProgramCard(miniProgram: item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 12,
                    color: Colors.white,
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 36,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SearchAppCard extends StatelessWidget {
  final App app;

  const SearchAppCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'app_icon_${app.name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: app.icon,
                    width: 64,
                    height: 64,
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
                    ApiService.incrementLaunchCount('app', app.name);
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
    );
  }
}

class SearchMiniProgramCard extends StatelessWidget {
  final MiniProgram miniProgram;

  const SearchMiniProgramCard({super.key, required this.miniProgram});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/miniProgramViewer', arguments: miniProgram);
        },
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
                    width: 64,
                    height: 64,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    ApiService.incrementLaunchCount('wp', miniProgram.name);
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
    );
  }
}
