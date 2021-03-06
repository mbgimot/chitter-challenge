ENV["RACK_ENV"] ||= "development"

require 'sinatra/base'
require 'sinatra/flash'
require 'encrypted_cookie'
require_relative 'data_mapper_setup'
require 'pry'
require_relative 'helpers'

class Chitter < Sinatra::Base
  set :public_folder, Proc.new { File.join(root, 'static') }
  register Sinatra::Flash
  use Rack::MethodOverride
  use Rack::Session::EncryptedCookie,
    secret: 'ad51d97857116860975480f71544061c7b6212d63073ae587c463928c793c7c9'

  DataMapper::Logger.new($stdout, :debug)

  helpers Helpers

  before do
    Peep.count > 0 ? @peeps = Peep.all(order: :created_at.desc) : @peeps = nil
  end

  get '/' do
    erb(:index)
  end

  get '/users/new' do
    session[:email] ? @email_res = session[:email] : nil
    session[:name] ? @name_res = session[:name] : nil
    session[:username] ? @user_res = session[:username] : nil
    erb(:'users/new')
  end

  post '/users/new' do
    user = User.create(name: params[:name], username: params[:username], email: params[:email], password: params[:password], password_conf: params[:password_conf])
    if user.save
      session[:user_id] = user.id
      redirect '/peeps'
    else
      session[:email] = params[:email]
      session[:name] = params[:name]
      session[:username] = params[:username]
      flash[:errors] = user.errors.full_messages
      redirect '/users/new'
    end
  end

  post '/users/existing' do
    user = User.authenticate(params[:email], params[:password])
    if user
      session[:user_id] = user.id
      redirect '/peeps'
    else
      flash[:errors] = ['The email or password is incorrect.']
      redirect '/'
    end
  end

  delete '/sessions' do
    session[:user_id] = nil
    session[:email] = nil
    session[:name] = nil
    session[:username] = nil
    flash.keep[:notice] = "Goodbye!"
    redirect to '/'
  end

  get '/peeps' do
    if session[:user_id]
      erb(:'peeps/list')
    else
      flash[:notice] = "Please sign in to view this page"
      redirect '/'
    end
  end

  post '/peeps' do
    user = User.get(session[:user_id])
    peep = user.peeps.create(message: params[:message], name: user.name, username: user.username)
    redirect '/peeps'
  end

  run! if app_file == $0
end
