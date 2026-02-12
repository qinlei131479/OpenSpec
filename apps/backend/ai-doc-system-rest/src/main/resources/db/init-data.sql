-- ============================================
-- PostgreSQL 初始数据脚本
-- ============================================
-- 创建时间: 2024-02-07
-- 版本: 2.0.0
-- 说明: 初始化系统标签等基础数据
-- 特点: 幂等设计，使用 ON CONFLICT DO NOTHING
-- ============================================

-- 初始化系统标签数据
-- 使用 ON CONFLICT DO NOTHING 确保幂等性

-- 专业标签
INSERT INTO template_tags (name, category, is_system, sort_order, user_id) VALUES
('建筑', 'profession', TRUE, 1, NULL),
('结构', 'profession', TRUE, 2, NULL),
('暖通', 'profession', TRUE, 3, NULL),
('给排水', 'profession', TRUE, 4, NULL),
('电气', 'profession', TRUE, 5, NULL),
('弱电', 'profession', TRUE, 6, NULL),
('景观', 'profession', TRUE, 7, NULL),
('室内', 'profession', TRUE, 8, NULL)
ON CONFLICT (name, category, user_id) DO NOTHING;

-- 业态标签
INSERT INTO template_tags (name, category, is_system, sort_order, user_id) VALUES
('学校', 'business_type', TRUE, 1, NULL),
('医院', 'business_type', TRUE, 2, NULL),
('工厂', 'business_type', TRUE, 3, NULL),
('办公楼', 'business_type', TRUE, 4, NULL),
('住宅', 'business_type', TRUE, 5, NULL),
('商业综合体', 'business_type', TRUE, 6, NULL),
('酒店', 'business_type', TRUE, 7, NULL),
('体育场馆', 'business_type', TRUE, 8, NULL)
ON CONFLICT (name, category, user_id) DO NOTHING;

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE 'Initial data inserted successfully!';
END $$;
