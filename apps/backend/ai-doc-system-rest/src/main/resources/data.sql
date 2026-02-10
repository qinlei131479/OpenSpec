-- Seed sample data for local testing
-- Requires schema from initial_schema.sql to be present in database `doc_generator`

-- Documents
INSERT INTO doc_generator.documents (id, name, user_id, project_info, meta_tags, version, last_modified_by)
VALUES
  ('DOC-100001', 'Demo PRD 文档', 'user-001', JSON_OBJECT('project', 'AI Doc Demo', 'env', 'local'), JSON_ARRAY('demo', 'prd'), 1, 'user-001'),
  ('DOC-100002', '接口说明文档', 'user-002', JSON_OBJECT('project', 'API Spec', 'env', 'local'), JSON_ARRAY('api', 'spec'), 1, 'user-002')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Document blocks for DOC-100001
-- 使用 Fractional Indexing: a < m < z < za < zb (字典序)
INSERT INTO doc_generator.document_blocks (
  id, document_id, block_type, block_name, order_key, parent_id, level, content, metadata, is_deleted, creator_id, modifier_id
) VALUES
  ('BLK-100001', 'DOC-100001', 'heading_1', '概述', 'a', NULL, 1, '1. 概述', JSON_OBJECT('style', 'bold'), FALSE, 'user-001', 'user-001'),
  ('BLK-100002', 'DOC-100001', 'paragraph', '引言', 'm', NULL, 1, '这是一个用于本地联调的示例文档，用于验证接口。', JSON_OBJECT('lang', 'zh-CN'), FALSE, 'user-001', 'user-001'),
  ('BLK-100003', 'DOC-100001', 'heading_2', '目标', 'z', NULL, 1, '1.1 目标', NULL, FALSE, 'user-001', 'user-001'),
  ('BLK-100004', 'DOC-100001', 'list_item', '要点一', 'za', NULL, 1, '提供最小可用数据集合', NULL, FALSE, 'user-001', 'user-001'),
  ('BLK-100005', 'DOC-100001', 'list_item', '要点二', 'zb', NULL, 1, '验证查询、创建、更新、删除接口', NULL, FALSE, 'user-001', 'user-001')
ON DUPLICATE KEY UPDATE content = VALUES(content);

-- Document blocks for DOC-100002
-- 使用 Fractional Indexing: a < m (字典序)
INSERT INTO doc_generator.document_blocks (
  id, document_id, block_type, block_name, order_key, parent_id, level, content, metadata, is_deleted, creator_id, modifier_id
) VALUES
  ('BLK-200001', 'DOC-100002', 'heading_1', '接口列表', 'a', NULL, 1, '接口列表', NULL, FALSE, 'user-002', 'user-002'),
  ('BLK-200002', 'DOC-100002', 'table', '接口表', 'm', NULL, 1,
    '|
接口|方法|路径|
|---|---|---|
|获取文档|GET|/documents/{id}|
|查询文档块|GET|/document-blocks?documentId={id}|
|创建文档块|POST|/document-blocks|
', JSON_OBJECT('format', 'markdown'), FALSE, 'user-002', 'user-002')
ON DUPLICATE KEY UPDATE content = VALUES(content);


