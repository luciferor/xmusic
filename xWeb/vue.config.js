const { defineConfig } = require("@vue/cli-service");
module.exports = defineConfig({
  lintOnSave: false,
  transpileDependencies: true,
  devServer: {
    // host: '192.168.0.52', 
    // port: 8080,
    // historyApiFallback: true,
    allowedHosts: "all",
  },
});
