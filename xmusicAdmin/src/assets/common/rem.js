// 基准大小
const baseSize = 32
// 设置 rem 函数
function refreshRem() {
    // 当前页面宽度相对于 750 宽的缩放比例，可根据自己需要修改。
    const scale = document.documentElement.clientWidth / 750
    // 设置页面根节点字体大小
    document.documentElement.style.fontSize = (baseSize * Math.min(scale, 2)) + 'px'
}
// 初始化
refreshRem()

let tid
window.addEventListener('resize', function () {
    clearTimeout(tid);
    tid = setTimeout(refreshRem, 300);
}, false);
window.addEventListener('pageshow', function (e) {
    if (e.persisted) {
        // 页面从浏览器的缓存中读取
        clearTimeout(tid);
        tid = setTimeout(refreshRem, 300);
    }
}, false);