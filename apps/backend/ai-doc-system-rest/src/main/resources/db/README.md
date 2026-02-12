# 数据库更新记录

本目录存放所有数据库脚本。

## 文件说明

- `init-schema.sql`: 完整的表结构初始化脚本（幂等）
- `init-data.sql`: 初始数据脚本（幂等）
- `DATABASE_UPDATE_GUIDE.md`: 数据库更新规范文档
- `migration/`: 旧的 Flyway 脚本（已废弃，仅供参考）
- 增量更新脚本: `YYYY-MM-DD-description.sql` 格式的文件

## 更新历史

### 2024-02-07 - 初始化数据库（从 MySQL 迁移到 PostgreSQL）
- **文件**: `init-schema.sql`, `init-data.sql`
- **作者**: ArchSpec Team
- **描述**:
  - 从 MySQL 迁移到 PostgreSQL
  - 初始化 6 张业务表：documents, document_blocks, template_tags, document_template, document_template_tags, cad_template
  - 移除 Flyway，采用幂等脚本管理
- **影响**:
  - 新增 6 张表
  - 新增 15+ 个索引
  - 新增触发器（自动更新 updated_at）
- **执行方式**:
  ```bash
  # 方式 1: Docker 自动初始化（首次启动）
  docker-compose up -d postgres

  # 方式 2: 手动执行
  psql -U archspec -d doc_generator -f init-schema.sql
  psql -U archspec -d doc_generator -f init-data.sql
  ```

---

## 如何添加新的更新脚本

请参考 [DATABASE_UPDATE_GUIDE.md](DATABASE_UPDATE_GUIDE.md) 中的详细说明。

**快速步骤**:

1. 在本目录创建脚本文件: `YYYY-MM-DD-description.sql`
2. 编写幂等 SQL（使用 `IF NOT EXISTS`）
3. 本地测试
4. 更新本 README
5. 提交代码并通知团队

**脚本模板**:
```sql
-- ============================================
-- 增量更新脚本
-- ============================================
-- 日期: YYYY-MM-DD
-- 作者: 姓名
-- 描述: 详细描述
-- Jira: ARCH-XXX
-- ============================================

-- 你的 SQL 代码（必须幂等）
CREATE TABLE IF NOT EXISTS ...;

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE 'Update completed successfully!';
END $$;
```

---

## 待执行的更新（按日期排序）

> 当前无待执行的更新

---

## 执行记录模板

```markdown
### YYYY-MM-DD - 更新标题
- **文件**: `YYYY-MM-DD-description.sql`
- **作者**: 姓名
- **描述**: 详细描述
- **影响**: 影响范围
- **执行方式**:
  ```bash
  psql -U archspec -d doc_generator -f YYYY-MM-DD-description.sql
  ```
- **执行状态**:
  - [ ] 开发环境
  - [ ] 测试环境
  - [ ] 生产环境
```
