class TipController < BaseController
  before_action :login_required

  def index
    begin
      @amount = Float(params[:amount])
    rescue ArgumentError, TypeError
      @amount = ""
    end

    @coinaddr = params[:coinaddr]
    @balance = 10.0
    @tax = 0.5

    @magic = (0...10).map{ ('A'..'Z').to_a[rand(26)] }.join
    session[:withdraw_magic] = @magic
  end

  private
  def twitter_client
    Twitter::REST::Client.new(
      :oauth_token        => @current_user.token,
      :oauth_token_secret => @current_user.secret
    )
  end
end
