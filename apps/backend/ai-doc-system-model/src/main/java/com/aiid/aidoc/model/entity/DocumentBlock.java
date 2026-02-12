package com.aiid.aidoc.model.entity;

import com.aiid.aidoc.model.handler.JsonbTypeHandler;
import com.baomidou.mybatisplus.annotation.TableField;
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
    
    @TableField(typeHandler = JsonbTypeHandler.class)
    private String docReference; // 文档参考内容，JSON 格式存储为 JSONB
    
    @TableField(typeHandler = JsonbTypeHandler.class)
    private String chunkReference; // 块参考内容，JSON 格式存储为 JSONB
    
    @TableField(typeHandler = JsonbTypeHandler.class)
    private String metadata; // JSON string stored as JSONB
    
    private Boolean isDeleted;
    private String creatorId;
    private String modifierId;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


