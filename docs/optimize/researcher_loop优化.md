# Researcher 循环优化说明

## 修改概述

针对 `researcher_node` 反复检索导致大量耗时的问题，已实施综合优化方案。

## 修改内容

### 1. 新增配置常量 (L39-40)

```python
MAX_RESEARCH_LOOPS = 3  # Researcher 最大循环次数（硬性上限）
MIN_CONTENT_THRESHOLD = 500  # 检索内容最小阈值（字符数）
```

**说明**：
- `MAX_RESEARCH_LOOPS`: 硬性限制循环次数，默认最多 3 次
- `MIN_CONTENT_THRESHOLD`: 用于评估检索内容是否充足

---

### 2. 新增辅助函数 `evaluate_retrieval_quality` (L76-120)

**功能**：智能评估检索结果质量，判断是否应该提前退出循环

**终止条件**：
1. 连续 3 次以上检索失败（"未检索到"）且已循环 2 次以上
2. 最近两次检索均返回空结果且已循环 1 次以上

**返回值**：
```python
{
    "should_stop": bool,  # 是否应该停止
    "reason": str         # 停止原因
}
```

---

### 3. 优化 `researcher_node` 函数 (L203-292)

#### 3.1 添加循环计数追踪 (L216-219)

```python
loop_count = state.get("research_loop_count", 0)
logger.info(f"[Researcher] Loop iteration: {loop_count + 1}/{MAX_RESEARCH_LOOPS}")
```

#### 3.2 动态 Prompt 引导 (L221-227)

根据循环次数生成不同的引导语：

- **第 1 次**：鼓励全面收集资料
- **第 2 次**：提示补充关键信息，如有足够资料可结束
- **第 3 次**：⚠️ 强调这是最后机会，避免过度追求完美

#### 3.3 更新循环计数器 (L288-292)

```python
return {
    "messages": [thought_response, tool_response],
    "research_loop_count": loop_count + 1  # 递增计数
}
```

---

### 4. 重构 `researcher_condition` 函数 (L434-470)

**新增四层判断逻辑**（按优先级）：

#### 优先级 1: 硬性限制 (L447-452)
```python
if loop_count >= MAX_RESEARCH_LOOPS:
    logger.warning(f"[Researcher] Reached max loops ({MAX_RESEARCH_LOOPS})")
    return "generate"
```

#### 优先级 2: 质量评估 (L455-461)
```python
quality_check = evaluate_retrieval_quality(state)
if quality_check["should_stop"]:
    logger.info(f"[Researcher] Quality check triggered early exit")
    return "generate"
```

#### 优先级 3: LLM 判断 (L464-466)
```python
if last_msg.tool_calls:
    return "researcher_tools"  # 继续循环
```

#### 优先级 4: 正常退出 (L469-470)
```python
logger.info(f"[Researcher] No tool calls, exiting after {loop_count} loops")
return "generate"
```

---

## 优化效果

### 问题场景
- **修改前**：检索结果不理想时，LLM 可能无限循环检索
- **修改后**：最多循环 3 次，或检测到连续失败时提前退出

### 预期改进

| 场景 | 修改前 | 修改后 |
|------|--------|--------|
| 正常检索（1-2次成功） | ✅ 正常 | ✅ 正常 |
| 检索失败（连续空结果） | ❌ 可能无限循环 | ✅ 2次后自动退出 |
| 检索结果不理想 | ❌ 反复尝试 | ✅ 3次后强制退出 |
| 平均耗时 | 不可控 | 可控（最多3轮） |

---

## 配置调整建议

### 场景 1: 知识库内容丰富
```python
MAX_RESEARCH_LOOPS = 2  # 减少到 2 次
MIN_CONTENT_THRESHOLD = 1000  # 提高内容要求
```

### 场景 2: 知识库内容稀疏
```python
MAX_RESEARCH_LOOPS = 4  # 增加到 4 次
MIN_CONTENT_THRESHOLD = 300  # 降低内容要求
```

### 场景 3: 快速响应优先
```python
MAX_RESEARCH_LOOPS = 2  # 最多 2 次
# 在 evaluate_retrieval_quality 中调整：
# empty_results >= 2  # 改为 2 次空结果就退出
```

---

## 日志监控

### 关键日志输出

1. **循环开始**
```
[Researcher] Loop iteration: 1/3
```

2. **达到上限**
```
[Researcher] Reached max loops (3), forcing exit to generate
```

3. **质量检测退出**
```
[Researcher] Quality check triggered early exit: 连续 3 次检索失败，提前退出
```

4. **正常退出**
```
[Researcher] No tool calls, exiting to generate after 2 loops
```

### 监控建议

在生产环境中监控以下指标：
- 平均循环次数
- 强制退出频率
- 质量检测触发频率

---

## 测试建议

### 测试用例 1: 正常场景
- **输入**：常规文档生成请求
- **预期**：1-2 次循环后正常退出

### 测试用例 2: 空结果场景
- **输入**：知识库中不存在的内容
- **预期**：2 次循环后质量检测触发退出

### 测试用例 3: 极端场景
- **输入**：LLM 持续认为资料不足
- **预期**：3 次循环后硬性限制触发退出

---

## 回滚方案

如需回滚到原始版本，修改以下内容：

1. 移除 `evaluate_retrieval_quality` 函数
2. 恢复 `researcher_condition` 为简单版本：
```python
def researcher_condition(state: AgentState):
    last_msg = state["messages"][-1]
    if last_msg.tool_calls:
        return "researcher_tools"
    return "generate"
```
3. 移除 `researcher_node` 中的循环计数更新

---

## 后续优化方向

1. **自适应循环次数**：根据历史成功率动态调整 `MAX_RESEARCH_LOOPS`
2. **内容质量评分**：使用 LLM 评估检索内容的相关性和完整性
3. **用户可配置**：允许用户在请求中指定最大循环次数
4. **性能监控面板**：可视化展示循环统计数据

---

## 修改文件清单

- ✅ `apps/agent/service/workflow/construction_agent.py`
  - 新增配置常量 (L39-40)
  - 新增辅助函数 (L76-120)
  - 优化 researcher_node (L203-292)
  - 重构 researcher_condition (L434-470)

---

**修改日期**: 2026-01-16
**修改人**: Claude Code
**版本**: v1.0
