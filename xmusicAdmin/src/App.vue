<template>
  <nut-config-provider theme="" :theme-vars="themeVars">
    <router-view />
  </nut-config-provider>
  <Loading />
</template>

<script setup>
import { ref } from 'vue';
import Loading from '@/components/Loading.vue';
const themeVars = ref({
  primaryColor: 'rgb(25, 91, 255)',
  primaryColorEnd: 'rgb(25, 91, 255)'
})
</script>

<style lang="scss">
@import url('@/assets/css/common.css');
</style>
