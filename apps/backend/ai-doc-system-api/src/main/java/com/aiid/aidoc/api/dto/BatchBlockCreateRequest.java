package com.aiid.aidoc.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class BatchBlockCreateRequest {
    private String anchor_after_id;  // 可选：首个块的插入锚点
    private Integer level = 1;        // 可选：统一的层级，默认1
    private String parent_id = null; // 可选：统一的父块ID，默认null
    
    @NotEmpty(message = "blocks 数组不能为空")
    @Size(max = 100, message = "单次最多创建100个块")
    @Valid
    private List<BlockItem> blocks;  // 必填：块数组
    
    private Boolean returnOnlyIds = true;  // 可选：是否只返回 id 和 order_key，默认true
    
    @Data
    public static class BlockItem {
        @NotBlank(message = "block_name 不能为空")
        private String block_name;  // 必填：块名称
        @NotBlank(message = "block_type 不能为空")
        private String block_type;  // 必填：块类型
        private String content;     // 可选：块内容，可以为空
        private Object docReference; // 可选：文档参考内容，JSON 格式
        private Object chunkReference; // 可选：块参考内容，JSON 格式
    }
}

