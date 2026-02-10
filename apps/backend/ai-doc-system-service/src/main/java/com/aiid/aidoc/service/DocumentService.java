package com.aiid.aidoc.service;

import com.aiid.aidoc.model.entity.Document;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.util.Optional;

public interface DocumentService {
    Page<Document> list(String status, String keyword, long page, long pageSize);
    Page<Document> listByUser(String userId, String status, String keyword, long page, long pageSize);
    Document create(Document doc);
    void rename(String id, String name);
    void delete(String id);
    Optional<Document> findById(String id);
}


