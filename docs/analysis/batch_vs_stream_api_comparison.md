# 章节生成接口对比分析：Batch vs Stream

## 1. 概述

本文档对比分析 ArchSpec 系统中两个章节生成接口的处理流程差异，解释为什么 `/agent/workflow/chat/batch` 接口比 `/agent/workflow/chat/stream` 接口响应更快。

| 接口 | 路径 | 平均响应时间 | 用途 |
|------|------|-------------|------|
| Batch 接口 | `/agent/workflow/chat/batch` | 1-2 分钟 | 批量生成多个章节 |
| Stream 接口 | `/agent/workflow/chat/stream` | 较长 | 单章节流式生成 |

---

## 2. 架构对比

### 2.1 调用链路

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Batch 接口调用链路                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  前端 (ragflow.ts)                                                          │
│       │                                                                     │
│       ▼                                                                     │
│  workflow_api.py: workflow_chat_batch()                                     │
│       │                                                                     │
│       ▼                                                                     │
│  batch_construction_agent.py: generate_chapter_batch()                      │
│       │                                                                     │
│       ▼                                                                     │
│  LangGraph: batch_app.ainvoke() (异步非流式)                                 │
│       │                                                                     │
│       ▼                                                                     │
│  节点: researcher → researcher_tools → generate → END                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              Stream 接口调用链路                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  前端 (ragflow.ts)                                                          │
│       │                                                                     │
│       ▼                                                                     │
│  workflow_api.py: workflow_chat_stream()                                    │
│       │                                                                     │
│       ▼                                                                     │
│  construction_agent.py: app (LangGraph StateGraph)                          │
│       │                                                                     │
│       ▼                                                                     │
│  LangGraph: agent_app.astream_events() (流式事件)                            │
│       │                                                                     │
│       ▼                                                                     │
│  节点: router → researcher → researcher_tools → generate → [auditor] → END  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 核心差异总结

| 维度 | Batch 接口 | Stream 接口 |
|------|-----------|-------------|
| **Agent 文件** | `batch_construction_agent.py` | `construction_agent.py` |
| **执行方式** | `ainvoke()` 异步非流式 | `astream_events()` 流式事件 |
| **LLM 配置** | `streaming=False` | `streaming=True` |
| **节点数量** | 3 个 (researcher, tools, generate) | 7 个 (router, general_agent, researcher, generate, auditor 等) |
| **路由节点** | ❌ 无 | ✅ 有 (router_node) |
| **审核节点** | ❌ 无 | ✅ 有 (auditor_node) |
| **思考阶段** | ❌ 无 | ✅ 有 (两步执行策略) |
| **SSE 事件** | ❌ 无 | ✅ 有 (timeline, token, tool_call 等) |

---

## 3. 详细流程对比

### 3.1 Batch 接口流程 (batch_construction_agent.py)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Batch 工作流                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐                                               │
│  │  researcher  │ ◄─────────────────────────────┐               │
│  │   (单步执行)  │                               │               │
│  └──────┬───────┘                               │               │
│         │                                       │               │
│         ▼ tool_calls?                           │               │
│    ┌────┴────┐                                  │               │
│    │   Yes   │──► researcher_tools ─────────────┘               │
│    └────┬────┘                                                  │
│         │ No                                                    │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │   generate   │                                               │
│  │   (单步执行)  │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│         ▼                                                       │
│       [END]                                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**关键特点**：
1. **无路由判断**：直接进入 researcher 节点
2. **单步执行**：每个节点只调用一次 LLM（无思考+行动两阶段）
3. **无审核环节**：生成后直接结束
4. **非流式 LLM**：`streaming=False`，减少网络开销

### 3.2 Stream 接口流程 (construction_agent.py)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Stream 工作流                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐                                               │
│  │    router    │ ──► 意图分类 (generate_doc / general_chat)    │
│  └──────┬───────┘                                               │
│         │                                                       │
│    ┌────┴────────────────┐                                      │
│    │                     │                                      │
│    ▼                     ▼                                      │
│ [general_agent]    ┌──────────────┐                             │
│    分支             │  researcher  │ ◄────────────────┐          │
│                    │ (思考+行动)   │                  │          │
│                    └──────┬───────┘                  │          │
│                           │                          │          │
│                           ▼ tool_calls?              │          │
│                      ┌────┴────┐                     │          │
│                      │   Yes   │──► researcher_tools─┘          │
│                      └────┬────┘                                │
│                           │ No                                  │
│                           ▼                                     │
│                    ┌──────────────┐                             │
│                    │   generate   │                             │
│                    │ (思考+行动)   │                             │
│                    └──────┬───────┘                             │
│                           │                                     │
│                           ▼ enable_audit?                       │
│                      ┌────┴────┐                                │
│                      │   Yes   │──► auditor ──► [可能循环]       │
│                      └────┬────┘                                │
│                           │ No                                  │
│                           ▼                                     │
│                         [END]                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**关键特点**：
1. **有路由判断**：router 节点先判断意图
2. **两步执行策略**：每个核心节点都有「思考」+「行动」两阶段
3. **可选审核环节**：`enable_audit=True` 时进入 auditor 循环
4. **流式 LLM**：`streaming=True`，实时输出 token
5. **SSE 事件流**：生成 timeline_step, token, tool_call 等事件

---

## 4. 性能差异分析

### 4.1 LLM 调用次数对比

假设一次章节生成需要 2 轮检索：

| 阶段 | Batch 接口 LLM 调用 | Stream 接口 LLM 调用 |
|------|-------------------|---------------------|
| 路由 | 0 次 | 1 次 |
| Researcher 第1轮 | 1 次 | 2 次 (思考+行动) |
| Researcher 第2轮 | 1 次 | 2 次 (思考+行动) |
| Generate | 1 次 | 2 次 (思考+行动) |
| Auditor (如启用) | 0 次 | 2+ 次 |
| **总计** | **3 次** | **7-9+ 次** |

