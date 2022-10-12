# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

def valid_list_name?(new_name)
  if !(1..100).cover?(new_name.size)
    session[:error] = 'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name].downcase == new_name.downcase }
    session[:error] = 'List name already exists.'
  else
    session[:success] = 'The list has been created.'
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
