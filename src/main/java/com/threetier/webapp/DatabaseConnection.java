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
        try {
            return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
        } catch (SQLException e) {
            // Improve error handling to distinguish between connection and permission issues
            if (e.getMessage().contains("permission") ||
                e.getMessage().contains("privilege") ||
                e.getSQLState().equals("42501")) {  // PostgreSQL permission denied code
                LOGGER.log(Level.SEVERE, "Database permission error: User '" + DB_USER +
                          "' lacks required permissions", e);
                throw new SQLException("Database permission error: The application user lacks " +
                                     "required permissions to perform this operation. " +
                                     "Please check database user privileges.", e);
            } else if (e.getMessage().contains("connection") ||
                      e.getSQLState().startsWith("08")) {  // PostgreSQL connection error codes
                LOGGER.log(Level.SEVERE, "Database connection error: Unable to connect to " + DB_URL, e);
                throw new SQLException("Database connection error: Unable to establish connection " +
                                     "to the database. Please check database availability and " +
                                     "connection parameters.", e);
            }
            // If it's another type of error, just rethrow
            throw e;
        }
    }
    
    /**
     * Initialize database schema and sample data
     */
    /**
     * Initialize database schema and sample data
     * @return boolean indicating if initialization was successful
     */
    public static boolean initializeDatabase() {
        LOGGER.info("Initializing database schema...");
        boolean success = false;
        
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            
            // First verify if we have proper permissions by checking if we can query the users table
            try {
                stmt.executeQuery("SELECT 1 FROM users LIMIT 1");
                LOGGER.info("Users table exists and is accessible");
            } catch (SQLException e) {
                // Table might not exist or we don't have permission
                if (e.getMessage().contains("relation") && e.getMessage().contains("does not exist")) {
                    LOGGER.info("Users table does not exist, will attempt to create it");
                } else if (e.getMessage().contains("permission") ||
                          e.getMessage().contains("privilege") ||
                          e.getSQLState().equals("42501")) {
                    LOGGER.severe("Permission denied: User '" + DB_USER +
                                "' lacks required permissions to access the users table");
                    LOGGER.severe("Please ensure the database user has appropriate permissions");
                    return false;
                } else {
                    throw e; // Rethrow unexpected errors
                }
            }
            
            // Create users table
            try {
                String createTable = "CREATE TABLE IF NOT EXISTS users (" +
                    "id SERIAL PRIMARY KEY, " +
                    "name VARCHAR(100) NOT NULL, " +
                    "email VARCHAR(100) UNIQUE NOT NULL, " +
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, " +
                    "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)";
                stmt.execute(createTable);
                LOGGER.info("Users table created/verified");
            } catch (SQLException e) {
                if (e.getMessage().contains("permission") ||
                    e.getMessage().contains("privilege") ||
                    e.getSQLState().equals("42501")) {
                    LOGGER.severe("Permission denied: User '" + DB_USER +
                                "' lacks required permissions to create tables");
                    LOGGER.severe("Please ensure the database user has CREATE TABLE permission");
                    return false;
                } else {
                    throw e; // Rethrow unexpected errors
                }
            }
            
            // Insert sample data
            try {
                String insertSample = "INSERT INTO users (name, email) VALUES " +
                    "('John Doe', 'john.doe@example.com'), " +
                    "('Jane Smith', 'jane.smith@example.com'), " +
                    "('Bob Johnson', 'bob.johnson@example.com') " +
                    "ON CONFLICT (email) DO NOTHING";
                int rowsInserted = stmt.executeUpdate(insertSample);
                LOGGER.info("Sample data inserted: " + rowsInserted + " rows");
            } catch (SQLException e) {
                if (e.getMessage().contains("permission") ||
                    e.getMessage().contains("privilege") ||
                    e.getSQLState().equals("42501")) {
                    LOGGER.warning("Permission denied: User '" + DB_USER +
                                 "' lacks required permissions to insert data");
                    LOGGER.warning("Application will continue but may have limited functionality");
                    // Continue execution as read-only operations might still work
                } else {
                    throw e; // Rethrow unexpected errors
                }
            }
            
            // Create index for better performance
            try {
                String createIndex = "CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)";
                stmt.execute(createIndex);
                LOGGER.info("Database index created/verified");
            } catch (SQLException e) {
                if (e.getMessage().contains("permission") ||
                    e.getMessage().contains("privilege") ||
                    e.getSQLState().equals("42501")) {
                    LOGGER.warning("Permission denied: User '" + DB_USER +
                                 "' lacks required permissions to create indexes");
                    LOGGER.warning("Application will continue but may have reduced performance");
                    // Continue execution as the application can still function without the index
                } else {
                    throw e; // Rethrow unexpected errors
                }
            }
            
            LOGGER.info("Database initialization completed successfully");
            success = true;
            
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to initialize database", e);
            if (e.getMessage().contains("permission") ||
                e.getMessage().contains("privilege") ||
                e.getSQLState().equals("42501")) {
                LOGGER.severe("Database permission error: Please check user privileges");
            } else if (e.getMessage().contains("connection") ||
                      e.getSQLState().startsWith("08")) {
                LOGGER.severe("Database connection error: Please check database availability");
            }
        }
        
        return success;
    }
    
    /**
     * Test database connectivity
     * @return true if connection is successful
     */
    /**
     * Test database connectivity and permissions
     * @return true if connection is successful and has basic permissions
     */
    public static boolean testConnection() {
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            
            // First test basic connection
            if (conn == null || conn.isClosed()) {
                LOGGER.warning("Database connection failed or is closed");
                return false;
            }
            
            // Then test if we can execute a simple query
            stmt.executeQuery("SELECT 1").close();
            
            // Finally test if we can access the users table
            try {
                stmt.executeQuery("SELECT COUNT(*) FROM users").close();
                LOGGER.info("Database connection and permissions verified");
                return true;
            } catch (SQLException e) {
                if (e.getMessage().contains("permission") ||
                    e.getMessage().contains("privilege") ||
                    e.getSQLState().equals("42501")) {
                    LOGGER.warning("Database permission error: User '" + DB_USER +
                                 "' lacks required permissions to access the users table");
                    return false;
                } else if (e.getMessage().contains("relation") &&
                          e.getMessage().contains("does not exist")) {
                    LOGGER.warning("Users table does not exist. Database may need initialization");
                    return false;
                }
                throw e; // Rethrow unexpected errors
            }
            
        } catch (SQLException e) {
            if (e.getMessage().contains("permission") ||
                e.getMessage().contains("privilege") ||
                e.getSQLState().equals("42501")) {
                LOGGER.log(Level.WARNING, "Database permission test failed", e);
            } else {
                LOGGER.log(Level.WARNING, "Database connection test failed", e);
            }
            return false;
        }
    }
    
    /**
     * Get database connection information for debugging
     * @return connection info string
     */
    public static String getConnectionInfo() {
        return String.format("host=%s port=%s dbname=%s user=%s",
                         DB_HOST, DB_PORT, DB_NAME, DB_USER);
    }
}
