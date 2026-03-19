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
              name TEXT NOT NULL, 
              description TEXT,
              store TEXT,
              state BOOLEAN)')
end

def populate_tables(db)
  db.execute('INSERT INTO grocerylist (name, description, store, state) VALUES ("Mjölk", "3 liter mellanmjölk, eko", "ICA", 0)')
  db.execute('INSERT INTO grocerylist (name, description, store, state) VALUES ("Bröd", "Vete bröd", "Systembolaget", 0)')
  db.execute('INSERT INTO grocerylist (name, description, store, state) VALUES ("Smör", "Levererad smör", "Coop", 0)')

  # example user (password: sekret123)
  require 'bcrypt'
  pw = BCrypt::Password.create('sekret123')
  db.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)', ['demo', pw.to_s])
end

seed!(db)