require 'sqlite3'

db = SQLite3::Database.new("db/grocerylist.db")


def seed!(db)
  puts "Using db file: db/grocerylist.db"
  puts "🧹 Dropping old tables..."
  drop_tables(db)
  puts "🧱 Creating tables..."
  create_tables(db)
  puts "🍎 Populating tables..."
  populate_tables(db)
  puts "✅ Done seeding the database!"
end

def drop_tables(db)
  db.execute('DROP TABLE IF EXISTS users')
  db.execute('DROP TABLE IF EXISTS grocerylist')
end

def create_tables(db)
  db.execute('CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE NOT NULL,
              password_hash TEXT NOT NULL)')
              
  db.execute('CREATE TABLE grocerylist (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              store TEXT,
              state BOOLEAN DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id))')
end

def populate_tables(db)
  now = Time.now.strftime('%Y-%m-%d')

  # no demo account; start with empty lists until users register and add items
  # sample data can be added by users through the app interface.
end

seed!(db)