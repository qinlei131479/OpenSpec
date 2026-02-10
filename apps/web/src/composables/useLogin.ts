/**
 * 登录相关的 Composable
 */
import { ref, type Ref } from 'vue';
import { login as loginApi } from '@/service/user';
import type { LoginParams, UserData } from '@/service/user';
import { authStorage } from '@/utils/auth';
import type { UserInfo } from '@/utils/auth';
import { encryptPassword } from '@/utils/rsa';

export interface UseLoginReturn {
  loading: Ref<boolean>;
  login: (params: { email: string; password: string }) => Promise<number>;
  error: Ref<string | null>;
}

/**
 * 登录 Composable
 * @returns 登录相关的状态和方法
 */
export function useLogin(): UseLoginReturn {
  const loading = ref(false);
  const error = ref<string | null>(null);

  const login = async (params: { email: string; password: string }): Promise<number> => {
    loading.value = true;
    error.value = null;

    try {
      // 1. 使用 RSA 加密密码
      const encryptedPassword = encryptPassword(params.password);

      // 2. 调用登录接口
      const loginParams: LoginParams = {
        email: params.email.trim(),
        password: encryptedPassword,
      };

      const { data: response, response: httpResponse } = await loginApi(loginParams);

      // 3. 处理登录结果
      if (response.code === 0 && response.data) {
        const userData = response.data;
        
        // 4. 从响应头获取 Authorization token
        // axios 会将响应头转换为小写
        const authorization = httpResponse.headers['authorization'] 
          || httpResponse.headers['Authorization']
          || `Bearer ${userData.access_token}`;

        // 5. 保存认证信息
        const userInfo: UserInfo = {
          id: userData.id,
          email: userData.email,
          name: userData.nickname,
          nickname: userData.nickname,
          avatar: userData.avatar,
        };

        authStorage.setAuthData({
          Authorization: authorization,
          Token: userData.access_token,
          userInfo: userInfo,
        });

        return 0; // 成功
      } else {
        error.value = response.message || '登录失败';
        return response.code || -1;
      }
    } catch (err: any) {
      error.value = err.response?.data?.message || err.message || '登录失败，请检查网络连接';
      return -1;
    } finally {
      loading.value = false;
    }
  };

  return {
    loading,
    login,
    error,
  };
}

