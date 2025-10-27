// 动态设置 rem 基准值
(function (doc, win) {
  function setRem() {
    // 设定 1rem = 10px
    const baseSize = 10;

    // 根据当前视口宽度比例调整缩放因子（以设计稿宽度为 750px 为例）
    const scale = doc.documentElement.clientWidth / 750;

    // 设置最大缩放比例为 2，避免过大
    doc.documentElement.style.fontSize = baseSize * Math.min(scale, 2) + 'px';
  }

  // 初始化
  setRem();

  // 监听窗口变化
  win.addEventListener('resize', setRem);
  win.addEventListener('pageshow', function (e) {
    if (e.persisted) {
      setRem();
    }
  });
})(document, window);