const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bodyParser = require("body-parser");
// NOTE: For proper production use, consider using 'mysql2/promise' for cleaner async/await syntax,
// but for consistency, we will stick to the callback style for transaction management here.

const app = express();
const port = 3000;

app.use(cors());
// Increased limit for body parser to handle potentially large Base64 image strings
app.use(bodyParser.json({ limit: "50mb" }));

// --- DATABASE CONNECTION SETUP ---
// NOTE: For security, sensitive information like credentials should be stored
// in environment variables, not directly in the code.
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

// Helper to generate a dummy VIN (since it is required by schema)
const generateVIN = () => {
  return (
    "1HG" +
    Math.random().toString(36).substring(2, 10).toUpperCase() +
    Math.floor(100000 + Math.random() * 900000)
  );
};

// Helper to split a full name into first and last name
const splitName = (fullName) => {
  const parts = fullName.trim().split(/\s+/);
  const firstName = parts[0] || "";
  const lastName = parts.length > 1 ? parts.slice(1).join(" ") : "";
  return { firstName, lastName };
};

// Helper: Fetch user role by ID
const getUserRoleById = (userId) => {
  return new Promise((resolve, reject) => {
    db.query(
      "SELECT role FROM users WHERE id = ?",
      [userId],
      (err, results) => {
        if (err) return reject(err);
        if (results.length === 0) return resolve(null); // User not found
        resolve(results[0].role);
      }
    );
  });
};

// --- AUTHENTICATION ---
app.post("/login", (req, res) => {
  // SECURITY WARNING: Passwords should be hashed using bcrypt for storage and verified here.
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
  // SECURITY WARNING: Passwords should be hashed using bcrypt before insertion.
  const { name, email, password } = req.body;
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

app.post("/users", (req, res) => {
  const { name, email, password, role } = req.body;
  const sql =
    "INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)";
  db.query(sql, [name, email, password, role], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });

    // --- Salesperson Sync: Insert if role is 'sales' ---
    if (role === "sales") {
      const { firstName, lastName } = splitName(name);
      // Note: The mobile_phone, office_phone, and address are not available here, so they are NULL.
      const sqlSalesperson =
        "INSERT INTO salesperson (first_name, last_name, email, hire_date) VALUES (?, ?, ?, NOW())";
      db.query(sqlSalesperson, [firstName, lastName, email], (err) => {
        if (err) {
          // Log warning but proceed, as core user creation succeeded.
          console.error(
            "Warning: Failed to sync new user to salesperson table:",
            err.message
          );
        }
      });
    }
    // ---------------------------------------------------

    res.json({ message: "User added", id: result.insertId });
  });
});

app.put("/users/:id", (req, res) => {
  const { name, email, password, role } = req.body;
  const { firstName, lastName } = splitName(name);
  const userId = req.params.id;

  // SECURITY WARNING: You should check for authentication/authorization (e.g., is this an admin or the user themselves?)
  const sqlUser =
    "UPDATE users SET name=?, email=?, password=?, role=? WHERE id=?";
  db.query(sqlUser, [name, email, password, role, userId], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });

    // --- Salesperson Sync: Update or Insert the corresponding salesperson record ---
    if (role === "sales") {
      // Try to update existing salesperson record (in case name or email changed)
      // NOTE: This assumes the salesperson email is unique and matches the user email.
      const sqlSalespersonUpdate =
        "UPDATE salesperson SET first_name = ?, last_name = ?, email = ? WHERE email = ?";
      db.query(
        sqlSalespersonUpdate,
        [firstName, lastName, email, email],
        (err, updateResult) => {
          if (err) {
            console.error(
              "Warning: Failed to update salesperson during user update:",
              err.message
            );
            return res.json({
              message: "User updated, but salesperson sync failed (update).",
            });
          }

          if (updateResult.affectedRows === 0) {
            // If update affected 0 rows, no existing record was found -> insert one.
            const sqlSalespersonInsert =
              "INSERT INTO salesperson (first_name, last_name, email, hire_date) VALUES (?, ?, ?, NOW())";
            db.query(
              sqlSalespersonInsert,
              [firstName, lastName, email],
              (err) => {
                if (err) {
                  console.error(
                    "Warning: Failed to insert salesperson during user update:",
                    err.message
                  );
                  return res.json({
                    message:
                      "User updated, but salesperson sync failed (insert).",
                  });
                }
                res.json({
                  message: "User updated and synced as new salesperson",
                });
              }
            );
          } else {
            res.json({ message: "User updated and salesperson synced" });
          }
        }
      );
    } else {
      // User is not 'sales', only update the user record and respond.
      res.json({ message: "User updated" });
    }
  });
});

