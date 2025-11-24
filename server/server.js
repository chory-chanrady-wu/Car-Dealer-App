const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bodyParser = require("body-parser");

const app = express();
const port = 3000;

app.use(cors());
// Increased limit for body parser to handle potentially large Base64 image strings
app.use(bodyParser.json({ limit: "50mb" }));

const db = mysql.createConnection({
  host: "localhost",
  user: "admin",
  password: "Admin@11032002",
  database: "user_directory",
});

db.connect((err) => {
  if (err) console.error("Error connecting to MySQL:", err);
  else console.log("Connected to MySQL Database");
});

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

// --- USER MANAGEMENT ---
app.get("/users", (req, res) => {
  db.query("SELECT * FROM users ORDER BY created_at DESC", (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Admin Add User
app.post("/users", (req, res) => {
  const { name, email, password, role } = req.body;
  const sql =
    "INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)";
  db.query(sql, [name, email, password, role], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "User added", id: result.insertId });
  });
});

// Update User / Profile
app.put("/users/:id", (req, res) => {
  const { name, email, password, role } = req.body;
  const sql = "UPDATE users SET name=?, email=?, password=?, role=? WHERE id=?";
  db.query(sql, [name, email, password, role, req.params.id], (err, result) => {
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

// --- CAR ENDPOINTS (UPDATED IMAGE UPLOAD LOGIC) ---

// 1. GET ALL CARS (With ONE Thumbnail)
app.get("/cars", (req, res) => {
  const sql = `
        SELECT c.*, 
        (SELECT image_base64 FROM car_images WHERE car_id = c.id LIMIT 1) as thumbnail 
        FROM cars c 
        ORDER BY c.created_at DESC`;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// 2. GET SINGLE CAR (With ALL Images)
app.get("/cars/:id", (req, res) => {
  const carId = req.params.id;
  const sqlCar = "SELECT * FROM cars WHERE id = ?";
  const sqlImages = "SELECT image_base64 FROM car_images WHERE car_id = ?";

  db.query(sqlCar, [carId], (err, carResult) => {
    if (err) return res.status(500).json({ error: err.message });
    if (carResult.length === 0)
      return res.status(404).json({ error: "Car not found" });

    db.query(sqlImages, [carId], (err, imageResults) => {
      if (err) return res.status(500).json({ error: err.message });

      const car = carResult[0];
      // Attach images array to car object
      car.images = imageResults.map((img) => img.image_base64);
      res.json(car);
    });
  });
});

// 3. ADD CAR (With Multiple Images) - FIX: Ensure image insertion completes before responding
app.post("/cars", (req, res) => {
  const { brand, model, year, import_price, price, images } = req.body; // images is Array of strings

  const sqlCar =
    "INSERT INTO cars (brand, model, year, import_price, price) VALUES (?, ?, ?, ?, ?)";

  db.query(sqlCar, [brand, model, year, import_price, price], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });

    const carId = result.insertId;

    // --- NEW IMAGE HANDLING LOGIC ---
    if (images && images.length > 0) {
      const imageValues = images.map((img) => [carId, img]);
      const sqlImages =
        "INSERT INTO car_images (car_id, image_base64) VALUES ?";

      // Execute image insertion and handle potential errors
      db.query(sqlImages, [imageValues], (err, imgResult) => {
        if (err) {
          // CRITICAL: Image failed. Delete the car entry (rollback) and return failure.
          db.query("DELETE FROM cars WHERE id = ?", [carId], (deleteErr) => {
            if (deleteErr)
              console.error(
                "FATAL: Failed to rollback car insert after image failure.",
                deleteErr
              );

            // Send the original image insertion error back to the client.
            return res.status(500).json({
              error:
                "Car creation failed due to image upload error. Transaction rolled back.",
              details: err.message,
            });
          });
        } else {
          // Success: Car and images added successfully.
          res.json({ message: "Car added successfully", id: carId });
        }
      });
    } else {
      // No images provided, successful car addition.
      res.json({ message: "Car added (no images provided)", id: carId });
    }
  });
});

// 4. SELL CAR (Update Profit)
app.put("/cars/:id/sell", (req, res) => {
  const carId = req.params.id;
  const { sold_price } = req.body; // User inputs actual sold price

  // Calculate profit dynamically via SQL
  const sql = `
        UPDATE cars 
        SET status = 'sold', 
            sold_at = NOW(), 
            sold_price = ?, 
            profit = ? - import_price 
        WHERE id = ?`;

  db.query(sql, [sold_price, sold_price, carId], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car sold" });
  });
});

// 5. UPDATE CAR DETAILS
app.put("/cars/:id", (req, res) => {
  const { brand, model, year, import_price, price } = req.body;
  const sql = `
    UPDATE cars 
    SET brand = ?, model = ?, year = ?, import_price = ?, price = ?
    WHERE id = ?`;
  db.query(
    sql,
    [brand, model, year, import_price, price, req.params.id],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Car updated" });
    }
  );
});

// 6. DELETE CAR
app.delete("/cars/:id", (req, res) => {
  // Images delete automatically due to ON DELETE CASCADE
  db.query("DELETE FROM cars WHERE id = ?", [req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Car deleted" });
  });
});
// --- CONTACTS ---
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

// --- REPORTS (UPDATED) ---
app.get("/reports/stats", (req, res) => {
  // UPDATED: Calculate SUM(sold_price) and SUM(profit)
  const sqlStats = `
        SELECT 
            COUNT(*) as count, 
            SUM(sold_price) as revenue, 
            SUM(profit) as total_profit 
        FROM cars WHERE status = 'sold'`;

  const sqlRecent = `
        SELECT id, brand, model, year, import_price, sold_price, profit, sold_at 
        FROM cars 
        WHERE status = 'sold' 
        ORDER BY sold_at DESC 
        LIMIT 10`;

  db.query(sqlStats, (err, stats) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(sqlRecent, (err, recent) => {
      if (err) return res.status(500).json({ error: err.message });

      res.json({
        total_sold: stats[0].count,
        total_revenue: stats[0].revenue || 0,
        total_profit: stats[0].total_profit || 0, // NEW FIELD
        recent_sales: recent,
      });
    });
  });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
