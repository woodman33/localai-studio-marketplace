# CRITICAL FIX: Database path must use mounted volume
# Line 52 and other sqlite3.connect() calls

# BEFORE (BROKEN - saves to /purchases.db in root):
# conn = sqlite3.connect('purchases.db')

# AFTER (FIXED - saves to /app/data/purchases.db in mounted volume):
DB_PATH = os.path.join('/app/data', 'purchases.db')

def init_db():
    """Create purchases database if it doesn't exist"""
    os.makedirs('/app/data', exist_ok=True)  # Ensure directory exists
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS purchases
                 (user_id TEXT NOT NULL,
                  model_id TEXT NOT NULL,
                  purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  stripe_session_id TEXT,
                  PRIMARY KEY (user_id, model_id))''')
    conn.commit()
    conn.close()

# Replace ALL sqlite3.connect('purchases.db') with sqlite3.connect(DB_PATH)
# Lines to fix: 52, 243, 253, 271

# SEARCH AND REPLACE:
# OLD: sqlite3.connect('purchases.db')
# NEW: sqlite3.connect(DB_PATH)
