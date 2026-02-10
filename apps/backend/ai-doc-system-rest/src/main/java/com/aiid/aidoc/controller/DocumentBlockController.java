package com.aiid.aidoc.controller;

import com.aiid.aidoc.api.dto.BatchBlockCreateRequest;
import com.aiid.aidoc.api.dto.BlockCreateRequest;
import com.aiid.aidoc.api.dto.PaginationResponse;
import com.aiid.aidoc.api.dto.RenameRequest;
import com.aiid.aidoc.api.dto.UpdateBlockContentRequest;
import com.aiid.aidoc.model.common.ApiResponse;
import com.aiid.aidoc.model.entity.DocumentBlock;
import com.aiid.aidoc.service.DocumentBlockService;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/documents/{id}/blocks")
public class DocumentBlockController {
    private final DocumentBlockService documentBlockService;

    @GetMapping
    public ApiResponse<PaginationResponse<DocumentBlock>> list(
            @PathVariable("id") String documentId,
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) long pageSize,
            @RequestParam(required = false, name = "blockType") String blockType,
            @RequestParam(required = false) String keyword
    ) {
        Page<DocumentBlock> p = documentBlockService.list(documentId, blockType, keyword, page, pageSize);
        PaginationResponse<DocumentBlock> resp = new PaginationResponse<>();
        resp.setTotal(p.getTotal());
        resp.setPage(p.getCurrent());
        resp.setPageSize(p.getSize());
        resp.setList(p.getRecords() != null ? p.getRecords() : java.util.Collections.emptyList());
        return ApiResponse.success(resp);
    }

    @PostMapping
    public ApiResponse<DocumentBlock> create(@PathVariable("id") String documentId, @Valid @RequestBody BlockCreateRequest body) {
        DocumentBlock block = new DocumentBlock();
        block.setDocumentId(documentId);
        block.setBlockType(body.getBlock_type());
        block.setBlockName(body.getBlock_name());
        block.setContent(body.getContent());
        block.setLevel(body.getLevel());
        block.setParentId(body.getParent_id());
        
        // 处理 docReference 和 chunkReference（JSON 格式）
        try {
            com.fasterxml.jackson.databind.ObjectMapper objectMapper = new com.fasterxml.jackson.databind.ObjectMapper();
            if (body.getDocReference() != null) {
                block.setDocReference(objectMapper.writeValueAsString(body.getDocReference()));
            }
            if (body.getChunkReference() != null) {
                block.setChunkReference(objectMapper.writeValueAsString(body.getChunkReference()));
            }
        } catch (Exception e) {
            return ApiResponse.message(400, "JSON 格式错误: " + e.getMessage());
        }
        
        // 使用 Fractional Indexing 自动计算 order_key
        // 如果指定了 after_id，插入到该 block 之后；否则插入到最前面
        try {
            String calculatedOrderKey = documentBlockService.calculateOrderKey(
                documentId, 
                (body.getAfter_id() != null && !body.getAfter_id().isBlank()) ? body.getAfter_id() : null
            );
            block.setOrderKey(calculatedOrderKey);
        } catch (IllegalArgumentException e) {
            return ApiResponse.message(400, e.getMessage());
        }
        
        DocumentBlock created = documentBlockService.create(block);
        return ApiResponse.created(created);
    }

    @PostMapping("/batch")
    public ApiResponse<?> batchCreate(@PathVariable("id") String documentId, @Valid @RequestBody BatchBlockCreateRequest body) {
        try {
            // 将 DTO 转换为 Service 层需要的数据结构
            com.fasterxml.jackson.databind.ObjectMapper objectMapper = new com.fasterxml.jackson.databind.ObjectMapper();
            java.util.List<com.aiid.aidoc.service.DocumentBlockService.BlockItemData> blockItems = new java.util.ArrayList<>();
            for (BatchBlockCreateRequest.BlockItem item : body.getBlocks()) {
                // 处理 docReference 和 chunkReference（JSON 格式）
                String docReference = null;
                String chunkReference = null;
                try {
                    if (item.getDocReference() != null) {
                        docReference = objectMapper.writeValueAsString(item.getDocReference());
                    }
                    if (item.getChunkReference() != null) {
                        chunkReference = objectMapper.writeValueAsString(item.getChunkReference());
                    }
                } catch (Exception e) {
                    return ApiResponse.message(400, "JSON 格式错误: " + e.getMessage());
                }
                
                blockItems.add(new com.aiid.aidoc.service.DocumentBlockService.BlockItemData(
                    item.getBlock_name(),
                    item.getBlock_type(),
                    item.getContent(),  // content 可以为 null
                    docReference,      // docReference 可以为 null
                    chunkReference      // chunkReference 可以为 null
                ));
            }
            
            java.util.List<DocumentBlock> createdBlocks = documentBlockService.batchCreate(
                documentId,
                body.getLevel(),
                body.getParent_id(),
                blockItems,
                body.getAnchor_after_id()
            );
            
            // 根据 returnOnlyIds 决定返回内容
            if (Boolean.TRUE.equals(body.getReturnOnlyIds())) {
                java.util.List<java.util.Map<String, String>> result = new java.util.ArrayList<>();
                for (DocumentBlock block : createdBlocks) {
                    java.util.Map<String, String> item = new java.util.HashMap<>();
                    item.put("id", block.getId());
                    item.put("order_key", block.getOrderKey());
                    result.add(item);
                }
                return ApiResponse.created(result);
            } else {
                return ApiResponse.created(createdBlocks);
            }
        } catch (IllegalArgumentException e) {
            return ApiResponse.message(400, e.getMessage());
        }
    }

    @GetMapping("/{blockId}")
    public ApiResponse<DocumentBlock> get(@PathVariable String blockId) {
        return documentBlockService.findById(blockId)
                .map(ApiResponse::success)
                .orElseGet(() -> ApiResponse.message(404, "Not Found"));
    }

    @PutMapping("/{blockId}")
    public ApiResponse<Void> update(@PathVariable String blockId, @Valid @RequestBody UpdateBlockContentRequest body) {
        String blockName = body.getBlock_name();
        String content = body.getContent();
        Object docReferenceObj = body.getDocReference();
        Object chunkReferenceObj = body.getChunkReference();
        
        // 将 Object 转换为 JSON 字符串
        String docReference = null;
        String chunkReference = null;
        try {
            com.fasterxml.jackson.databind.ObjectMapper objectMapper = new com.fasterxml.jackson.databind.ObjectMapper();
            if (docReferenceObj != null) {
                docReference = objectMapper.writeValueAsString(docReferenceObj);
            }
            if (chunkReferenceObj != null) {
                chunkReference = objectMapper.writeValueAsString(chunkReferenceObj);
            }
        } catch (Exception e) {
            return ApiResponse.message(400, "JSON 格式错误: " + e.getMessage());
        }
        
        if ((blockName == null || blockName.isBlank()) 
            && (content == null || content.isBlank()) 
            && (docReference == null)
            && (chunkReference == null)) {
            return ApiResponse.message(400, "请求体不能为空，至少提供 block_name、content、docReference 或 chunkReference 其中之一");
        }
        try {
            documentBlockService.updateFields(blockId, blockName, content, docReference, chunkReference);
        } catch (IllegalArgumentException e) {
            return ApiResponse.message(400, e.getMessage());
        }
        return ApiResponse.message(200, "文档块更新成功");
    }

    @PatchMapping("/{blockId}/rename")
    public ApiResponse<Void> rename(@PathVariable String blockId, @Valid @RequestBody RenameRequest body) {
        documentBlockService.rename(blockId, body.getName());
        return ApiResponse.message(200, "文档块重命名成功");
    }

    @DeleteMapping("/{blockId}")
    public ApiResponse<Void> delete(@PathVariable String blockId) {
        documentBlockService.delete(blockId);
        return ApiResponse.message(200, "文档块删除成功");
    }
}


