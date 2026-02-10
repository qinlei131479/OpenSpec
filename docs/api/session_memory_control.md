# Session 记忆区间控制功能

## 概述

本文档介绍如何根据用户需求控制 AI Agent 的对话记忆区间，支持两种过滤策略：
1. **按轮数过滤**：保留最近 N 轮对话
2. **按章节过滤**：只保留指定章节的对话历史

## 技术架构

### 数据存储

Session 功能基于 **PostgreSQL** 实现，使用 LangGraph 的 `PostgresSaver` 作为 checkpointer。

#### 自动创建的表结构

当调用 `checkpointer.setup()` 时，会自动创建 3 张表：

```sql
-- 1. checkpoints: 存储对话状态快照
CREATE TABLE checkpoints (
    thread_id TEXT,
    checkpoint_ns TEXT,
    checkpoint_id TEXT,
    parent_checkpoint_id TEXT,
    type TEXT,
    checkpoint JSONB,
    metadata JSONB,
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id)
);

-- 2. checkpoint_blobs: 存储大型二进制数据
CREATE TABLE checkpoint_blobs (
    thread_id TEXT,
    checkpoint_ns TEXT,
    channel TEXT,
    version TEXT,
    type TEXT,
    blob BYTEA,
    PRIMARY KEY (thread_id, checkpoint_ns, channel, version)
);

-- 3. checkpoint_writes: 存储检查点写入记录
CREATE TABLE checkpoint_writes (
    thread_id TEXT,
    checkpoint_ns TEXT,
    checkpoint_id TEXT,
    task_id TEXT,
    idx INTEGER,
    channel TEXT,
    type TEXT,
    blob BYTEA,
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id, task_id, idx)
);
```

### 当前状态

⚠️ **注意**：由于 `langgraph-checkpoint-postgres` 版本 3.0.3 的异步兼容性问题，checkpointer 当前处于**临时禁用**状态。

- 代码位置：`apps/agent/service/workflow/construction_agent.py`
- 问题：`aget_tuple` 方法未实现异步支持，导致 `astream_events` 调用失败
- 影响：对话状态不会持久化，使用内存模式
- 解决方案：等待 LangGraph 库升级后重新启用

## API 使用方法

### 请求参数

在 `WorkflowChatRequest` 中新增了以下参数：

```python
class WorkflowChatRequest(BaseModel):
    # ... 其他字段 ...
    
    # Session 控制
    resume_session: Optional[bool] = True  # 是否恢复历史 Session
    
    # 记忆区间控制（新增）
    memory_window: Optional[int] = None     # 保留最近 N 轮对话（None=全部，0=清空）
    memory_chapters: Optional[List[str]] = None  # 指定保留的章节名称列表
```

### 使用场景

#### 场景 1：保留最近 3 轮对话

适用于：减少上下文长度，提高响应速度

```json
{
  "message": "生成第五章：施工方案",
  "user_id": "user_123",
  "document_id": "doc_456",
  "chapter_name": "第五章",
  "resume_session": true,
  "memory_window": 3
}
```

**效果**：
- 只保留最近 3 轮对话（HumanMessage + AIMessage + ToolMessage）
- 更早的对话历史会被过滤掉
- 减少 token 消耗，加快生成速度

#### 场景 2：只保留特定章节的对话

适用于：生成相关章节时需要参考之前的内容

```json
{
  "message": "生成第五章：施工方案",
  "user_id": "user_123",
  "document_id": "doc_456",
  "chapter_name": "第五章",
  "resume_session": true,
  "memory_chapters": ["第一章", "第三章", "第五章"]
}
```

**效果**：
- 只保留提到"第一章"、"第三章"、"第五章"的对话
- 自动包含当前章节（第五章）
- 过滤掉其他无关章节的对话

#### 场景 3：清空所有历史

适用于：开始新的文档生成，不需要任何历史

```json
{
  "message": "生成第一章：工程概况",
  "user_id": "user_123",
  "document_id": "doc_456",
  "chapter_name": "第一章",
  "resume_session": false
}
```

或者：

```json
{
  "message": "生成第一章：工程概况",
  "user_id": "user_123",
  "document_id": "doc_456",
  "chapter_name": "第一章",
  "resume_session": true,
  "memory_window": 0
}
```

**效果**：
- 完全清空对话历史
- 从零开始新的对话

#### 场景 4：保留全部历史（默认）

适用于：需要完整的上下文信息

```json
{
  "message": "生成第五章：施工方案",
  "user_id": "user_123",
  "document_id": "doc_456",
  "chapter_name": "第五章",
  "resume_session": true
}
```

**效果**：
- 保留所有历史对话
- 提供最完整的上下文

## 过滤策略优先级

当同时设置多个参数时，按以下优先级执行：

