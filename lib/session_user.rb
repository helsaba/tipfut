class SessionUser
  attr_reader :name
  attr_reader :uid
  attr_reader :token
  attr_reader :secret

  def initialize(session)
    @name   = session[:name]
    @uid    = session[:user_id]
    @token  = session[:oauth_token]
    @secret = session[:oauth_token_secret]
  end
end
