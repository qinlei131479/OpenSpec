package com.aiid.aidoc.model.common;

import lombok.Data;

@Data
public class ApiResponse<T> {
    private int code;
    private String message;
    private T data;

    public static <T> ApiResponse<T> success(T data) {
        ApiResponse<T> r = new ApiResponse<>();
        r.setCode(200);
        r.setMessage("success");
        r.setData(data);
        return r;
    }

    public static <T> ApiResponse<T> created(T data) {
        ApiResponse<T> r = new ApiResponse<>();
        r.setCode(201);
        r.setMessage("created");
        r.setData(data);
        return r;
    }

    public static <T> ApiResponse<T> message(int code, String message) {
        ApiResponse<T> r = new ApiResponse<>();
        r.setCode(code);
        r.setMessage(message);
        r.setData(null);
        return r;
    }
}


