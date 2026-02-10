package com.aiid.aidoc.model.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("document_blocks")
public class DocumentBlock {
    @TableId
    private String id;
    private String documentId;
    private String blockType;
    private String blockName;
    private String orderKey;
    private String parentId; // always null in MVP
    private Integer level;   // 1 in MVP
    private String content;
    private String docReference; // 文档参考内容，JSON 格式
    private String chunkReference; // 块参考内容，JSON 格式
    private String metadata; // JSON string
    private Boolean isDeleted;
    private String creatorId;
    private String modifierId;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