app.delete("/users/:id", (req, res) => {
  const userId = req.params.id;

  // 1. Get the email before deleting the user record
  db.query("SELECT email FROM users WHERE id=?", [userId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0)
      return res.status(404).json({ error: "User not found" });

    const email = results[0].email;

    // 2. Delete the user record
    db.query("DELETE FROM users WHERE id=?", [userId], (err, result) => {
      if (err) return res.status(500).json({ error: err.message });

      // 3. Attempt to delete the salesperson record by email (will fail if FK constraints exist, which is good)
      db.query("DELETE FROM salesperson WHERE email=?", [email], (err) => {
        if (err) {
          // If deletion fails (likely due to FK constraint from car_pricing), log and proceed.
          console.error(
            "Warning: Failed to delete salesperson record (likely due to sales history):",
            err.message
          );
        }
        res.json({ message: "User deleted" });
      });
    });
  });
});

// --- CAR ENDPOINTS ---

// 1. GET ALL CARS
app.get("/cars", (req, res) => {
  // Join 'cars' (c) with 'car_pricing' (cp) and 'cars_detail' (cd) to get all information.
  const sql = `
  SELECT 
  c.car_id as id, 
  c.car_id, 
  c.vin_number, 
  c.make, 
  c.model, 
  c.model_year as year, 
  cp.price, 
  cp.import_price, 
  cp.status, 
  cp.sold_price, 
  cp.profit, 
  cp.sold_at,
  cd.color, 
  cd.car_condition,
  cd.description,
  (SELECT image_base64 FROM car_images WHERE car_id = c.car_id LIMIT 1) as thumbnail 
FROM cars c 
LEFT JOIN car_pricing cp ON c.car_id = cp.car_id
LEFT JOIN cars_detail cd ON c.car_id = cd.car_id -- New join for car details
ORDER BY c.car_id DESC`;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// 2. GET SINGLE CAR
app.get("/cars/:id", (req, res) => {
  const carId = req.params.id;

  // Query 1: Get core car data
  const sqlCar =
    "SELECT c.car_id as id, c.car_id, c.vin_number, c.make, c.model, c.model_year as year, cd.* FROM cars c JOIN cars_detail cd ON c.car_id = cd.car_id WHERE c.car_id = ?";

  // Query 2: Get pricing data
  const sqlPricing =
    "SELECT price, import_price, status, sold_price, profit, sold_at FROM car_pricing WHERE car_id = ?";

  // Query 3: Get images
  const sqlImages = "SELECT image_base64 FROM car_images WHERE car_id = ?";

  db.query(sqlCar, [carId], (err, carResult) => {
    if (err) return res.status(500).json({ error: err.message });
    if (carResult.length === 0)
      return res.status(404).json({ error: "Car not found" });

    db.query(sqlPricing, [carId], (err, pricingResult) => {
      if (err) return res.status(500).json({ error: err.message });

      db.query(sqlImages, [carId], (err, imageResults) => {
        if (err) return res.status(500).json({ error: err.message });

        const car = {
          ...carResult[0],
          ...pricingResult[0], // Merge pricing data into car object
        };
        car.images = imageResults.map((img) => img.image_base64);
        res.json(car);
      });
    });
  });
});

// 3. ADD CAR (Now uses a Transaction for Atomicity)
app.post("/cars", async (req, res) => {
  // CRITICAL FIX: Destructure all necessary fields for cars_detail table.
  const {
    make,
    brand,
    model,
    year,
    price,
    import_price,
    images,
    salesperson_id,
    color,
    engine_type,
    car_condition,
    car_type,
    description,
    remark,
  } = req.body;

  // SECURITY WARNING: In a real app, 'salesperson_id' should be derived from a JWT/Session token
  // after the user logs in, not passed in the request body.
  if (!salesperson_id) {
    return res.status(401).json({
      error: "User ID (salesperson_id) is required for authorization context.",
    });
  }

  // --- Authorization Check ---
  try {
    const role = await getUserRoleById(salesperson_id);
    if (!role || (role !== "admin" && role !== "sales")) {
      return res.status(403).json({
        error: "Access denied. Only admin or sales roles can add cars.",
      });
    }
  } catch (err) {
    console.error("Error during role check:", err);
    return res
      .status(500)
      .json({ error: "Internal server error during authorization." });
  }
  // ---------------------------

  if (!import_price || !price) {
    return res
      .status(400)
      .json({ error: "price and import_price are required." });
  }

  const carMake = make || brand;
  const vin = generateVIN();

  // --- TRANSACTION START ---
  // Using a single connection to manage the transaction sequence
  db.beginTransaction((err) => {
    if (err) {
      return res
        .status(500)
        .json({ error: "Failed to start transaction.", details: err.message });
    }

    let carId = null;

    // 1. Insert Core Car Data
    const sqlCar =
      "INSERT INTO cars (vin_number, make, model, model_year) VALUES (?, ?, ?, ?)";

    db.query(sqlCar, [vin, carMake, model, year], (err, result) => {
      if (err) {
        return db.rollback(() =>
          res.status(500).json({
            error: "Failed to insert car data (Rollback).",
            details: err.message,
          })
        );
      }
      carId = result.insertId;

      // 2. Insert cars_detail
      const sqlDetail = `
        INSERT INTO cars_detail 
        (car_id, color, engine_type, car_condition, car_type, description, remark)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `;
      db.query(
        sqlDetail,
        [
          carId,
          color,
          engine_type,
          car_condition,
          car_type,
          description,
          remark,
        ],
        (err) => {
          if (err) {
            return db.rollback(() =>
              res.status(500).json({
                error: "Failed to insert car detail data (Rollback).",
                details: err.message,
              })
            );
          }

          // 3. Insert Pricing
          const sqlPricing =
            "INSERT INTO car_pricing (car_id, price, import_price) VALUES (?, ?, ?)";

          db.query(sqlPricing, [carId, price, import_price], (err) => {
            if (err) {
              return db.rollback(() =>
                res.status(500).json({
                  error: "Failed to insert pricing data (Rollback).",
                  details: err.message,
                })
              );
            }

            // 4. Insert Images (Optional step, but still part of the transaction)
            if (images && images.length > 0) {
              const imageValues = images.map((img) => [carId, img]);
              const sqlImages =
                "INSERT INTO car_images (car_id, image_base64) VALUES ?";

              db.query(sqlImages, [imageValues], (err) => {
                if (err) {
                  console.error("Image upload failed:", carId, err);
                  // Image failure is treated as critical and causes rollback
                  return db.rollback(() =>
                    res.status(500).json({
                      error: "Failed to insert image data (Rollback).",
                      details: err.message,
                    })
                  );
                }

                // --- COMMIT TRANSACTION ---
                db.commit((err) => {
                  if (err) {
                    return db.rollback(() =>
                      res.status(500).json({
                        error: "Failed to commit transaction (Rollback).",
                        details: err.message,
                      })
                    );
                  }
                  res.json({ message: "Car added successfully", id: carId });
                });
              });
            } else {
              // --- COMMIT TRANSACTION (No Images) ---
              db.commit((err) => {
                if (err) {
                  return db.rollback(() =>
                    res.status(500).json({
                      error: "Failed to commit transaction (Rollback).",
                      details: err.message,
                    })
                  );
                }
                res.json({ message: "Car added (no images)", id: carId });
              });
            }
          });
        }
      );
    });
  });
  // --- TRANSACTION END ---
});

// Get user role + email from users table
function getUserDataById(id) {
  return new Promise((resolve, reject) => {
    const sql = "SELECT id, email, role FROM users WHERE id = ?";
    db.query(sql, [id], (err, results) => {
      if (err) return reject(err);
      resolve(results[0] || null);
    });
  });
}

// Get salesperson_id by email
function getSalespersonIdByEmail(email) {
  return new Promise((resolve, reject) => {
    const sql = "SELECT salesperson_id FROM salesperson WHERE email = ?";
    db.query(sql, [email], (err, results) => {
      if (err) return reject(err);
      resolve(results[0]?.salesperson_id || null);
    });
  });
}


// --------------------------
// SELL CAR ENDPOINT
// --------------------------
app.post("/cars/:id/sell", async (req, res) => {
  const carId = req.params.id;
  const { sold_price, id: user_id_from_body } = req.body;

  if (!user_id_from_body) {
    return res.status(401).json({
      error: "User ID is required for authorization and transaction logging.",
    });
  }

  let actual_salesperson_id;
  let userData;

  try {
    // 1. Get user data
    userData = await getUserDataById(user_id_from_body);

    if (!userData) {
      return res.status(404).json({ error: "User not found." });
    }

    // 2. Authorization check
    if (userData.role !== "admin" && userData.role !== "sales") {
      return res.status(403).json({
        error: `Access denied. Your role (${userData.role}) is not authorized to sell cars.`,
      });
    }

    // 3. Get salesperson ID by email
    actual_salesperson_id = await getSalespersonIdByEmail(userData.email);

    if (!actual_salesperson_id) {
      return res.status(400).json({
        error: "Foreign Key Constraint Failure: User needs a salesperson ID.",
        message:
          "The authorized user must exist in 'salesperson' table to sell cars.",
      });
    }
  } catch (err) {
    console.error("Error during authorization/lookup:", err);
    return res.status(500).json({
      error: "Internal server error during authorization/lookup.",
    });
  }

  if (!sold_price) {
    return res.status(400).json({ error: "sold_price is required for sale." });
  }

  // Update sale details
  const sql = `
      UPDATE car_pricing 
      SET 
        status = 'sold', 
        sold_by_id = ?,
        sold_price = ?, 
        profit = (? - import_price), 
        sold_at = NOW() 
      WHERE car_id = ? AND status = 'in_stock'
    `;

  db.query(sql, [actual_salesperson_id, sold_price, sold_price, carId], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Car not found or already sold." });
    }

    res.json({ message: "Car marked as sold and profit calculated." });
  });
});
// 5. UPDATE CAR DETAILS (General Updates - Uses two separate UPDATEs)
app.put("/cars/:id", (req, res) => {
  // Fields for `cars` table
  const { make, brand, model, year } = req.body;
  const carMake = make || brand;

  // Fields for `car_pricing` table
  const { price, import_price, status } = req.body;
  const carId = req.params.id;

  // Update 1: Core Car details
  const sqlCar = `UPDATE cars SET make = ?, model = ?, model_year = ? WHERE car_id = ?`;

  // Update 2: Pricing details
  const sqlPricing = `UPDATE car_pricing SET price = ?, import_price = ?, status = ? WHERE car_id = ?`;

  db.query(sqlCar, [carMake, model, year, carId], (err) => {
    if (err)
      return res
        .status(500)
        .json({ error: `Failed to update car details: ${err.message}` });

    db.query(sqlPricing, [price, import_price, status, carId], (err) => {
      if (err)
        return res
          .status(500)
          .json({ error: `Failed to update pricing details: ${err.message}` });
      res.json({ message: "Car and pricing updated" });
    });
  });
});

