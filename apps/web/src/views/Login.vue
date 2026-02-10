<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-form">
        <div class="login-header">
          <h2>登录</h2>
          <p class="subtitle">欢迎回来，请登录您的账户</p>
        </div>

        <form class="login-form-content" @submit.prevent="handleSubmit">
          <div class="form-item">
            <label class="form-label">邮箱</label>
            <div class="form-control">
              <el-input
                v-model="formData.email"
                type="email"
                placeholder="请输入邮箱"
                size="large"
                clearable
                @keyup.enter="handleSubmit"
              />
            </div>
          </div>

          <div class="form-item">
            <label class="form-label">密码</label>
            <div class="form-control">
              <el-input
                v-model="formData.password"
                type="password"
                placeholder="请输入密码"
                size="large"
                show-password
                clearable
                @keyup.enter="handleSubmit"
              />
            </div>
          </div>

          <div class="form-item form-inline">
            <el-checkbox v-model="formData.remember">记住我</el-checkbox>
          </div>

          <div class="form-item" v-if="localError || loginError">
            <el-alert :title="localError || loginError" type="error" :closable="false" show-icon />
          </div>

          <div class="form-item">
            <el-button
              type="primary"
              size="large"
              :loading="loginLoading"
              native-type="submit"
              class="submit-button"
            >
              登录
            </el-button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue';
import { ElMessage } from 'element-plus';
import { useRouter, useRoute } from 'vue-router';
import { useLogin } from '@/composables/useLogin';

const router = useRouter();
const route = useRoute();
const localError = ref('');

const formData = reactive({
  email: '',
  password: '',
  remember: false,
});

const { loading: loginLoading, login, error: loginError } = useLogin();


const handleSubmit = async () => {
  localError.value = '';
  const email = formData.email.trim();
  const password = formData.password.trim();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!email) {
    localError.value = '请输入邮箱';
    return;
  }
  if (!emailRegex.test(email)) {
    localError.value = '请输入正确的邮箱格式';
    return;
  }
  if (!password) {
    localError.value = '请输入密码';
    return;
  }

  const code = await login({
    email,
    password,
  });

  if (code === 0) {
    ElMessage.success('登录成功');
    const redirect = route.query.redirect as string;
    router.push(redirect || '/');
  } else {
    ElMessage.error(loginError.value || '登录失败');
  }
};
</script>

<style scoped lang="scss">
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

  .login-container {
    background: white;
    border-radius: 12px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
    width: 100%;
    max-width: 480px;

    .login-form {
      padding: 40px 20px;

      .login-header {
        text-align: center;
        margin-bottom: 40px;

        h2 {
          font-size: 28px;
          font-weight: 600;
          margin-bottom: 8px;
          color: #333;
        }

        .subtitle {
          color: #666;
          font-size: 14px;
        }
      }

      .login-form-content {
        display: flex;
        flex-direction: column;
        gap: 16px;
        padding: 5px 20px;
        
        .form-item {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .form-label {
          font-size: 14px;
          color: #666;
        }

        .form-control {
          width: 100%;
        }

        .form-control :deep(.el-input__wrapper) {
          width: 100%;
        }

        .submit-button {
          width: 100%;
          margin-top: 10px;
        }
      }
    }
  }
}
</style>

