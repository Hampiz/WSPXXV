require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

helpers do
  def current_user
    return nil unless session[:user_id]
    db = SQLite3::Database.new('db/grocerylist.db')
    db.results_as_hash = true
    user = db.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
    user
  end

  def current_list
    return nil unless logged_in?
    db = SQLite3::Database.new('db/grocerylist.db')
    db.results_as_hash = true
    list = db.get_first_row('SELECT * FROM lists WHERE user_id = ? AND state = 0 ORDER BY id DESC LIMIT 1', current_user['id'])
    unless list
      now = Time.now.strftime('%Y-%m-%d')
      db.execute('INSERT INTO lists (user_id, name, state, created_at) VALUES (?, ?, 0, ?)', [current_user['id'], 'Min inköpslista', now])
      list = db.get_first_row('SELECT * FROM lists WHERE id = ?', db.last_insert_row_id)
    end
    list
  end

  def logged_in?
    !!current_user
  end
end

before '/grocerylist*' do
  unless logged_in?
    redirect('/login')
  end
end

get('/') do  
    slim(:index)
end

get('/login') do
  slim(:login)
end

get('/register') do
  slim(:register)
end

post('/login') do
  username = params["username"]
  pwd = params["pwd"]
  db = SQLite3::Database.new("db/grocerylist.db")
  db.results_as_hash = true
  result=db.execute("SELECT id,password_hash FROM users WHERE username=?", username)
  if result.empty?
    @error = 'Invalid username or password'
    slim(:login)
  else
    user_id = result.first["id"]
    pwd_digest = result.first["password_hash"]
    if BCrypt::Password.new(pwd_digest) == pwd
      session[:user_id] = user_id
      redirect('/grocerylist')
    else
      @error = 'Invalid username or password'
      slim(:login)
    end
  end
end


post('/register') do
  username = params["username"]
  pwd = params["pwd"]
  pwd_confirm = params["pwd_confirm"]

  db = SQLite3::Database.new("db/grocerylist.db")
  result = db.execute("SELECT id FROM users WHERE username=?", username)

  if result.empty?
    if pwd == pwd_confirm
      pwd_digest = BCrypt::Password.create(pwd)
      db.execute("INSERT INTO users(username, password_hash) VALUES(?,?)", [username, pwd_digest])
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

post('/logout') do
  session.clear
  redirect('/')
end

get('/grocerylist') do
    query = params['q']
    db = SQLite3::Database.new('db/grocerylist.db')
    edit_id = params[:edit_id]
    db.results_as_hash = true
    @current_list = current_list
    @done_lists = db.execute('SELECT * FROM lists WHERE user_id = ? AND state = 1 ORDER BY id DESC', [current_user['id']])
  if query && !query.empty?
        @grocerylist = db.execute("SELECT * FROM grocerylist WHERE list_id = ? AND name LIKE ?", [@current_list['id'], "%#{query}%"])
  else
        @grocerylist = db.execute('SELECT * FROM grocerylist WHERE list_id = ?', [@current_list['id']])
    end
    slim(:grocerylist)
end

get('/grocerylist/:list_id') do
  db = SQLite3::Database.new('db/grocerylist.db')
  db.results_as_hash = true
  list = db.get_first_row('SELECT * FROM lists WHERE id = ? AND user_id = ?', [params[:list_id].to_i, current_user['id']])
  redirect('/grocerylist') unless list
  @current_list = list
  @grocerylist = db.execute('SELECT * FROM grocerylist WHERE list_id = ?', [list['id']])
  @done_lists = db.execute('SELECT * FROM lists WHERE user_id = ? AND state = 1 ORDER BY id DESC', [current_user['id']])
  slim(:grocerylist)
end

post('/list/new') do
  name = params['list_name']
  name = 'Ny inköpslista' if name.nil? || name.strip.empty?
  db = SQLite3::Database.new('db/grocerylist.db')
  created_at = Time.now.strftime('%Y-%m-%d')
  db.execute('INSERT INTO lists (user_id, name, state, created_at) VALUES (?, ?, 0, ?)', [current_user['id'], name, created_at])
  redirect('/grocerylist?message=created')
end

post('/list/done') do
  list = current_list
  return redirect('/grocerylist') unless list
  db = SQLite3::Database.new('db/grocerylist.db')
  db.execute('UPDATE lists SET state = 1 WHERE id = ? AND user_id = ?', [list['id'], current_user['id']])
  redirect('/grocerylist?message=done')
end

post('/grocerylist') do
    new_grocery = params['new_grocery']
    description = params[:description]
    store = params[:store]
    db = SQLite3::Database.new('db/grocerylist.db')
  created_at = Time.now.strftime('%Y-%m-%d')
    list = current_list
    db.execute('INSERT INTO grocerylist (list_id, name, description, store, state, created_at) VALUES (?, ?, ?, ?, ?, ?)', [list['id'], new_grocery, description, store, 0, created_at])
    redirect('/grocerylist')
end

post('/grocerylist/:id/update') do
    # plocka upp id, name, description och store
    id = params[:id].to_i
    name = params[:name]
    description = params[:description]
    store = params[:store]
    # koppla till databasen
    db = SQLite3::Database.new('db/grocerylist.db')
      list = current_list
      db.execute('UPDATE grocerylist SET name = ?, description = ?, store = ? WHERE id = ? AND list_id = ?', [name, description, store, id, list['id']])
    # slutligen, redirect till grocerylist sidan
    redirect('/grocerylist')
end

post('/grocerylist/:id/delete') do
    #hämta grocerylist
    id = params[:id].to_i
    #koppla till databasen
    db = SQLite3::Database.new("db/grocerylist.db")
      list = current_list
      db.execute("DELETE FROM grocerylist WHERE id = ? AND list_id = ?", [id, list['id']])
    redirect('/grocerylist')
end

post('/grocerylist/:id/done') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/grocerylist.db")
      list = current_list
      db.execute("UPDATE grocerylist SET state = 1 WHERE id = ? AND list_id = ?", [id, list['id']])
    redirect('/grocerylist')
    end


post('/grocerylist/:id/undone') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/grocerylist.db")
      list = current_list
      db.execute("UPDATE grocerylist SET state = 0 WHERE id = ? AND list_id = ?", [id, list['id']])
    redirect('/grocerylist')
end