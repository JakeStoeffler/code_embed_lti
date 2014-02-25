require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/multi_route'
require 'sinatra/flash'
require 'ims/lti'
require 'dm-core'
require 'dm-migrations'
require 'json'
# must include the oauth proxy object
require 'oauth/request_proxy/rack_request'

enable :sessions
set :protection, :except => :frame_options

helpers do
  def versioned_css(css)
    "/css/#{css}?" + File.mtime(File.join("public", "css", css)).to_i.to_s
  end
  def versioned_js(js)
    "/js/#{js}?" + File.mtime(File.join("public", "js", js)).to_i.to_s
  end
end

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
  # Let's not worry about auth for now... just make any key/secret work.
#   if key = params['oauth_consumer_key']
#     if secret = $oauth_creds[key]
#       @tp = IMS::LTI::ToolProvider.new(key, secret, params)
#       @tp.extend IMS::LTI::Extensions::Content::ToolProvider
#     else
#       @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
#       @tp.lti_msg = "Your consumer didn't use a recognized key."
#       @tp.lti_errorlog = "You did it wrong!"
#       show_error "Consumer key wasn't recognized"
#       return false
#     end
#   else
#     show_error "No consumer key."
#     return false
#   end
# 
#   if !@tp.valid_request?(request)
#     show_error "The OAuth signature was invalid."
#     return false
#   end
# 
#   if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
#     show_error "Your request is too old."
#     return false
#   end
# 
#   # this isn't actually checking anything like it should, just want people
#   # implementing real tools to be aware they need to check the nonce
#   if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
#     show_error "Why are you reusing the nonce?"
#     return false
#   end

  # save the launch parameters for use in later request
  #session['launch_params'] = @tp.to_params
  
  @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
  @tp.extend IMS::LTI::Extensions::Content::ToolProvider
  @tp.extend IMS::LTI::Extensions::OutcomeData::ToolProvider
  return true
end

# Render the requested placement
route :get, :post, '/placement/:placement_id' do
  logger.info "GET /placement/#{params['placement_id']}"
  return "Request is missing placement_id" unless params['placement_id']
  placement = Placement.first(:placement_id => params['placement_id'])
  return "Placement with id \"#{params['placement_id']}\" does not exist" unless placement
  erb :code_embed, :locals => { :content => placement.content,
                                :editor_settings => placement.editor_settings,
                                :hide_settings => true,
                                :for_outcome => false,
                                :placement_id => params['placement_id'] }
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  logger.info "POST /lti_tool"
  return erb :error unless authorize!
  return "missing resource_link_id in request: #{params}" unless params['resource_link_id']
  
  old_placement_id = params['resource_link_id'] + (params['tool_consumer_instance_guid'] or "")
  for_outcome = false
  
  placement = Placement.first(:placement_id => old_placement_id)
  if placement
    # Placement already exists
    # Set up and display an editor with stored contents and settings.
    logger.info "existing placement: #{old_placement_id}"
    content = placement.content
    editor_settings = placement.editor_settings
    hide_settings = true
    placement_id = old_placement_id
    
  else
    # New placement
    # Set up the placement_id and return_url
    base_url = "https" + "://" + request.host_with_port + "/placement/"
    # make a random placement_id since Canvas doesn't give us unique ids with the editor button launch
    placement_id = (0...20).map { ((0..9).to_a+('a'..'z').to_a+('A'..'Z').to_a)[rand(62)] }.join
    url = base_url + placement_id
    
    if @tp.is_content_for?(:homework) && @tp.accepts_url?
      # Placement in a homework submission
      logger.info "Launch for homework - url"
      return_url = @tp.url_content_return_url(url, "Code Embed submission")
      
    elsif @tp.accepts_iframe?
      # Placement in rich text editor
      logger.info "Launch for iframe"
      return_url = @tp.iframe_content_return_url(url, 600, 400, "Code Embed")
      
    elsif @tp.accepts_lti_launch_url?
      # Placement in "new" module
      logger.info "Launch for lti_launch_url - new module"
      return_url = @tp.lti_launch_content_return_url(url, "Code Embed")
    elsif @tp.outcome_service? && @tp.accepts_outcome_url?
      # Placement as outcome response
      logger.info "Launch for outcome response"
      for_outcome = true
      # Save params to build outcome request upon save
      flash[:launch_params] = params.to_json.to_s
      return_url = @tp.build_return_url
    else
      # Placement in "old" module
      logger.info "Launch for old module"
      placement_id = old_placement_id
      return_url = base_url + placement_id
    end
    
    logger.info "new placement: #{placement_id}"
    content = "// Welcome to Code Embed!\n" + # default content
      "// To get started, select the language you want to code in and pick a theme!\n" +
      "// Feel free to play around with the other settings as well.\n" +
      "// When you're done, just click 'Embed this code!' and the code will be embedded in your LMS exactly as it appears here!"
    editor_settings = cookies[:editor_settings] or nil # get settings from cookie if exists
    hide_settings = false
    # use a cookie-based session to remember placement permission
    flash["can_save_" + placement_id] = true
  end
  
  @tp.lti_msg = "Thanks for using Code Embed!"
  
  # code_embed will set things up accordingly
  erb :code_embed, :locals => { :content => content,
                                :editor_settings => editor_settings,
                                :hide_settings => hide_settings,
                                :placement_id => placement_id,
                                :for_outcome => for_outcome,
                                :return_url => return_url }
