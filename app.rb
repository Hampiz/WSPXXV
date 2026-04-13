# Import required gems
require 'sinatra'       # Web framework
require 'slim'          # Templating engine
require 'sqlite3'       # Database
require 'sinatra/reloader' # Auto-reload app on file changes during development
require 'bcrypt'        # Password hashing

# Enable session support for storing logged-in user state
enable :sessions

# Helper methods available in both routes and views
helpers do
  # Returns the currently logged-in user's data, or nil if not logged in
  def current_user
    return nil unless session[:user_id]
    db = SQLite3::Database.new('db/grocerylist.db')
    db.results_as_hash = true
    user = db.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
    user
  end

  # Returns the current user's active (not done) list, or nil if none exists
  def current_list
    return nil unless logged_in?
    db = SQLite3::Database.new('db/grocerylist.db')
    db.results_as_hash = true
    db.get_first_row('SELECT * FROM lists WHERE user_id = ? AND state = 0 ORDER BY id DESC LIMIT 1', current_user['id'])
  end

  # Returns true if a user is logged in, false otherwise
  def logged_in?
    !!current_user
  end
end

# Before filter — protect all /grocerylist routes from unauthenticated access
before '/grocerylist*' do
  unless logged_in?
    redirect('/login')
  end
end

# Render the home/index page
get('/') do  
  slim(:index)
end

# Render the login page
get('/login') do
  slim(:login)
end

# Render the registration page
get('/register') do
  slim(:register)
end

# Handle login form submission
post('/login') do
  username = params["username"]
  pwd = params["pwd"]
  db = SQLite3::Database.new("db/grocerylist.db")
  db.results_as_hash = true
  # Look up the user by username
  result = db.execute("SELECT id,password_hash FROM users WHERE username=?", username)
  if result.empty?
    # No user found — show error
    @error = 'Invalid username or password'
    slim(:login)
  else
    user_id = result.first["id"]
    pwd_digest = result.first["password_hash"]
    # Compare submitted password against the stored BCrypt hash
    if BCrypt::Password.new(pwd_digest) == pwd
      # Password matches — store user ID in session and redirect
      session[:user_id] = user_id
      redirect('/grocerylist')
    else
      # Wrong password — show error
      @error = 'Invalid username or password'
      slim(:login)
    end
  end
end

# Handle registration form submission
post('/register') do
  username = params["username"]
  pwd = params["pwd"]
  pwd_confirm = params["pwd_confirm"]

  db = SQLite3::Database.new("db/grocerylist.db")
  # Check if the username is already taken
  result = db.execute("SELECT id FROM users WHERE username=?", username)

  if result.empty?
    # Username is available — check that passwords match
    if pwd == pwd_confirm
      # Hash the password and insert the new user into the database
      pwd_digest = BCrypt::Password.create(pwd)
      db.execute("INSERT INTO users(username, password_hash) VALUES(?,?)", [username, pwd_digest])
      # Log the new user in immediately by storing their ID in the session
      session[:user_id] = db.last_insert_row_id
      redirect('/grocerylist')
    else
      @error = 'Lösenorden matchar inte'
      slim(:register)
    end
  else
    @error = 'Användarnamnet är redan taget'
    slim(:register)
  end
end

# Handle logout — clear the session and redirect to home
post('/logout') do
  session.clear
  redirect('/')
end

# Display the grocery list page for the current user
get('/grocerylist') do
  query = params['q']
  db = SQLite3::Database.new('db/grocerylist.db')
  db.results_as_hash = true
  @current_list = current_list
  # Fetch all completed lists belonging to the current user
  @done_lists = db.execute('SELECT * FROM lists WHERE user_id = ? AND state = 1 ORDER BY id DESC', [current_user['id']])
  if @current_list
    if query && !query.empty?
      # If a search query is present, filter items by name
      @grocerylist = db.execute("SELECT * FROM grocerylist WHERE list_id = ? AND name LIKE ?", [@current_list['id'], "%#{query}%"])
    else
      # Otherwise fetch all items in the active list
      @grocerylist = db.execute('SELECT * FROM grocerylist WHERE list_id = ?', [@current_list['id']])
    end
  else
    @grocerylist = []
  end
  # If show_list_id param is present, load that completed list's items to display
  if params[:show_list_id]
    shown = db.get_first_row('SELECT * FROM lists WHERE id = ? AND user_id = ? AND state = 1', [params[:show_list_id].to_i, current_user['id']])
    if shown
      @shown_list = shown
      @shown_items = db.execute('SELECT * FROM grocerylist WHERE list_id = ?', [shown['id']])
    end
  end
  slim(:grocerylist)
end

