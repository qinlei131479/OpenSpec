package com.aiid.aidoc.service.impl;

import com.aiid.aidoc.model.entity.Document;
import com.aiid.aidoc.repository.mapper.DocumentMapper;
import com.aiid.aidoc.service.DocumentService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DocumentServiceImpl implements DocumentService {
    private final DocumentMapper documentMapper;

    @Override
    public Page<Document> list(String status, String keyword, long page, long pageSize) {
        LambdaQueryWrapper<Document> qw = new LambdaQueryWrapper<>();
        qw.eq(Document::getIsDeleted, false);  // 只查询未删除的文档
        if (keyword != null && !keyword.isBlank()) {
            qw.like(Document::getName, keyword);
        }
        Page<Document> p = new Page<>(page, pageSize);
        return documentMapper.selectPage(p, qw);
    }

    @Override
    public Page<Document> listByUser(String userId, String status, String keyword, long page, long pageSize) {
        LambdaQueryWrapper<Document> qw = new LambdaQueryWrapper<>();
        qw.eq(Document::getIsDeleted, false);
        qw.eq(Document::getUserId, userId);
        if (keyword != null && !keyword.isBlank()) {
            qw.like(Document::getName, keyword);
        }
        Page<Document> p = new Page<>(page, pageSize);
        return documentMapper.selectPage(p, qw);
    }

    @Override
    public Document create(Document doc) {
        doc.setId(UUID.randomUUID().toString());
        doc.setVersion(0);
        doc.setIsDeleted(false);  // 新建文档默认未删除
        doc.setCreatedAt(LocalDateTime.now());
        doc.setUpdatedAt(LocalDateTime.now());
        documentMapper.insert(doc);
        return doc;
    }

    @Override
    public void rename(String id, String name) {
        // 只重命名未删除的文档
        LambdaQueryWrapper<Document> qw = new LambdaQueryWrapper<>();
        qw.eq(Document::getId, id);
        qw.eq(Document::getIsDeleted, false);
        Document d = documentMapper.selectOne(qw);
        if (d == null) return;
        d.setName(name);
        d.setUpdatedAt(LocalDateTime.now());
        documentMapper.updateById(d);
    }

    @Override
    public void delete(String id) {
        // 软删除：设置 is_deleted 为 true
        Document doc = documentMapper.selectById(id);
        if (doc != null && !Boolean.TRUE.equals(doc.getIsDeleted())) {
            doc.setIsDeleted(true);
            doc.setUpdatedAt(LocalDateTime.now());
            documentMapper.updateById(doc);
        }
    }

    @Override
    public Optional<Document> findById(String id) {
        // 只查找未删除的文档
        LambdaQueryWrapper<Document> qw = new LambdaQueryWrapper<>();
        qw.eq(Document::getId, id);
        qw.eq(Document::getIsDeleted, false);
        return Optional.ofNullable(documentMapper.selectOne(qw));
    }
}


