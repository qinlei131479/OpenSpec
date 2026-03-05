package com.aiid.aidoc.controller;

import com.aiid.aidoc.api.dto.DocumentCreateRequest;
import com.aiid.aidoc.api.dto.PaginationResponse;
import com.aiid.aidoc.api.dto.RenameRequest;
import com.aiid.aidoc.model.common.ApiResponse;
import com.aiid.aidoc.model.entity.Document;
import com.aiid.aidoc.service.DocumentService;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;


@RestController
@RequestMapping("/documents")
@RequiredArgsConstructor
public class DocumentController {
    private final DocumentService documentService;

    @GetMapping
    public ApiResponse<PaginationResponse<Document>> list(
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) long pageSize,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String keyword,
            @RequestParam(name = "userId") String userId
    ) {
        if (userId == null || userId.isBlank()) {
            return ApiResponse.message(400, "userId 参数不能为空");
        }
        Page<Document> p = documentService.listByUser(userId, status, keyword, page, pageSize);
        PaginationResponse<Document> resp = new PaginationResponse<>();
        resp.setTotal(p.getTotal());
        resp.setPage(p.getCurrent());
        resp.setPageSize(p.getSize());
        resp.setList(p.getRecords() != null ? p.getRecords() : java.util.Collections.emptyList());
        return ApiResponse.success(resp);
    }

    @GetMapping("/{id}")
    public ApiResponse<Document> getById(@PathVariable String id) {
        return documentService.findById(id)
                .map(ApiResponse::success)
                .orElseGet(() -> ApiResponse.message(404, "文档不存在"));
    }

    @PostMapping("/create")
    public ApiResponse<Document> create(@Valid @RequestBody DocumentCreateRequest body) {
        Document doc = new Document();
        doc.setName(body.getName());
        doc.setUserId(body.getUserId());  // 设置用户ID
        if (body.getProjectInfo() != null) {
            doc.setProjectInfo(com.fasterxml.jackson.databind.json.JsonMapper.builder().build()
                    .createObjectNode().putPOJO("projectInfo", body.getProjectInfo()).toString());
        }
        Document created = documentService.create(doc);
        return ApiResponse.created(created);
    }

    @PatchMapping("/{id}/rename")
    public ApiResponse<Void> rename(@PathVariable String id, @Valid @RequestBody RenameRequest body) {
        documentService.rename(id, body.getName());
        return ApiResponse.message(200, "文档重命名成功");
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(@PathVariable String id) {
        documentService.delete(id);
        return ApiResponse.message(200, "文档删除成功");
    }
}


