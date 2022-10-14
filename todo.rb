# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

def valid_list_name?(new_name, update: false)
  new_name = new_name.strip
  if !(1..100).cover?(new_name.size)
    session[:error] = 'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == new_name }
    handle_duplicates(new_name, update)
  else
    session[:success] = update ? 'The list has been updated.' : 'The list has been created.'
  end
end

def handle_duplicates(name, update)
  if update && session[:lists].none? { |list| list[:name] == name }
    session[:success] = 'List name saved'
  else
    session[:error] = 'List name already exists.'
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
  erb :lists
end

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

get '/lists/new' do
  erb :new_list, layout: :layout
end

get '/lists/:id' do
  @list = session[:lists][params[:id].to_i]
  erb :todo_items
end

get '/lists/:id/edit' do
  erb :edit_list
end

post '/lists/:id/edit' do
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
