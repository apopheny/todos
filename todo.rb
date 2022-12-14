# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

def name_length_error
  session[:error] = 'Entry must be between 1 and 100 characters.'
end

def valid_list_name?(new_name, update: false)
  new_name = new_name.strip
  if !(1..100).cover?(new_name.size)
    name_length_error
  elsif session[:lists].any? { |list| list[:name] == new_name }
    handle_duplicates(new_name, update)
  else
    session[:success] =
      update ? 'The list has been updated.' : 'The list has been created.'
  end
end

def valid_todo_name?(new_name)
  if !(1..100).cover?(new_name.size)
    name_length_error
    false
  else
    session[:success] = "Todo item \"#{new_name}\" has been added."
    true
  end
end

def handle_duplicates(name, update)
  if update && session[:lists].none? { |list| list[:name] == name }
    session[:success] = 'List name saved'
  else
    session[:error] = 'List name already exists.'
  end
end

def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = 'The list specified was not found.'
  redirect '/lists'
end

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

helpers do
  def list_complete?(list)
    list[:todos].size >= 1 && list[:todos].all? { |todo| todo[:completed] }
  end

  def valid_string_int?(str)
    Integer(str, exception: false)
  end

  def list_class(list)
    list_complete?(list) ? 'complete' : ''
  end

  def todo_map_completed(todos)
    todos.sort_by! { |todo| todo[:completed] ? 1 : 0 }
  end

  def list_map_completed(list)
    list.sort_by! do |todo_list|
      list_complete?(todo_list) ? 1 : 0
    end
  end
end

before do
  session[:lists] ||= []
end

# view all lists by default
get '/' do
  redirect '/lists'
end

# view all lists
get '/lists' do
  @lists = session[:lists]
  list_map_completed(@lists)
  erb :lists
end

# submit new list
post '/lists' do
  list_name = params[:list_name].strip
  valid_list_name?(list_name)

  if session[:error]
    erb :new_list
  elsif session[:success]
    session[:lists] << { name: list_name, todos: [] }
    redirect '/lists'
  end
end

# access page to create a new list
get '/lists/new' do
  erb :new_list, layout: :layout
end

# retrieve list details
get '/lists/:id' do
  @list = load_list(params[:id].to_i)
  todo_map_completed(@list[:todos])
  erb :todo_items
end

# access page to edit a list
get '/lists/:id/edit' do
  load_list(params[:id].to_i)
  @list_id = params[:id].to_i
  @list_name = session[:lists][@list_id][:name]
  erb :edit_list
end

# submit list changes
post '/lists/:id/edit' do
  load_list(params[:id].to_i)
  list_id = params[:id].to_i
  list_name = params[:list_name]
  valid_list_name?(list_name, update: true)

  if session[:error]
    erb :edit_list
  elsif session[:success]
    session[:lists][list_id][:name] = list_name
    redirect "/lists/#{list_id}"
  end
end

# delete a list
post '/lists/:id/delete_list' do
  load_list(params[:id].to_i)
  id = params[:id].to_i
  name = session[:lists][id][:name]

  session[:lists].delete_at(id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = "List \"#{name}\" has been successfully deleted"
    redirect '/lists'
  end
end

# add a new todo item to a list
post '/lists/:list_id/add_item' do
  load_list(params[:list_id].to_i)
  id = params[:list_id].to_i
  @list = session[:lists][id]
  name = params[:todo].strip

  if valid_todo_name?(name)
    (session[:lists][id][:todos] << { name:, completed: false })
    redirect "/lists/#{id}"
  else
    erb :todo_items
  end
end

# delete a todo item
post '/lists/:list_id/todos/:item_id/delete' do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  item_id = params[:item_id].to_i
  list = session[:lists][list_id]
  item_name = session[:lists][list_id][:todos][item_id][:name]

  list[:todos].delete_at(item_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = "\"#{item_name}\" was successfully deleted."
    redirect "/lists/#{list_id}"
  end
end

# mark a todo item as completed
post '/lists/:list_id/todos/:item_id/checkbox' do
  load_list(params[:list_id].to_i)
  list_id = params[:list_id].to_i
  item_id = params[:item_id].to_i
  todo_item = session[:lists][list_id][:todos][item_id]
  todo_name = todo_item[:name]
  todo_completed = params[:completed] == 'true'

  todo_item[:completed] = todo_completed

  session[:success] = if todo_completed
                        "\"#{todo_name}\" is complete!"
                      else
                        "\"#{todo_name}\" is incomplete."
                      end

  redirect "/lists/#{list_id}"
end

# mark all todo items as completed
post '/lists/:list_id/todos/complete_all' do
  load_list(params[:list_id].to_i)
  list_id = valid_string_int?(params[:list_id])
  list = session[:lists][list_id]
  list_name = session[:lists][list_id][:name]

  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All items in \"#{list_name}\" are complete!"

  redirect "/lists/#{list_id}"
end
