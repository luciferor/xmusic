const _root = `${process.env.NODE_ENV == 'development' ? 'http://192.168.2.3:8090/' : '/'}`;
// const _root = "https://mhcwj.com/prod-api/";
// const _root = "http://192.168.0.55:8090/";
// const _root = "http://192.168.2.6:8090/";
export const apis = {
  //调用接口:后端地址 //接口功能
  api_login: `${_root}login`, //登录
  api_sso_login: `${_root}ssoLogin`,//单点登录
  api_get_sso_url: `${_root}sso/getLoginUrl`,//获取跳转单点登录地址
  api_logout: `${_root}logout`, //登出 | 退出
  api_logout_user: `${_root}logout/user`, //单点登出 | 退出
  api_get_userinfo: `${_root}douyin/account/loginInfo`, //获取登录账户用户
  api_checkimg: `${_root}captchaImage`, //验证码
  api_menus: `${_root}douyin/account/menu`, //获取首页菜单
  //用户数据
  api_get_user_video: `${_root}data/external/user/item`, //获取用户视频情况
  api_get_user_fans_like_comment_share_profile: `${_root}douyin/userData/list`, //获取用户粉丝数 | 获取用户点赞数 | 获取用户评论数 | 获取用户分享数 | 获取用户主页访问数
  //粉丝画像数据
  api_get_user_fans_data: `${_root}api/douyin/v1/user/fans_data`, //获取用户粉丝数据
  api_get_user_fans_source: `${_root}data/extern/fans/source`, //获取用户粉丝来源
  api_get_user_fans_favourite: `${_root}data/extern/fans/favourite`, //获取用户粉丝喜好
  api_get_user_fans_comment: `${_root}data/extern/fans/comment`, //获取用户粉丝热评
  //用户视频数据
  api_get_user_video_list: `${_root}api/douyin/v1/video/video_list`, //查询授权账号视频列表
  api_get_user_video: `${_root}data/external/item/base`, //获取视频基础数据
  api_get_user_video_like_comment_play_share: `${_root}douyin/videoData/list`, //获取视频点赞数据 | 评论 | 分享 | 播放
  //用户直播数据
  api_get_room_ids: `${_root}douyin/liveRoom/list`, //获取主播历史开播过的房间ID
  api_get_room_dynamic_base_dudience: `${_root}douyin/liveRoom/roomData`, //获取直播间互动数据 | 看播数据 | 基础数据
  //直播间数据
  api_get_today_data: `${_root}v1.0/qianchuan/report/live/get`, //获取今日直播间数据
  api_live_root: `${_root}qianchuan/live/room/calendar`, //获取直播间列表
  api_get_flow: `${_root}v1.0/qianchuan/today_live/room/flow_performance/get`, //获取直播间流量表现
  api_get_room_detail: `${_root}v1.0/qianchuan/today_live/room/detail/get`, //获取直播间详情
  api_cus_room_detail: `${_root}qianchuan/live/room/calendar/detail`, //获取直播间详情数据库
  api_get_room_user_detail: `${_root}v1.0/qianchuan/today_live/room/user/get`, //获取直播间用户洞察
  api_get_room_product_detail: `${_root}v1.0/qianchuan/today_live/room/product_list/get`, //获取直播间商品列表
  api_get_dy_today_room_list: `${_root}v1.0/qianchuan/today_live/room/get`, //获取抖音今日直播间列表
  //获取巨量用户关心
  api_get_users: `${_root}qianchuan/auth/getAwemeList`, //获取千川账户下已授权抖音号
  //广告数据报表
  api_get_ad_account: `${_root}v1.0/qianchuan/report/advertiser/get`, //获取广告账户数据
  api_get_ad_plan: `${_root}v1.0/qianchuan/report/ad/get`,//获取广告计划数据
  api_get_ad_cy: `${_root}v1.0/qianchuan/report/creative/get`,//获取广告创意数据
  api_get_ad_material: `${_root}v1.0/qianchuan/report/material/get`,//获取广告素材数据
  api_get_keywords: `${_root}v1.0/qianchuan/report/search_word/get`, //获取搜索词/关键词数据
  api_get_ad_video_dynamic: `${_root}v1.0/qianchuan/report/video_user_lose/get`,//获取视频互动流失数据
  api_get_ad_orderdetail: `${_root}v1.0/qianchuan/report/long_transfer/order/get`,//长周期转化价值-订单明细
  api_get_all_promotion: `${_root}v1.0/qianchuan/report/uni_promotion/get`, //获取全域推广账户维度数据
  api_get_all_dimension_data_live: `${_root}v1.0/qianchuan/qianchuan/report/uni_promotion/dimension_data/room/get`, //获取全域推广直播间维度数据
  api_get_all_dimension_data_dyh: `${_root}v1.0/qianchuan/report/uni_promotion/dimension_data/author/get`, //获取全域推广抖音号维度数据
  api_get_system_comment_keywords: `${_root}v1.0/qianchuan/ad/recommend_keywords/get`, //获取系统推荐关键词
  api_get_all_area_commit_list: `${_root}v1.0/qianchuan/uni_promotion/list`, //获取全域推广列表
  //商品竞争分析
  api_get_analyse: `${_root}v1.0/qianchuan/product/analyse/list`, //获取商品竞争分析列表
  api_get_compare: `${_root}v1.0/qianchuan/product/analyse/compare_stats_data`, //商品竞争分析详情-效果对比
  api_get_creative: `${_root}v1.0/qianchuan/product/analyse/compare_creative`, //商品竞争分析详情-创意比对
  //其他接口
  api_get_product_available: `${_root}v1.0/qianchuan/product/available/get`, //商家获取可投商品列表
  api_get_product_brand: `${_root}v1.0/qianchuan/brand/authorized/get`, //获取广告主绑定的品牌列表
  api_get_product_authorized_store: `${_root}v1.0/qianchuan/shop/authorized/get`, //获取广告主绑定的店铺列表
  //系统处理
  api_refresh_token: `${_root}qianchuan/auth/refresh`, //刷新千川token
  api_refresh_douyin: `${_root}douyin/auth/refresh/`,//刷新抖音token | put请求 22测一测
  api_get_refresh_douyin: `${_root}douyin/auth/getDataScreenOauthUrl`,//重新获取refreshtoken
  api_get_refresh_token_douyin: `${_root}douyin/auth/callbackDataScreen`,//获取抖音refreshtoken
  api_get_content: `http://192.168.31.99:8080/system/retention/text/get`, //获取内容
};