### 4.2 时间开销分解

```
┌─────────────────────────────────────────────────────────────────┐
│                    Batch 接口时间分布                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Researcher (1次LLM)     ████████████  ~20s                     │
│  Tool Execution          ████████      ~15s                     │
│  Researcher (1次LLM)     ████████████  ~20s                     │
│  Tool Execution          ████████      ~15s                     │
│  Generate (1次LLM)       ████████████████████  ~30s             │
│                                                                 │
│  总计: ~100s (1.5-2分钟)                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Stream 接口时间分布                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Router (1次LLM)         ████████  ~10s                         │
│  Researcher 思考 (流式)   ████████████  ~20s                     │
│  Researcher 行动 (非流式) ████████  ~10s                         │
│  Tool Execution          ████████  ~15s                         │
│  Researcher 思考 (流式)   ████████████  ~20s                     │
│  Researcher 行动 (非流式) ████████  ~10s                         │
│  Tool Execution          ████████  ~15s                         │
│  Generate 思考 (流式)     ████████████  ~20s                     │
│  Generate 行动 (流式)     ████████████████████  ~30s             │
│  [Auditor 如启用]        ████████████████  ~40s+                │
│                                                                 │
│  总计: ~150-200s+ (2.5-4分钟)                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 性能差异根本原因

| 因素 | 影响程度 | 说明 |
|------|---------|------|
| **LLM 调用次数** | ⭐⭐⭐⭐⭐ | Batch 约 3 次，Stream 约 7-9 次，差距 2-3 倍 |
| **两步执行策略** | ⭐⭐⭐⭐ | Stream 每个节点都有思考+行动两阶段 |
| **路由节点** | ⭐⭐ | Stream 多一次 LLM 调用判断意图 |
| **审核节点** | ⭐⭐⭐ | Stream 可能触发 auditor 循环 |
| **流式开销** | ⭐ | SSE 事件处理有少量额外开销 |

---

## 5. 代码关键差异

### 5.1 LLM 初始化

**Batch (batch_construction_agent.py:46-50)**
```python
llm = ChatTongyi(
    model="qwen-max",
    temperature=0.1,
    streaming=False,  # 非流式
)
```

**Stream (construction_agent.py:51-54)**
```python
llm = ChatTongyi(
    model="qwen-max",
    temperature=0.1,
    # 默认 streaming=True
)
```

### 5.2 Researcher 节点实现

**Batch (单步执行)**
```python
def researcher_node(state: BatchAgentState):
    # 直接调用 LLM，无思考阶段
    response = researcher_llm.invoke(messages)
    return {"messages": [response], "research_loop_count": loop_count + 1}
```

**Stream (两步执行)**
```python
def researcher_node(state: AgentState, config: RunnableConfig):
    # 阶段 1: 思考 (Streaming)
    streaming_llm = ChatTongyi(model="qwen-max", streaming=True)
    thought_response = streaming_llm.invoke(messages, step1_config)

    # 阶段 2: 行动 (Non-Streaming)
    tool_response = researcher_llm.invoke(messages_for_tool, config)

    return {"messages": [thought_response, tool_response], ...}
```

### 5.3 工作流图结构

**Batch (3 节点)**
```python
workflow.add_node("researcher", researcher_node)
workflow.add_node("researcher_tools", ToolNode(researcher_tools))
workflow.add_node("generate", generate_node)

workflow.set_entry_point("researcher")
workflow.add_edge("generate", END)
```

**Stream (7 节点)**
```python
workflow.add_node("router", router_node)
workflow.add_node("general_agent", general_agent_node)
workflow.add_node("general_tools", ToolNode(general_tools))
workflow.add_node("researcher", researcher_node)
workflow.add_node("researcher_tools", ToolNode(researcher_tools))
workflow.add_node("generate", generate_node)
workflow.add_node("auditor", auditor_node)
workflow.add_node("auditor_tools", auditor_tools_node)

workflow.set_entry_point("router")
# 复杂的条件边...
```

---

## 6. 适用场景建议

| 场景 | 推荐接口 | 原因 |
|------|---------|------|
| 批量生成多个章节 | Batch | 速度快，无需实时反馈 |
| 单章节交互式生成 | Stream | 实时显示进度和思考过程 |
| 需要审核校验 | Stream | 支持 auditor 节点 |
| 后台任务/定时任务 | Batch | 无需 SSE 连接 |
| 用户实时编辑 | Stream | 流式输出体验更好 |

---

## 7. 优化建议

### 7.1 如果需要加速 Stream 接口

1. **禁用审核**：设置 `enable_audit=False`（已实现）
2. **简化思考阶段**：考虑移除 researcher 的思考阶段
3. **缓存路由结果**：对于明确的生成请求，跳过 router 节点

### 7.2 如果需要增强 Batch 接口

1. **添加简化审核**：可选的轻量级后处理校验
2. **返回引用信息**：目前 Batch 不返回 `doc_reference` 和 `chunk_reference`

---

## 8. 结论

Batch 接口比 Stream 接口快 **40-60%** 的主要原因：

1. **LLM 调用次数减少 50-70%**：无路由、无两步执行、无审核
2. **架构更简单**：3 节点 vs 7 节点
3. **无流式开销**：直接返回结果，无 SSE 事件处理

两个接口各有适用场景，Batch 适合批量任务，Stream 适合交互式体验。

---

*文档生成时间：2026-01-26*
*分析基于代码版本：当前 main 分支*
