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

-- 8. 模板标签表
DROP TABLE IF EXISTS doc_generator.template_tags;
CREATE TABLE doc_generator.template_tags (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL COMMENT '标签名称',
  category ENUM('profession', 'business_type', 'custom') NOT NULL COMMENT '标签分类：profession-专业，business_type-业态，custom-自定义',
  user_id BIGINT COMMENT '创建用户ID，系统标签为NULL',
  is_system BOOLEAN DEFAULT FALSE COMMENT '是否系统标签',
  sort_order INT DEFAULT 0 COMMENT '排序顺序',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_category (category),
  INDEX idx_user (user_id),
  UNIQUE KEY uk_name_category_user (name, category, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模板标签表';

-- 9. 文档模板表
DROP TABLE IF EXISTS doc_generator.document_template;
CREATE TABLE doc_generator.document_template (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL COMMENT '模板名称',
  description TEXT COMMENT '模板描述',
  file_path VARCHAR(500) COMMENT '文件存储路径',
  file_name VARCHAR(200) COMMENT '原始文件名',
  file_size BIGINT COMMENT '文件大小（字节）',
  file_type VARCHAR(50) COMMENT '文件类型（如：docx, pdf）',
  content TEXT COMMENT '模板内容（解释后的文本）',
  chapters JSON COMMENT '章节目录结构',
  status ENUM('uploaded', 'parsing', 'success', 'failed') DEFAULT 'uploaded' COMMENT '状态：uploaded-已上传，parsing-解释中，success-解释成功，failed-解释失败',
  error_message TEXT COMMENT '错误信息（解释失败时）',
  user_id BIGINT NOT NULL COMMENT '上传用户ID',
  is_standard BOOLEAN DEFAULT FALSE COMMENT '是否标准模板（供下载）',
  download_count INT DEFAULT 0 COMMENT '下载次数',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_is_standard (is_standard),
  INDEX idx_updated_at (updated_at),
  FULLTEXT INDEX ft_name_content (name, description)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档模板表';

-- 10. 文档模板与标签关联表
DROP TABLE IF EXISTS doc_generator.document_template_tags;
CREATE TABLE doc_generator.document_template_tags (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  template_id BIGINT NOT NULL COMMENT '模板ID',
  tag_id BIGINT NOT NULL COMMENT '标签ID',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (template_id) REFERENCES doc_generator.document_template(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES doc_generator.template_tags(id) ON DELETE CASCADE,
  UNIQUE KEY uk_template_tag (template_id, tag_id),
  INDEX idx_template (template_id),
  INDEX idx_tag (tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档模板与标签关联表';

-- 11. CAD模板表
DROP TABLE IF EXISTS doc_generator.cad_template;
CREATE TABLE doc_generator.cad_template (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL COMMENT 'CAD模板名称',
  description TEXT COMMENT '模板描述',
  file_path VARCHAR(500) NOT NULL COMMENT '文件存储路径',
  file_name VARCHAR(200) NOT NULL COMMENT '原始文件名',
  file_size BIGINT COMMENT '文件大小（字节）',
  file_type VARCHAR(50) COMMENT '文件类型（如：dwg, dxf）',
  user_id BIGINT NOT NULL COMMENT '上传用户ID',
  download_count INT DEFAULT 0 COMMENT '下载次数',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  UNIQUE KEY uk_user_template (user_id) COMMENT '每个用户只保留一份CAD模板'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CAD模板表';

-- 初始化系统标签数据
INSERT INTO doc_generator.template_tags (name, category, is_system, sort_order) VALUES
-- 专业标签
('建筑', 'profession', TRUE, 1),
('结构', 'profession', TRUE, 2),
('暖通', 'profession', TRUE, 3),
('给排水', 'profession', TRUE, 4),
('电气', 'profession', TRUE, 5),
('弱电', 'profession', TRUE, 6),
('景观', 'profession', TRUE, 7),
('室内', 'profession', TRUE, 8),
-- 业态标签
('学校', 'business_type', TRUE, 1),
('医院', 'business_type', TRUE, 2),
('工厂', 'business_type', TRUE, 3),
('办公楼', 'business_type', TRUE, 4),
('住宅', 'business_type', TRUE, 5),
('商业综合体', 'business_type', TRUE, 6),
('酒店', 'business_type', TRUE, 7),
('体育场馆', 'business_type', TRUE, 8);

-- SELECT 'Database schema created successfully!' as message;

