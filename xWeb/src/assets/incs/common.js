import { notification } from "ant-design-vue";
import Cookies from 'js-cookie';
//全屏
export const fullScreen = (e, document) => {
  if (!e) {
    // 取消全屏
    if (document.exitFullscreen) {
      document.exitFullscreen();
    } else if (document.webkitCancelFullScreen) {
      document.webkitCancelFullScreen();
    } else if (document.mozCancelFullScreen) {
      document.mozCancelFullScreen();
    } else if (document.msExitFulldcreen) {
      document.msExitFulldcreen();
    }
  } else {
    // 全屏
    var element = document.documentElement;
    if (element.requestFullscreen) {
      element.requestFullscreen();
    } else if (element.webkitRequestFullScreen) {
      element.webkitRequestFullScreen();
    } else if (element.mozRequestFullScreen) {
      element.mozRequestFullScreen();
    } else if (element.msRequestFulldcreen) {
      element.msRequestFulldcreen();
    }
  }
};

const TokenKey = "Application-Token";

export function getToken() {
  return Cookies.get(TokenKey);
}

export function setToken(token) {
  return Cookies.set(TokenKey, token);
}

export function removeToken() {
  return Cookies.remove(TokenKey);
}
