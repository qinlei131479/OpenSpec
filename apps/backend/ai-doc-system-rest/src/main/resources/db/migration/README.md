# 数据库迁移管理

本项目使用 **Flyway** 进行数据库版本管理和自动迁移。

## 📋 目录结构

```
src/main/resources/
└── db/
    └── migration/
        ├── V1__Initial_schema.sql         # 初始数据库结构
        ├── V2__Example_migration.sql      # 示例迁移脚本
        └── V{n}__{description}.sql        # 新的迁移脚本
```

## ✅ 优势

1. **自动执行**: Spring Boot 启动时自动执行未执行的迁移脚本
2. **版本管理**: 清晰记录每次数据库变更
3. **避免冲突**: 多人开发时避免数据库结构冲突
4. **环境一致**: 开发、测试、生产环境数据库结构保持一致
5. **可回溯**: 可以查看历史变更记录

## 🚀 使用方法

### 1. 添加新的数据库变更

创建新的迁移脚本，文件名格式：`V{版本号}__{描述}.sql`

```sql
-- 文件名: V3__Add_user_profile_table.sql

CREATE TABLE IF NOT EXISTS user_profile (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  avatar VARCHAR(500),
  bio TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2. 修改现有表

```sql
-- 文件名: V4__Add_email_to_document_template.sql

ALTER TABLE document_template 
  ADD COLUMN IF NOT EXISTS email VARCHAR(200) COMMENT '联系邮箱';

CREATE INDEX IF NOT EXISTS idx_email ON document_template(email);
```

### 3. 插入初始数据

```sql
-- 文件名: V5__Insert_default_settings.sql

INSERT IGNORE INTO settings (key, value) VALUES
  ('system_name', 'ArchSpec'),
  ('version', '1.0.0');
```

## 📝 命名规范

### 版本号规则
- **V1, V2, V3...**: 主版本号，递增
- **V1.1, V1.2**: 次版本号（可选）
- **V1.1.1**: 补丁版本号（可选）

### 描述规则
- 使用双下划线 `__` 分隔版本号和描述
- 描述使用英文，用下划线分隔单词
- 描述要清晰说明变更内容

### 示例
```
V1__Initial_schema.sql
V2__Add_user_table.sql
V3__Add_email_column.sql
V3.1__Fix_email_index.sql
```

## ⚙️ 配置说明

在 `application.yml` 中的配置：

```yaml
spring:
  flyway:
    enabled: true                   # 启用Flyway
    baseline-on-migrate: true       # 对已存在的数据库启用baseline
    baseline-version: 0             # baseline版本号
    locations: classpath:db/migration  # 迁移脚本位置
    encoding: UTF-8
    validate-on-migrate: true       # 迁移时验证
```

## 🔍 查看迁移历史

Flyway 会在数据库中创建 `flyway_schema_history` 表，记录所有迁移历史：

```sql
SELECT * FROM flyway_schema_history ORDER BY installed_rank;
```

字段说明：
- `installed_rank`: 执行顺序
- `version`: 版本号
- `description`: 描述
- `script`: 脚本文件名
- `installed_on`: 执行时间
- `success`: 是否成功

## ⚠️ 注意事项

### 1. 不要修改已执行的脚本
一旦迁移脚本执行成功，**不要修改**已执行的脚本。如需修改，请创建新的迁移脚本。

### 2. 使用幂等性操作
使用 `IF NOT EXISTS`、`INSERT IGNORE` 等语句，确保脚本可以重复执行：

```sql
-- ✅ 推荐
CREATE TABLE IF NOT EXISTS users (...);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(200);
INSERT IGNORE INTO settings VALUES (...);

-- ❌ 不推荐
CREATE TABLE users (...);  -- 重复执行会报错
ALTER TABLE users ADD COLUMN email VARCHAR(200);  -- 重复执行会报错
```

### 3. 测试迁移脚本
在开发环境测试通过后，再应用到生产环境。

### 4. 备份数据库
在生产环境执行迁移前，务必**备份数据库**。

## 🐛 常见问题

### Q1: 启动时报错 "Validate failed"
**原因**: 已执行的迁移脚本被修改了。

**解决**: 
1. 检查 `flyway_schema_history` 表，找到失败的版本
2. 恢复脚本内容，或者清理数据库重新初始化

### Q2: 如何在已有数据库上使用 Flyway？
**解决**: 配置中已设置 `baseline-on-migrate: true`，Flyway 会自动处理。

### Q3: 如何跳过某个版本？
**不推荐**: Flyway 强制按顺序执行。如果确实需要，可以手动在 `flyway_schema_history` 表中插入记录。

## 📚 更多资源

- [Flyway 官方文档](https://flywaydb.org/documentation/)
- [Flyway 命令参考](https://flywaydb.org/documentation/usage/commandline/)
