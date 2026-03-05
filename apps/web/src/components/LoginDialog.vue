<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { useLogin } from '@/composables/useLogin'
import { ElMessage } from 'element-plus'

const props = defineProps<{ visible: boolean }>()
const emit = defineEmits<{
  'update:visible': [value: boolean]
  success: []
  cancel: []
}>()

const { loading: loginLoading, login, error: loginError } = useLogin()
const localError = ref('')

const formData = reactive({
  email: '',
  password: '',
})

// 弹窗关闭时重置表单
watch(() => props.visible, (val) => {
  if (!val) {
    formData.email = ''
    formData.password = ''
    localError.value = ''
  }
})

const handleSubmit = async () => {
  localError.value = ''
  const email = formData.email.trim()
  const password = formData.password.trim()
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

  if (!email) {
    localError.value = '请输入邮箱'
    return
  }
  if (!emailRegex.test(email)) {
    localError.value = '请输入正确的邮箱格式'
    return
  }
  if (!password) {
    localError.value = '请输入密码'
    return
  }

  const code = await login({ email, password })

  if (code === 0) {
    ElMessage.success('登录成功')
    emit('success')
  }
}

const handleClose = () => {
  emit('update:visible', false)
  emit('cancel')
}
</script>

<template>
  <el-dialog
    :model-value="visible"
    @update:model-value="$emit('update:visible', $event)"
    width="420px"
    :close-on-click-modal="false"
    :close-on-press-escape="true"
    @close="handleClose"
    class="login-dialog"
    :show-close="true"
    append-to-body
  >
    <template #header>
      <div class="login-dialog-header">
        <h3>登录</h3>
        <p class="login-dialog-subtitle">请登录后继续操作</p>
      </div>
    </template>

    <form class="login-dialog-form" @submit.prevent="handleSubmit">
      <div class="form-item">
        <label class="form-label">邮箱</label>
        <el-input
          v-model="formData.email"
          type="email"
          placeholder="请输入邮箱"
          size="large"
          clearable
          @keyup.enter="handleSubmit"
        />
      </div>

      <div class="form-item">
        <label class="form-label">密码</label>
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

      <el-alert
        v-if="localError || loginError"
        :title="localError || loginError"
        type="error"
        :closable="false"
        show-icon
        class="login-dialog-error"
      />

      <el-button
        type="primary"
        size="large"
        :loading="loginLoading"
        native-type="submit"
        class="login-dialog-submit"
      >
        登录
      </el-button>

      <div class="login-dialog-footer">
        还没有账户？<router-link to="/register" @click="handleClose">立即注册</router-link>
      </div>
    </form>
  </el-dialog>
</template>

<style scoped>
.login-dialog-header {
  text-align: center;
}

.login-dialog-header h3 {
  font-size: 22px;
  font-weight: 600;
  color: var(--gray-900);
  margin: 0 0 4px;
}

.login-dialog-subtitle {
  font-size: 14px;
  color: var(--gray-500);
  margin: 0;
}

.login-dialog-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-label {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-700);
}

.login-dialog-error {
  margin: 0;
}

.login-dialog-submit {
  width: 100%;
  margin-top: 4px;
}

.login-dialog-footer {
  text-align: center;
  font-size: 14px;
  color: var(--gray-500);
}

.login-dialog-footer a {
  color: var(--primary-color);
  text-decoration: none;
  font-weight: 500;
}

.login-dialog-footer a:hover {
  text-decoration: underline;
}
</style>
