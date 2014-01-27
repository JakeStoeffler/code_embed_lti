require 'sinatra'
require 'sinatra/flash'
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
                                :editor_settings => params['editor_settings'],
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
      @tp.extend IMS::LTI::Extensions::Content::ToolProvider
    else
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      show_error "Consumer key wasn't recognized"
      return false
    end
  else
    show_error "No consumer key."
    return false
  end

  if !@tp.valid_request?(request)
    show_error "The OAuth signature was invalid."
    return false
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    show_error "Your request is too old."
    return false
  end

  # this isn't actually checking anything like it should, just want people
  # implementing real tools to be aware they need to check the nonce
  if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
    show_error "Why are you reusing the nonce?"
    return false
  end

  # save the launch parameters for use in later request
  #session['launch_params'] = @tp.to_params
end

# Render the requested placement
get '/placement/:placement_id' do
  logger.info "GET /placement/#{params['placement_id']}"
  return "Request is missing placement_id" unless params['placement_id']
  placement = Placement.first(:placement_id => params['placement_id'])
  return "Placement with id \"#{params['placement_id']}\" does not exist" unless placement
  erb :code_embed, :locals => { :content => placement.content,
                                :editor_settings => placement.editor_settings,
                                :hide_settings => true,
                                :placement_id => params['placement_id'] }
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  logger.info "POST /lti_tool"
  return erb :error unless authorize!
  return "missing resource_link_id in request: #{params}" unless params['resource_link_id']
  placement_id = params['resource_link_id'] + (params['tool_consumer_instance_guid'] or "")
  logger.info "placement_id: #{placement_id}"
  placement = Placement.first(:placement_id => placement_id)
  # If placement already exists, set up and display an editor with stored =
  # contents and settings; else, let user create new editor placement.
  if placement
    content = placement.content
    editor_settings = placement.editor_settings
    hide_settings = true
  else
    content = "// Welcome to Code Embed!\n" + # default content
      "// To get started, select the language you want to code in and pick a theme!\n" +
      "// Feel free to play around with the other settings as well.\n" +
      "// When you're done, just click 'Embed this code!' and the code will be embedded in your LMS exactly as it appears here!"
    editor_settings = nil
    hide_settings = false
    # use a cookie-based session to remember placement permission
    flash["can_save_" + placement_id] = true
  end
  @tp.lti_msg = "Thanks for using Code Embed!"
  
  return_url = nil
  # If this if for a rich content editor, set up the return url
  if @tp.is_content_for?(:embed) && @tp.accepts_iframe?
    url = "https" + "://" + request.host_with_port + "/placement/" + placement_id
    return_url = @tp.iframe_content_return_url(url, 600, 400, "Code Embed")
  end
  # code_embed will set things up accordingly
  erb :code_embed, :locals => { :content => content,
                                :editor_settings => editor_settings,
                                :hide_settings => hide_settings,
                                :placement_id => placement_id,
                                :return_url => return_url }
end

# Handle POST requests to the endpoint "/save_editor"
post "/save_editor" do
  logger.info "POST /save_editor"
  if flash["can_save_" + params['placement_id']]
    Placement.create(:placement_id => params['placement_id'],
                     :content => params['content'],
                     :editor_settings => params['editor_settings'])
    if params['return_url'] && !params['return_url'].empty?
      redirect_url = params['return_url']
    else
      redirect_url = "https" + "://" + request.host_with_port + "/placement/" + params['placement_id']
    end
    response = { :success => true, :redirect_url => redirect_url }
  else
    response = { :success => false }
  end
  response.to_json
end

get '/tool_config.xml' do
  host = "https" + "://" + request.host_with_port
  url = host + "/lti_tool"
  icon_url = host + "/images/icon.png"
  tc = IMS::LTI::ToolConfig.new(:title => "Code Embed LTI Tool", :launch_url => url)
  tc.extend IMS::LTI::Extensions::Canvas::ToolConfig
  tc.description = "Code Embed allows users to embed a code editor in their LMS per standard LTI."
  tc.canvas_icon_url!(icon_url)
  rce_props = {
    :enabled => true,
    :text => "Code Embed",
    :selection_width => 850,
    :selection_height => 600,
    :icon_url => icon_url
  }
  #tc.canvas_editor_button!(rce_props)
  #tc.canvas_resource_selection!(rce_props)

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
  property :editor_settings, String, :length => 1024
end

DataMapper::Logger.new($stdout, :debug)
env = ENV['RACK_ENV'] || settings.environment
# ENV["DATABASE_URL"] is for Heroku, sqlite3 is for local
DataMapper.setup(:default, (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/#{env}.sqlite3"))
DataMapper.auto_upgrade!
DataMapper.finalize