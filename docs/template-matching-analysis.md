# 模板自动匹配功能分析与改进建议

## 1. 概述

本文档分析 `ChatAssistant.vue` 中模板自动匹配功能的现有处理逻辑，并结合 `TemplateDetail.vue` 的改进经验，提出优化建议。

---

## 2. 现有处理逻辑详解

### 2.1 核心函数 - `matchTemplate()` (L160-210)

**位置**: `apps/web/src/components/ChatAssistant.vue`

```typescript
const matchTemplate = async () => {
  matchStatus.value = 'none';
  if (!props.currentChapter || documentTemplates.value.length === 0) return;

  isMatchingTemplate.value = true;

  const mockContent = getChapterTemplate(props.currentChapter.title);
  if (mockContent) {
    chapterTemplateText.value = mockContent;
    selectedTemplateId.value = null;
    matchStatus.value = 'default';
  }

  // TODO: 智能匹配 API 暂时禁用
  isMatchingTemplate.value = false;
};
```

**处理流程**:

1. **前置检查**
   - 重置匹配状态 `matchStatus = 'none'`
   - 检查是否有当前章节 (`currentChapter`)
   - 检查是否有模板列表 (`documentTemplates`)

2. **Mock 数据回退**
   - 调用 `getChapterTemplate(title)` 获取预设的章节模板
   - 设置 `chapterTemplateText` 为 Mock 内容
   - 清空选中的模板 ID
   - 设置状态为 `'default'`

3. **智能匹配 (已禁用)**
   - 原计划调用 `searchTemplateChapter()` API
   - 使用 RAGFlow 进行向量检索
   - 根据相似度阈值 (0.5) 匹配最佳结果

### 2.2 手动选择处理 - `handleTemplateChange()` (L212-256)

```typescript
const handleTemplateChange = async (val) => {
  if (!val) {
    // 清除选择，恢复 Mock
    const mockContent = getChapterTemplate(props.currentChapter?.title);
    chapterTemplateText.value = formatContentToString(mockContent);
    matchStatus.value = 'default';
    return;
  }

  matchStatus.value = 'manual';
  // 尝试智能检索对应章节
  // ...
  // 回退：使用模板全文内容
};
```

**处理流程**:

1. **清除选择时**: 恢复 Mock 数据
2. **选择模板时**:
   - 设置状态为 `'manual'`
   - 尝试通过 `searchTemplateChapter()` 获取章节内容
   - 失败时回退到模板全文

### 2.3 API 接口 - `searchTemplateChapter()`

**位置**: `apps/web/src/service/template.ts`

```typescript
interface TemplateMatchResult {
  templateId: number
  templateName: string
  chunkId: string
  chunkContent: string
  chapterTitle: string
  similarity: number
  matchType: 'auto' | 'manual' | 'default'
}

async function searchTemplateChapter(params: {
  userId: string
  chapterTitle: string
  tagIds?: number[]
  threshold?: number  // 默认 0.5
  limit?: number      // 默认 3
}): Promise<ApiResponse<{
  matched: TemplateMatchResult | null
  alternatives: TemplateMatchResult[]
}>>
```

**功能**:
- 基于 RAGFlow Metadata 的智能匹配
- 使用用户 ID 进行权限过滤
- 使用章节标题进行向量检索
- 返回最佳匹配及备选项

### 2.4 匹配状态机

| 状态 | 含义 | 触发条件 |
|------|------|----------|
| `'none'` | 未匹配 | 初始化 / 重置 |
| `'default'` | 使用 Mock 数据 | 无模板或智能匹配失败 |
| `'success'` | 智能匹配成功 | API 返回有效结果 |
| `'manual'` | 手动选择 | 用户选择模板 |

---

## 3. 数据流图

```
┌────────────────────────────────────────────────────────────────────┐
│                         ChatAssistant.vue                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  currentChapter ──┬──> matchTemplate() ──> chapterTemplateText     │
│                   │         │                                      │
│                   │         ├──> getChapterTemplate() [Mock]       │
│                   │         │                                      │
│                   │         └──> searchTemplateChapter() [API]     │
│                   │                      │                         │
│                   │                      ↓                         │
│                   │               RAGFlow 检索                     │
│                   │                      │                         │
│                   │                      ↓                         │
│                   │             TemplateMatchResult                │
│                   │                                                │
│  selectedTemplateId ──> handleTemplateChange() ──> ...             │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 4. 与 TemplateDetail.vue 的关联

### 4.1 TemplateDetail.vue 中的改进

在 `TemplateDetail.vue` 中，我们解决了以下问题：

1. **Chunks 与 Chapters 不匹配问题**
   - `content` 字段有 30 个 chunks（按 `\n---\n\n` 分隔）
   - `chapters` 字段有 100+ 个层级结构（level 1/2/3）
   - 原代码简单用索引对应，导致显示错误

2. **解决方案**
   - 从每个 chunk 内容中提取主章节号（如 "11"）
   - 将所有属于同一主章节的 chunks 合并
   - 为每个主章节创建单一的 section

### 4.2 对 ChatAssistant 的影响

`searchTemplateChapter()` API 返回的 `chunkContent` 可能存在同样的问题：
- **问题**: 返回的单个 chunk 可能不是完整的章节内容
- **影响**: 用户看到的模板参考内容不完整

---

## 5. 改进建议

### 5.1 短期改进 (Quick Wins)

#### 5.1.1 启用智能匹配 API

```typescript
// 移除 TODO 注释，启用智能匹配
const matchTemplate = async () => {
  // ... 前置检查

  try {
    const result = await searchTemplateChapter({
      userId: String(user.id),
      chapterTitle: props.currentChapter.title,
      threshold: 0.5,
      limit: 3
    });

    if (result.code === 200 && result.data?.matched) {
      const matched = result.data.matched;
      selectedTemplateId.value = matched.templateId;
      chapterTemplateText.value = matched.chunkContent;
      matchStatus.value = 'success';
    } else {
      // 回退到 Mock
    }
  } catch (error) {
    // 回退到 Mock
  }
};
```

#### 5.1.2 添加加载状态反馈

```typescript
// 添加匹配进度提示
const matchingProgress = ref<string>('');

