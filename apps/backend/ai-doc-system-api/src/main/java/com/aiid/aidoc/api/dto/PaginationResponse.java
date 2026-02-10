package com.aiid.aidoc.api.dto;

import lombok.Data;

import java.util.List;

@Data
public class PaginationResponse<T> {
    private long total;
    private long page;
    private long pageSize;
    private List<T> list;
}


