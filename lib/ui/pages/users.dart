import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/cached_image.dart';

class Users extends StatefulWidget {
  const Users({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _UsersState createState() => _UsersState();
}

class _UsersState extends State<Users> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // 分页参数
  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreUsers();
      }
    }
  }

  Future<void> _loadUsers({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _users.clear();
        _hasMoreData = true;
        _errorMessage = null;
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://xxx/getaliuser'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'page': _currentPage, 'count': _pageSize}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['code'] == 200) {
          final message = data['message'];
          final usersData = message['data'] as List;
          final total = message['total'] ?? 0;
          final currentPage = message['current_page'] ?? 1;
          final lastPage = message['last_page'] ?? 1;

          final users = usersData
              .map((user) => UserModel.fromJson(user))
              .toList();

          setState(() {
            if (isRefresh) {
              _users = users;
            } else {
              _users.addAll(users);
            }
            _isLoading = false;
            _hasMoreData = currentPage < lastPage;

            if (kDebugMode) {
              print(
                '📄 分页信息: 当前页=$currentPage, 总页数=$lastPage, 总数=$total, 本页数据=${users.length}',
              );
            }
          });
        } else {
          setState(() {
            _errorMessage = '获取用户数据失败: ${data['message'] ?? '未知错误'}';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP请求失败: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载用户数据失败: $e');
      }
      setState(() {
        _errorMessage = '网络请求异常: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await http.post(
        Uri.parse('https://xxx/getaliuser'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'page': nextPage, 'count': _pageSize}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['code'] == 200) {
          final message = data['message'];
          final usersData = message['data'] as List;
          final currentPage = message['current_page'] ?? nextPage;
          final lastPage = message['last_page'] ?? 1;

          final users = usersData
              .map((user) => UserModel.fromJson(user))
              .toList();

          setState(() {
            _users.addAll(users);
            _currentPage = currentPage;
            _hasMoreData = currentPage < lastPage;
            _isLoadingMore = false;

            if (kDebugMode) {
              print(
                '📄 加载更多: 当前页=$currentPage, 总页数=$lastPage, 新增数据=${users.length}',
              );
            }
          });
        } else {
          setState(() {
            _isLoadingMore = false;
            _hasMoreData = false;
          });
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载更多用户数据失败: $e');
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshUsers() async {
    await _loadUsers(isRefresh: true);
  }

  // 构建前三名特殊展示
  Widget _buildTopThreeSection() {
    if (_users.length < 3) return SizedBox.shrink();

    return Container(
      height: 380.rpx(context),
      margin: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: EdgeInsets.only(bottom: 30.rpx(context)),
              child: _buildTopUser(_users[0], 1, true),
            ),
          ),
          Positioned.fill(
            top: 100.rpx(context),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopUser(_users[1], 2, false),
                  _buildTopUser(_users[2], 3, false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建前三名用户项
  Widget _buildTopUser(UserModel user, int rank, bool isFirst) {
    final pedestalColors = [
      Color(0x308F69FF), // 粉色 - TOP.1
      Color(0x30C36FFF), // 紫色 - TOP.2
      Color(0x30CD87EB), // 浅蓝色 - TOP.3
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: isFirst ? 200.rpx(context) : 160.rpx(context),
          margin: EdgeInsets.only(
            top: isFirst ? 100.rpx(context) : 80.rpx(context),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                pedestalColors[rank - 1].withAlpha(150),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30.rpx(context)),
              topRight: Radius.circular(30.rpx(context)),
            ),
          ),
        ),
        // 皇冠
        Positioned(
          left: isFirst ? 100.rpx(context) : 80.rpx(context),
          top: isFirst ? -25.rpx(context) : -15.rpx(context),
          child: Center(
            child: Image.asset(
              'assets/images/${rank == 1
                  ? 't'
                  : rank == 2
                  ? 'tt'
                  : 'ttt'}.png',
              width: isFirst ? 80.rpx(context) : 60.rpx(context),
            ),
          ),
        ),
        SizedBox(
          width: isFirst ? 200.rpx(context) : 160.rpx(context),
          child: Column(
            children: [
              // 六边形底座
              Container(
                width: isFirst ? 180.rpx(context) : 140.rpx(context),
                height: isFirst ? 180.rpx(context) : 140.rpx(context),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      pedestalColors[rank - 1].withAlpha((0.1 * 255).round()),
                      pedestalColors[rank - 1].withAlpha((0.2 * 255).round()),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pedestalColors[rank - 1].withAlpha(
                        (0.1 * 255).round(),
                      ),
                      blurRadius: 20.rpx(context),
                      spreadRadius: 5.rpx(context),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 头像
                    Container(
                      width: isFirst ? 140.rpx(context) : 110.rpx(context),
                      height: isFirst ? 140.rpx(context) : 110.rpx(context),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white60,
                          width: 4.rpx(context),
                        ),
                      ),
                      child: ClipOval(
                        child: CachedImage(
                          imageUrl: user.avatar,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.person_circle_fill,
                              color: Colors.grey[500],
                              size: 50.rpx(context),
                            ),
                          ),
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.person_circle_fill,
                              color: Colors.grey[500],
                              size: 50.rpx(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.rpx(context)),
              // 用户名
              GradientText(
                user.name.length > 8
                    ? '${user.name.substring(0, 8)}...'
                    : user.name,
                gradient: LinearGradient(
                  colors: user.isMember == 1
                      ? [
                          Color(0x089178FF),
                          Color(0xC69178FF),
                          Color(0xFF9178FF),
                        ]
                      : [
                          Color(0x09FFFFFF),
                          Color(0xC7FFFFFF),
                          Color(0xFFFFFFFF),
                        ], // 绿色到蓝色
                ),
                style: TextStyle(
                  fontSize: 24.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建排行榜列表项 (4名以后)
  Widget _buildRankListItem(UserModel user, int rank) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 40.rpx(context),
        vertical: 15.rpx(context),
      ),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.all(10.rpx(context)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 排名数字
            Container(
              width: 80.rpx(context),
              height: 80.rpx(context),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20.rpx(context)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25.rpx(context)),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 36.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 20.rpx(context)),
            // 头像
            Container(
              width: 90.rpx(context),
              height: 90.rpx(context),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: CachedImage(
                imageUrl: user.avatar,
                fit: BoxFit.cover,
                placeholder: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.person_circle_fill,
                    color: Colors.grey[500],
                    size: 30.rpx(context),
                  ),
                ),
                errorWidget: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.person_circle_fill,
                    color: Colors.grey[500],
                    size: 30.rpx(context),
                  ),
                ),
              ),
            ),
            SizedBox(width: 20.rpx(context)),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 用户名
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GradientText(
                        user.name.length > 12
                            ? '${user.name.substring(0, 12)}...'
                            : user.name,
                        isOver: true,
                        style: TextStyle(
                          fontSize: 28.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Color(0x09EBEEFF),
                            Color(0x8FEBEEFF),
                            Color(0xFFEBEEFF),
                          ],
                        ),
                      ),
                      GradientText(
                        _formatTotalSeconds(user.totalSeconds),
                        isOver: true,
                        style: TextStyle(
                          fontSize: 24.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Color(0x09EBEEFF),
                            Color(0x8FEBEEFF),
                            Color(0xFFEBEEFF),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 7.rpx(context)),
                  GradientText(
                    user.userId,
                    isOver: true,
                    style: TextStyle(
                      fontSize: 18.rpx(context),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Nufei',
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color(0x9FEBEEFF),
                        Color(0x39EBEEFF),
                        Color(0x00EBEEFF),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 格式化总秒数为用户友好的格式
  String _formatTotalSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0秒';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours时$minutes分$seconds秒';
    } else if (minutes > 0) {
      return '$minutes分$seconds秒';
    } else {
      return '$seconds秒';
    }
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(20.rpx(context)),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30.rpx(context),
              height: 30.rpx(context),
              child: CircularProgressIndicator(
                color: Color(0xFF2379FF),
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 15.rpx(context)),
            Text(
              '加载更多...',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 24.rpx(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreDataIndicator() {
    return Container(
      padding: EdgeInsets.all(20.rpx(context)),
      child: Center(
        child: Text(
          '没有更多数据了',
          style: TextStyle(color: Colors.white38, fontSize: 24.rpx(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Column(
        children: [
          // 顶部导航栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Re(),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.only(left: 0.rpx(context)),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10.rpx(context)),
                  child: Center(
                    child: GradientText(
                      '${_users.length}',
                      style: TextStyle(
                        fontSize: 28.rpx(context),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nufei',
                        letterSpacing: 4.rpx(context),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Color(0x31737CFF),
                          Color(0x95737CFF),
                          Color(0xFF737CFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SizedBox(height: 40.rpx(context)),
          // 前三名特殊展示
          if (_users.length >= 3) _buildTopThreeSection(),
          // 排行榜内容
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2379FF)),
                        SizedBox(height: 20.rpx(context)),
                        Text(
                          '正在加载排行榜数据...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 28.rpx(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: Colors.orange,
                          size: 80.rpx(context),
                        ),
                        SizedBox(height: 20.rpx(context)),
                        Text(
                          '加载失败',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.rpx(context)),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 24.rpx(context),
                          ),
                        ),
                        SizedBox(height: 30.rpx(context)),
                        ElevatedButton(
                          onPressed: _refreshUsers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2379FF),
                            padding: EdgeInsets.symmetric(
                              horizontal: 30.rpx(context),
                              vertical: 15.rpx(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                25.rpx(context),
                              ),
                            ),
                          ),
                          child: Text(
                            '重试',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28.rpx(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.star,
                          color: Colors.white38,
                          size: 80.rpx(context),
                        ),
                        SizedBox(height: 20.rpx(context)),
                        Text(
                          '暂无排行榜数据',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 28.rpx(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshUsers,
                    color: Color(0xFF2379FF),
                    backgroundColor: Colors.amber,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: 40.rpx(context),
                        bottom: 120.rpx(context),
                      ),
                      children: [
                        // 排行榜列表 (4名以后)
                        if (_users.length > 3) ...[
                          ...List.generate(
                            _users.length - 3,
                            (index) => _buildRankListItem(
                              _users[index + 3],
                              index + 4,
                            ),
                          ),
                        ],

                        // 加载更多指示器
                        if (_hasMoreData && _users.length > 3)
                          _buildLoadingMoreIndicator()
                        else if (!_hasMoreData && _users.length > 3)
                          _buildNoMoreDataIndicator(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// 用户数据模型
class UserModel {
  final int id;
  final String userId;
  final String name;
  final String avatar;
  final int isMember;
  final String createdAt;
  final String updatedAt;
  final int totalSeconds;

  UserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.isMember,
    required this.createdAt,
    required this.updatedAt,
    required this.totalSeconds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      isMember: json['is_member'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      totalSeconds: (json['total_seconds'] ?? 0).toInt(),
    );
  }

  @override
  String toString() {
    return 'UserModel{id: $id, userId: $userId, name: $name, isMember: $isMember, totalSeconds: $totalSeconds}';
  }
}
