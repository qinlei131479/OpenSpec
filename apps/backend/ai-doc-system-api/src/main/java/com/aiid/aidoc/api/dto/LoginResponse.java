package com.aiid.aidoc.api.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class LoginResponse {
    private String id;
    private String email;
    private String nickname;
    private String avatar;

    @JsonProperty("access_token")
    private String accessToken;
}
