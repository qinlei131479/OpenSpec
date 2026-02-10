# Mark2CAD 处理逻辑文档

## 📋 目录

1. [整体流程概览](#整体流程概览)
2. [阶段详解](#阶段详解)
3. [关键参数配置](#关键参数配置)
4. [防重叠机制](#防重叠机制)
5. [代码结构说明](#代码结构说明)

---

## 整体流程概览

```
Markdown 文件 
  ↓
解析为段落片段 (ParseMarkdownSegments)
  ↓
应用硬换行 (ApplyHardBreaks)
  ↓
按高度分割 (SplitSegmentsByHeight)
  ↓
计算度量 (ComputeSegmentMetrics)
  ↓
构建页面布局 (BuildPages)
  ↓
放置内容到 AutoCAD (PlacePageContent)
```

---

## 阶段详解

### 阶段 1: 文件读取与解析

**位置**: `Mark2CAD()` 方法 (303-466行)

#### 1.1 文件选择与读取
- 用户通过文件对话框选择 Markdown 文件
- 使用 UTF-8 编码读取文件内容
- 验证文件非空

#### 1.2 图框选择
- 提示用户在图纸空间中选择一个图框块（BlockReference）
- 验证图框是否在当前图纸空间中
- 获取图框的本地坐标边界（Extents3d）

#### 1.3 布局参数计算

```csharp
// 基础参数
列数 = 4
左边距 = 1600.0
右边距 = 1600.0
上边距 = 200.0
下边距 = 150.0
列间距 = 800.0
文字高度 = 300.0
行间距倍数 = 1.2

// 计算内容区域
内容宽度 = 图框宽度 - 左边距 - 右边距
内容高度 = 图框高度 - 上边距 - 下边距

// 计算列宽
列宽 = (内容宽度 - 列间距 * (列数 - 1)) / 列数
列宽 = min(列宽, 17000.0)  // 最大列宽限制

// 计算每列可容纳的行数
行高 = 文字高度 * 行间距倍数  // 300 * 1.2 = 360
每列行数 = floor((内容高度 / 行高) - 安全边距)
```

#### 1.4 字符宽度估算

```csharp
// 检测是否包含中文字符
if (包含CJK字符) {
    字符宽度因子 = 0.95  // 中文字符
} else {
    字符宽度因子 = 0.55  // 拉丁字符
}

字符宽度 = 文字高度 * 字符宽度因子
每行字符数 = max(10, 列宽 / 字符宽度)
```

---

### 阶段 2: Markdown 解析

**位置**: `ParseMarkdownSegments()` 方法 (499-664行)

#### 2.1 文本预处理

```csharp
// 统一换行符
normalized = markdown.Replace("\r\n", "\n").Replace("\r", "\n")

// 处理 <br> 标签（转换为换行符）
normalized = Regex.Replace(normalized, @"<br\s*/?>", "\n", RegexOptions.IgnoreCase)
normalized = Regex.Replace(normalized, @"<br[^>]*>", "\n", RegexOptions.IgnoreCase)
```

#### 2.2 元素识别

按优先级顺序识别以下元素：

| 元素类型 | 识别规则 | 生成片段类型 |
|---------|---------|------------|
| **HTML 表格** | 以 `<table` 开头 | `Table` |
| **Markdown 表格** | 以 `\|` 开头，包含至少 3 个 `\|` | `Table` |
| **代码块** | 以 ` ``` ` 开头和结尾 | `Code` |
| **标题** | 以 `#` 开头（1-6 个） | `Heading1/2/3` |
| **有序列表** | 以 `数字. ` 开头 | `Ordered` |
| **无序列表** | 以 `- `、`* ` 或 `+ ` 开头 | `Unordered` |
| **普通段落** | 其他文本 | `Body` |

#### 2.3 表格处理

**Markdown 表格**:
```markdown
| 列1 | 列2 | 列3 |
| --- | --- | --- |
| 数据1 | 数据2 | 数据3 |
```

- 识别分隔行（仅包含 `|`、`-`、`:`、空格）
- 解析单元格内容（按 `|` 分割）
- 存储为 `List<string[]>` 格式

**HTML 表格**:
```html
<table>
  <tr><td>单元格1</td><td>单元格2</td></tr>
</table>
```

- 使用正则表达式提取 `<tr>` 和 `<td>` 标签
- 处理 `rowspan` 和 `colspan` 属性
- 解码 HTML 实体（`&nbsp;`、`&lt;` 等）

#### 2.4 段落累积

- 连续的非特殊元素文本累积为一个段落
- 遇到空行时刷新当前段落
- 保留段落内部的换行符（来自 `<br>` 标签）

---

### 阶段 3: 文本换行处理

**位置**: `ApplyHardBreaks()` 方法 (1027-1045行)

#### 3.1 硬换行阈值

```csharp
阈值 = max(16, floor(每行字符数 * 1.2))
```

#### 3.2 换行插入逻辑

**对于格式化内容**（包含 MText 格式代码）:
- 跳过格式代码（`\H`、`\P`、`\b`、`\i` 等）
- 在连续非空白字符达到阈值时插入 `\P`
- 遇到空白字符时重置计数器

**对于纯文本**:
- 在连续非空白字符达到阈值时插入 `\n`
- 遇到换行符或空白字符时重置计数器

---

### 阶段 4: 按高度分割

**位置**: `SplitSegmentsByHeight()` 方法 (1130-1257行)

#### 4.1 分割规则

- **表格片段**: 不分割，作为整体处理
- **其他片段**: 按 `maxLinesPerColumn` 限制分割

#### 4.2 分割算法

```csharp
for (每个片段) {
    按 \P 分割内容为行列表
    
    currentPiece = 新片段
    usedLines = 0
    
    for (每行) {
        lineWeight = 片段行倍数
        
        if (usedLines + lineWeight > maxLinesPerColumn) {
            保存 currentPiece
            currentPiece = 新片段
            usedLines = 0
        }
        
        将行添加到 currentPiece
        usedLines += lineWeight
    }
    
    保存最后一个 currentPiece
}
```

#### 4.3 行倍数

不同片段类型的行倍数：
- `Heading1`: 2.0
- `Heading2`: 1.7
- `Heading3`: 1.4
- `Code`: 1.2
- `Body/Ordered/Unordered`: 1.0

---

### 阶段 5: 计算度量

**位置**: `ComputeSegmentMetrics()` 方法 (1324-1379行)

#### 5.1 表格高度计算（重点）

```csharp
// 1. 估算列宽
estimatedColumnWidth = TargetColumnWidth / ColumnCount  // 17000 / 4 = 4250

// 2. 计算每单元格可容纳的字符数
charsPerCellLine = max(10, columnWidth / (TextHeight * 0.95))
// 例如: max(10, 4250 / (300 * 0.95)) = max(10, 14.9) = 14.9

// 3. 遍历每一行，计算最大行数
totalRowHeight = 0
tableLineHeight = TextHeight * LineSpacingFactor * 1.5  // 300 * 1.2 * 1.5 = 540

for (每行 r) {
    maxLinesInRow = 1
    
    for (每个单元格 c) {
        cellText = 单元格文本
        if (cellText 非空) {
            // 估算该单元格需要的行数
            linesInCell = ceil(cellText.Length / charsPerCellLine)
            maxLinesInRow = max(maxLinesInRow, linesInCell)
        }
    }
    
    // 该行的总高度 = 最大行数 * 行高
    totalRowHeight += maxLinesInRow * tableLineHeight
}

// 4. 转换为等效文本行数
baseLines = totalRowHeight / (TextHeight * LineSpacingFactor)
// 例如: totalRowHeight / 360
```

#### 5.2 文本高度计算

```csharp
// 按换行符分割文本
plainLines = 片段纯文本.Split('\n')

baseLines = 0
for (每行 line) {
    trimmed = line.Trim()
    length = max(1, trimmed.Length)
    
    // 计算该行需要的行数（考虑换行）
    linesNeeded = max(1.0, length / 每行字符数)
    baseLines += linesNeeded
}

// 应用行倍数
baseLines = baseLines * 片段行倍数

// 四舍五入
片段.EstimatedLines = round(baseLines, 3)
```

---

### 阶段 6: 构建页面布局

**位置**: `BuildPages()` 方法 (1361-1401行)

#### 6.1 布局算法

```csharp
pages = []
currentPage = 新页面(4列)
columnIndex = 0
usedInColumn = 0

for (每个片段) {
    cost = 片段.EstimatedLines + (片段.TrailingBreaks * 片段行倍数)
    
    while (未放置) {
        available = linesPerColumn - usedInColumn
        
        if (cost > linesPerColumn && usedInColumn > 0) {
            // 片段太大，需要新列
            columnIndex++
            usedInColumn = 0
            
            if (columnIndex >= 4) {
                // 当前页已满，创建新页
                pages.Add(currentPage)
                currentPage = 新页面(4列)
                columnIndex = 0
            }
        } else if (cost > available && usedInColumn > 0) {
            // 当前列空间不足，移动到下一列
            columnIndex++
            usedInColumn = 0
            
            if (columnIndex >= 4) {
                pages.Add(currentPage)
                currentPage = 新页面(4列)
                columnIndex = 0
            }
        } else {
            // 可以放入当前列
            currentPage.Columns[columnIndex].Add(片段)
            usedInColumn += cost
            placed = true
        }
    }
}

// 保存最后一页
if (!currentPage.IsEmpty) {
    pages.Add(currentPage)
}
```

#### 6.2 页面结构

```csharp
class PageLayout {
    List<List<ParagraphSegment>> Columns  // 4 列
}

class ParagraphSegment {
    string Content          // MText 格式化内容
    string PlainText        // 纯文本
    ParagraphType Type      // 片段类型
    double LineMultiplier   // 行倍数
    int TrailingBreaks      // 后续空行数
    double EstimatedLines   // 估算行数
    List<string[]> TableData  // 表格数据（仅 Table 类型）
}
```

---

### 阶段 7: 放置内容到 AutoCAD

**位置**: `PlacePageContent()` 方法 (1534-2047行)

#### 7.1 初始化边界

```csharp
// 内容区域边界
contentMinX = 图框左边界 + 左边距 + 内容偏移X  // +1000
contentMaxY = 图框上边界 - 上边距 + 内容偏移Y - 安全边距  // -1000 - 4*TextHeight
contentMinY = 图框下边界 + 下边距 + 内容偏移Y + 安全边距  // -1000 + 4*TextHeight
contentMaxX = 图框右边界 - 右边距

// 初始位置
currentY = contentMaxY  // 从顶部开始
```

#### 7.2 放置表格

```csharp
if (片段类型 == Table) {
    // ========== 步骤 1: 创建表格 ==========
    table = CreateAutoCADTable(表格数据, ...)
    
    // ========== 步骤 2: 处理单元格文本换行 ==========
    for (每行 row) {
        maxLinesInRow = 1
        
        // 第一遍：计算每行最大行数
        for (每个单元格 col) {
            cellText = 单元格文本.Trim()
            
            if (!string.IsNullOrEmpty(cellText)) {
                // 根据列宽计算每行字符数
                charsPerCellLine = max(10, columnWidth / (TextHeight * 0.95))
                
                // 文本换行处理
                cellText = WrapCellText(cellText, charsPerCellLine)
                
                // 计算换行后的行数（统计 \P 分隔符）
                linesInCell = cellText.Split("\\P").Length
                maxLinesInRow = max(maxLinesInRow, linesInCell)
            }
        }
        
        // 根据最大行数设置行高
        table.Rows[row].Height = baseRowHeight * maxLinesInRow
        // baseRowHeight = TextHeight * LineSpacingFactor * 1.5 = 540
    }
    
    // 第二遍：填充单元格文本
    for (每行 row) {
        for (每个单元格 col) {
            cellText = WrapCellText(单元格文本, charsPerCellLine)
            table.Cells[row, col].TextString = cellText
            table.Cells[row, col].TextHeight = TextHeight
            table.Cells[row, col].Alignment = CellAlignment.MiddleCenter
            // 设置边框、文本样式等
        }
    }
    
    // ========== 步骤 3: 放置表格 ==========
    tableY = min(currentY, contentMaxY)
    table.Position = new Point3d(x, tableY, 0.0)
    table.TransformBy(blockRef.BlockTransform)
    
    // 添加到数据库
    paperBtr.AppendEntity(table)
    tr.AddNewlyCreatedDBObject(table, true)
    
    // ========== 步骤 4: 获取实际几何边界 ==========
    try {
        extents = table.GeometricExtents  // 世界坐标
        inverse = blockRef.BlockTransform.Inverse()
        minLocal = extents.MinPoint.TransformBy(inverse)  // 转换为本地坐标
        maxLocal = extents.MaxPoint.TransformBy(inverse)
        
        tableTopY = maxLocal.Y
        tableBottomY = minLocal.Y
        tableHeight = maxLocal.Y - minLocal.Y
        
        // 添加 15% 安全边距
        safetyMargin = tableHeight * 0.15
        tableHeight = tableHeight + safetyMargin
        tableBottomY = tableTopY - tableHeight
    } catch {
        // 回退：使用估算值
        tableHeight = 估算高度
        tableBottomY = tableY - tableHeight
    }
    
    // ========== 步骤 5: 边界检查 ==========
    if (tableTopY > contentMaxY || tableBottomY < contentMinY) {
        // 超出边界，删除表格并停止
        table.Erase()
        break
    }
    
    // ========== 步骤 6: 更新 currentY（关键！）==========
    spacingMargin = TextHeight * LineSpacingFactor * 3.0  // 3倍行高 = 1080
    currentY = tableBottomY - spacingMargin
    
    // 安全检查：确保 currentY 不低于最小边界
    if (currentY < contentMinY) {
        currentY = contentMinY + TextHeight * LineSpacingFactor
    }
    
    // ========== 步骤 7: 处理后续空行 ==========
    for (i = 0; i < 片段.TrailingBreaks; i++) {
        nextBreakY = currentY - tableLineHeight
        if (nextBreakY < contentMinY) {
            break  // 超出边界，停止
        }
        currentY = nextBreakY
    }
}
```

#### 7.3 放置文本

```csharp
if (片段类型 != Table) {
    // ========== 步骤 1: 估算高度 ==========
    segmentTextHeight = TextHeight * 片段行倍数
    segmentLineHeight = segmentTextHeight * LineSpacingFactor
    estimatedHeight = 片段.EstimatedLines * segmentLineHeight * 1.2  // 20% 安全边距
    
    // ========== 步骤 2: 预检查 ==========
    if (currentY - estimatedHeight < contentMinY) {
        break  // 超出边界，停止放置
    }
    
    // ========== 步骤 3: 创建 MText ==========
    mt = new MText()
    mt.Contents = 片段.Content  // 包含格式代码
    mt.TextHeight = segmentTextHeight
    mt.LineSpacingFactor = LineSpacingFactor
    mt.Width = columnWidth
    mt.Location = new Point3d(x, min(currentY, contentMaxY), 0.0)
    mt.TransformBy(blockRef.BlockTransform)
    
    // 添加到数据库
    paperBtr.AppendEntity(mt)
    tr.AddNewlyCreatedDBObject(mt, true)
    
    // ========== 步骤 4: 获取实际几何边界 ==========
    try {
        extents = mt.GeometricExtents
        inverse = blockRef.BlockTransform.Inverse()
        minLocal = extents.MinPoint.TransformBy(inverse)
        maxLocal = extents.MaxPoint.TransformBy(inverse)
        
        textTopY = maxLocal.Y
        textBottomY = minLocal.Y
        actualHeight = maxLocal.Y - minLocal.Y
    } catch {
        // 回退：使用估算值
        actualHeight = 片段.EstimatedLines * segmentLineHeight
        textBottomY = currentY - actualHeight
    }
    
    // ========== 步骤 5: 边界检查 ==========
    if (textTopY > contentMaxY || textBottomY < contentMinY) {
        mt.Erase()
        break
    }
    
    // ========== 步骤 6: 更新 currentY ==========
    spacingMargin = TextHeight * LineSpacingFactor * 1.5  // 1.5倍行高 = 540
    currentY = textBottomY - spacingMargin
    
    // 安全检查
    minSafeY = contentMinY + TextHeight * LineSpacingFactor
    if (currentY < minSafeY) {
        currentY = minSafeY
    }
    
    // ========== 步骤 7: 处理后续空行 ==========
    for (i = 0; i < 片段.TrailingBreaks; i++) {
        nextBreakY = currentY - segmentLineHeight
        if (nextBreakY < contentMinY) {
            break
        }
        currentY = nextBreakY
    }
}
```

#### 7.4 文本换行函数

**位置**: `WrapCellText()` 方法

```csharp
private static string WrapCellText(string text, int maxCharsPerLine) {
    if (text.Length <= maxCharsPerLine) {
        return text
    }
    
    result = StringBuilder()
    currentPos = 0
    
    while (currentPos < text.Length) {
        if (currentPos > 0) {
            result.Append("\\P")  // MText 段落分隔符
        }
        
        remaining = text.Length - currentPos
        take = min(maxCharsPerLine, remaining)
        
        // 尝试在单词边界处断行（提高可读性）
        if (take < remaining) {
            breakPos = currentPos + take
            
            // 向前查找空格或标点符号
            for (i = breakPos; i > currentPos + maxCharsPerLine * 2/3; i--) {
                ch = text[i - 1]
                if (ch 是空格或中文标点) {
                    breakPos = i
                    break
                }
            }
            take = breakPos - currentPos
        }
        
        result.Append(text.Substring(currentPos, take))
        currentPos += take
    }
    
    return result.ToString()
}
```

---

## 关键参数配置

### 布局参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `ColumnCount` | 4 | 列数 |
| `TextHeight` | 300.0 | 基础文字高度（mm） |
| `LineSpacingFactor` | 1.2 | 行间距倍数 |
| `LeftMargin` | 1600.0 | 左边距（mm） |
| `RightMargin` | 1600.0 | 右边距（mm） |
| `TopMargin` | 200.0 | 上边距（mm） |
| `BottomMargin` | 150.0 | 下边距（mm） |
| `ColumnSpacing` | 800.0 | 列间距（mm） |
| `ContentOffsetX` | 1000.0 | 内容向右偏移（mm） |
| `ContentOffsetY` | -1000.0 | 内容向下偏移（mm） |
| `TargetColumnWidth` | 17000.0 | 目标列宽（mm） |
| `TargetColumnHeight` | 57400.0 | 目标列高（mm） |

### 字符宽度因子

| 字符类型 | 因子 | 说明 |
|---------|------|------|
| `ApproxCharWidthFactorCjk` | 0.95 | 中文字符宽度（相对于文字高度） |
| `ApproxCharWidthFactorLatin` | 0.55 | 拉丁字符宽度（相对于文字高度） |

### 间距参数

| 间距类型 | 倍数 | 实际值 | 说明 |
|---------|------|--------|------|
| **表格后间距** | 3.0 | `TextHeight * 1.2 * 3.0 = 1080mm` | 表格与后续内容的间距 |
| **文本后间距** | 1.5 | `TextHeight * 1.2 * 1.5 = 540mm` | 文本段落之间的间距 |
| **表格安全边距** | 15% | `tableHeight * 1.15` | 表格高度增加的安全边距 |
| **文本安全边距** | 20% | `estimatedHeight * 1.2` | 文本高度估算的安全边距 |

### 行倍数

| 片段类型 | 行倍数 | 说明 |
|---------|--------|------|
| `Heading1` | 2.0 | 一级标题占用 2 倍行高 |
| `Heading2` | 1.7 | 二级标题占用 1.7 倍行高 |
| `Heading3` | 1.4 | 三级标题占用 1.4 倍行高 |
| `Code` | 1.2 | 代码块占用 1.2 倍行高 |
| `Body/Ordered/Unordered` | 1.0 | 普通文本占用 1 倍行高 |

---

## 防重叠机制

### 1. 表格单元格文本换行

**问题**: 单元格文本过长会导致行高自动扩展，实际高度超出估算值。

**解决方案**:
- 使用 `WrapCellText()` 函数根据列宽自动换行
- 优先在空格和标点符号处断行
- 使用 `\P` 作为 MText 段落分隔符

### 2. 动态行高设置

**问题**: 固定行高无法容纳换行后的多行文本。

**解决方案**:
- 两遍处理：先计算每行最大行数，再设置行高
- 根据单元格换行后的实际行数动态设置：`row.Height = baseRowHeight * maxLinesInRow`

### 3. 实际几何边界计算

**问题**: 估算高度可能不准确，导致位置计算错误。

**解决方案**:
- 使用 `GeometricExtents` 获取表格和文本的实际渲染尺寸
- 将世界坐标转换为本地坐标进行准确计算
- 基于实际边界更新 `currentY`

### 4. 安全边距机制

**问题**: 渲染差异可能导致实际高度略大于估算值。

**解决方案**:
- **表格**: 实际高度增加 15% 安全边距
- **文本**: 估算高度增加 20% 安全边距
- **间距**: 表格后 3 倍行高，文本后 1.5 倍行高

### 5. 边界检查

**问题**: 内容可能超出图框边界。

**解决方案**:
- 放置前预检查：`if (currentY - estimatedHeight < contentMinY) break`
- 放置后验证：检查 `GeometricExtents` 是否在边界内
- 双重检查：确保 `textBottomY >= contentMinY` 和 `tableBottomY >= contentMinY`
- 最小安全位置：`currentY = max(currentY, contentMinY + TextHeight * LineSpacingFactor)`

### 6. 位置更新策略

**关键原则**: 始终使用实际几何边界更新位置，而不是估算值。

```csharp
// ❌ 错误：使用估算值
currentY = currentY - estimatedHeight

// ✅ 正确：使用实际边界
extents = entity.GeometricExtents
actualBottomY = extents.MinPoint.Y (转换到本地坐标)
currentY = actualBottomY - spacingMargin
```

---

## 代码结构说明

### 主要方法列表

| 方法名 | 行数范围 | 功能 |
|--------|---------|------|
| `Mark2CAD()` | 303-466 | 主入口方法，协调整个流程 |
| `ParseMarkdownSegments()` | 499-664 | 解析 Markdown 为段落片段 |
| `ApplyHardBreaks()` | 1027-1045 | 在长文本中插入硬换行 |
| `SplitSegmentsByHeight()` | 1130-1257 | 按高度分割超长片段 |
| `ComputeSegmentMetrics()` | 1324-1379 | 计算每个片段的估算行数 |
| `BuildPages()` | 1361-1401 | 构建页面布局，分配片段到列 |
| `PlacePageContent()` | 1534-2047 | 在 AutoCAD 中放置内容 |
| `CreateAutoCADTable()` | 2058-2179 | 创建 AutoCAD 表格对象 |
| `WrapCellText()` | 1047-1081 | 单元格文本换行处理 |

### 数据结构

#### ParagraphSegment

```csharp
class ParagraphSegment {
    string Content          // MText 格式化内容（包含 \H、\P、\b 等格式代码）
    string PlainText        // 纯文本（用于计算）
    ParagraphType Type      // 片段类型
    double LineMultiplier   // 行倍数（标题、代码等占用更多空间）
    int TrailingBreaks      // 后续空行数
    double EstimatedLines   // 估算占用的行数
    List<string[]> TableData  // 表格数据（仅 Table 类型）
    
    double LineCost => EstimatedLines + (TrailingBreaks * LineMultiplier)
}
```

#### PageLayout

```csharp
class PageLayout {
    List<List<ParagraphSegment>> Columns  // 4 列，每列包含片段列表
    
    bool IsEmpty => Columns.All(c => c.Count == 0)
}
```

---

## 处理流程图

```
┌─────────────────┐
│  Markdown 文件  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ ParseMarkdownSegments() │ 解析为段落片段
│ - 识别标题、表格、列表等 │
│ - 处理 <br> 标签        │
│ - 累积段落文本          │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  ApplyHardBreaks()      │ 插入硬换行
│ - 长文本插入 \P         │
│ - 阈值：每行字符数 * 1.2 │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ SplitSegmentsByHeight() │ 按高度分割
│ - 表格不分割            │
│ - 其他按 maxLines 分割   │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ ComputeSegmentMetrics() │ 计算度量
│ - 表格：考虑换行计算高度 │
│ - 文本：按行长度计算     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│    BuildPages()         │ 构建页面布局
│ - 分配到 4 列           │
│ - 自动分页              │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  PlacePageContent()      │ 放置内容
│                         │
│  ┌───────────────────┐  │
│  │ 放置表格           │  │
│  │ 1. 单元格文本换行  │  │
│  │ 2. 动态设置行高     │  │
│  │ 3. 获取实际边界     │  │
│  │ 4. 更新 currentY   │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │ 放置文本           │  │
│  │ 1. 创建 MText     │  │
│  │ 2. 获取实际边界     │  │
│  │ 3. 更新 currentY   │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

---

## 注意事项

1. **坐标系统**: 
   - AutoCAD 使用世界坐标，需要转换为图框的本地坐标
   - Y 轴向上为正，向下为负

2. **文本换行**:
   - MText 使用 `\P` 作为段落分隔符
   - 单元格文本换行需要考虑列宽和字符宽度

3. **边界检查**:
   - 始终在放置前预检查
   - 放置后验证实际边界
   - 使用安全边距防止边界情况

4. **性能考虑**:
   - 表格解析有最大行数限制（100行）防止无限循环
   - 使用估算值进行预检查，减少不必要的计算

5. **错误处理**:
   - 表格创建失败时返回 null，不影响其他内容
   - 边界检查失败时删除实体并停止当前列的处理

---

## 版本历史

- **v1.0** (当前版本)
  - 实现基础 Markdown 解析和导入
  - 支持表格、标题、列表等元素
  - 实现防重叠机制
  - 支持自动分页和多图框复制

---

## 相关文件

- 主代码文件: `AutoCAD 2026 Plugin CS1/AutoCAD 2026 Plugin CS1/myCommands.cs`
- 测试文件: `test/设计说明示例.md`
- 项目说明: `README.md`

---

*最后更新: 2024年*

