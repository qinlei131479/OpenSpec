import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

import components from 'unplugin-vue-components/vite';
import { AntDesignXVueResolver } from 'ant-design-x-vue/resolver';

// https://vite.dev/config/
export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '');

  const server = command === 'serve'
    ? {
        proxy: {
          '/api': {
            target: env.VITE_API_TARGET || env.VITE_PROXY_TARGET,
            changeOrigin: true,
            rewrite: (path: string) => path.replace(/^\/api/, '/api'),
          },
          '/agent': {
            target: env.VITE_AGENT_TARGET,
            changeOrigin: true,
          }
        }
      }
    : undefined;

  return {
    base: '/',
    plugins: [
      vue(),
      components({ resolvers: [AntDesignXVueResolver()] }),
    ],
    envPrefix: ['VITE_', 'RAGFLOW_', 'AI_'],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    server
  }
})
