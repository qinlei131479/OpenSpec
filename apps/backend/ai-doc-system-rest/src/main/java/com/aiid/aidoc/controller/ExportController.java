package com.aiid.aidoc.controller;

import com.aiid.aidoc.model.common.ApiResponse;
import com.aiid.aidoc.model.entity.DocumentBlock;
import com.aiid.aidoc.service.DocumentBlockService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequiredArgsConstructor
@RequestMapping("/documents/{id}/export")
public class ExportController {
    private final DocumentBlockService documentBlockService;

    @PostMapping("/markdown")
    public ApiResponse<Map<String, String>> exportMarkdown(@PathVariable("id") String documentId) {
        // Fetch all blocks for the document (no pagination)
        List<DocumentBlock> all = documentBlockService
                .list(documentId, null, null, 1, Long.MAX_VALUE)
                .getRecords();

        StringBuilder sb = new StringBuilder();
        String lastBlockName = null;
        for (DocumentBlock b : all) {
            // 如果 blockName 发生变化且不为空，添加一级标题
            String currentBlockName = b.getBlockName();
            if (currentBlockName != null && !currentBlockName.isBlank() 
                && !currentBlockName.equals(lastBlockName)) {
                sb.append("\n# ").append(currentBlockName).append("\n\n");
                lastBlockName = currentBlockName;
            }
            
            switch (b.getBlockType()) {
                case "heading_1" -> sb.append(b.getContent()).append("\n\n");
                case "paragraph" -> sb.append(b.getContent()).append("\n\n");
                case "list_item" -> sb.append("- ").append(b.getContent()).append("\n");
                case "code_block" -> sb.append("```\n").append(b.getContent()).append("\n```\n\n");
                case "table" -> sb.append(b.getContent()).append("\n\n");
                default -> sb.append(b.getContent()).append("\n\n");
            }
        }

        Map<String, String> data = new HashMap<>();
        data.put("content", sb.toString().trim());
        data.put("fileName", "建筑设计说明_" + LocalDate.now().toString().replace("-", "") + ".md");
        return ApiResponse.success(data);
    }
}