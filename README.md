<p align="center">
  <a href="./README.md">English</a> |
  <a href="./README_zh.md">中文</a>
</p>

<h3 align="center">Enterprise-Grade AI Professional Long-Document Generation Platform</h3>
<p align="center">Powered by RAG + multi-agent workflows, delivering high-quality automated long-document generation for architecture design, automotive repair, healthcare, bidding & tendering, and more.</p>

<p align="center">
  <a href="https://github.com/zhuzhaoyun/OpenSpec/releases/latest"><img src="https://img.shields.io/github/v/release/zhuzhaoyun/OpenSpec" alt="Latest release"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec"><img src="https://img.shields.io/github/stars/zhuzhaoyun/OpenSpec?color=%23F4A460" alt="GitHub Stars"></a>
  <a href="https://github.com/zhuzhaoyun/OpenSpec"><img src="https://img.shields.io/github/forks/zhuzhaoyun/OpenSpec?color=%2388CCFF" alt="GitHub Forks"></a>
</p>

---

## What is OpenSpec?

OpenSpec is an **enterprise-grade intelligent platform for professional long-document generation**.

In specialized fields such as architecture design, automotive repair, healthcare, and bidding & tendering, professionals need to produce large volumes of structurally complex, technically rigorous, and standards-compliant long documents. These documents typically share the following characteristics:

- **Lengthy** — Often tens or even hundreds of pages, with multiple chapters and sub-chapters;
- **Highly specialized** — Content must reference industry standards and regulatory provisions, with no room for fabrication;
- **Strictly formatted** — Must follow specific document templates and layout standards;
- **Repetitive** — Documents of the same type share similar structures, but details vary by project.

OpenSpec was built to solve this pain point. Users simply input basic project information, and the system will:

1. **Intelligent Retrieval** — Retrieve relevant standards, historical cases, and reference materials from the knowledge base;
2. **Chapter-by-Chapter Generation** — A multi-agent workflow (Researcher + Auditor) generates standards-compliant professional content chapter by chapter;
3. **Human-AI Collaboration** — Supports chapter-level review, rewriting, and supplementation for efficient human-AI collaboration;
4. **One-Click Export** — Generate PDF, Markdown, AutoCAD title blocks, and other professional formats.

**OpenSpec 2-Minute Video Introduction (Architecture Design Scenario):** https://www.bilibili.com/video/BV1DoFUzBEmW/?share_source=copy_web&vd_source=d91cce476d06006159a799f4db6b9171

### Use Cases

| Domain | Typical Documents |
|--------|-------------------|
| Architecture Design | Construction drawing design notes, feasibility study reports |
| Automotive Repair | Repair technical manuals, fault diagnosis reports |
| Healthcare | Clinical trial reports, diagnosis & treatment standard documents |
| Bidding & Tendering | Technical proposals, tender document preparation |
| More | Any structured long document that needs to be generated from a knowledge base |

## UI Showcase

<table style="border-collapse: collapse; border: 1px solid black;">
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/2d67e1a4-a779-43b7-a770-a07deb649711" alt="Project List" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/efcae9fa-bf8d-4b53-93f6-2d49e6119042" alt="Document Editor" /></td>
  </tr>
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/889a30b5-d014-46ca-84e4-26334f6076ba" alt="AI Chat Assistant" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src="https://github.com/user-attachments/assets/1b04355c-709a-4a33-9e39-ac7d04ce483c" alt="Knowledge Base Retrieval" /></td>
  </tr>
</table>

## Online Demo

Try OpenSpec online: [https://archspec.aizzyun.com/](https://archspec.aizzyun.com/)

- Email: `test@qq.com`
- Password: `test`

## Quick Start

### Requirements

| Component | Version |
|-----------|---------|
| Docker | >= 20.10 |
| Docker Compose | >= 2.0 |

### One-Click Deployment

```bash
# 1. Clone the repository
git clone https://github.com/zhuzhaoyun/OpenSpec.git
cd OpenSpec

# 2. Copy and edit environment variables
cp deploy/docker/.env.example deploy/docker/.env
# Edit .env and fill in required configurations (RAGFlow, LLM API Key, etc.)

# 3. Start all services
cd deploy/docker
docker compose up -d
```

Once started, visit `http://localhost` to use the platform.

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `RAGFLOW_API_KEY` | RAGFlow API key | Yes |
| `RAGFLOW_BASE_URL` | RAGFlow service URL | Yes |
| `DASHSCOPE_API_KEY` | LLM API key (default: Qwen) | Yes |
| `LANGFUSE_SECRET_KEY` | Langfuse secret key (Prompt management) | No |
| `LANGFUSE_PUBLIC_KEY` | Langfuse public key | No |
| `LANGFUSE_BASE_URL` | Langfuse service URL | No |

For the full list of environment variables, see [`deploy/docker/.env.example`](deploy/docker/.env.example).

### Local Development

<details>
<summary>Expand to view local development guide</summary>

#### Frontend

```bash
cd apps/web
npm install
npm run dev
# Visit http://localhost:5173
```

#### AI Agent

```bash
cd apps/agent
pip install -r requirements.txt
cp ../../deploy/docker/.env.example .env
# Edit .env and fill in required configurations
uvicorn app:app --reload --port 5000 --host 0.0.0.0
```

#### Backend

```bash
cd apps/backend
mvn spring-boot:run
```

</details>

## Open Source vs Enterprise

| Feature | Open Source | Enterprise |
|---------|:----------:|:----------:|
| Intelligent Retrieval & Chapter Generation | ✅ | ✅ |
| Human-AI Collaborative Editing | ✅ | ✅ |
| PDF / Markdown Export | ✅ | ✅ |
| AutoCAD Plugin (File Import) | ❌ | ✅ |
| Training & Q&A Support | ❌ | ✅ |
| Data Processing Consulting | ❌ | ✅ |

### Contact Us

For enterprise edition details or business cooperation, feel free to reach out:

- Email: `dlutyaol@qq.com`
- WeChat: Scan the QR code below

  <img src="docs/wechat_qr.png" alt="WeChat" width="200" />

## License

Copyright (c) 2024-2026 OpenSpec Contributors.

Licensed under [The GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
