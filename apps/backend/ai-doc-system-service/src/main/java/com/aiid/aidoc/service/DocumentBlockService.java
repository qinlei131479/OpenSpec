package com.aiid.aidoc.service;

import com.aiid.aidoc.model.entity.DocumentBlock;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.util.List;
import java.util.Optional;

public interface DocumentBlockService {
    Page<DocumentBlock> list(String documentId, String blockType, String keyword, long page, long pageSize);
    DocumentBlock create(DocumentBlock block);
    List<DocumentBlock> batchCreate(String documentId, Integer level, String parentId, 
                                    List<BlockItemData> blockItems, 
                                    String anchorAfterId);
    Optional<DocumentBlock> findById(String id);
    void updateFields(String id, String blockName, String content, String docReference, String chunkReference);
    void rename(String id, String name);
    void delete(String id);
    // 使用 Fractional Indexing 计算 order_key
    // afterBlockId 如果为 null，则插入到最前面
    String calculateOrderKey(String documentId, String afterBlockId);
    
    // 批量创建使用的数据类
    record BlockItemData(String blockName, String blockType, String content, String docReference, String chunkReference) {}
}


