# 数据库 Schema 更新规范

## 概述

本文档定义了 ArchSpec 项目的数据库 Schema 更新规范，用于替代 Flyway 的版本管理机制。

## 背景

**为什么移除 Flyway？**

1. **版本冲突频繁**: 多人协作时，Flyway 版本号容易冲突
2. **开发体验差**: 本地开发升级多个版本后，其他开发者启动失败
3. **测试环境混乱**: 版本管理复杂，难以追踪
4. **过度工程**: 对于中小型项目，Flyway 的复杂度超过实际需求

**新方案优势**

1. ✅ **幂等设计**: 所有脚本可重复执行，不怕失败
2. ✅ **灵活可控**: 团队自主决定何时执行更新
3. ✅ **简单直接**: 无需学习 Flyway 复杂的版本管理
4. ✅ **易于协作**: 脚本冲突时手动协调，更透明

---

## 核心原则

### 1. 幂等性原则

所有 DDL 语句必须是幂等的，即可以重复执行而不会出错。

**正确示例**:
```sql
-- ✅ 使用 IF NOT EXISTS
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL
);

-- ✅ 使用 IF EXISTS
DROP TABLE IF EXISTS temp_table;

-- ✅ 使用 ON CONFLICT
INSERT INTO template_tags (name, category, is_system)
VALUES ('建筑', 'profession', TRUE)
ON CONFLICT (name, category, user_id) DO NOTHING;

-- ✅ 先检查再创建索引
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
```

**错误示例**:
```sql
-- ❌ 不使用 IF NOT EXISTS，重复执行会报错
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL
);

-- ❌ 不使用 ON CONFLICT，重复执行会报错
INSERT INTO template_tags (name, category, is_system)
VALUES ('建筑', 'profession', TRUE);
```

### 2. 不可变原则

**禁止直接修改 `init-schema.sql` 和 `init-data.sql`**，除非：
- 重建整个数据库
- 修复严重的设计缺陷

**原因**: 这两个文件是数据库的"基准版本"，修改后会导致已有环境无法同步。

### 3. 增量更新原则

所有新功能、字段变更、索引调整都应该使用**增量脚本**。

---

## 文件结构

```
apps/backend/src/main/resources/db/
├── init-schema.sql          # 完整的表结构（幂等，仅用于初始化）
├── init-data.sql            # 初始数据（幂等，仅用于初始化）
├── updates/                 # 增量更新脚本目录
│   ├── README.md            # 更新记录和执行说明
│   ├── 2024-02-07-add-user-table.sql
│   ├── 2024-02-15-add-template-field.sql
│   └── 2024-03-01-add-index-performance.sql
└── migration/               # 旧的 Flyway 脚本（仅供参考，已废弃）
    └── V1__Initial_schema.sql
```

---

## 增量更新流程

### 步骤 1: 创建更新脚本

**命名规范**: `YYYY-MM-DD-description.sql`

**示例**: `2024-02-15-add-user-table.sql`

```sql
-- ============================================
-- 增量更新脚本
-- ============================================
-- 日期: 2024-02-15
-- 作者: 张三
-- 描述: 添加用户表和相关索引
-- Jira: ARCH-123
-- ============================================

-- 1. 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_users_username UNIQUE (username),
    CONSTRAINT uk_users_email UNIQUE (email)
);

-- 2. 创建索引
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- 3. 创建触发器（自动更新 updated_at）
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4. 添加表注释
COMMENT ON TABLE users IS '用户表';
COMMENT ON COLUMN users.username IS '用户名（唯一）';
COMMENT ON COLUMN users.email IS '邮箱（唯一）';
COMMENT ON COLUMN users.password_hash IS '密码哈希';
COMMENT ON COLUMN users.is_active IS '是否激活';

-- 5. 插入初始数据（如有必要）
INSERT INTO users (username, email, password_hash, is_active)
VALUES ('admin', 'admin@archspec.com', 'hashed_password', TRUE)
ON CONFLICT (username) DO NOTHING;

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE 'User table created successfully!';
END $$;
```

### 步骤 2: 本地测试

```bash
# 连接到本地 PostgreSQL
psql -U archspec -d doc_generator

# 执行脚本
\i apps/backend/src/main/resources/db/updates/2024-02-15-add-user-table.sql

# 验证结果
\dt users
\d users
SELECT * FROM users;
```

