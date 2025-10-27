const _root = `${process.env.NODE_ENV == 'development' ? 'http://192.168.2.4:8080/' : '/'}`;
export const apis = {
    //调用接口:后端地址 //接口功能
    get_all_category: `${_root}no-auth/category/all-categories`,//获取所有分类
    get_all_goods: `${_root}no-auth/product/list`,//获取所有商品
    get_goods_detail: `${_root}no-auth/product/detail/`,//获取商品详情
};
