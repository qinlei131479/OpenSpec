package com.aiid.aidoc.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.Map;

@Data
public class DocumentCreateRequest {
    @NotBlank
    private String name;
    @NotBlank(message = "用户ID不能为空")
    private String userId;  // 用户ID，创建文档时必填
    private Map<String, Object> projectInfo;
}


