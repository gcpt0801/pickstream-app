package com.pickstream.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class NameResponse {
    
    @JsonProperty("name")
    private String name;
    
    @JsonProperty("timestamp")
    private long timestamp;
    
    public NameResponse() {
        this.timestamp = System.currentTimeMillis();
    }
    
    public NameResponse(String name) {
        this.name = name;
        this.timestamp = System.currentTimeMillis();
    }
    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
    
    public long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }
}
