<template>
    <a-menu v-model:selectedKeys="state.selectedKeys" style="width: 256px" mode="inline" :open-keys="state.openKeys"
        :items="items" @openChange="onOpenChange"></a-menu>
</template>
<script setup>
import { useRouter } from 'vue-router';
import { onMounted, VueElement, h, reactive } from 'vue';
import { SlidersTwoTone, AppstoreTwoTone, UsbTwoTone, MehTwoTone } from '@ant-design/icons-vue';
function getItem(label, key, icon, children, type) {
    return {
        key,
        icon,
        children,
        label,
        type,
    };
}
const items = reactive([
    getItem('仪表盘', 'sub1', () => h(AppstoreTwoTone), [
        getItem('数据统计', '1'),
    ]),
    getItem('音频', 'sub2', () => h(UsbTwoTone), [
        getItem('专辑', '2'),
        getItem('曲风', '3'),
        getItem('分类', '4'),
    ]),
    getItem('会员', 'sub3', () => h(MehTwoTone), [
        getItem('会员管理', '5'),
        getItem('会员歌单', '6'),
        getItem('会员等级', '7'),
    ]),
    getItem('系统管理', 'sub4', () => h(SlidersTwoTone), [
        getItem('用户', '8'),
        getItem('设置', '9'),
    ]),
]);
const state = reactive({
    rootSubmenuKeys: ['sub1', 'sub2', 'sub4'],
    openKeys: ['sub1'],
    selectedKeys: [],
});
const onOpenChange = openKeys => {
    const latestOpenKey = openKeys.find(key => state.openKeys.indexOf(key) === -1);
    if (state.rootSubmenuKeys.indexOf(latestOpenKey) === -1) {
        state.openKeys = openKeys;
    } else {
        state.openKeys = latestOpenKey ? [latestOpenKey] : [];
    }
};
</script>
<style lang="scss">
:where(.css-dev-only-do-not-override-1p3hq3p).ant-menu-light.ant-menu-root.ant-menu-inline,
:where(.css-dev-only-do-not-override-1p3hq3p).ant-menu-light.ant-menu-root.ant-menu-vertical {
    border: none !important;
}
</style>