import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import Home from '../views/Home.vue'
import CreateDocument from '../views/CreateDocument.vue'
import Editor from '../views/Editor.vue'
import Login from '../views/Login.vue'
import Register from '../views/Register.vue'
import ProjectQA from '../views/ProjectQA.vue'
import Settings from '../views/Settings.vue'
import TemplateDetail from '../views/TemplateDetail.vue'
import { authStorage } from '../utils/auth'

const routes: RouteRecordRaw[] = [
  // 公开路由
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { requiresAuth: false }
  },
  {
    path: '/register',
    name: 'Register',
    component: Register,
    meta: { requiresAuth: false }
  },

  // 主页（新增）
  {
    path: '/',
    redirect: '/home'
  },
  {
    path: '/home',
    name: 'Home',
    component: Home,
    meta: { requiresAuth: false }
  },

  // 文档新建（新增）
  {
    path: '/create',
    name: 'CreateDocument',
    component: CreateDocument,
    meta: { requiresAuth: true }
  },

  // 文档编辑（精简，id 必填）
  {
    path: '/editor/:id',
    name: 'Editor',
    component: Editor,
    meta: { requiresAuth: true }
  },

  // 其他保持不变
  {
    path: '/qa',
    name: 'ProjectQA',
    component: ProjectQA,
    meta: { requiresAuth: true }
  },
  {
    path: '/settings',
    name: 'Settings',
    component: Settings,
    meta: { requiresAuth: true }
  },
  {
    path: '/template/:id',
    name: 'TemplateDetail',
    component: TemplateDetail,
    meta: { requiresAuth: true }
  },

  // 兜底
  {
    path: '/:pathMatch(.*)*',
    redirect: '/home'
  }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// 路由守卫：检查登录状态
router.beforeEach((to, from, next) => {
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const isAuthenticated = authStorage.isAuthenticated()

  // 如果路由需要认证但用户未登录，重定向到登录页
  if (requiresAuth && !isAuthenticated) {
    next({
      path: '/login',
      query: { redirect: to.fullPath } // 保存原始路径，登录后可以跳转回去
    })
  }
  // 如果已登录用户访问登录页或注册页，重定向到首页
  else if ((to.path === '/login' || to.path === '/register') && isAuthenticated) {
    next('/home')
  }
  else {
    next()
  }
})

export default router
