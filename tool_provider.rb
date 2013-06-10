require 'sinatra'
require 'ims/lti'
require 'dm-core'
require 'dm-migrations'
require 'json'
# must include the oauth proxy object
require 'oauth/request_proxy/rack_request'

enable :sessions
set :protection, :except => :frame_options

get '/' do
  erb :index
end

# Simply display an editor with the contents passed to us.
# No need for auth since we aren't doing any db stuff.
post '/' do
  erb :index unless params['content']
  erb :code_embed, :locals => { :content => params['content'],
                               :hide_settings => true }
end

# the consumer keys/secrets
$oauth_creds = {"test" => "secret", "testing" => "supersecret"}

def show_error(message)
  @message = message
  erb :error
end

def authorize!
  if key = params['oauth_consumer_key']
    if secret = $oauth_creds[key]
      @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    else
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      return show_error "Consumer key wasn't recognized"
    end
  else
    return show_error "No consumer key"
  end

  if !@tp.valid_request?(request)
    return show_error "The OAuth signature was invalid"
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    return show_error "Your request is too old."
  end

  # this isn't actually checking anything like it should, just want people
  # implementing real tools to be aware they need to check the nonce
  if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
    return show_error "Why are you reusing the nonce?"
  end

  # save the launch parameters for use in later request
  session['launch_params'] = @tp.to_params

  @username = @tp.username("Dude")
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  authorize!
  return "missing required values: #{params}" unless params['resource_link_id'] && params['tool_consumer_instance_guid']
  placement_id = params['resource_link_id'] + 
      params['tool_consumer_instance_guid']
  placement = Placement.first(:placement_id => placement_id)
  # If placement already exists, set up and display an editor with stored =
  # contents and settings; else, let user create new editor placement.
  if placement
    content = placement.content
    hide_settings = true
  else
    content = "Enter your code here..." # default content
    hide_settings = false
    # use a cookie-based session to remember placement permission
    session["can_save_" + placement_id] = true
  end
  @tp.lti_msg = "Thanks for using Code Embed!"
  # code_embed will set things up accordingly
  erb :code_embed, :locals => { :content => content,
                                :hide_settings => hide_settings,
                                :placement_id => placement_id }
end

# Handle POST requests to the endpoint "/save_video"
post "/save_editor" do
  if session["can_save_" + params['placement_id']]
    Placement.create(:placement_id => params['placement_id'],
                     :content => params['content'])
    url = request.scheme + "://" + request.host_with_port + "/?redirect=1"
    response = { :success => true, :redirect_url => url }
  else
    response = { :success => false }
  end
  response.to_json
end

get '/tool_config.xml' do
  host = request.scheme + "://" + request.host_with_port
  url = host + "/lti_tool"
  tc = IMS::LTI::ToolConfig.new(:title => "Example Sinatra Tool Provider", :launch_url => url)
  tc.description = "This example LTI Tool Provider supports LIS Outcome pass-back."

  headers 'Content-Type' => 'text/xml'
  tc.to_xml(:indent => 2)
end

def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
  # some kind of caching solution or something to keep a short-term memory of used nonces
  false
end

# Data model to remember placements
class Placement
  include DataMapper::Resource
  property :id, Serial
  property :placement_id, String, :length => 1024
  property :content, Text
end

DataMapper::Logger.new($stdout, :debug)
env = ENV['RACK_ENV'] || settings.environment
# ENV["DATABASE_URL"] is for Heroku, sqlite3 is for local
DataMapper.setup(:default, (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/#{env}.sqlite3"))
DataMapper.auto_upgrade!
DataMapper.finalize