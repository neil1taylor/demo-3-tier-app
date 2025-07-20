package com.threetier.webapp;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Date;
import java.util.logging.Logger;
import java.util.logging.Level;

/**
 * Health check servlet for monitoring application and database status
 */
public class HealthServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(HealthServlet.class.getName());
    
    /**
     * GET /health - Health check endpoint
     */
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Access-Control-Allow-Origin", "*");
        
        // Check application status
        String appStatus = "UP";
        String appDetails = "Application is running normally";
        
        // Check database status
        boolean dbHealthy = false;
        String dbStatus = "DOWN";
        String dbDetails = "Database connection failed";
        
        try (Connection conn = DatabaseConnection.getConnection();
             Statement stmt = conn.createStatement()) {
            // Test actual table access instead of just connection
            stmt.executeQuery("SELECT COUNT(*) FROM users");
            dbHealthy = true;
            dbStatus = "UP";
            dbDetails = "Database connection and permissions verified";
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Database health check failed", e);
            dbHealthy = false;
            dbStatus = "DEGRADED";
            dbDetails = "Database error: " + e.getMessage();
        }
        
        // Determine overall status
        String overallStatus = dbHealthy ? "UP" : "DEGRADED";
        
        // Build health response
        String healthJson = String.format(
            "{" +
            "\"status\":\"%s\"," +
            "\"timestamp\":\"%s\"," +
            "\"application\":{" +
                "\"status\":\"%s\"," +
                "\"details\":\"%s\"" +
            "}," +
            "\"database\":{" +
                "\"status\":\"%s\"," +
                "\"details\":\"%s\"," +
                "\"connection\":\"%s\"" +
            "}," +
            "\"version\":\"1.0.0\"," +
            "\"environment\":\"production\"" +
            "}",
            overallStatus, new Date().toString(),
            appStatus, appDetails,
            dbStatus, dbDetails, DatabaseConnection.getConnectionInfo()
        );
        
        // Set appropriate HTTP status
        if (!dbHealthy) {
            response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
        } else {
            response.setStatus(HttpServletResponse.SC_OK);
        }
        
        response.getWriter().write(healthJson);
        LOGGER.info("Health check completed - Overall status: " + overallStatus);
    }
}