1. **`memory_chapters`**（章节过滤）- 优先级最高
2. **`memory_window`**（轮数过滤）- 次之
3. **默认行为**（保留全部）- 最低

示例：

```json
{
  "memory_window": 5,
  "memory_chapters": ["第一章", "第三章"]
}
```

实际执行：只应用章节过滤，忽略轮数过滤。

## 实现细节

### 核心函数

#### 1. `filter_memory_by_window()`

按对话轮数过滤历史消息。

```python
def filter_memory_by_window(messages: list, memory_window: Optional[int] = None) -> list:
    """
    根据对话轮数过滤历史消息
    
    Args:
        messages: 原始消息列表
        memory_window: 保留最近 N 轮对话（None=全部，0=清空）
    
    Returns:
        过滤后的消息列表
    """
```

**算法**：
1. 跳过所有 `SystemMessage`
2. 将消息按轮次分组（一轮 = HumanMessage + AIMessage + ToolMessage）
3. 保留最近 N 轮
4. 展平返回

#### 2. `filter_memory_by_chapters()`

按章节名称过滤历史消息。

```python
def filter_memory_by_chapters(messages: list, 
                              chapter_names: Optional[List[str]] = None,
                              current_chapter: Optional[str] = None) -> list:
    """
    根据章节名称过滤历史消息
    
    Args:
        messages: 原始消息列表
        chapter_names: 要保留的章节名称列表
        current_chapter: 当前章节名称（自动保留）
    
    Returns:
        过滤后的消息列表
    """
```

**算法**：
1. 构建章节关键词集合（包含 `current_chapter`）
2. 遍历所有消息
3. 保留 `SystemMessage` 和包含目标章节关键词的消息
4. 返回过滤结果

#### 3. `apply_memory_filters()`

统一的过滤入口，应用优先级策略。

```python
def apply_memory_filters(messages: list, 
                        memory_window: Optional[int] = None,
                        memory_chapters: Optional[List[str]] = None,
                        current_chapter: Optional[str] = None) -> list:
    """
    应用记忆过滤策略
    
    优先级：
    1. memory_chapters（章节过滤）优先级最高
    2. memory_window（轮数过滤）次之
    3. 如果都不设置，保留全部历史
    """
```

### 集成到 API

在 `workflow_chat_stream()` 中的实现：

```python
# 当 checkpointer 启用后，可以获取并过滤历史消息
if request.memory_window is not None or request.memory_chapters:
    state = agent_app.get_state(config)
    if state and state.values.get("messages"):
        original_messages = state.values["messages"]
        filtered_messages = apply_memory_filters(
            original_messages,
            memory_window=request.memory_window,
            memory_chapters=request.memory_chapters,
            current_chapter=request.chapter_name
        )
        # 更新状态
        agent_app.update_state(config, {"messages": filtered_messages})
```

## 启用 PostgreSQL Checkpointer

当 LangGraph 库升级后，按以下步骤启用：

### 1. 取消注释代码

编辑 `apps/agent/service/workflow/construction_agent.py`：

```python
def get_checkpointer():
    postgres_url = os.getenv('POSTGRES_URL')
    if not postgres_url:
        logger.warning("POSTGRES_URL not set, memory persistence disabled")
        return None

    try:
        # 创建连接池
        connection_pool = ConnectionPool(
            conninfo=postgres_url,
            max_size=20,
            kwargs={
                "autocommit": True,
                "prepare_threshold": 0,
            }
        )

        # 创建 PostgresSaver
        checkpointer = PostgresSaver(connection_pool)

        # 初始化数据库表（如果不存在）
        checkpointer.setup()  # 👈 自动创建 3 张表

        logger.info("PostgreSQL Checkpointer initialized successfully")
        return checkpointer
    except Exception as e:
        logger.error(f"Failed to initialize PostgreSQL Checkpointer: {e}")
        return None
```

### 2. 验证数据库连接

确保 `.env` 文件中配置正确：

```bash
POSTGRES_URL="postgresql://archspec:archspec_doc_pass@localhost:5433/doc_generator"
```

### 3. 重启服务

```bash
docker-compose restart agent
```

### 4. 验证表创建

连接到 PostgreSQL 并检查：

```sql
\dt  -- 查看所有表

SELECT * FROM checkpoints LIMIT 5;
SELECT * FROM checkpoint_blobs LIMIT 5;
SELECT * FROM checkpoint_writes LIMIT 5;
```

## 日志示例

### 成功过滤日志

```
[INFO] [workflow_chat_stream] Applying memory filters: window=3, chapters=None
[INFO] [Memory Filter] Kept 3/10 rounds, 15/50 messages
[INFO] [workflow_chat_stream] Filtered messages: 50 -> 15
```