end

# Handle POST requests to the endpoint "/save_editor"
post "/save_editor" do
  logger.info "POST /save_editor"
  return { :success => false }.to_json unless flash["can_save_" + params['placement_id']]
  
  Placement.create(:placement_id => params['placement_id'],
                   :content => params['content'],
                   :editor_settings => params['editor_settings'])
  
  # Save the editor_settings in a cookie so user doesn't have to re-enter them
  cookies[:editor_settings] = params['editor_settings']
  if params['return_url'] && !params['return_url'].empty?
    redirect_url = params['return_url']
  else
    redirect_url = "https" + "://" + request.host_with_port + "/placement/" + params['placement_id']
  end
  
  response = { :success => true, :redirect_url => redirect_url }
  
  if params['for_outcome'] == "true"
    logger.info "Saving for outcome"
    # Set up an new tool provider using the original params we were given
    # so the outcome gets sent to the right place (a different save could
    # have happened since the last tool launch).
    orig_params = JSON.parse(flash[:launch_params])
    outcome_tp = IMS::LTI::ToolProvider.new("key", "secret", orig_params)
    outcome_tp.extend IMS::LTI::Extensions::Content::ToolProvider
    outcome_tp.extend IMS::LTI::Extensions::OutcomeData::ToolProvider
    # Make an outcome request that includes the url for this placement
    score = 1.0
    url = "https://#{request.host_with_port}/placement/#{params['placement_id']}"
    outcome_res = outcome_tp.post_replace_result_with_data!(score, "url" => url)
    response[:success] = outcome_res.success?
    logger.info outcome_res.generate_response_xml
    outcome_req = outcome_tp.last_outcome_request
    logger.info ("Req score: " + outcome_req.score.to_s)
    logger.info ("Req URL: " + outcome_req.outcome_url.to_s)
    logger.info ("Req text: " + outcome_req.outcome_text.to_s)
    logger.info outcome_tp.post_read_result!.generate_response_xml
  end
  
  response.to_json
end

get '/tool_config.xml' do
  host = "https" + "://" + request.host_with_port
  url = host + "/lti_tool"
  icon_url = host + "/images/icon.png"
  # Generate the config
  tc = IMS::LTI::ToolConfig.new(:title => "Code Embed LTI Tool", :launch_url => url)
  tc.extend IMS::LTI::Extensions::Canvas::ToolConfig
  tc.description = "Code Embed is a tool that lets you embed a code editor in an LMS such as Canvas, Blackboard, or Moodle."
  rce_props = {
    :enabled => true,
    :selection_height => 650,
    :selection_width => 850
  }
  tc.canvas_domain! request.host_with_port
  tc.canvas_editor_button! rce_props
  tc.canvas_homework_submission! rce_props
  tc.canvas_icon_url! icon_url
  tc.canvas_privacy_public!
  tc.canvas_resource_selection! rce_props
  tc.canvas_text! "Code Embed"
  
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