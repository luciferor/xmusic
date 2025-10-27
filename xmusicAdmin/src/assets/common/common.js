import Cookies from 'js-cookie';

export function getToken() {
  return Cookies.get('TokenKey');
}

export function setToken(token) {
  Cookies.set('TokenKey', token);
}

export function getUrlParams(url, name) {
  let u = url.substring(url.indexOf("?") + 1);
  let array = u.split("&");
  for (let i = 0; i < array.length; i++) {
    let item = array[i];
    if (item.startsWith(name)) {
      let b = item.split("=");
      return b[1];
    }
  }
  return "";
}