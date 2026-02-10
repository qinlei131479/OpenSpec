# 建筑设计说明文档生成系统 - 后端接口文档（MVP 精简版）

> 说明：本次开发仅验证最小可用版本（MVP）。仅支持单层目录（parent_id=null, level=1），采用 Google Docs 风格的 `document_blocks` 模型。未列出的功能暂不实现，原有复杂方案保留为附录参考。

> 内容格式：Markdown 存储，前端使用 marked 渲染。错误码仅保留常用：200/201/400/401/404/409/500。

# 建筑设计说明文档生成系统 - 后端接口文档

## 1. 概述

本文档描述了建筑设计说明文档生成系统的后端API接口规范。

### 1.1 基础信息
- **Base URL**: `https://api.example.com/v1`
- **认证方式**: Bearer Token
- **数据格式**: JSON
- **字符编码**: UTF-8

### 1.2 通用响应格式

#### 成功响应
```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

#### 错误响应
```json
{
  "code": 400,
  "message": "错误描述",
  "data": null
}
```

### 1.3 HTTP状态码
- `200`: 请求成功
- `201`: 创建成功
- `400`: 请求参数错误
- `401`: 未授权
- `403`: 禁止访问
- `404`: 资源不存在
- `500`: 服务器内部错误

---

## 2. 用户认证

// 用户模块登录、登出使用 ragflow 用户模块，或待后续完善

## 3. 文档管理

### 3.1 获取文档列表
**接口**: `GET /documents`

**请求头**: `Authorization: Bearer <token>`

**查询参数**:
- `page`: 页码，默认1
- `pageSize`: 每页数量，默认20
- `status`: 文档状态(draft/reviewing/finalized)
- `keyword`: 搜索关键词
- `userId`（必填）: 当前用户ID，仅返回该用户创建的文档

**说明**:
- 服务端会根据 `userId` 过滤文档（等价于查询条件 `documents.user_id = :userId`）。
- 未提供 `userId` 时，返回 400（参数缺失）。

**请求示例**:
```bash
GET /documents?page=1&pageSize=20&userId=user-001
```

**响应示例**:
```json
{
    "code": 200,
    "message": "success",
    "data": {
        "total": 2,
        "page": 1,
        "pageSize": 20,
        "list": [
            {
                "id": "DOC-100001",
                "name": "Demo PRD 文档",
                "userId": "user-001",
                "projectInfo": "{\"env\": \"local\", \"project\": \"AI Doc Demo\"}",
                "metaTags": "[\"demo\", \"prd\"]",
                "version": 1,
                "lastModifiedBy": "user-001",
                "isDeleted": false,
                "createdAt": "2025-10-31T01:52:43",
                "updatedAt": "2025-10-31T01:52:43"
            },
            {
                "id": "DOC-100002",
                "name": "接口说明文档",
                "userId": "user-002",
                "projectInfo": "{\"env\": \"local\", \"project\": \"API Spec\"}",
                "metaTags": "[\"api\", \"spec\"]",
                "version": 1,
                "lastModifiedBy": "user-002",
                "isDeleted": false,
                "createdAt": "2025-10-31T01:52:43",
                "updatedAt": "2025-10-31T01:52:43"
            }
        ]
    }
}
```

### 3.2 创建文档
**接口**: `POST /documents/create`

**请求头**: `Authorization: Bearer <token>`

**请求参数**:
```json
{
  "name": "测试文档1号",
  "userId": "user123",  // 新增：用户ID（必填）
  "projectInfo": {
    "projectName": "AI Doc Demo",
    "env": "dby",
    "place": "sz",
    "startDate": "1995-02-18"
  }
}
```

**参数说明**:
- `name`: 文档名称（字符串）
- `projectInfo`: 项目信息（JSON 对象），字段不固定，可根据实际需求动态扩展

**响应示例**:
```json
{
    "code": 201,
    "message": "created",
    "data": {
        "id": "df873c5b-c06d-4bdc-ac4e-b2863fb5fde5",
        "name": "测试文档2号",
        "userId": "user123",
        "projectInfo": "{\"projectInfo\":{\"projectName\":\"AI Doc Demo\",\"env\":\"dby\",\"place\":\"sz\",\"startDate\":\"1995-02-18\"}}",
        "version": 0,
        "isDeleted": false,
        "createdAt": "2025-10-31T10:01:50.8186135",
        "updatedAt": "2025-10-31T10:01:50.8186135"
    }
}
```

### 3.5 重命名文档
**接口**: `PATCH /documents/:id/rename`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID（在URL路径中）

**请求体参数**:
```json
{
  "name": "新文档名称"
}
```

**参数说明**:
- `id`: 文档ID（路径参数，在URL中传递，例如：`/documents/doc_001/rename`）
- `name`: 新文档名称（请求体参数，必填）

**响应示例**:
```json
{
  "code": 200,
  "message": "文档重命名成功"
}
```

### 3.6 删除文档
**接口**: `DELETE /documents/:id`

**请求头**: `Authorization: Bearer <token>`

**响应示例**:
```json
{
  "code": 200,
  "message": "文档删除成功"
}
```

---

## 4. 文档块（Blocks）管理（单层）

> 关系说明（MVP）：当前不使用章节/段落概念。文档由一组单层 Blocks 顺序构成：
> - 一级目录对应一个 `heading_1` 类型 Block（每个目录=一个 Block）
> - 正文内容使用 `paragraph/table/list_item/code_block` Block
> - `parent_id = null`，`level = 1`，通过 `order_key` 维护顺序      

### 4.1 获取文档块列表
**接口**: `GET /documents/:id/blocks`

**请求头**: `Authorization: Bearer <token>`

**查询参数**:
- `page`: 页码，默认1
- `pageSize`: 每页数量，默认20
- `block_type`: 块类型（可选），筛选指定类型的块。可选值：`heading_1`、`heading_2`、`heading_3`、`heading_4`、`paragraph`、`table`、`list_item`、`code_block`
- `keyword`: 搜索关键词（可选），在块内容中搜索

**请求示例**:
```bash
# 查询所有块
GET /documents/doc_001/blocks?page=1&pageSize=20