const matchTemplate = async () => {
  matchingProgress.value = '正在检索模板...';
  // ...
  matchingProgress.value = '';
};
```

### 5.2 中期改进 (Architecture)

#### 5.2.1 合并章节内容

参考 `TemplateDetail.vue` 的改进，在后端或前端合并属于同一主章节的 chunks：

**后端改进 (推荐)**:
```python
# agent/template/search.py
def merge_chunks_by_chapter(chunks, chapter_number):
    """将属于同一主章节的所有chunks合并"""
    merged = []
    for chunk in chunks:
        if extract_chapter_number(chunk.content) == chapter_number:
            merged.append(chunk.content)
    return '\n\n'.join(merged)
```

**前端改进**:
```typescript
// 在 searchTemplateChapter 返回后处理
const mergeChunksByChapter = (matched: TemplateMatchResult, template: DocumentTemplate) => {
  if (!template.content || !template.chapters) return matched.chunkContent;

  // 解析 chapters 获取主章节号
  const chapters = JSON.parse(template.chapters);
  const mainChapters = chapters.filter(ch => ch.level === 1);

  // 从 chunkContent 提取主章节号
  const chapterMatch = matched.chunkContent.match(/(?:^|\n)#+\s+(\d+)[\.\s]/m);
  if (!chapterMatch) return matched.chunkContent;

  const chapterNumber = chapterMatch[1];

  // 合并所有属于该章节的 chunks
  const chunkParts = template.content.split('\n---\n\n');
  const mergedContent = chunkParts
    .filter(chunk => {
      const m = chunk.match(/(?:^|\n)#+\s+(\d+)[\.\s]/m);
      return m && m[1] === chapterNumber;
    })
    .join('\n\n');

  return mergedContent || matched.chunkContent;
};
```

#### 5.2.2 改进 API 接口

扩展 `searchTemplateChapter` 接口，支持返回完整章节：

```typescript
// service/template.ts
interface EnhancedTemplateMatchResult extends TemplateMatchResult {
  // 新增：完整的章节内容（合并后）
  fullChapterContent: string
  // 新增：章节在文档中的位置
  chapterPosition: {
    start: number
    end: number
    totalChapters: number
  }
}
```

### 5.3 长期改进 (Feature Enhancement)

#### 5.3.1 多模板比较

允许用户同时查看多个模板的相同章节：

```typescript
interface TemplateComparison {
  templateId: number
  templateName: string
  chapterContent: string
  similarity: number
}

const compareTemplates = async (chapterTitle: string): Promise<TemplateComparison[]>
```

#### 5.3.2 模板推荐系统

基于项目信息和用户历史，推荐最合适的模板：

```typescript
interface TemplateRecommendation {
  templateId: number
  score: number
  reasons: string[]  // 推荐理由
}

const recommendTemplates = async (projectInfo: ProjectInfo): Promise<TemplateRecommendation[]>
```

#### 5.3.3 章节差异对比

显示当前内容与模板章节的差异：

```typescript
interface ChapterDiff {
  additions: string[]
  deletions: string[]
  modifications: Array<{
    original: string
    modified: string
  }>
}
```

---

## 6. 实施优先级

| 优先级 | 改进项 | 工作量 | 影响范围 |
|--------|--------|--------|----------|
| P0 | 启用智能匹配 API | 低 | ChatAssistant |
| P0 | 添加加载状态反馈 | 低 | ChatAssistant |
| P1 | 合并章节内容（后端） | 中 | Agent API |
| P1 | 改进 API 返回结构 | 中 | template.ts |
| P2 | 多模板比较 | 高 | 新功能 |
| P2 | 模板推荐系统 | 高 | 新功能 |
| P3 | 章节差异对比 | 高 | 新功能 |

---

## 7. 总结

### 7.1 现有问题

1. **智能匹配已禁用**: 当前仅使用 Mock 数据
2. **Chunk 不完整**: 返回的单个 chunk 可能不是完整章节
3. **缺少加载反馈**: 用户无法感知匹配进度
4. **无备选方案展示**: 仅显示最佳匹配，不展示备选

### 7.2 建议行动

1. **立即执行**: 启用智能匹配 API，添加加载状态
2. **短期规划**: 实现章节内容合并逻辑（参考 TemplateDetail.vue）
3. **中期规划**: 改进 API 接口，支持完整章节返回
4. **长期规划**: 多模板比较、推荐系统、差异对比

---

## 附录

### A. 相关文件

- `apps/web/src/components/ChatAssistant.vue` - 主组件
- `apps/web/src/service/template.ts` - API 服务
- `apps/web/src/views/TemplateDetail.vue` - 模板详情（参考改进）
- `apps/agent/service/tools/template_matcher.py` - 后端匹配服务

### B. 参考 PR

- TemplateDetail.vue 章节合并改进 (本次修改)