### 步骤 3: 更新 README.md

在 `updates/README.md` 中记录更新：

```markdown
# 数据库更新记录

## 2024-02-15 - 添加用户表
- **文件**: `2024-02-15-add-user-table.sql`
- **作者**: 张三
- **描述**: 添加用户表，支持用户登录和权限管理
- **影响**: 新增 1 张表，3 个索引
- **执行方式**:
  ```bash
  psql -U archspec -d doc_generator -f updates/2024-02-15-add-user-table.sql
  ```

## 2024-02-07 - 初始化数据库
- **文件**: `init-schema.sql`, `init-data.sql`
- **作者**: ArchSpec Team
- **描述**: 从 MySQL 迁移到 PostgreSQL，初始化 6 张业务表
```

### 步骤 4: 提交代码

```bash
git add apps/backend/src/main/resources/db/updates/
git commit -m "feat: 添加用户表和相关索引 (ARCH-123)"
git push origin feature/add-user-table
```

### 步骤 5: 通知团队

在团队群或 PR 中通知：

```
📢 数据库更新通知

新增脚本: updates/2024-02-15-add-user-table.sql
执行命令:
  psql -U archspec -d doc_generator -f apps/backend/src/main/resources/db/updates/2024-02-15-add-user-table.sql

请在拉取代码后手动执行该脚本。
```

---

## 常见场景示例

### 场景 1: 添加新字段

```sql
-- 添加字段（幂等）
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS author_id BIGINT;

-- 添加外键约束（需要先检查是否存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_documents_author'
    ) THEN
        ALTER TABLE documents
        ADD CONSTRAINT fk_documents_author
        FOREIGN KEY (author_id) REFERENCES users(id);
    END IF;
END $$;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_documents_author_id ON documents(author_id);
```

### 场景 2: 修改字段类型

```sql
-- 修改字段类型（需要先检查数据兼容性）
ALTER TABLE documents
ALTER COLUMN name TYPE VARCHAR(500);

-- 如果有数据，可能需要先备份
-- CREATE TABLE documents_backup AS SELECT * FROM documents;
```

### 场景 3: 删除字段

```sql
-- 删除字段（谨慎操作，建议先备份）
ALTER TABLE documents
DROP COLUMN IF EXISTS deprecated_field;
```

### 场景 4: 添加索引优化性能

```sql
-- 添加普通索引
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);

-- 添加复合索引
CREATE INDEX IF NOT EXISTS idx_documents_user_created
ON documents(user_id, created_at DESC);

-- 添加 JSONB 索引
CREATE INDEX IF NOT EXISTS idx_documents_project_info_gin
ON documents USING gin(project_info);

-- 添加全文搜索索引
CREATE INDEX IF NOT EXISTS idx_documents_content_fts
ON documents USING gin(to_tsvector('simple', content));
```

### 场景 5: 数据迁移

```sql
-- 数据迁移示例：将旧字段数据迁移到新字段
UPDATE documents
SET new_field = old_field
WHERE new_field IS NULL;

-- 批量更新（避免锁表）
DO $$
DECLARE
    batch_size INT := 1000;
    affected_rows INT;
BEGIN
    LOOP
        UPDATE documents
        SET new_field = old_field
        WHERE id IN (
            SELECT id FROM documents
            WHERE new_field IS NULL
            LIMIT batch_size
        );

        GET DIAGNOSTICS affected_rows = ROW_COUNT;
        EXIT WHEN affected_rows = 0;

        RAISE NOTICE 'Migrated % rows', affected_rows;
        COMMIT;
    END LOOP;
END $$;
```

---

## 环境执行策略

### 开发环境

**方式 1: 自动初始化（推荐）**

在 `application.yml` 中配置：
```yaml
spring:
  sql:
    init:
      mode: always  # 每次启动都执行
```

或在 `application-dev.yml` 中配置：
```yaml
app:
  database:
    init:
      enabled: true  # 启用 DatabaseInitializer
```

**方式 2: 手动执行**

```bash
psql -U archspec -d doc_generator -f updates/2024-02-15-add-user-table.sql
```

### 测试环境

**推荐方式: Docker 初始化脚本**

