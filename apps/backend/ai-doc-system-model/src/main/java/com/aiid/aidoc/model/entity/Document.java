package com.aiid.aidoc.model.entity;

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
    private String projectInfo; // JSON string
    private String metaTags;    // JSON string
    private Integer version;
    private String lastModifiedBy;
    private Boolean isDeleted;  // 软删除标记
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


