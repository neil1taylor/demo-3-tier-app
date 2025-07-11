package com.threetier.webapp;

import java.time.LocalDateTime;

/**
 * User entity class
 */
public class User {
    private int id;
    private String name;
    private String email;
    private String createdAt;
    private String updatedAt;
    
    // Default constructor
    public User() {}
    
    // Constructor with all fields
    public User(int id, String name, String email, String createdAt) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.createdAt = createdAt;
    }
    
    // Constructor for new users (without ID)
    public User(String name, String email) {
        this.name = name;
        this.email = email;
    }
    
    // Getters and setters
    public int getId() { 
        return id; 
    }
    
    public void setId(int id) { 
        this.id = id; 
    }
    
    public String getName() { 
        return name; 
    }
    
    public void setName(String name) { 
        this.name = name; 
    }
    
    public String getEmail() { 
        return email; 
    }
    
    public void setEmail(String email) { 
        this.email = email; 
    }
    
    public String getCreatedAt() { 
        return createdAt; 
    }
    
    public void setCreatedAt(String createdAt) { 
        this.createdAt = createdAt; 
    }
    
    public String getUpdatedAt() { 
        return updatedAt; 
    }
    
    public void setUpdatedAt(String updatedAt) { 
        this.updatedAt = updatedAt; 
    }
    
    // Validation methods
    public boolean isValid() {
        return name != null && !name.trim().isEmpty() && 
               email != null && !email.trim().isEmpty() && 
               isValidEmail(email);
    }
    
    private boolean isValidEmail(String email) {
        return email.contains("@") && email.contains(".") && email.length() > 5;
    }
    
    @Override
    public String toString() {
        return String.format("User{id=%d, name='%s', email='%s', createdAt='%s'}", 
                           id, name, email, createdAt);
    }
    
    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        User user = (User) obj;
        return id == user.id;
    }
    
    @Override
    public int hashCode() {
        return Integer.hashCode(id);
    }
}