# 查询指定类型的块
GET /documents/doc_001/blocks?blockType=heading_1

# 搜索关键词
GET /documents/doc_001/blocks?keyword=设计

# 组合查询
GET /documents/doc_001/blocks?blockType=paragraph&keyword=设计&page=1&pageSize=10
```

**响应示例**:
```json
{
    "code": 200,
    "message": "success",
    "data": {
        "total": 2,
        "page": 1,
        "pageSize": 20,
        "list": [
            {
                "id": "BLK-200001",
                "documentId": "DOC-100002",
                "blockType": "heading_1",
                "blockName": "接口列表",
                "orderKey": "0001",
                "level": 1,
                "content": "接口列表",
                "docReference": {"doc_id": "DOC-001", "title": "参考文档标题"},
                "chunkReference": {"chunk_id": "CHK-001", "content": "参考块内容"},
                "isDeleted": false,
                "creatorId": "user-002",
                "modifierId": "user-002",
                "createdAt": "2025-10-31T01:52:44",
                "updatedAt": "2025-10-31T01:52:44"
            },
            {
                "id": "BLK-200002",
                "documentId": "DOC-100002",
                "blockType": "table",
                "blockName": "接口表格",
                "orderKey": "0002",
                "level": 1,
                "content": "|\n接口|方法|路径|\n|---|---|---|\n|获取文档|GET|/documents/{id}|\n|查询文档块|GET|/document-blocks?documentId={id}|\n|创建文档块|POST|/document-blocks|\n",
                "docReference": null,
                "chunkReference": null,
                "metadata": "{\"format\": \"markdown\"}",
                "isDeleted": false,
                "creatorId": "user-002",
                "modifierId": "user-002",
                "createdAt": "2025-10-31T01:52:44",
                "updatedAt": "2025-10-31T01:52:44"
            }
        ]
    }
}
```

### 4.2 新增文档块
**接口**: `POST /documents/:id/blocks`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `block_type` | string | 是 | 块类型 (heading_1/heading_2/heading_3/heading_4/paragraph/table/list_item/code_block) |
| `block_name` | string | 是 | 块名称 |
| `content` | string | 是 | 块内容 |
| `docReference` | object/string | 否 | 文档参考内容，JSON 格式 |
| `chunkReference` | object/string | 否 | 块参考内容，JSON 格式 |
| `level` | integer | 否 | 层级，MVP 固定为 1，默认 1 |
| `parent_id` | string | 否 | 父块ID，MVP 固定为 null |
| `after_id` | string | 可选 | 插入到指定 block 之后，系统会自动计算中间的 `order_key`（推荐）


**参数说明**:
- 使用 `after_id` 时，系统会基于字母排序自动计算中间值，**不会修改其他 blocks 的 order_key**

**方式1：使用 `after_id` 自动计算（推荐）**:
```bash
POST /documents/doc_001/blocks
Content-Type: application/json

