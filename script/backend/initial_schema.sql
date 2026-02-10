-- ============================================
-- 初始化数据库结构
-- ============================================
-- 创建时间: 2024-01-XX
-- 版本: 1.0.0
-- 说明: Google Docs 风格数据库设计的初始化脚本
-- MVP 约束：仅单层目录（parent_id 为 NULL，level 固定为 1），以便快速验证。
-- ============================================

-- 选择数据库（如果不存在则创建）
CREATE DATABASE IF NOT EXISTS doc_generator CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1. 文档表
DROP TABLE IF EXISTS doc_generator.documents;
CREATE TABLE doc_generator.documents (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  project_info JSON,
  meta_tags JSON,
  version INT DEFAULT 0,
  last_modified_by VARCHAR(50),
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_updated_at (updated_at),
  INDEX idx_deleted (is_deleted),
  FULLTEXT INDEX ft_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 文档块表
DROP TABLE IF EXISTS doc_generator.document_blocks;
CREATE TABLE doc_generator.document_blocks (
  id VARCHAR(50) PRIMARY KEY,
  document_id VARCHAR(50) NOT NULL,
  block_type ENUM('heading_1', 'heading_2', 'heading_3', 'heading_4', 'paragraph', 'table', 'list_item', 'code_block') NOT NULL,
  block_name VARCHAR(200) NOT NULL,
  order_key VARCHAR(100) NOT NULL,
  parent_id VARCHAR(50), -- MVP: 始终为 NULL（单层）
  level INT DEFAULT 1,   -- MVP: 固定为 1（单层）
  content TEXT,
  metadata JSON,
  is_deleted BOOLEAN DEFAULT FALSE,
  creator_id VARCHAR(50),
  modifier_id VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (document_id) REFERENCES doc_generator.documents(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES doc_generator.document_blocks(id) ON DELETE SET NULL,
  INDEX idx_document_order (document_id, order_key),
  INDEX idx_parent (parent_id),
  INDEX idx_type (document_id, block_type),
  INDEX idx_deleted (document_id, is_deleted),
  FULLTEXT INDEX ft_content (content)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -- 3. 操作日志表
-- DROP TABLE IF EXISTS document_operations;
-- CREATE TABLE document_operations (
--   id VARCHAR(50) PRIMARY KEY,
--   document_id VARCHAR(50) NOT NULL,
--   user_id VARCHAR(50) NOT NULL,
--   operation_type ENUM('insert', 'update', 'delete', 'move', 'format') NOT NULL,
--   block_id VARCHAR(50),
--   operation_data JSON NOT NULL,
--   version INT NOT NULL,
--   prev_version INT,
--   timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
--   INDEX idx_document_version (document_id, version),
--   INDEX idx_user (user_id, timestamp),
--   INDEX idx_block (block_id)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -- 4. 文档快照表
-- DROP TABLE IF EXISTS document_snapshots;
-- CREATE TABLE document_snapshots (
--   id VARCHAR(50) PRIMARY KEY,
--   document_id VARCHAR(50) NOT NULL,
--   snapshot_data JSON NOT NULL,
--   version INT NOT NULL,
--   created_by VARCHAR(50),
--   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
--   INDEX idx_document_version (document_id, version)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. 协作者表
-- DROP TABLE IF EXISTS document_collaborators;
-- CREATE TABLE document_collaborators (
--   id VARCHAR(50) PRIMARY KEY,
--   document_id VARCHAR(50) NOT NULL,
--   user_id VARCHAR(50) NOT NULL,
--   role ENUM('owner', 'editor', 'viewer') NOT NULL DEFAULT 'viewer',
--   status ENUM('active', 'pending', 'removed') DEFAULT 'active',
--   invited_by VARCHAR(50),
--   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
--   FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
--   UNIQUE KEY uk_document_user (document_id, user_id),
--   INDEX idx_user (user_id, status)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -- 6. AI生成任务表
-- DROP TABLE IF EXISTS ai_generation_tasks;
-- CREATE TABLE ai_generation_tasks (
--   id VARCHAR(50) PRIMARY KEY,
--   document_id VARCHAR(50),
--   block_id VARCHAR(50),
--   task_type ENUM('generate', 'continue', 'rewrite') NOT NULL,
--   status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending',
--   config JSON,
--   result JSON,
--   error_message TEXT,
--   progress INT DEFAULT 0,
--   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   completed_at TIMESTAMP,
--   FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
--   INDEX idx_status (status),
--   INDEX idx_document (document_id),
--   INDEX idx_block (block_id)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -- 7. 创建视图
-- DROP VIEW IF EXISTS v_document_with_blocks;
-- CREATE VIEW v_document_with_blocks AS
-- SELECT 
--   d.id,
--   d.name,
--   d.user_id,
--   d.status,
--   d.project_info,
--   d.version,
--   d.created_at,
--   d.updated_at,
--   COUNT(db.id) as block_count
-- FROM documents d
-- LEFT JOIN document_blocks db ON d.id = db.document_id AND db.is_deleted = FALSE
-- GROUP BY d.id;

-- SELECT 'Database schema created successfully!' as message;