# Display a specific list by its ID (used when viewing a particular list directly)
get('/grocerylist/:list_id') do
  db = SQLite3::Database.new('db/grocerylist.db')
  db.results_as_hash = true
  # Ensure the list belongs to the current user
  list = db.get_first_row('SELECT * FROM lists WHERE id = ? AND user_id = ?', [params[:list_id].to_i, current_user['id']])
  redirect('/grocerylist') unless list
  @current_list = list
  @grocerylist = db.execute('SELECT * FROM grocerylist WHERE list_id = ?', [list['id']])
  @done_lists = db.execute('SELECT * FROM lists WHERE user_id = ? AND state = 1 ORDER BY id DESC', [current_user['id']])
  slim(:grocerylist)
end

# Create a new grocery list for the current user
post('/list/new') do
  name = params['list_name']
  # Default name if left blank
  name = 'Ny inköpslista' if name.nil? || name.strip.empty?
  db = SQLite3::Database.new('db/grocerylist.db')
  # Prevent creating a new list if one is already active
  active = db.get_first_row('SELECT id FROM lists WHERE user_id = ? AND state = 0', [current_user['id']])
  if active
    redirect('/grocerylist?message=already_active')
  else
    created_at = Time.now.strftime('%Y-%m-%d')
    db.execute('INSERT INTO lists (user_id, name, state, created_at) VALUES (?, ?, 0, ?)', [current_user['id'], name, created_at])
    redirect('/grocerylist?message=created')
  end
end

# Mark the current active list as done (state = 1)
post('/list/done') do
  list = current_list
  return redirect('/grocerylist') unless list
  db = SQLite3::Database.new('db/grocerylist.db')
  db.execute('UPDATE lists SET state = 1 WHERE id = ? AND user_id = ?', [list['id'], current_user['id']])
  redirect('/grocerylist?message=done')
end

# Add a new grocery item to the current active list
post('/grocerylist') do
  list = current_list
  # Redirect with error if no active list exists
  return redirect('/grocerylist?message=no_list') unless list
  new_grocery = params['new_grocery']
  description = params[:description]
  store = params[:store]
  db = SQLite3::Database.new('db/grocerylist.db')
  created_at = Time.now.strftime('%Y-%m-%d')
  list = current_list
  db.execute('INSERT INTO grocerylist (list_id, name, description, store, state, created_at) VALUES (?, ?, ?, ?, ?, ?)', [list['id'], new_grocery, description, store, 0, created_at])
  redirect('/grocerylist')
end

# Update an existing grocery item's name, description and store
post('/grocerylist/:id/update') do
  id = params[:id].to_i
  name = params[:name]
  description = params[:description]
  store = params[:store]
  db = SQLite3::Database.new('db/grocerylist.db')
  list = current_list
  # Only update if the item belongs to the current active list
  db.execute('UPDATE grocerylist SET name = ?, description = ?, store = ? WHERE id = ? AND list_id = ?', [name, description, store, id, list['id']])
  redirect('/grocerylist')
end

# Delete a specific grocery item from the current active list
post('/grocerylist/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/grocerylist.db")
  list = current_list
  # Only delete if the item belongs to the current active list
  db.execute("DELETE FROM grocerylist WHERE id = ? AND list_id = ?", [id, list['id']])
  redirect('/grocerylist')
end

# Delete an entire list and all its grocery items
post('/list/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/grocerylist.db')
  # Delete all items in the list first, then delete the list itself
  db.execute('DELETE FROM grocerylist WHERE list_id = ?', [id])
  db.execute('DELETE FROM lists WHERE id = ? AND user_id = ?', [id, current_user['id']])
  redirect('/grocerylist')
end

# Mark a specific grocery item as done (state = 1)
post('/grocerylist/:id/done') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/grocerylist.db")
  list = current_list
  db.execute("UPDATE grocerylist SET state = 1 WHERE id = ? AND list_id = ?", [id, list['id']])
  redirect('/grocerylist')
end

# Mark a specific grocery item as not done (state = 0)
post('/grocerylist/:id/undone') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/grocerylist.db")
  list = current_list
  db.execute("UPDATE grocerylist SET state = 0 WHERE id = ? AND list_id = ?", [id, list['id']])
  redirect('/grocerylist')
end

# Mark a completed list as active again (state = 0)
post('/list/:id/undone') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/grocerylist.db')
  # Prevent reactivating if another list is already active
  active = db.get_first_row('SELECT id FROM lists WHERE user_id = ? AND state = 0', [current_user['id']])
  if active
    redirect('/grocerylist?message=already_active')
  else
    db.execute('UPDATE lists SET state = 0 WHERE id = ? AND user_id = ?', [id, current_user['id']])
    redirect('/grocerylist?message=undone')
  end
end