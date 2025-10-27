import axios from "axios";
import store from "@/store";
import router from "@/router/index";
import { notification } from "ant-design-vue";
import { getToken, removeSSOInfo, removeToken } from "@/assets/incs/common";
const setLoadingState = (e) => store.commit("setLoadingState", e);
import { apis } from "./apis";
//axios实例
const service = axios.create({
  baseURL: process.env.VUE_APP_API_URL,//"http://192.168.1.104:8080",
  timeout: 100000,
});

//axios请求拦截器
service.interceptors.request.use(
  (config) => {
    setLoadingState(true);
    config.headers["Content-Language"] = "zh_CN";
    config.headers["AUTH-ID"] = localStorage.getItem("authid");
    config.headers["Authorization"] =
      "Bearer " + getToken() || "";
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

//axios响应拦截器
service.interceptors.response.use(
  (res) => {
    setLoadingState(false);
    try {
      if (res.data.code == 200 || res.data.code == 0) {
        return res;
      } else if (res.data.code == 10010) {
        notification["error"]({
          message: "系统提示",
          description: '即将跳转到“抖音”获取新的授权信息~',
          placement: "top",
        });
        //重新获取refresh token
        getRefreshTokenHandler();

        return;
      } else if (res.data.code == 500) return res;
      //处理token过期，弹出登录页面
      if (res.data.code == 401) {
        notification["error"]({
          message: "系统提示",
          description: '登录过期，即将重新登录！',
          placement: "top",
        });
        setTimeout(() => {
          removeToken();
          removeSSOInfo();
          // router.replace({ path: "/login" }); //跳转登录页
          window.location.href = 'https://222.220.55.29:8443/mhmain';
        }, 3000);
        return;
      } else if (res.data.code == 40100) {
        //调用退出
        ssoLoginout();
        return;
      } else if (res.data.code == 50136) {
        notification["error"]({
          message: "系统提示",
          description: res.data.message,
          placement: "top",
        });
        return;
      } else if (res.data.code == 40102 || res.data.code == 40105) {
        setTimeout(() => {
          //千川token过期
          refreshTokenHandler();
        }, 5000);
        return;
      } else if (res.data.data.error_code == 2190008) {
        setTimeout(() => {
          //抖音token过期
          refreshDouyinHandler();
        }, 5000);
        return;
      }
      return res;
    } catch (error) {
      notification["error"]({
        message: "系统提示",
        description: '网络错误',
        placement: "top",
      });
    }
  },
  (error) => {
    setLoadingState(false);
    if (error && error.response) {
      switch (error.response.status) {
        case 401:
          error.message = "token过期";
        case 403:
          error.message = `拒绝访问`;
          break;
        case 404:
          error.message = `目标地址不存在`;
          break;
        case 500:
          error.message = `服务端出错`;
          break;
        case 502:
          error.message = `服务端出错`;
          break;
        default:
          error.message = `连接错误${error.response.status}`;
      }
    }
    notification["error"]({
      message: "系统提示",
      description: error.message,
      placement: "top",
    });
    return Promise.resolve(error.response);
  }
);

//封装请求函数
export const https = (url, options = {}) => {
  const method = options.method || "GET";
  const params = options.params || {};

  if (method == "get" || method == "GET") {
    return new Promise((resolve, reject) => {
      service
        .get(url, { params: params })
        .then((res) => {
          if (res && res.data) resolve(res);
        })
        .catch((err) => {
          reject(err);
        });
    });
  } else {
    return new Promise((resolve, reject) => {
      service
        .post(url, params)
        .then((res) => {
          if (res && res.data) resolve(res);
        })
        .catch((err) => {
          reject(err);
        });
    });
  }
};

//刷新巨量千川
function refreshTokenHandler() {
  if (localStorage.getItem("refresh") && localStorage.getItem("refresh") != 0) {
    const count = Number(localStorage.getItem("refresh")) - 1;
    localStorage.setItem("refresh", count);
  } else {
    localStorage.setItem("refresh", 3);
  }
  service
    .put(apis.api_refresh_token, {})
    .then((res) => {
      setTimeout(() => {
        router.go(0); //刷新
      }, 5000);
    })
    .catch((err) => {
      console.error(err, "刷新千川Token失败！");
    });
}


//刷新抖音token
function refreshDouyinHandler() {
  if (localStorage.getItem("douyinrefresh") && localStorage.getItem("douyinrefresh") != 0) {
    const count = Number(localStorage.getItem("douyinrefresh")) - 1;
    localStorage.setItem("douyinrefresh", count);
  } else {
    localStorage.setItem("douyinrefresh", 3);
  }
  service
    .put(apis.api_refresh_douyin + localStorage.getItem("authid"), {})
    .then((res) => {
      setTimeout(() => {
        // router.go(0); //刷新
      }, 5000);
    })
    .catch((err) => {
      console.error(err, "刷新千川Token失败！");
    });
}

//重新刷新refresh token
function getRefreshTokenHandler() {
  service
    .get(apis.api_get_refresh_douyin, {})
    .then((res) => {
      setTimeout(() => {
        window.open(res.data.data);
      }, 3000);
    })
    .catch((err) => {
      console.error(err, "");
    });
}

//退出sso登录接口
async function ssoLoginout() {
  const res = await https(apis.api_logout, { method: "POST", params: {} });
  removeToken();
  removeSSOInfo();
  // router.replace({ path: "/login" }); //跳转登录页
  window.location.href = 'https://222.220.55.29:8443/mhmain';
}