package com.aiid.aidoc.api.dto;

import lombok.Data;

@Data
public class UpdateBlockContentRequest {
    // 可选字段：传递则更新
    private String block_name;
    private String content;
    private Object docReference; // 文档参考内容，JSON 格式
    private Object chunkReference; // 块参考内容，JSON 格式
}


