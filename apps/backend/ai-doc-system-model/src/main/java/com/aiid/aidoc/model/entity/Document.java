package com.aiid.aidoc.model.entity;

import com.aiid.aidoc.model.handler.JsonbTypeHandler;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("documents")
public class Document {
    @TableId
    private String id;
    private String name;
    private String userId;
    
    @TableField(typeHandler = JsonbTypeHandler.class)
    private String projectInfo; // JSON string stored as JSONB
    
    @TableField(typeHandler = JsonbTypeHandler.class)
    private String metaTags;    // JSON string stored as JSONB
    
    private Integer version;
    private String lastModifiedBy;
    private Boolean isDeleted;  // 软删除标记
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