在 `docker-compose.yml` 中配置：
```yaml
postgres:
  volumes:
    - ./db/init-schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    - ./db/init-data.sql:/docker-entrypoint-initdb.d/02-data.sql
```

**增量更新**: 由 CI/CD 或运维手动执行

```bash
docker exec -i ai-doc-postgres psql -U archspec -d doc_generator < updates/2024-02-15-add-user-table.sql
```

### 生产环境

**严格流程**:

1. **备份数据库**
   ```bash
   pg_dump -U archspec -d doc_generator > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **在测试环境验证**
   ```bash
   psql -U archspec -d doc_generator_test -f updates/2024-02-15-add-user-table.sql
   ```

3. **生产环境执行**
   ```bash
   psql -U archspec -d doc_generator -f updates/2024-02-15-add-user-table.sql
   ```

4. **验证结果**
   ```sql
   \dt users
   SELECT COUNT(*) FROM users;
   ```

5. **记录执行日志**
   ```bash
   echo "$(date): Executed 2024-02-15-add-user-table.sql" >> db_updates.log
   ```

---

## 故障排查

### 问题 1: 脚本执行失败

**症状**: `ERROR: relation "users" already exists`

**原因**: 脚本不是幂等的

**解决**: 使用 `CREATE TABLE IF NOT EXISTS`

### 问题 2: 外键约束冲突

**症状**: `ERROR: insert or update on table "documents" violates foreign key constraint`

**原因**: 数据不一致

**解决**:
```sql
-- 先清理不一致的数据
DELETE FROM documents WHERE author_id NOT IN (SELECT id FROM users);

-- 再添加外键
ALTER TABLE documents ADD CONSTRAINT fk_documents_author ...;
```

### 问题 3: 索引创建超时

**症状**: 大表创建索引时锁表，影响业务

**解决**: 使用 `CONCURRENTLY` 选项
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_created_at
ON documents(created_at);
```

---

## 最佳实践

### 1. 脚本编写规范

- ✅ 每个脚本只做一件事（单一职责）
- ✅ 添加详细的注释和说明
- ✅ 使用事务（如果需要原子性）
- ✅ 添加执行提示（RAISE NOTICE）
- ✅ 测试幂等性（至少执行两次）

### 2. 命名规范

- **表名**: 小写 + 下划线，复数形式（如 `users`, `document_blocks`）
- **字段名**: 小写 + 下划线（如 `user_id`, `created_at`）
- **索引名**: `idx_表名_字段名`（如 `idx_users_username`）
- **外键名**: `fk_表名_引用表名`（如 `fk_documents_users`）
- **约束名**: `uk_表名_字段名`（如 `uk_users_email`）

### 3. 性能优化

- 大表添加索引使用 `CONCURRENTLY`
- 批量更新数据时分批执行
- 避免在高峰期执行重量级操作
- 定期执行 `VACUUM ANALYZE`

### 4. 安全性

- 生产环境操作前必须备份
- 敏感操作需要 Code Review
- 记录所有执行日志
- 保留回滚脚本

---

## 与 Flyway 对比

| 特性 | Flyway | 新方案 |
|------|--------|--------|
| 版本管理 | 自动，严格顺序 | 手动，灵活控制 |
| 幂等性 | 不支持 | 强制要求 |
| 学习成本 | 高 | 低 |
| 协作体验 | 版本冲突频繁 | 手动协调，更透明 |
| 回滚支持 | 需要编写回滚脚本 | 需要编写回滚脚本 |
| 适用场景 | 大型项目，严格流程 | 中小型项目，敏捷开发 |

---

## 总结

这套规范的核心思想是：

1. **简单优于复杂**: 不需要 Flyway 的复杂版本管理
2. **幂等优于顺序**: 脚本可重复执行，不怕失败
3. **灵活优于严格**: 团队自主决定执行时机
4. **透明优于自动**: 手动执行更可控，问题更容易排查

遵循这套规范，可以在保持灵活性的同时，确保数据库变更的可控性和可追溯性。

---

## 参考资料

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [PostgreSQL DDL 最佳实践](https://wiki.postgresql.org/wiki/Don%27t_Do_This)
- [数据库迁移最佳实践](https://www.prisma.io/dataguide/types/relational/migration-strategies)