// 6. DELETE CAR
app.delete("/cars/:id", (req, res) => {
  // Deleting from the 'cars' table cascades deletes to car_pricing, car_images, and cars_detail
  db.query(
    "DELETE FROM cars WHERE car_id = ?",
    [req.params.id],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Car deleted" });
    }
  );
});

// --- CONTACTS (Salespeople) ---
app.get("/contacts", (req, res) => {
  // Mapping salesperson table
  db.query("SELECT * FROM salesperson", (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post("/contacts", (req, res) => {
  // Updated to match salesperson schema
  const { first_name, last_name, email, mobile_phone, office_phone, address } =
    req.body;
  const sql =
    "INSERT INTO salesperson (first_name, last_name, email, mobile_phone, office_phone, address, hire_date) VALUES (?, ?, ?, ?, ?, ?, NOW())";

  db.query(
    sql,
    [first_name, last_name, email, mobile_phone, office_phone, address],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Salesperson added", id: result.insertId });
    }
  );
});

// --- REPORTS ---
app.get("/reports/stats", (req, res) => {
  // 1. Calculate total inventory value (asking price) and total number of cars
  const sqlTotalStats = `
        SELECT 
            COUNT(c.car_id) as total_in_stock_cars, 
            SUM(cp.price) as total_inventory_value
        FROM cars c
        JOIN car_pricing cp ON c.car_id = cp.car_id
        WHERE cp.status = 'in_stock'`;

  // 2. Calculate sales revenue and total profit from sold cars
  const sqlSalesStats = `
        SELECT 
            COUNT(car_id) as total_sold_count, 
            SUM(sold_price) as total_revenue,
            SUM(profit) as total_profit
        FROM car_pricing
        WHERE status = 'sold'`;

  // 3. List the 10 most profitable sales
  const sqlRecentProfitable = `
        SELECT c.car_id, c.make, c.model, c.model_year, cp.sold_price, cp.profit, s.first_name, s.last_name
        FROM cars c
        JOIN car_pricing cp ON c.car_id = cp.car_id
        JOIN salesperson s ON cp.sold_by_id = s.salesperson_id
        WHERE cp.status = 'sold'
        ORDER BY cp.profit DESC 
        LIMIT 10`;

  db.query(sqlTotalStats, (err, inventoryStats) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(sqlSalesStats, (err, salesStats) => {
      if (err) return res.status(500).json({ error: err.message });

      db.query(sqlRecentProfitable, (err, profitableSales) => {
        if (err) return res.status(500).json({ error: err.message });

        res.json({
          inventory_stats: {
            total_in_stock_cars: inventoryStats[0].total_in_stock_cars || 0,
            total_inventory_value: inventoryStats[0].total_inventory_value || 0,
          },
          sales_stats: {
            total_sold_count: salesStats[0].total_sold_count || 0,
            total_revenue: salesStats[0].total_revenue || 0,
            total_profit: salesStats[0].total_profit || 0,
          },
          most_profitable_sales: profitableSales,
        });
      });
    });
  });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
