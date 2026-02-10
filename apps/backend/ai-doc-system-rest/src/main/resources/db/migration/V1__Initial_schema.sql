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
  doc_reference JSON,     -- 文档参考内容，JSON 格式
  chunk_reference JSON,   -- 块参考内容，JSON 格式
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



-- SELECT 'Database schema created successfully!' as message;

