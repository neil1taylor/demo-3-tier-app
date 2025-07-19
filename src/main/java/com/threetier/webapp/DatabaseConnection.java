package com.threetier.webapp;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.logging.Logger;
import java.util.logging.Level;

/**
 * Database connection utility class for PostgreSQL
 */
public class DatabaseConnection {
    private static final Logger LOGGER = Logger.getLogger(DatabaseConnection.class.getName());
    
    // Database configuration - can be overridden by environment variables
    private static final String DB_HOST = System.getenv().getOrDefault("DB_HOST", "db-primary-service");
    private static final String DB_PORT = System.getenv().getOrDefault("DB_PORT", "5432");
    private static final String DB_NAME = System.getenv().getOrDefault("DB_NAME", "appdb");
    private static final String DB_USER = System.getenv().getOrDefault("DB_USER", "appuser");
    private static final String DB_PASSWORD = System.getenv().getOrDefault("DB_PASSWORD", "apppassword");
    
    private static final String DB_URL = String.format("jdbc:postgresql://%s:%s/%s", DB_HOST, DB_PORT, DB_NAME);
    
    static {
        try {
            Class.forName("org.postgresql.Driver");
            LOGGER.info("PostgreSQL JDBC driver loaded successfully");
        } catch (ClassNotFoundException e) {
            LOGGER.log(Level.SEVERE, "Failed to load PostgreSQL JDBC driver", e);
        }
    }
    
    /**
     * Get a database connection
     * @return Connection object
     * @throws SQLException if connection fails
     */
    public static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }
    
    /**
     * Initialize database schema and sample data
     */
    public static void initializeDatabase() {
        LOGGER.info("Initializing database schema...");
        
        try (Connection conn = getConnection(); 
             Statement stmt = conn.createStatement()) {
            
            // Create users table
            String createTable = "CREATE TABLE IF NOT EXISTS users (" +
                "id SERIAL PRIMARY KEY, " +
                "name VARCHAR(100) NOT NULL, " +
                "email VARCHAR(100) UNIQUE NOT NULL, " +
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, " +
                "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)";
            stmt.execute(createTable);
            LOGGER.info("Users table created/verified");
            
            // Insert sample data
            String insertSample = "INSERT INTO users (name, email) VALUES " +
                "('John Doe', 'john.doe@example.com'), " +
                "('Jane Smith', 'jane.smith@example.com'), " +
                "('Bob Johnson', 'bob.johnson@example.com') " +
                "ON CONFLICT (email) DO NOTHING";
            int rowsInserted = stmt.executeUpdate(insertSample);
            LOGGER.info("Sample data inserted: " + rowsInserted + " rows");
            
            // Create index for better performance
            String createIndex = "CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)";
            stmt.execute(createIndex);
            LOGGER.info("Database index created/verified");
            
            LOGGER.info("Database initialization completed successfully");
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to initialize database", e);
        }
    }
    
    /**
     * Test database connectivity
     * @return true if connection is successful
     */
    public static boolean testConnection() {
        try (Connection conn = getConnection()) {
            return conn != null && !conn.isClosed();
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Database connection test failed", e);
            return false;
        }
    }
    
    /**
     * Get database connection information for debugging
     * @return connection info string
     */
    public static String getConnectionInfo() {
        return String.format("%s@%s:%s/%s", DB_USER, DB_HOST, DB_PORT, DB_NAME);
    }
}