{
  "block_type": "heading_1",
  "block_name": "新增目录",
  "content": "新增目录",
  "docReference": {"doc_id": "DOC-001", "title": "参考文档标题"},
  "chunkReference": {"chunk_id": "CHK-001", "content": "参考块内容"},
  "level": 1,
  "parent_id": null,
  "after_id": "BLK-100001"  // 插入到指定 block 之后，自动计算 order_key
}
```

### 4.2.1 批量新增文档块（Batch）
**接口**: `POST /documents/:id/blocks/batch`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID

**请求体**:
```json
{
  "anchor_after_id": "BLK-100001",   // 可选
  "level": 1,
  "parent_id": null,
  "blocks": [
    {
      "block_name": "一级目录-1",      // 必填
      "block_type": "heading_1",      // 必填（移到内部）
      "content": "第一段",              // 可选，可以为空
      "docReference": {"doc_id": "DOC-001", "title": "参考文档1"},  // 可选，文档参考内容，JSON 格式
      "chunkReference": {"chunk_id": "CHK-001", "content": "参考块内容1"}  // 可选，块参考内容，JSON 格式
    },
    {
      "block_name": "一级目录-2",      // 必填
      "block_type": "paragraph",       // 必填（移到内部）
      "content": "",                   // 可选，可以为空字符串或省略
      "docReference": null,           // 可选，文档参考内容，JSON 格式
      "chunkReference": null          // 可选，块参考内容，JSON 格式
    }
  ],
  "returnOnlyIds": true
}
```

**参数说明**:
- `anchor_after_id`（可选）: 首个块的插入锚点，表示将第一条插入到该 block 之后；未提供时，批量从文档最前面开始依次插入。
- `level`（可选，默认 1）: 统一的层级，所有块使用相同的 level。
- `parent_id`（可选，默认 null）: 统一的父块ID，所有块使用相同的 parent_id。
- `blocks`（必填）: 需要创建的块数组，按数组顺序插入。每个元素包含：
  - `block_name`（必填）: 块名称
  - `block_type`（必填）: 块类型 (heading_1/heading_2/heading_3/heading_4/paragraph/table/list_item/code_block)
  - `content`（可选）: 块内容，可以为空
  - `docReference`（可选）: 文档参考内容，JSON 格式
  - `chunkReference`（可选）: 块参考内容，JSON 格式
- `returnOnlyIds`（可选，默认 true）: 为 true 时仅返回各新建块的 `id` 与 `order_key`，减少响应体体积。

**插入与排序规则（Fractional Indexing）**:
- 不需要也不允许在批量接口中显式传 `order_key`；服务端基于 Fractional Indexing 自动生成。
- 若提供 `anchor_after_id`，第1条插入在该块之后；其余条目依次插在上一条新建块之后，严格保持与请求数组相同的顺序。
- 若未提供 `anchor_after_id`，第1条插入文档最前面（如无前缀则起始使用 `"A"`），其余条目依次在上一条之后生成中间 key。
- 算法保证在两 key 之间生成无限可分的中间值，不会回写或重排已有块。

**限制**:
- 单次最大 100 条（可按需要在实现时调整）。
- 任一条目校验失败返回 400，并附带错误条目索引与原因；不进行部分提交（默认原子性）。

**响应示例（returnOnlyIds=false）**:
```json
{
  "code": 201,
  "message": "批量创建成功",
  "data": [
    { "id": "new_block_id_1", "block_type": "heading_1", "order_key": "A",   "level": 1, "parent_id": null },
    { "id": "new_block_id_2", "block_type": "paragraph", "order_key": "Am", "level": 1, "parent_id": null }
  ]
}
```

**响应示例（returnOnlyIds=true）**:
```json
{
  "code": 201,
  "message": "批量创建成功",
  "data": [
    { "id": "new_block_id_1", "order_key": "A" },
    { "id": "new_block_id_2", "order_key": "Am" }
  ]
}
```


### 4.3 获取文档块详情
**接口**: `GET /documents/:id/blocks/:blockId`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID
- `blockId`: 块ID

**请求示例**:
```bash
GET /documents/doc_001/blocks/b1
```

**响应示例**:
```json
{
    "code": 200,
    "message": "success",
    "data": {
        "id": "53220dd2-d224-4c39-b015-89594cdecca5",
        "documentId": "DOC-100001",
        "blockType": "heading_1",
        "blockName": "房中镜",
        "orderKey": "A",
        "level": 1,
        "content": "### 《房中镜》\n\n林远搬进那间出租屋的第三天，就注意",
        "doc_reference": {"doc_id": "DOC-001", "title": "参考文档标题"},
        "chunk_reference": {"chunk_id": "CHK-001", "content": "参考块内容"},
        "isDeleted": false,
        "createdAt": "2025-10-31T12:37:21",
        "updatedAt": "2025-10-31T12:37:21"
    }
}
```

### 4.4 更新文档块内容
**接口**: `PUT /documents/:id/blocks/:blockId`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID
- `blockId`: 块ID

**请求参数（均为可选）**:
```json
{
  "block_name": "新的块名称",
  "content": "更新后的内容",
  "docReference": {"doc_id": "DOC-001", "title": "更新后的文档参考"},
  "chunkReference": {"chunk_id": "CHK-001", "content": "更新后的块参考"}
}
```

说明：
- 仅传 `block_name` 时，只更新名称；
- 仅传 `content` 时，只更新内容；
- 仅传 `docReference` 时，只更新文档参考内容；
- 仅传 `chunkReference` 时，只更新块参考内容；
- 可以同时传多个字段，同时更新多个字段；
- `docReference` 和 `chunkReference` 可以为 `null`（设置为 `null` 时会更新为 `null`）；
- 若请求体为空或所有字段均为空，返回 400。

**请求示例**:
```bash
PUT /documents/doc_001/blocks/b1
Content-Type: application/json

