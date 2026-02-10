package com.aiid.aidoc.service.impl;

import com.aiid.aidoc.model.entity.DocumentBlock;
import com.aiid.aidoc.repository.mapper.DocumentBlockMapper;
import com.aiid.aidoc.service.DocumentBlockService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DocumentBlockServiceImpl implements DocumentBlockService {
    private final DocumentBlockMapper documentBlockMapper;

    @Override
    public Page<DocumentBlock> list(String documentId, String blockType, String keyword, long page, long pageSize) {
        LambdaQueryWrapper<DocumentBlock> qw = new LambdaQueryWrapper<>();
        qw.eq(DocumentBlock::getDocumentId, documentId)
          .eq(DocumentBlock::getIsDeleted, false);
        if (blockType != null && !blockType.isBlank()) {
            qw.eq(DocumentBlock::getBlockType, blockType);
        }
        if (keyword != null && !keyword.isBlank()) {
            qw.like(DocumentBlock::getContent, keyword);
        }
        // 使用二进制序确保严格的字节序排序，避免大小写不敏感排序导致的位置异常
        qw.last("ORDER BY BINARY order_key ASC");
        return documentBlockMapper.selectPage(new Page<>(page, pageSize), qw);
    }

    @Override
    public DocumentBlock create(DocumentBlock block) {
        block.setId(UUID.randomUUID().toString());
        block.setIsDeleted(false);
        block.setCreatedAt(LocalDateTime.now());
        block.setUpdatedAt(LocalDateTime.now());
        documentBlockMapper.insert(block);
        return block;
    }

    @Override
    public List<DocumentBlock> batchCreate(String documentId, Integer level, String parentId,
                                           List<DocumentBlockService.BlockItemData> blockItems,
                                           String anchorAfterId) {
        if (blockItems == null || blockItems.isEmpty()) {
            throw new IllegalArgumentException("blocks 数组不能为空");
        }
        
        List<DocumentBlock> createdBlocks = new ArrayList<>();
        String currentAfterId = anchorAfterId;
        LocalDateTime now = LocalDateTime.now();
        
        for (DocumentBlockService.BlockItemData item : blockItems) {
            DocumentBlock block = new DocumentBlock();
            block.setId(UUID.randomUUID().toString());
            block.setDocumentId(documentId);
            block.setBlockType(item.blockType());
            block.setBlockName(item.blockName());
            block.setContent(item.content());  // content 可以为 null
            block.setDocReference(item.docReference());  // docReference 可以为 null
            block.setChunkReference(item.chunkReference());  // chunkReference 可以为 null
            block.setLevel(level != null ? level : 1);
            block.setParentId(parentId);
            block.setIsDeleted(false);
            block.setCreatedAt(now);
            block.setUpdatedAt(now);
            
            // 使用 Fractional Indexing 计算 order_key
            try {
                String orderKey = calculateOrderKey(documentId, currentAfterId);
                block.setOrderKey(orderKey);
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("计算 order_key 失败: " + e.getMessage());
            }
            
            documentBlockMapper.insert(block);
            createdBlocks.add(block);
            
            // 下一次插入时，使用当前创建的 block 作为锚点
            currentAfterId = block.getId();
        }
        
        return createdBlocks;
    }

    @Override
    public Optional<DocumentBlock> findById(String id) {
        return Optional.ofNullable(documentBlockMapper.selectById(id));
    }

    @Override
    public void updateFields(String id, String blockName, String content, String docReference, String chunkReference) {
        if ((blockName == null || blockName.isBlank()) 
            && (content == null || content.isBlank()) 
            && (docReference == null)
            && (chunkReference == null)) {
            throw new IllegalArgumentException("至少提供 block_name、content、doc_reference 或 chunk_reference 其中之一");
        }
        DocumentBlock b = documentBlockMapper.selectById(id);
        if (b == null) return;
        if (blockName != null && !blockName.isBlank()) {
            b.setBlockName(blockName);
        }
        if (content != null && !content.isBlank()) {
            b.setContent(content);
        }
        if (docReference != null) { // docReference 可以为空字符串，所以只检查 null
            b.setDocReference(docReference);
        }
        if (chunkReference != null) { // chunkReference 可以为空字符串，所以只检查 null
            b.setChunkReference(chunkReference);
        }
        b.setUpdatedAt(LocalDateTime.now());
        documentBlockMapper.updateById(b);
    }

    @Override
    public void rename(String id, String name) {
        DocumentBlock b = documentBlockMapper.selectById(id);
        if (b == null) return;
        b.setBlockName(name);
        b.setUpdatedAt(LocalDateTime.now());
        documentBlockMapper.updateById(b);
    }

    @Override
    public void delete(String id) {
        documentBlockMapper.deleteById(id);
    }

    @Override
    public String calculateOrderKey(String documentId, String afterBlockId) {
        // 如果没有指定 afterBlockId，插入到最前面
        if (afterBlockId == null || afterBlockId.isBlank()) {
            return calculateOrderKeyAtStart(documentId);
        }
        
        // 找到指定的 block
        DocumentBlock afterBlock = documentBlockMapper.selectById(afterBlockId);
        if (afterBlock == null || !afterBlock.getDocumentId().equals(documentId)) {
            throw new IllegalArgumentException("指定的 block 不存在或不属于该文档");
        }

        String afterOrderKey = afterBlock.getOrderKey();

        // 查找下一个 block 的 order_key（必须严格大于 afterOrderKey）
        LambdaQueryWrapper<DocumentBlock> qw = new LambdaQueryWrapper<>();
        qw.eq(DocumentBlock::getDocumentId, documentId)
          .eq(DocumentBlock::getIsDeleted, false)
          .gt(DocumentBlock::getOrderKey, afterOrderKey)
          .orderByAsc(DocumentBlock::getOrderKey)
          .last("LIMIT 1");
        
        DocumentBlock nextBlock = documentBlockMapper.selectOne(qw);
        
        // 如果没有下一个 block，在 afterOrderKey 后面追加 "m"（中间字符）
        if (nextBlock == null) {
            return afterOrderKey + "m";
        }
        
        // 使用 Fractional Indexing 计算两个字符串之间的中间值
        return fractionalIndexBetween(afterOrderKey, nextBlock.getOrderKey());
    }

    /**
     * 计算插入到最前面的 order_key
     * 如果已经有 blocks，生成比最小的还小的值；如果没有，使用 "a"
     */
    private String calculateOrderKeyAtStart(String documentId) {
        // 查找最小的 order_key
        LambdaQueryWrapper<DocumentBlock> qw = new LambdaQueryWrapper<>();
        qw.eq(DocumentBlock::getDocumentId, documentId)
          .eq(DocumentBlock::getIsDeleted, false)
          .orderByAsc(DocumentBlock::getOrderKey)
          .last("LIMIT 1");
        
        DocumentBlock firstBlock = documentBlockMapper.selectOne(qw);
        
        // 如果没有 blocks，选择一个起始字符（使用 'A' 作为起始，比 'a' 小）
        if (firstBlock == null) {
            return "A";
        }

        // 如果有 blocks，生成比最小的还小的值，遵循 Fractional Indexing 的常见做法：
        // - 若最小 key 的首字符大于 'A'，直接返回 "A"
        // - 若最小 key 以 'A' 或比其更小的字符开头，则在其前面不断追加一个更小的前缀 '@'
        //   例如：最小为 "a" -> "A"；若最小已是 "A" -> "@A"；再次插入 -> "@@A" ...
        String minOrderKey = firstBlock.getOrderKey();
        char firstChar = minOrderKey.charAt(0);
        if (firstChar > 'A') {
            return "A";
        }
        // 前缀一个比 'A' 更小的字符 '@'，确保严格更小，重复插入会得到 "@@...@" + minOrderKey
        return "@" + minOrderKey;
    }

    /**
     * Fractional Indexing 核心算法：计算两个字符串之间的中间值
     * 这个算法保证生成的字符串在字典序上严格位于 a 和 b 之间
     */
    private String fractionalIndexBetween(String a, String b) {
        // 找到公共前缀
        int minLen = Math.min(a.length(), b.length());
        int prefixLen = 0;
        for (int i = 0; i < minLen; i++) {
            if (a.charAt(i) == b.charAt(i)) {
                prefixLen++;
            } else {
                break;
            }
        }
        
        String prefix = a.substring(0, prefixLen);
        
        // 情况1：a 是 b 的前缀（例如 "a" 和 "aa"）
        if (prefixLen == a.length() && b.length() > a.length()) {
            // 在 a 后面追加字符，但要比 b 的第一个不同字符小
            char nextChar = b.charAt(prefixLen);
            if (nextChar > 'a') {
                return a + "m";  // "a" + "m" = "am"，位于 "a" 和 "aa" 之间
            } else {
                return a + "a";  // 如果 b 的第一个字符是 'a'，使用 "aa"
            }
        }
        
        // 情况2：获取第一个不同的字符
        char charA = prefixLen < a.length() ? a.charAt(prefixLen) : 0;
        char charB = prefixLen < b.length() ? b.charAt(prefixLen) : 0;
        
        // 情况3：如果字符差距大于1，取中间字符
        if (charB - charA > 1) {
            char middleChar = (char) ((charA + charB) / 2);
            return prefix + middleChar;
        }
        
        // 情况4：如果字符差距为1（如 'a' 和 'b'），在 prefix + charA 后面加 "m"
        if (charB - charA == 1) {
            return prefix + charA + "m";
        }
        
        // 情况5：其他情况，在 prefix 后面加 "m"
        return prefix + "m";
    }

}


