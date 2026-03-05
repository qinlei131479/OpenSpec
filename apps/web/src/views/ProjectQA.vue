<template>
  <div class="qa-page">
    <AppHeader>
      <template #nav>
        <router-link class="nav-item" to="/editor">文档生成</router-link>
        <router-link class="nav-item active" to="/qa">项目问答</router-link>
      </template>
      <template #actions>
        <div class="search-bar">
          <el-input
            v-model="searchText"
            placeholder="输入项目问题，例如：设备房设置是否满足规范？"
            class="qa-search-input"
            clearable
            @keyup.enter="submitQuestion"
          >
          </el-input>
          <el-button @click="submitQuestion">
            <el-icon><Search /></el-icon>
          </el-button>
        </div>
      </template>
    </AppHeader>

    <div class="qa-container">
      <ProjectList 
        :projects="projects"
        :activeId="selectedProjectId"
        @select="handleSelectProject"
        @create="createProject"
        @create-session="handleCreateSession"
      />
      <main class="qa-main">
        <div class="qa-thread">
          <div
            class="qa-item"
            v-for="qa in qaList"
            :key="qa.id"
          >
            <div class="qa-item-header">
              <div class="qa-title">
                <el-tag type="info">问题</el-tag>
                <span class="qa-question">{{ qa.question }}</span>
              </div>
              <span class="qa-time">{{ qa.time }}</span>
            </div>

            <div class="qa-answer">
              <div class="qa-section">
                <div class="qa-section-header">
                  <h4>管理建议</h4>
                </div>
                <p class="qa-text">{{ qa.suggestion }}</p>
              </div>

              <div class="qa-section">
                <div class="qa-section-header">
                  <h4>规范依据</h4>
                </div>
                <div class="ref-list">
                  <div
                    v-for="ref in qa.references"
                    :key="ref.id"
                    class="ref-card"
                    :class="ref.status"
                  >
                    <div class="ref-header">
                      <h5 class="ref-title">{{ ref.title }}</h5>
                      <el-tag v-if="ref.status === 'applicable'" type="success">建议应用</el-tag>
                      <el-tag v-else-if="ref.status === 'warning'" type="warning">需审查</el-tag>
                      <el-tag v-else type="danger">不适用</el-tag>
                    </div>
                    <p class="ref-snippet">{{ ref.snippet }}</p>
                    <div class="ref-meta">
                      <span class="ref-code">{{ ref.code }}</span>
                      <div class="ref-actions">
                        <el-button size="small" type="primary">应用</el-button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="qa-input-bar">
          <el-input
            v-model="newQuestion"
            placeholder="继续提问：请输入您的项目问题"
            clearable
            @keyup.enter="addQuestion"
          >
            <template #prefix>
              <el-icon><ChatDotRound /></el-icon>
            </template>
            <template #append>
              <el-button type="primary" @click="addQuestion">发送</el-button>
            </template>
          </el-input>
        </div>
      </main>

      <aside class="qa-sidebar">
        <div class="knowledge-search">
          <el-input 
            v-model="knowledgeSearch"
            placeholder="搜索规范、标准条文..."
            @input="filterKnowledge"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>

        <div class="knowledge-categories">
          <el-radio-group v-model="activeCategory" @change="filterKnowledge">
            <el-radio-button v-for="category in knowledgeCategories" :key="category.label" :label="category.label">{{ category.name }}</el-radio-button>
          </el-radio-group>
        </div>

        <div class="knowledge-list">
          <div 
            v-for="item in filteredKnowledgeItems"
            :key="item.id"
            class="knowledge-item"
            :data-category="item.category"
          >
            <div class="knowledge-header">
              <h4>{{ item.title }}</h4>
              <el-button size="small" type="primary" @click="applyKnowledge(item)">插入</el-button>
            </div>
            <p class="knowledge-snippet">{{ item.snippet }}</p>
            <div class="knowledge-meta">
              <el-tag size="small">{{ item.tag }}</el-tag>
              <span class="usage">使用 {{ item.usage }} 次</span>
            </div>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { Search, ChatDotRound } from '@element-plus/icons-vue'
import AppHeader from '@/components/AppHeader.vue'
import ProjectList from '@/components/ProjectList.vue'
import { knowledgeItems as mockKnowledgeItems, knowledgeCategories as mockKnowledgeCategories, mockProjects, type ProjectItem } from '@/data/mockData'

const searchText = ref('')
const submitQuestion = () => {
  if (!searchText.value.trim()) {
    ElMessage.warning('请输入问题再发起问答')
    return
  }
  newQuestion.value = searchText.value.trim()
  addQuestion()
  searchText.value = ''
}

interface QAReference {
  id: number
  title: string
  snippet: string
  code: string
  status: 'applicable' | 'warning' | 'not_applicable'
}
interface QAItem {
  id: number
  question: string
  suggestion: string
  time: string
  references: QAReference[]
}

