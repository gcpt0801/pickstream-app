package com.pickstream.controller;

import com.pickstream.model.ApiResponse;
import com.pickstream.model.NameResponse;
import com.pickstream.service.NameService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class RandomNameController {
    
    private static final Logger logger = LoggerFactory.getLogger(RandomNameController.class);
    
    @Autowired
    private NameService nameService;
    
    @GetMapping("/random-name")
    @Timed(value = "api.random.name.get", description = "Time taken to get random name")
    public ResponseEntity<NameResponse> getRandomName() {
        logger.info("GET /api/random-name - Fetching random name");
        try {
            String name = nameService.getRandomName();
            NameResponse response = new NameResponse(name);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error getting random name", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new NameResponse("Error"));
        }
    }
    
    @PostMapping("/random-name")
    @Timed(value = "api.random.name.post", description = "Time taken to add name")
    public ResponseEntity<ApiResponse> addName(@RequestParam("name") String name) {
        logger.info("POST /api/random-name - Adding name: {}", name);
        
        if (name == null || name.trim().isEmpty()) {
            logger.warn("Attempted to add empty name");
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Name cannot be empty"));
        }
        
        boolean added = nameService.addName(name);
        if (added) {
            return ResponseEntity.ok(ApiResponse.success("Name added successfully"));
        } else {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Name already exists or is invalid"));
        }
    }
    
    @GetMapping("/names")
    @Timed(value = "api.names.list", description = "Time taken to list all names")
    public ResponseEntity<ApiResponse> getAllNames() {
        logger.info("GET /api/names - Fetching all names");
        List<String> names = nameService.getAllNames();
        Map<String, Object> data = new HashMap<>();
        data.put("names", names);
        data.put("count", names.size());
        return ResponseEntity.ok(ApiResponse.success("Names retrieved successfully", data));
    }
    
    @DeleteMapping("/names/{name}")
    @Timed(value = "api.names.delete", description = "Time taken to delete name")
    public ResponseEntity<ApiResponse> deleteName(@PathVariable String name) {
        logger.info("DELETE /api/names/{} - Removing name", name);
        boolean removed = nameService.removeName(name);
        if (removed) {
            return ResponseEntity.ok(ApiResponse.success("Name removed successfully"));
        } else {
            return ResponseEntity.notFound().build();
        }
    }
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "UP");
        health.put("service", "pickstream-backend");
        health.put("namesCount", nameService.getNameCount());
        health.put("timestamp", System.currentTimeMillis());
        return ResponseEntity.ok(health);
    }
}
