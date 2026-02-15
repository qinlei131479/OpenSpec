<p align="center">
  <a href="./README.md">English</a> |
  <a href="./README_zh.md">中文</a>
</p>

<h3 align="center">企业级 AI 专业长文档生成平台</h3>
<p align="center">基于 RAG + 多智能体工作流，为建筑设计、汽车维修、医疗、招投标等专业领域提供高质量长文档自动生成能力</p>

<p align="center">
  <a href="https://github.com/zhuzhaoyun/OpenSpec/releases/latest"><img src="https://img.shields.io/github/v/release/zhuzhaoyun/OpenSpec" alt="Latest release"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec"><img src="https://img.shields.io/github/stars/zhuzhaoyun/OpenSpec?color=%23F4A460" alt="GitHub Stars"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec"><img src="https://img.shields.io/github/forks/zhuzhaoyun/OpenSpec?color=%2388CCFF" alt="GitHub Forks"></a>
</p>

---

## 什么是 OpenSpec？

OpenSpec 是一款 **企业级智能专业长文档生成平台**。

在建筑设计、汽车维修、医疗、招投标等专业领域，从业者需要编写大量结构复杂、内容严谨、符合行业规范的长文档。这类文档通常具有以下特点：

- **篇幅长**：动辄数十页甚至上百页，包含多个章节和子章节；
- **专业性强**：内容必须引用行业标准、规范条文，不能凭空编造；
- **格式严格**：需要遵循特定的文档模板和排版规范；
- **重复度高**：同类项目的文档结构相似，但细节因项目而异。

OpenSpec 正是为解决这一痛点而生。用户只需输入项目基本信息，系统即可：

1. **智能检索** — 从知识库中检索相关规范条文、历史案例和参考资料；
2. **按章节生成** — 由多智能体工作流（Researcher + Auditor）逐章生成符合标准的专业内容；
3. **人机协作** — 支持逐章校审、改写、补充，AI 与人工高效协同；
4. **一键导出** — 生成 PDF、Markdown、AutoCAD 图框等多种专业格式。

**OpenSpec 两分钟视频介绍（建筑设计场景示例）：** https://www.bilibili.com/video/BV1DoFUzBEmW/?share_source=copy_web&vd_source=d91cce476d06006159a799f4db6b9171

### 适用场景

| 领域 | 典型文档 |
|------|---------|
| 建筑设计 | 施工图设计说明、可行性研究报告 |
| 汽车维修 | 维修技术手册、故障诊断报告 |
| 医疗健康 | 临床试验报告、诊疗规范文档 |
| 招投标 | 投标技术方案、招标文件编制 |
| 更多领域 | 任何需要基于知识库生成的结构化长文档 |

## UI 展示

<table style="border-collapse: collapse; border: 1px solid black;">
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/2d67e1a4-a779-43b7-a770-a07deb649711" alt="项目列表" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/efcae9fa-bf8d-4b53-93f6-2d49e6119042" alt="文档编辑器" /></td>
  </tr>
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/889a30b5-d014-46ca-84e4-26334f6076ba" alt="AI 对话助手" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/1b04355c-709a-4a33-9e39-ac7d04ce483c" alt="知识库检索" /></td>
  </tr>
</table>

## 快速开始

### 环境要求

| 组件 | 版本要求 |
|------|---------|
| Docker | >= 20.10 |
| Docker Compose | >= 2.0 |

### 一键部署

```bash
# 1. 克隆项目
git clone https://github.com/zhuzhaoyun/OpenSpec.git
cd OpenSpec

# 2. 复制并修改环境变量
cp deploy/docker/.env.example deploy/docker/.env
# 编辑 .env 文件，填入必要配置（RAGFlow、LLM API Key 等）

# 3. 启动所有服务
cd deploy/docker
docker compose up -d
```

启动完成后访问 `http://localhost` 即可使用。

### 环境变量说明

| 变量名 | 说明 | 必填 |
|--------|------|------|
| `RAGFLOW_API_KEY` | RAGFlow API 密钥 | 是 |
| `RAGFLOW_BASE_URL` | RAGFlow 服务地址 | 是 |
| `DASHSCOPE_API_KEY` | LLM API 密钥（默认通义千问） | 是 |
| `LANGFUSE_SECRET_KEY` | Langfuse 私钥（Prompt 管理） | 否 |
| `LANGFUSE_PUBLIC_KEY` | Langfuse 公钥 | 否 |
| `LANGFUSE_BASE_URL` | Langfuse 服务地址 | 否 |

完整的环境变量说明请参考 [`deploy/docker/.env.example`](deploy/docker/.env.example)。

### 本地开发

<details>
<summary>展开查看本地开发指南</summary>

#### 前端

```bash
cd apps/web
npm install
npm run dev
# 访问 http://localhost:5173
```

#### AI Agent

```bash
cd apps/agent
pip install -r requirements.txt
cp ../../deploy/docker/.env.example .env
# 编辑 .env 填入必要配置
uvicorn app:app --reload --port 5000 --host 0.0.0.0
```

#### 后端

```bash
cd apps/backend
mvn spring-boot:run
```

</details>

## License

Copyright (c) 2024-2026 OpenSpec Contributors.

Licensed under [The GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