{
  "content": "更新后的内容",
  "docReference": {"doc_id": "DOC-001", "title": "更新后的文档参考"},
  "chunkReference": {"chunk_id": "CHK-001", "content": "更新后的块参考"}
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "文档块更新成功"
}
```

### 4.5 重命名文档块
**接口**: `PATCH /documents/:id/blocks/:blockId/rename`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID
- `blockId`: 块ID

**请求参数**:
```json
{
  "name": "新文档名称"
}
```

**请求示例**:
```bash
PATCH /documents/doc_001/blocks/b1/rename
Content-Type: application/json

{
  "name": "新文档名称"
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "文档块重命名成功"
}
```

### 4.6 删除文档块
**接口**: `DELETE /documents/:id/blocks/:blockId`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID
- `blockId`: 块ID

**请求示例**:
```bash
DELETE /documents/doc_001/blocks/b1
```

**响应示例**:
```json
{
  "code": 200,
  "message": "文档块删除成功"
}
```

---

## 6. 导出功能

### 6.1 导出Markdown
**接口**: `POST /documents/:id/export/markdown`

**请求头**: `Authorization: Bearer <token>`

**路径参数**:
- `id`: 文档ID

**说明**: 导出整个文档的所有blocks为Markdown格式

**请求示例**:
```bash
POST /documents/doc_001/export/markdown
```

**响应示例**:
```json
{
  "code": 200,
  "message": "导出成功",
  "data": {
    "content": "# 文档设计说明 20251027\n\n## 1. 设计依据\n\n### 1.1 国家及地方规范\n\n- 《建筑设计防火规范》GB 50016-2014（2018年版）\n- 《民用建筑设计统一标准》GB 50352-2019\n\n...\n\n## 2. 工程概况\n\n本工程遵循国家相关建筑规范，确保工程质量与安全。",
    "fileName": "建筑设计说明_20251027.md"
  }
}
```

**响应内容说明**:
- `content`: Markdown格式的文档内容（完整文本，约2万字）
- `fileName`: 建议的文件名，前端可提供下载功能

。