#!/bin/bash
# =============================================================================
# sync-to-openspec.sh
# 从商业版 ArchSpec-Pro 同步代码到开源版 OpenSpec
# 用法: 在商业版仓库根目录执行 ./script/sync-to-openspec.sh
# =============================================================================

set -e

# CI 环境: 确保 GitHub SSH host key 可信
if [ -n "$CI" ]; then
    mkdir -p ~/.ssh
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
fi

# --- 配置 ---
OPENSPEC_REPO="git@github.com:zhuzhaoyun/OpenSpec.git"
OPENSPEC_BRANCH="main"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

SOURCE_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "=== OpenSpec Sync Script ==="
echo "商业版目录: $PROJECT_ROOT"
echo "源 commit: $SOURCE_HASH"
echo "临时工作目录: $WORK_DIR"

# --- Step 1: 复制商业版代码到临时目录 ---
echo ""
echo "[1/7] 复制商业版代码到临时目录..."
cp -r "$PROJECT_ROOT/." "$WORK_DIR/"
cd "$WORK_DIR"

# 清理 git 信息
rm -rf .git

# --- Step 2: 删除商业目录 ---
echo "[2/7] 删除商业功能目录..."
rm -rf apps/backend/ai-doc-system-license
rm -rf apps/backend/ai-doc-system-license-gen
rm -rf apps/backend/keys
rm -rf apps/cad-plugin

# --- Step 3: 删除商业 Java 文件 ---
echo "[3/7] 删除商业 Java 文件..."

# Controllers
rm -f apps/backend/ai-doc-system-rest/src/main/java/com/aiid/aidoc/controller/LicenseController.java
rm -f apps/backend/ai-doc-system-rest/src/main/java/com/aiid/aidoc/controller/TemplateController.java
rm -f apps/backend/ai-doc-system-rest/src/main/java/com/aiid/aidoc/controller/TemplateTagController.java

# Entities
rm -f apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/entity/CadTemplate.java
rm -f apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/entity/DocumentTemplate.java
rm -f apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/entity/DocumentTemplateTag.java
rm -f apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/entity/PersonalTemplate.java
rm -f apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/entity/TemplateTag.java

# DTOs
rm -f apps/backend/ai-doc-system-api/src/main/java/com/aiid/aidoc/api/dto/DocumentTemplateCreateRequest.java
rm -f apps/backend/ai-doc-system-api/src/main/java/com/aiid/aidoc/api/dto/PersonalTemplateCreateRequest.java
rm -f apps/backend/ai-doc-system-api/src/main/java/com/aiid/aidoc/api/dto/PersonalTemplateQueryRequest.java
rm -f apps/backend/ai-doc-system-api/src/main/java/com/aiid/aidoc/api/dto/PersonalTemplateUpdateRequest.java
rm -f apps/backend/ai-doc-system-api/src/main/java/com/aiid/aidoc/api/dto/TemplateTagCreateRequest.java

# Mappers
rm -f apps/backend/ai-doc-system-repository/src/main/java/com/aiid/aidoc/repository/mapper/CadTemplateMapper.java
rm -f apps/backend/ai-doc-system-repository/src/main/java/com/aiid/aidoc/repository/mapper/DocumentTemplateMapper.java
rm -f apps/backend/ai-doc-system-repository/src/main/java/com/aiid/aidoc/repository/mapper/DocumentTemplateTagMapper.java
rm -f apps/backend/ai-doc-system-repository/src/main/java/com/aiid/aidoc/repository/mapper/PersonalTemplateMapper.java
rm -f apps/backend/ai-doc-system-repository/src/main/java/com/aiid/aidoc/repository/mapper/TemplateTagMapper.java

# Services
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/CadTemplateService.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/DocumentTemplateService.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/PersonalTemplateService.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/TemplateTagService.java

# Service Impls
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/impl/CadTemplateServiceImpl.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/impl/DocumentTemplateServiceImpl.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/impl/PersonalTemplateServiceImpl.java
rm -f apps/backend/ai-doc-system-service/src/main/java/com/aiid/aidoc/service/impl/TemplateTagServiceImpl.java

# --- Step 4: 修改配置文件 ---
echo "[4/7] 修改配置文件..."

# 4.1 pom.xml - 移除 license 模块
sed -i '/<module>ai-doc-system-license<\/module>/d' apps/backend/pom.xml
sed -i '/<module>ai-doc-system-license-gen<\/module>/d' apps/backend/pom.xml

# 4.2 service pom.xml - 移除 license 依赖（删除整个 dependency 块）
python3 -c "
import re
with open('apps/backend/ai-doc-system-service/pom.xml', 'r') as f:
    content = f.read()
content = re.sub(r'\s*<dependency>\s*<groupId>com\.aiid</groupId>\s*<artifactId>ai-doc-system-license</artifactId>\s*<version>[^<]*</version>\s*</dependency>', '', content)
with open('apps/backend/ai-doc-system-service/pom.xml', 'w') as f:
    f.write(content)
" 2>/dev/null || {
    # fallback: sed
    sed -i '/<artifactId>ai-doc-system-license<\/artifactId>/{ N; N; d; }' apps/backend/ai-doc-system-service/pom.xml
}

