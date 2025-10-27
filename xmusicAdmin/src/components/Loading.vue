<template>
    <div :class="`loading-box-class ani notouch bg-blur-x ${visable ? 'show' : ''}`">
        <div class="loader">
            <div class="loader-inner ball-spin-fade-loader">
                <div class="five"></div>
                <div class="two"></div>
                <div class="three"></div>
                <div class="four"></div>
                <div class="five"></div>
                <div class="two"></div>
                <div class="three"></div>
                <div class="four"></div>
            </div>
        </div>
    </div>
</template>
<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
const store = useStore();
const visable = computed(() => store.state.loading);
</script>
<style lang="scss" scoped>
@import url('@/assets/css/loaders.min.css');

.loading-box-class {
    inset: 0;
    width: 100%;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    flex-direction: column;
    box-sizing: border-box;
    transition: 1s all ease;
    position: fixed;
    z-index: 99999;
    opacity: 0;
    outline: 0;
    text-align: center;
    -ms-transform: scale(1.185);
    transform: scale(1.185);
    backface-visibility: hidden;
    perspective: 2000px;
    background: rgba(255, 255, 255, 0.8);
    transition: all 0.3s ease-in-out 0s;
    pointer-events: none;
}

.loading-box-class.show {
    opacity: 1;
    transition-duration: 0.3s;
    -ms-transform: scale(1);
    transform: scale(1);
    overflow-x: hidden;
    overflow-y: auto;
    pointer-events: auto;
}

.one {
    background-image: linear-gradient(-30deg, DeepPink 0%, rgb(252, 169, 213) 100%);
    box-shadow: rgba(255, 20, 145, 0.5) 0px 5px 8px 1px;
    color: white;
}

.two {
    background-image: linear-gradient(-30deg, MediumSlateBlue 0%, rgb(192, 181, 255) 100%);
    box-shadow: rgba(124, 104, 238, 0.5) 0px 5px 8px 1px;
    color: white;
}

.three {
    background-image: linear-gradient(-30deg, #00BFFF 0%, rgb(153, 227, 252) 100%);
    box-shadow: rgba(0, 191, 255, 0.5) 0px 5px 8px 1px;
    color: white;
}

.four {
    background-image: linear-gradient(-30deg, #00FA9A 0%, rgb(154, 253, 215) 100%);
    box-shadow: rgba(0, 250, 154, 0.5) 0px 5px 8px 1px;
    color: white;
}

.five {
    background-image: linear-gradient(-30deg, #FFA500 0%, rgb(255, 245, 102) 100%);
    box-shadow: rgba(255, 166, 0, 0.5) 0px 5px 8px 1px;
    color: white;
}

.six {
    background-image: linear-gradient(-30deg, rgb(248, 106, 90) 0%, rgb(252, 162, 152) 100%);
    box-shadow: rgba(248, 106, 90, 0.5) 0px 5px 8px 1px;
    color: white;
}

.seven {
    background-image: linear-gradient(-30deg, #c7c7c7 0%, #f5f5f5 100%);
    box-shadow: #c7c7c7 0px 5px 8px 1px;
    color: #484848;
}
</style>
