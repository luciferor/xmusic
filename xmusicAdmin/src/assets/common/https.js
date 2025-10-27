import axios from "axios";
import store from "@/store";
import router from "@/router/index";
import { getToken } from "@/assets/common/common";
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
        console.log(res, 'AAAAAAAAAAAA')
        setLoadingState(false);
        try {
            if (res.data.code == 200 || res.data.code == 0) {
                return res;
            } else if (res.data.code == 500) return res;
            //处理token过期，弹出登录页面
            if (res.data.code == 401) {
                notification['error']({
                    message: 'System Information!',
                    description: '登录过期，即将重新登录！',
                });
                return;
            }
            return res;
        } catch (error) {
            notification['error']({
                message: 'System Information!',
                description: '网络错误！',
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
        notification['error']({
            message: 'System Information!',
            description: error.message,
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