require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get('/') do
    query = params['q']
    db = SQLite3::Database.new('grocerylist.db')
    edit_id = params['edit_id']
    db.results_as_hash = true
    @grocerylist = db.execute('SELECT * FROM grocerylist')
    if query && !query.empty?
        @grocerylist = db.execute("SELECT * FROM grocerylist WHERE name LIKE ?", "%#{query}%")
    else
        @grocerylist = db.execute('SELECT * FROM grocerylist')
    end
    slim(:index)
end

post('/grocerylist') do
    new_crocery = params['new_grocery']
    description = params[:description]
    store = params[:store]
    db = SQLite3::Database.new('grocerylist.db')
    db.execute('INSERT INTO grocerylist (name, description, store) VALUES (?, ?, ?)', [new_crocery, description, store])
    redirect('/grocerylist')
end

post('/grocerylist/:id/update') do
        #plocka upp id, name och description
        id = params[:id].to_i
        name = params[:name]
        store = params[:store]
        #koppla till databasen
        db = SQLite3::Database.new("db/grocerylist.db")
        db.execute("UPDATE grocerylist SET name = ?, store = ? WHERE id = ?",[name,store,id])
        #slutligen, redirect till grocerylist sidan
        redirect('/grocerylist')
end

post('/grocerylist/:id/delete') do
    #hämta grocerylist
    id = params[:id].to_i
    #koppla till databasen
    db = SQLite3::Database.new("db/grocerylist.db")
    db.execute("DELETE FROM grocerylist WHERE id = ?", id)
    redirect('/grocerylist')
end

post('/grocerylist/:id/done') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/grocerylist.db")
    db.execute("UPDATE grocerylist SET state = 1 WHERE id = ?", id)
    redirect('/grocerylist')
    end

post('/grocerylist/:id/undone') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/grocerylist.db")
    db.execute("UPDATE grocerylist SET state = 0 WHERE id = ?", id)
    redirect('/grocerylist')
    end