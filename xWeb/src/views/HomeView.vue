<template>
  <div class="home full flex justify-center align-center flex-flow">
    <div class="fill core radius-xlll border-white-x bg-blur-xs flex justify-between align-center">
      <div class="imgbox minfill margin-left-xl radius-xll">
        <video src="@/assets/images/111318054.mp4" autoplay="true" type="video/mp4" muted="true" loop object-fit="cover"
          class="hfill wfill"></video>
      </div>
      <div class="cc maxfill flex justify-center align-center flex-flow">
        <h1 class="padding-bottom-xl">欢迎使用荧惑音乐</h1>
        <h4 class="text-grey des">阿里云盘+“荧惑音乐”播放器，你的音乐全权掌控，永无会员，上传一次，随时随地播放！</h4>
        <div class="down-btn" @click="downloadHandler">下载安卓端</div>
        <a-statistic :value="downs" decimalSeparator="2" prefix="已下载：" suffix="次" class="margin-top-x"
          valueStyle="color:#c7c7c7;font-size:14px;" />
        <div class="qr bg-white radius-xlll over padding-xs margin-top-x"><img src="@/assets/images/gh_ad5c31404944.jpg"
            class="fill">
        </div>
      </div>
    </div>
    <div class="padding-vertical-x wfill flex justify-center align-center copyrght">
      &copy;Copyright {{ new Date().getFullYear() }} 荧惑音乐 All Rights Reserved.
      <a href="https://beian.miit.gov.cn" target="_blank"> 黔ICP备2023009039号-1</a>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Statistic as AStatistic } from 'ant-design-vue';
import _a from '@/assets/images/2025-08-20_141618_320.png';
import _b from '@/assets/images/2025-08-20_141624_247.png';
import _c from '@/assets/images/2025-08-20_141628_414.png';
import _d from '@/assets/images/2025-08-20_141632_456.png';
import _e from '@/assets/images/2025-08-20_141638_303.png';
import _f from '@/assets/images/2025-08-20_141644_407.png';
import _g from '@/assets/images/2025-08-20_141652_686.png';
import _h from '@/assets/images/2025-08-20_141659_190.png';
import _i from '@/assets/images/2025-08-20_141648_463.png';

const cuts = [
  _a,
  _b,
  _c,
  _d,
  _e,
  _f,
  _g,
  _h,
  _i
];


const router = useRouter();

const downs = ref(38954720);

//跳转路由
const navigateTo = (path) => {
  router.push({ path: '/' + path });
};

const downloadHandler = () => {
  downs.value += 1;
  localStorage.setItem('download', downs.value);
  window.open('https://music.dsnbc.com/android-release.apk', '_blank');
};

</script>

<style lang="scss" scoped>
.home {
  background: url('@/assets/images/homebg.jpg');
  background-size: cover;

  .core {
    width: 1024px;
    height: 600px;
    background: rgba(255, 255, 255, 0.575);

    .imgbox {
      height: 520px;
      border: 10px solid rgba(209, 209, 209, 0.1);
      overflow: hidden;
    }

    .count {
      color: gray;
      font-size: 14px;
    }

    .des {
      padding: 0 50px 20px 50px;
    }
  }
}

.copyrght {
  font-size: 12px;
  color: var(--grey);

  a {
    color: var(--darkGray);
  }
}

.down-btn {
  font-size: 16px;
  z-index: 99;
  padding: 10px 20px;
  align-self: center;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  border: none;
  color: white;
  background-color: #00F9E5;
  background-image: linear-gradient(110deg, #2D61FF4B, #2D61FF85 44%, #2D60FF);
  border-radius: 20px;
}

.qr {
  width: 200px;
  height: 200px;
}

@media screen and (min-width:0px) and (max-width:1280px) {

  .home {
    background: url('@/assets/images/homebg.jpg');
    background-size: cover;
    padding: 0 !important;

    .core {
      width: 100vw;
      height: 100vh;
      background: rgba(255, 255, 255, 0.575);
      border-radius: 0 !important;
      position: relative;
      padding: 0 !important;

      .imgbox {
        background: transparent;
        border-radius: 0;
        width: 100vw;
        height: 100vh;
        position: absolute;
        inset: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        border: 0 !important;
      }

      .cc {
        z-index: 99;
        position: absolute;
        inset: 0 !important;
        backdrop-filter: blur(4px);
        background: rgba(0, 0, 0, 0.5);

        .count {
          color: #c7c7c7;
          font-size: 2.4rem;
        }
      }

      h1 {
        font-size: 6rem;
        color: white;
      }

      h4 {
        font-size: 4rem;
        color: rgb(209, 209, 209);
      }
    }
  }

  .copyrght {
    display: none;
  }

  .down-btn {
    font-size: 3rem;
    z-index: 99;
    padding: 1.5rem 4rem;
    align-self: center;
    display: flex;
    justify-content: center;
    align-items: center;
    cursor: pointer;
    border: none;
    color: white;
    background-color: #00F9E5;
    background-image: linear-gradient(110deg, #2D61FF4B, #2D61FF85 44%, #2D60FF);
    border-radius: 2.5rem;
  }

  .qr {
    width: 30rem;
    height: 30rem;
  }
}
</style>