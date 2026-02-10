/**
 * 用户相关 API 服务
 */
import axios from 'axios';
import type { AxiosResponse } from 'axios';
import { getAuthorization, authStorage, redirectToLogin } from '@/utils/auth';

// 配置 API 基础 URL
// RAGFlow 后端地址
const API_BASE_URL = import.meta.env.RAGFLOW_BASE_URL  || 'https://rag.aizzyun.com/v1';

// 创建 axios 实例
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器：自动添加 Authorization header
apiClient.interceptors.request.use(
  (config: any) => {
    const authorization = getAuthorization();
    if (authorization && !(config.headers as any).skipToken) {
      config.headers.Authorization = authorization;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器：处理错误
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // 未授权，清除认证信息并跳转到登录页
      authStorage.clearAll();
      redirectToLogin();
    }
    return Promise.reject(error);
  }
);

/**
 * API 响应格式
 */
export interface ApiResponse<T = any> {
  code: number;
  message?: string;
  data?: T;
}

/**
 * 登录请求参数
 */
export interface LoginParams {
  email: string;
  password: string;
}

/**
 * 用户信息
 */
export interface UserData {
  id: string;
  email: string;
  nickname: string;
  avatar?: string;
  access_token: string;
  is_superuser?: boolean;
  is_active?: string;
  [key: string]: any;
}

/**
 * 登录接口
 * @param params 登录参数
 * @returns 包含响应数据和完整响应对象的 Promise
 */
export async function login(
  params: LoginParams
): Promise<{ data: ApiResponse<UserData>; response: AxiosResponse }> {
  const response = await apiClient.post<ApiResponse<UserData>>(
    '/user/login',
    params,
    { headers: { skipToken: true } } as any // 登录接口不需要 token
  );
  return { data: response.data, response };
}

/**
 * 登出接口
 * @returns API 响应
 */
export async function logout(): Promise<ApiResponse> {
  const response = await apiClient.get<ApiResponse>('/user/logout');
  return response.data;
}

/**
 * 获取用户信息
 * @returns 用户信息
 */
export async function getUserInfo(): Promise<ApiResponse<UserData>> {
  const response = await apiClient.get<ApiResponse<UserData>>('/user/info');
  return response.data;
}

