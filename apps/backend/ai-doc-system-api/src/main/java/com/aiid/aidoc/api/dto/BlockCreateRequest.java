package com.aiid.aidoc.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class BlockCreateRequest {
    @NotBlank
    private String block_type;
    @NotBlank
    private String block_name;
    @NotBlank
    private String content;
    private Object docReference; // 文档参考内容，JSON 格式
    private Object chunkReference; // 块参考内容，JSON 格式
    private Integer level = 1;      // MVP fixed 1
    private String parent_id = null; // MVP null
    private String after_id;        // 可选：插入到指定 block 之后，使用 Fractional Indexing 自动计算 order_key；如果不指定，则插入到最前面
}


