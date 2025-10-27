import { createRouter, createWebHistory } from "vue-router";

const routes = [
  {
    path: "/",
    name: "home",
    component: () => import("../views/HomeView.vue"),
  },

];

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes,
});

// 添加全局前置守卫
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token');
  if (to.path === '/login') {//判断当login页面没有s参数，就进入带s参数
    next({ path: '/s/login' });
  } else {
    next();
  }
});

export default router;