# 4.3 application.yml - 移除 license 配置段
sed -i '/^# 授权配置$/,/^$/d' apps/backend/ai-doc-system-rest/src/main/resources/application.yml
sed -i '/^license:/,/^$/d' apps/backend/ai-doc-system-rest/src/main/resources/application.yml

# 4.4 application-prod.yml - 替换敏感默认值
sed -i 's|jdbc:mysql://8\.138\.233\.196:3306|jdbc:mysql://localhost:3306|g' apps/backend/ai-doc-system-rest/src/main/resources/application-prod.yml
sed -i 's|6VBG\*!bkeW|rootpass123|g' apps/backend/ai-doc-system-rest/src/main/resources/application-prod.yml

# 4.5 SQL - 移除 template 相关表
python3 -c "
import re
for sql_file in ['apps/backend/ai-doc-system-rest/src/main/resources/db/migration/V1__Initial_schema.sql', 'script/backend/initial_schema.sql']:
    try:
        with open(sql_file, 'r', encoding='utf-8') as f:
            content = f.read()
        # 删除从 '-- 8. 模板标签表' 到 INSERT 语句结束
        content = re.sub(r'-- 8\. 模板标签表.*?体育场馆.*?\);', '', content, flags=re.DOTALL)
        with open(sql_file, 'w', encoding='utf-8') as f:
            f.write(content)
    except FileNotFoundError:
        pass
"

# --- Step 5: 修改 Docker 配置 ---
echo "[5/7] 修改 Docker 配置..."

# docker-compose.yml: 移除 license volume 和 env
sed -i '/LICENSE_FILE.*license\.lic/d' deploy/docker/docker-compose.yml
sed -i '/LICENSE_PATH:/d' deploy/docker/docker-compose.yml

# archspec -> openspec 品牌替换
sed -i 's/archspec/openspec/g' deploy/docker/docker-compose.yml

# 删除 pro 配置
rm -f deploy/docker/docker-compose-pro.yml
rm -f deploy/docker/.env.pro

# 删除 license.lic 文件
rm -f apps/backend/license.lic deploy/docker/license.lic

# --- Step 6: 清理敏感信息 ---
echo "[6/7] 清理敏感信息..."

# 删除 .env 文件
rm -f deploy/docker/.env
rm -f apps/backend/.env
rm -f apps/agent/.env
rm -f apps/backend/env.example

# Python 文件: 替换硬编码的默认 URL
find apps/agent -name "*.py" -exec sed -i 's|"https://rag\.aizzyun\.com"|""|g' {} +

# main.py: 清理硬编码凭据
cat > apps/agent/main.py << 'PYEOF'
import os
from http import HTTPStatus
from dashscope import Application
from ragflow_sdk import RAGFlow
from dotenv import load_dotenv

load_dotenv()

RAGFLOW_API_KEY = os.getenv("RAGFLOW_API_KEY", "")
RAGFLOW_BASE_URL = os.getenv("RAGFLOW_BASE_URL", "")

rag_object = RAGFlow(api_key=RAGFLOW_API_KEY, base_url=RAGFLOW_BASE_URL)
assistant = rag_object.list_chats()
assistant = assistant[0]
session = assistant.create_session()

print("\n==================== Miss R =====================\n")
print("Hello. What can I do for you?")

while True:
    question = input("\n==================== User =====================\n`> ")
    print("\n==================== Miss R =====================\n")

    cont = ""
    for ans in session.ask(question, stream=True):
        print(ans.content[len(cont):], end='', flush=True)
        cont = ans.content
PYEOF

# 文档中的内部 URL 替换
find docs -name "*.md" -exec sed -i 's|https://rag\.aizzyun\.com|http://your-ragflow-host:9380|g' {} + 2>/dev/null || true

# --- Step 7: 删除文档和内部文件 ---
echo "[7/7] 删除内部文档..."
rm -f CLAUDE.md README.md AGENT.md MEMORY_IMPLEMENTATION_GUIDE.md
rm -f apps/backend/README.md apps/backend/README-Docker.md
rm -f docs/architecture/md2cad_integration.md
rm -f docs/template-metadata-implementation.md
rm -rf .claude/

echo ""
echo "=== 清理完成，准备同步到 OpenSpec ==="

# --- 同步到 openspec 仓库 ---
OPENSPEC_LOCAL=$(mktemp -d)
echo "克隆 openspec 仓库到: $OPENSPEC_LOCAL"
git clone "$OPENSPEC_REPO" "$OPENSPEC_LOCAL" 2>/dev/null || {
    echo "克隆失败，请检查仓库地址和权限"
    exit 1
}

# 清空 openspec 仓库内容（保留 .git）
find "$OPENSPEC_LOCAL" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# 复制清理后的代码
cp -r "$WORK_DIR/." "$OPENSPEC_LOCAL/"

cd "$OPENSPEC_LOCAL"
git add -A

# 检查是否有变更
if git diff --cached --quiet; then
    echo "没有变更需要同步。"
else
    COMMIT_MSG="sync: update from ArchSpec-Pro ${SOURCE_HASH} $(date +%Y-%m-%d)"
    git commit -m "$COMMIT_MSG"
    git push origin "$OPENSPEC_BRANCH"
    echo "=== 同步完成! ==="
fi

# 清理临时目录
rm -rf "$WORK_DIR" "$OPENSPEC_LOCAL"
echo "临时文件已清理。"