### 章节过滤日志

```
[INFO] [workflow_chat_stream] Applying memory filters: window=None, chapters=['第一章', '第三章']
[INFO] [Memory Filter] Kept 25/50 messages for chapters: {'第一章', '第三章', '第五章'}
[INFO] [workflow_chat_stream] Filtered messages: 50 -> 25
```

### Checkpointer 禁用警告

```
[WARNING] [workflow_chat_stream] Memory filtering requires PostgreSQL checkpointer (currently disabled)
[WARNING] [workflow_chat_stream] Memory filters will take effect once checkpointer is enabled
```

## 性能优化建议

### 1. 合理设置记忆窗口

- **短文档**（< 5 章）：`memory_window=None`（保留全部）
- **中等文档**（5-10 章）：`memory_window=5`
- **长文档**（> 10 章）：`memory_window=3` 或使用章节过滤

### 2. 使用章节过滤

对于相关章节生成，使用章节过滤比轮数过滤更精确：

```json
{
  "memory_chapters": ["工程概况", "施工部署", "施工方案"]
}
```

### 3. Token 消耗对比

假设每轮对话平均 2000 tokens：

| 策略 | 保留轮数 | Token 消耗 | 成本节省 |
|------|---------|-----------|---------|
| 全部保留 | 10 轮 | 20,000 | 0% |
| window=5 | 5 轮 | 10,000 | 50% |
| window=3 | 3 轮 | 6,000 | 70% |
| 章节过滤 | 4 轮 | 8,000 | 60% |

## 前端集成示例

### React/Vue 示例

```typescript
interface ChatRequest {
  message: string;
  user_id: string;
  document_id: string;
  chapter_name: string;
  resume_session?: boolean;
  memory_window?: number;
  memory_chapters?: string[];
}

// 场景 1: 用户选择"保留最近 3 轮"
const request: ChatRequest = {
  message: userInput,
  user_id: currentUser.id,
  document_id: currentDocument.id,
  chapter_name: currentChapter,
  resume_session: true,
  memory_window: 3
};

// 场景 2: 用户选择"只参考相关章节"
const request: ChatRequest = {
  message: userInput,
  user_id: currentUser.id,
  document_id: currentDocument.id,
  chapter_name: currentChapter,
  resume_session: true,
  memory_chapters: selectedChapters  // 用户勾选的章节
};

// 发送请求
const response = await fetch('/agent/workflow/chat/stream', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(request)
});
```

### UI 设计建议

```
┌─────────────────────────────────────┐
│ 记忆设置                             │
├─────────────────────────────────────┤
│ ○ 保留全部历史                       │
│ ● 保留最近 [3▼] 轮对话              │
│ ○ 只保留选定章节：                   │
│   ☑ 第一章：工程概况                 │
│   ☐ 第二章：施工部署                 │
│   ☑ 第三章：施工方案                 │
│   ☐ 第四章：质量管理                 │
│ ○ 清空所有历史                       │
└─────────────────────────────────────┘
```

## 故障排查

### 问题 1：过滤不生效

**症状**：设置了 `memory_window=3`，但仍然使用全部历史

**原因**：Checkpointer 被禁用

**解决**：
1. 检查日志是否有警告：`Memory filtering requires PostgreSQL checkpointer`
2. 等待 LangGraph 库升级
3. 或使用临时方案（在 inputs 中手动过滤）

### 问题 2：章节过滤不准确

**症状**：某些相关对话被过滤掉了

**原因**：章节名称匹配不精确

**解决**：
1. 使用更完整的章节名称（如"第一章：工程概况"而不是"第一章"）
2. 检查消息内容是否包含章节关键词
3. 调整过滤算法，使用模糊匹配

### 问题 3：性能下降

**症状**：启用过滤后响应变慢

**原因**：过滤逻辑在主线程执行

**解决**：
1. 优化过滤算法（使用索引、缓存）
2. 异步执行过滤操作
3. 减少过滤频率（仅在必要时过滤）

## 未来优化方向

1. **智能推荐**：根据当前章节自动推荐相关历史章节
2. **语义过滤**：使用向量相似度而不是关键词匹配
3. **分层记忆**：短期记忆（最近 3 轮）+ 长期记忆（重要章节）
4. **用户偏好**：记住用户的过滤偏好设置
5. **可视化**：展示哪些历史被保留/过滤

## 参考资料

- [LangGraph Checkpointing 文档](https://langchain-ai.github.io/langgraph/how-tos/persistence_postgres/)
- [PostgresSaver API 参考](https://reference.langchain.com/javascript/classes/_langchain_langgraph-checkpoint-postgres.index.PostgresSaver.html)
- [项目 Session 修复文档](../apps/agent/SESSION_USER_FIX_SUMMARY.md)
