import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import store from "./store";
import "./assets/common/rem.js";
import Antd from "ant-design-vue";
import 'ant-design-vue/dist/reset.css';

createApp(App).use(store).use(router).use(Antd).mount("#app");
