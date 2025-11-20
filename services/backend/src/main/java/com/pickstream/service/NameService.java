package com.pickstream.service;

import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class NameService {
    
    private static final Logger logger = LoggerFactory.getLogger(NameService.class);
    private final List<String> names;
    private final Random random;
    
    public NameService() {
        this.names = new CopyOnWriteArrayList<>();
        this.random = new Random();
        initializeDefaultNames();
        logger.info("NameService initialized with {} names", names.size());
    }
    
    private void initializeDefaultNames() {
        names.add("Alice");
        names.add("Bob");
        names.add("Charlie");
        names.add("Diana");
        names.add("Eve");
        names.add("Frank");
        names.add("Grace");
        names.add("Henry");
        names.add("Ivy");
        names.add("Jack");
    }
    
    public String getRandomName() {
        if (names.isEmpty()) {
            logger.warn("Name list is empty, returning default");
            return "No names available";
        }
        
        int index = random.nextInt(names.size());
        String selectedName = names.get(index);
        logger.debug("Selected name: {} at index {}", selectedName, index);
        return selectedName;
    }
    
    public boolean addName(String name) {
        if (name == null || name.trim().isEmpty()) {
            logger.warn("Attempted to add null or empty name");
            return false;
        }
        
        String trimmedName = name.trim();
        if (names.contains(trimmedName)) {
            logger.info("Name already exists: {}", trimmedName);
            return false;
        }
        
        names.add(trimmedName);
        logger.info("Added new name: {}. Total names: {}", trimmedName, names.size());
        return true;
    }
    
    public List<String> getAllNames() {
        return new ArrayList<>(names);
    }
    
    public int getNameCount() {
        return names.size();
    }
    
    public boolean removeName(String name) {
        if (name == null || name.trim().isEmpty()) {
            return false;
        }
        
        boolean removed = names.remove(name.trim());
        if (removed) {
            logger.info("Removed name: {}. Remaining: {}", name, names.size());
        }
        return removed;
    }
    
    public void clearAllNames() {
        int count = names.size();
        names.clear();
        logger.info("Cleared all {} names", count);
    }
}
