const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bodyParser = require("body-parser");

const app = express();
const port = 3000;

// Middleware
app.use(cors()); // Allow Flutter app to connect
app.use(bodyParser.json());

// MySQL Connection Configuration
// REPLACE these values with your actual database credentials
const db = mysql.createConnection({
  host: "localhost",
  user: "admin", // Default XAMPP/MySQL user
  password: "Admin@11032002", // Default XAMPP/MySQL password (often empty)
  database: "user_directory",
});

// Connect to Database
db.connect((err) => {
  if (err) {
    console.error("Error connecting to MySQL:", err);
    return;
  }
  console.log("Connected to MySQL Database");
});

// --- API Endpoints ---
// --- AUTHENTICATION ---
app.post("/login", (req, res) => {
  const { email, password } = req.body;
  const sql = "SELECT * FROM users WHERE email = ? AND password = ?";
  db.query(sql, [email, password], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length > 0)
      res.json({ message: "Login successful", user: results[0] });
    else res.status(401).json({ error: "Invalid email or password" });
  });
});

app.post("/signup", (req, res) => {
  const { name, email, password } = req.body; // Added name
  const sql =
    'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, "user")';
  db.query(sql, [name, email, password], (err, result) => {
    if (err) {
      if (err.code === "ER_DUP_ENTRY")
        return res.status(409).json({ error: "Email already exists" });
      return res.status(500).json({ error: err.message });
    }
    res.json({ message: "User created", id: result.insertId });
  });
});

// --- USER MANAGEMENT (ADMIN) ---
app.get("/users", (req, res) => {
  db.query("SELECT * FROM users ORDER BY created_at DESC", (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post("/users", (req, res) => {
  // Admin add user
  const { email, password, role } = req.body;
  const sql = "INSERT INTO users (email, password, role) VALUES (?, ?, ?)";
  db.query(sql, [email, password, role], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "User added", id: result.insertId });
  });
});

app.put("/users/:id", (req, res) => {
  const { email, password, role } = req.body;
  const sql = "UPDATE users SET email=?, password=?, role=? WHERE id=?";
  db.query(sql, [email, password, role, req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "User updated" });
  });
});

app.delete("/users/:id", (req, res) => {
  db.query("DELETE FROM users WHERE id=?", [req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "User deleted" });
  });
});

// --- CAR ENDPOINTS ---
app.get("/cars", (req, res) => {
  db.query("SELECT * FROM cars ORDER BY created_at DESC", (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post("/cars", (req, res) => {
  const { make, model, year, price } = req.body;
  const sql = "INSERT INTO cars (make, model, year, price) VALUES (?, ?, ?, ?)";
  db.query(sql, [make, model, year, price], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car added", id: result.insertId });
  });
});

app.put("/cars/:id/sell", (req, res) => {
  const sql = 'UPDATE cars SET status = "sold", sold_at = NOW() WHERE id = ?';
  db.query(sql, [req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car sold" });
  });
});

app.put("/cars/:id", (req, res) => {
  const { make, model, year, price } = req.body;
  const sql = "UPDATE cars SET make=?, model=?, year=?, price=? WHERE id=?";
  db.query(sql, [make, model, year, price, req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car updated" });
  });
});

app.delete("/cars/:id", (req, res) => {
  db.query("DELETE FROM cars WHERE id = ?", [req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car deleted" });
  });
});

// --- NEW REPORT ENDPOINT ---

app.get("/reports/stats", (req, res) => {
  const sqlStats =
    'SELECT COUNT(*) as count, SUM(price) as revenue FROM cars WHERE status = "sold"';
  const sqlRecent =
    'SELECT * FROM cars WHERE status = "sold" ORDER BY sold_at DESC LIMIT 10';

  db.query(sqlStats, (err, statsResult) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(sqlRecent, (err, recentResult) => {
      if (err) return res.status(500).json({ error: err.message });

      res.json({
        total_sold: statsResult[0].count,
        total_revenue: statsResult[0].revenue || 0,
        recent_sales: recentResult,
      });
    });
  });
});

// --- CONTACTS MANAGEMENT ---
// 1. GET all contacts
app.get("/contacts", (req, res) => {
  db.query("SELECT * FROM contacts", (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post("/contacts", (req, res) => {
  const { name, role, phone, email } = req.body;
  const sql =
    "INSERT INTO contacts (name, role, phone, email) VALUES (?, ?, ?, ?)";
  db.query(sql, [name, role, phone, email], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Contact added", id: result.insertId });
  });
});

app.put("/contacts/:id", (req, res) => {
  const { name, role, phone, email } = req.body;
  const sql = "UPDATE contacts SET name=?, role=?, phone=?, email=? WHERE id=?";
  db.query(sql, [name, role, phone, email, req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Contact updated" });
  });
});

app.delete("/contacts/:id", (req, res) => {
  db.query(
    "DELETE FROM contacts WHERE id=?",
    [req.params.id],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Contact deleted" });
    }
  );
});
// Start Server
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
