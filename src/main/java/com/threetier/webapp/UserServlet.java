package com.threetier.webapp;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;
import java.util.logging.Level;

/**
 * REST API servlet for user management
 */
public class UserServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(UserServlet.class.getName());
    private Gson gson;
    
    @Override
    public void init() throws ServletException {
        LOGGER.info("Initializing UserServlet...");
        
        // Configure Gson with pretty printing
        gson = new GsonBuilder()
                .setPrettyPrinting()
                .create();
        
        // Initialize database
        DatabaseConnection.initializeDatabase();
        
        LOGGER.info("UserServlet initialized successfully");
    }
    
    /**
     * GET /api/users/ - List all users
     */
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        LOGGER.info("GET request received for users list");
        setJsonResponse(response);
        
        List<User> users = new ArrayList<>();
        
        try (Connection conn = DatabaseConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM users ORDER BY id")) {
            
            while (rs.next()) {
                User user = new User(
                    rs.getInt("id"),
                    rs.getString("name"),
                    rs.getString("email"),
                    rs.getString("created_at")
                );
                users.add(user);
            }
            
            LOGGER.info("Retrieved " + users.size() + " users from database");
            response.getWriter().write(gson.toJson(users));
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error while retrieving users", e);
            sendErrorResponse(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, 
                            "Database error: " + e.getMessage());
        }
    }
    
    /**
     * POST /api/users/ - Create new user
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        LOGGER.info("POST request received for user creation");
        LOGGER.info("Content Type: " + request.getContentType());
        setJsonResponse(response);
        
        String name = request.getParameter("name");
        String email = request.getParameter("email");
        
        LOGGER.info("Received parameters - name: '" + name + "', email: '" + email + "'");
        LOGGER.info("name is null: " + (name == null) + ", email is null: " + (email == null));
        if (name != null) LOGGER.info("name is empty: " + name.trim().isEmpty());
        if (email != null) LOGGER.info("email is empty: " + email.trim().isEmpty());
        
        // Validate input
        if (name == null || email == null || name.trim().isEmpty() || email.trim().isEmpty()) {
            LOGGER.warning("Validation failed: Name and email are required");
            sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST,
                            "Name and email are required");
            return;
        }
        
        // Create and validate user object
        User newUser = new User(name.trim(), email.trim());
        if (!newUser.isValid()) {
            sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                            "Invalid email format");
            return;
        }
        
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                 "INSERT INTO users (name, email) VALUES (?, ?) RETURNING id, created_at")) {
            
            stmt.setString(1, newUser.getName());
            stmt.setString(2, newUser.getEmail());
            
            ResultSet rs = stmt.executeQuery();
            if (rs.next()) {
                User createdUser = new User(
                    rs.getInt("id"),
                    newUser.getName(),
                    newUser.getEmail(),
                    rs.getString("created_at")
                );
                
                LOGGER.info("Created new user: " + createdUser);
                response.setStatus(HttpServletResponse.SC_CREATED);
                response.getWriter().write(gson.toJson(createdUser));
            }
            
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Database error while creating user", e);
            
            // Handle unique constraint violation
            if (e.getMessage().contains("duplicate key") || e.getMessage().contains("unique")) {
                sendErrorResponse(response, HttpServletResponse.SC_CONFLICT, 
                                "User with this email already exists");
            } else {
                sendErrorResponse(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, 
                                "Database error: " + e.getMessage());
            }
        }
    }
    
    /**
     * Set JSON response headers
     */
    private void setJsonResponse(HttpServletResponse response) {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "Content-Type");
    }
    
    /**
     * Send error response in JSON format
     */
    private void sendErrorResponse(HttpServletResponse response, int statusCode, String message) 
            throws IOException {
        response.setStatus(statusCode);
        String errorJson = String.format("{\"error\":\"%s\",\"status\":%d}", message, statusCode);
        response.getWriter().write(errorJson);
        LOGGER.warning("Error response sent: " + message);
    }
}
