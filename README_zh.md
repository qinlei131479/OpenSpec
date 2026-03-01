<h1 align="center">OpenSpec</h1>

<p align="center">
  <strong>企业级 AI 专业长文档生成平台</strong>
</p>

<p align="center">
  将知识库变为符合行业标准、可直接交付的专业文档 —— 从数天缩短到数分钟。
</p>

<p align="center">
  <a href="./README.md">English</a> |
  <a href="./README_zh.md">中文</a>
</p>

<p align="center">
  <a href="https://github.com/zhuzhaoyun/OpenSpec/releases/latest"><img src="https://img.shields.io/github/v/release/zhuzhaoyun/OpenSpec" alt="Latest Release"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec/blob/main/LICENSE"><img src="https://img.shields.io/github/license/zhuzhaoyun/OpenSpec?color=blue" alt="License"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec"><img src="https://img.shields.io/github/stars/zhuzhaoyun/OpenSpec?style=social" alt="GitHub Stars"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec/fork"><img src="https://img.shields.io/github/forks/zhuzhaoyun/OpenSpec?style=social" alt="GitHub Forks"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec/pulls"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
</p>

<p align="center">
  <a href="https://archspec.aizzyun.com/">在线体验</a> &bull;
  <a href="https://www.bilibili.com/video/BV1DoFUzBEmW/">视频介绍</a> &bull;
  <a href="#快速开始">快速开始</a> &bull;
  <a href="#联系我们">联系我们</a>
</p>

---

## 为什么选择 OpenSpec？

通用 AI（ChatGPT、Claude、通义千问等）在专业长文档上力不从心：

| 问题 | 通用 AI | OpenSpec |
|------|:-------:|:--------:|
| 超过 50 页的文档 | 上下文丢失，前后矛盾 | 逐章生成，全篇连贯 |
| 行业标准与规范引用 | 幻觉严重，凭空编造 | RAG 检索你自己的知识库 |
| 文档格式与模板 | 无法控制排版 | PDF / Markdown / AutoCAD 导出 |
| 质量保障 | 单次生成，无审核 | 多智能体（Researcher + Auditor）工作流 |

**OpenSpec 不是又一个 AI 写作工具。** 它是一个为专业人士打造的文档工程平台，确保准确性、合规性和规模化生产。

## 工作原理

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
│  用户输入     │────▶│  RAG 智能检索     │────▶│  多智能体生成     │────▶│  人机协作      │
│  (项目信息)   │     │  (规范/案例/资料)  │     │  (Researcher +  │     │  编辑审校      │
│              │     │                  │     │   Auditor)      │     └──────┬───────┘
└─────────────┘     └──────────────────┘     └─────────────────┘            │
                                                                             ▼
                                                                    ┌──────────────┐
                                                                    │  一键导出      │
                                                                    │ (PDF/MD/CAD)  │
                                                                    └──────────────┘
```

1. **智能检索（RAG）** — 从知识库中检索相关规范条文、历史案例和参考资料
2. **多智能体生成** — Researcher 撰写，Auditor 审核 —— 逐章生成，就像一个真实的协作团队
3. **人机协作** — 支持逐章校审、改写、补充
4. **一键导出** — PDF、Markdown、AutoCAD 图框等多种专业格式

## 适用场景

| 领域 | 典型文档 |
|------|---------|
| 建筑设计 | 施工图设计说明、可行性研究报告 |
| 汽车维修 | 维修技术手册、故障诊断报告 |
| 医疗健康 | 临床试验报告、诊疗规范文档 |
| 招投标 | 投标技术方案、招标文件编制 |
| **更多领域** | **任何需要基于知识库生成的结构化长文档** |

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

> **视频演示（建筑设计场景）：** [在 B 站观看](https://www.bilibili.com/video/BV1DoFUzBEmW/?share_source=copy_web&vd_source=d91cce476d06006159a799f4db6b9171)

## 在线体验

试用地址：**[https://archspec.aizzyun.com/](https://archspec.aizzyun.com/)**

- 账号：`test@qq.com`
- 密码：`test`

## 技术栈

| 层级 | 技术 |
|------|-----|
| 前端 | Vue 3、TypeScript、Vite |
| 后端 | Spring Boot 3、Java 17 |
| AI Agent | Python、LangGraph、LangChain |
| 知识检索 | RAGFlow |
| 可观测性 | Langfuse（LLM 调用追踪与成本分析） |
| 数据库 | PostgreSQL |
| 部署 | Docker、Docker Compose |

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

## 开源版 vs 企业版

| 功能 | 开源版 | 企业版 |
|------|:------:|:------:|
| 智能检索与章节生成 | ✅ | ✅ |
| 人机协作编辑 | ✅ | ✅ |
| PDF / Markdown 导出 | ✅ | ✅ |
| AutoCAD 插件（web 与 CAD 同步） | ❌ | ✅ |
| 培训与答疑支持 | ❌ | ✅ |
| 数据处理咨询 | ❌ | ✅ |

## 参与贡献

欢迎参与贡献！你可以：

- 给项目点个 Star 表示支持
- 提交 [Issue](https://github.com/zhuzhaoyun/OpenSpec/issues) 反馈 Bug 或功能建议
- 发起 [Pull Request](https://github.com/zhuzhaoyun/OpenSpec/pulls) 贡献代码

## Star History

<a href="https://star-history.com/#zhuzhaoyun/OpenSpec&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=zhuzhaoyun/OpenSpec&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=zhuzhaoyun/OpenSpec&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=zhuzhaoyun/OpenSpec&type=Date" />
 </picture>
</a>

## 联系我们

如需了解企业版详情或商业合作，欢迎通过以下方式联系：

- 邮箱：`dlutyaol@qq.com`
- 企业微信：扫描下方二维码添加

  <img src="docs/wechat_qr.png" alt="企业微信" width="200" />

## License

Copyright (c) 2024-2026 OpenSpec Contributors.

Licensed under [The GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
