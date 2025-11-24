-- 1. Log into your MySQL server
-- 2. Run these commands to update the database structure.

CREATE DATABASE IF NOT EXISTS user_directory;

USE user_directory;

-- --- 1. AUTHENTICATION TABLE ---
DROP TABLE IF EXISTS users;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100), -- NEW COLUMN
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'user') DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default Admin
INSERT INTO users (name, email, password, role) VALUES ('Admin User', 'admin@gmail.com', 'admin', 'admin');

-- --- 2. INVENTORY TABLES ---
DROP TABLE IF EXISTS cars; 

CREATE TABLE IF NOT EXISTS cars (
    id INT AUTO_INCREMENT PRIMARY KEY,
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status ENUM('available', 'sold') DEFAULT 'available',
    sold_at TIMESTAMP NULL, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100)
);

INSERT INTO contacts (name, role, phone, email) VALUES 
('Mike Mechanic', 'Service Manager', '555-0101', 'mike@shop.com'),
('Sarah Sales', 'Supplier', '555-0202', 'sarah@imports.com');

INSERT INTO cars (make, model, year, price, status, sold_at) VALUES 
('Toyota', 'Camry', 2020, 22000.00, 'available', NULL),
('Honda', 'Civic', 2018, 18500.50, 'sold', NOW()),
('Ford', 'Mustang', 2021, 35000.00, 'available', NULL);