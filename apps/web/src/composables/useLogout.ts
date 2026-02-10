/**
 * 退出登录相关的 Composable
 */
import { ref, type Ref } from 'vue';
import { logout as logoutApi } from '@/service/user';
import { authStorage } from '@/utils/auth';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';

export interface UseLogoutReturn {
  loading: Ref<boolean>;
  logout: () => Promise<void>;
  error: Ref<string | null>;
}

/**
 * 退出登录 Composable
 * @returns 退出登录相关的状态和方法
 */
export function useLogout(): UseLogoutReturn {
  const loading = ref(false);
  const error = ref<string | null>(null);
  const router = useRouter();

  const logout = async (): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      // 1. 调用退出登录接口（可选，即使失败也清除本地数据）
      try {
        await logoutApi();
      } catch (err) {
        // 如果接口调用失败，仍然继续清除本地数据
        console.warn('退出登录接口调用失败:', err);
      }

      // 2. 清除本地认证信息
      authStorage.clearAll();

      // 3. 跳转到登录页
      ElMessage.success('已退出登录');
      router.push('/login');
    } catch (err: any) {
      error.value = err.response?.data?.message || err.message || '退出登录失败';
      ElMessage.error(error.value);
      
      // 即使出错也清除本地数据并跳转
      authStorage.clearAll();
      router.push('/login');
    } finally {
      loading.value = false;
    }
  };

  return {
    loading,
    logout,
    error,
  };
}