const qaList = ref<QAItem[]>([
  {
    id: 1,
    question: '装外平台设置是否满足检修电梯所需净高？需要配置是否电梯救援？',
    suggestion: '建议在施工深化阶段核对设备房间层高与检修平台布置，优先参考国家标准，其次结合公司标准与类似项目经验进行综合判断。',
    time: new Date().toLocaleString('zh-CN'),
    references: [
      {
        id: 11,
        title: 'GB 50045-2011 高层民用建筑设计防火规范',
        snippet: '电梯机房的耐火等级及疏散安全要求，应满足建筑整体防火分区的设置与疏散通道的连续性。',
        code: 'GB 50045-2011',
        status: 'applicable'
      },
      {
        id: 12,
        title: 'JGJ 312-2013 既有建筑电气改造',
        snippet: '对既有建筑电梯及附属设施的改造，需满足电气安全与检修维护空间的最小净空要求。',
        code: 'JGJ 312-2013',
        status: 'warning'
      },
      {
        id: 13,
        title: 'GB 16895.24-2005 低压配电系统',
        snippet: '电气设备检修平台的布置不应影响主要疏散通道，检修状态下仍需保证基本通行能力。',
        code: 'GB 16895.24-2005',
        status: 'not_applicable'
      }
    ]
  }
])

const newQuestion = ref('')
const addQuestion = () => {
  const q = newQuestion.value.trim()
  if (!q) return
  const item: QAItem = {
    id: Date.now(),
    question: q,
    suggestion: '已记录问题，系统将结合知识库给出建议与规范依据。',
    time: new Date().toLocaleString('zh-CN'),
    references: [
      {
        id: Date.now() + 1,
        title: 'GB 50016-2014 建筑设计防火规范',
        snippet: '疏散通道、设备附属空间的净空应满足相应条文的最低要求。',
        code: 'GB 50016-2014',
        status: 'applicable'
      }
    ]
  }
  qaList.value.unshift(item)
  newQuestion.value = ''
  ElMessage.success('已创建新的问答条目')
}

const knowledgeSearch = ref('')
const activeCategory = ref('all')
const knowledgeItems = ref([...mockKnowledgeItems])
const knowledgeCategories = ref([...mockKnowledgeCategories])

const filteredKnowledgeItems = computed(() => {
  const keyword = knowledgeSearch.value.trim().toLowerCase()
  const category = activeCategory.value
  return knowledgeItems.value.filter((it: any) => {
    const byCat = category === 'all' ? true : it.category === category
    const byKey = !keyword ? true : (it.title.toLowerCase().includes(keyword) || it.snippet.toLowerCase().includes(keyword))
    return byCat && byKey
  })
})

const filterKnowledge = () => {}
const applyKnowledge = (item: any) => {
  ElMessage.success(`已插入：${item.title}`)
}

const projects = ref<ProjectItem[]>([...mockProjects])
const selectedProjectId = ref<string>(projects.value[0]?.id || '')
const handleSelectProject = (projectId: string) => {
  selectedProjectId.value = projectId
  projects.value.forEach(p => p.isActive = p.id === projectId)
}
const handleSelectSession = (projectId: string, session: any) => {
  ElMessage.success(`已切换到会话：${session.name}`)
  // TODO: Load session data
}
const createProject = () => {
  //TODO 新建项目
  ElMessage.info('新建项目功能待接入')
}

const handleCreateSession = (projectId: string) => {
  //TODO 新建会话
  ElMessage.info('新建会话功能待接入')
}

</script>

<style scoped>
.qa-page {
  min-height: 100vh;
  background: var(--gray-50);
  display: flex;
  flex-direction: column;
}

.search-bar {
  display: flex;
}

.qa-search-input :deep(.el-input-group__append) {
  padding: 0;
}

.qa-container {
  display: grid;
  grid-template-columns: 280px 1fr 320px;
  gap: var(--spacing-md);
  padding: var(--spacing-md) 0;
  height: calc(100vh - 56px);
}

.qa-main {
  background: white;
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
  padding: var(--spacing-md);
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
  height: 100%;
  overflow: hidden;
}

.qa-thread {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
  flex: 1;
  overflow-y: auto;
}

.qa-item {
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
}

.qa-item-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: var(--spacing-sm);
}

.qa-title {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-weight: 600;
  color: var(--gray-900);
}
.qa-question {
  font-size: 14px;
}
.qa-time {
  font-size: 12px;
  color: var(--gray-600);
}

.qa-section {
  margin-top: var(--spacing-sm);
}
.qa-section-header h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-900);
  margin-bottom: 8px;
}
.qa-text {
  font-size: 13px;
  color: var(--gray-700);
  line-height: 1.7;
}

.ref-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}
.ref-card {
  background: white;
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
}
.ref-card.applicable { border-color: var(--success-color); }
.ref-card.warning { border-color: var(--warning-color); }
.ref-card.not_applicable { border-color: var(--error-color); }

.ref-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: var(--spacing-xs);
}
.ref-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-900);
}
.ref-snippet {
  font-size: 13px;
  color: var(--gray-700);
  line-height: 1.6;
  margin-bottom: var(--spacing-sm);
}
.ref-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: var(--gray-600);
}
.ref-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.qa-input-bar :deep(.el-input-group__append) {
  padding: 0;
  width: 60px;
}

.qa-sidebar {
  background: white;
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
  display: flex;
  flex-direction: column;
}

.knowledge-search {
  padding: 20px 10px;
}
.knowledge-list {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-md);
}
.knowledge-item {
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
  margin-bottom: var(--spacing-md);
}
.knowledge-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: var(--spacing-sm);
}
.knowledge-header h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-900);
}
.knowledge-snippet {
  font-size: 13px;
  color: var(--gray-700);
  line-height: 1.6;
  margin-bottom: var(--spacing-sm);
}
.knowledge-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.knowledge-categories {
  padding-left: 10px !important;
}
.usage {
  font-size: 11px;
  color: var(--gray-500);
}
</style>
