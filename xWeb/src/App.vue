<template>
  <!-- 开启顶部安全区适配 -->
  <!-- <van-nav-bar safe-area-inset-top /> --><!--浏览器不需要适配顶部安全区-->
  <router-view />
  <!-- 开启底部安全区适配 -->
  <van-number-keyboard safe-area-inset-bottom />
</template>

<style lang="scss">
@import url("@/assets/csses/common.css");
// @import url("@/assets/csses/all.min.css");</style>
