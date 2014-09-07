class HomeController < BaseController
  before_action :login_required, only: []

  def index
    if current_user
      render 'index'
    else
      render 'readme'
    end
  end

  private
  def twitter_client
    Twitter::REST::Client.new(
      :oauth_token        => @current_user.token,
      :oauth_token_secret => @current_user.secret
    )
  end
end
