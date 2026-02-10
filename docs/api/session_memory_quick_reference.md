# Session 记忆区间控制 - 快速参考

## API 参数

```typescript
{
  // 基础参数
  message: string;
  user_id: string;
  document_id: string;
  chapter_name: string;
  
  // Session 控制
  resume_session?: boolean;      // 是否恢复历史（默认 true）
  
  // 记忆过滤（新增）
  memory_window?: number;        // 保留最近 N 轮（null=全部，0=清空）
  memory_chapters?: string[];    // 保留指定章节
}
```

## 快速示例

### 1️⃣ 保留最近 3 轮

```json
{ "memory_window": 3 }
```

### 2️⃣ 只保留特定章节

```json
{ "memory_chapters": ["第一章", "第三章"] }
```

### 3️⃣ 清空历史

```json
{ "resume_session": false }
```
或
```json
{ "memory_window": 0 }
```

### 4️⃣ 保留全部（默认）

```json
{ "resume_session": true }
```

## 优先级

```
memory_chapters > memory_window > 默认（全部）
```

## 效果对比

| 策略 | Token 节省 | 适用场景 |
|------|-----------|---------|
| 全部保留 | 0% | 短文档（< 5 章） |
| window=5 | 50% | 中等文档（5-10 章） |
| window=3 | 70% | 长文档（> 10 章） |
| 章节过滤 | 60% | 相关章节生成 |

## curl 示例

```bash
# 保留最近 3 轮
curl -X POST http://localhost:5000/agent/workflow/chat/stream \
  -H "Content-Type: application/json" \
  -d '{"message":"生成第五章","user_id":"user_001","document_id":"doc_001","memory_window":3}'

# 章节过滤
curl -X POST http://localhost:5000/agent/workflow/chat/stream \
  -H "Content-Type: application/json" \
  -d '{"message":"生成第五章","user_id":"user_001","document_id":"doc_001","memory_chapters":["第一章","第三章"]}'
```

## 注意事项

⚠️ **当前状态**：PostgreSQL checkpointer 临时禁用
- 原因：LangGraph 库异步兼容性问题
- 影响：过滤功能暂不生效
- 解决：等待库升级后自动启用

## 完整文档

📖 [session_memory_control.md](./session_memory_control.md)
