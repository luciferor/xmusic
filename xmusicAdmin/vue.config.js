const { defineConfig } = require("@vue/cli-service");
module.exports = defineConfig({
  lintOnSave: false,
  transpileDependencies: true,
  devServer: {
    proxy: {
      [process.env.VUE_APP_API_URL]: {
        target: process.env.NODE_ENV == 'development' ? "http://192.168.2.4:8080/" : "https://system.mhcwj.com/",
        // target: process.env.NODE_ENV == 'development' ? "https://system.mhcwj.com/" : "https://system.mhcwj.com/",
        changeOrigin: true, //表示是否跨域，
        pathRewrite: {
          ["^" + process.env.VUE_APP_API_URL]: "",
        },
      }
    },
    allowedHosts: "all",
  },
});
