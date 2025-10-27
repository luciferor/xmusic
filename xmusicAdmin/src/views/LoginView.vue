<template>
    <div class="full flex justify-center align-center">
        <div class="login radius-xl bg-white border-white flex justify-between aling-center">
            <div class="logobox minfill hfill flex justify-end align-center"><img src="@/assets/images/logo.png"
                    style="transform: rotate(-90deg);"></div>
            <div class="maxfill flex justify-center align-center flex-flow">
                <a-form :model="formState" name="basic" :label-col="{ span: 8 }" :wrapper-col="{ span: 16 }"
                    autocomplete="off" @finish="onFinish" @finishFailed="onFinishFailed">
                    <a-form-item label="账号" name="username" :rules="[{ required: true, message: '请输入账号!' }]">
                        <a-input v-model:value="formState.username" />
                    </a-form-item>

                    <a-form-item label="密码" name="password" :rules="[{ required: true, message: '请输入密码!' }]">
                        <a-input-password v-model:value="formState.password" />
                    </a-form-item>

                    <a-form-item name="remember" :wrapper-col="{ offset: 8, span: 16 }">
                        <a-checkbox v-model:checked="formState.remember">记住密码</a-checkbox>
                    </a-form-item>

                    <a-form-item :wrapper-col="{ offset: 8, span: 16 }">
                        <a-button type="primary" html-type="submit">立即登录</a-button>
                    </a-form-item>
                </a-form>
            </div>
        </div>
    </div>
</template>
<script setup>
import router from '@/router';
import { reactive } from 'vue';
import { apis } from '@/assets/common/apis';
import { https } from '@/assets/common/https';
import { setToken } from '@/assets/common/common';
import { useRouter } from 'vue-router';
import Menu from '@/components/Menu.vue';

const formState = reactive({
    username: '',
    password: '',
    remember: true,
});
const onFinish = values => {
    console.log('Success:', values);
    setToken('aaaaaaaaaaaaaaaaaaaaa');
    router.replace({ path: '/' });
};
const onFinishFailed = errorInfo => {
    console.log('Failed:', errorInfo);
};
</script>
<style lang="scss" scoped>
.login {
    width: 824px;
    height: 400px;

    .logobox {
        width: 300px;
    }
}
</style>