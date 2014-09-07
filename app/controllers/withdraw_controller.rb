class WithdrawController < BaseController
  before_action :login_required

  def index
    if params[:withdraw_magic] != session[:withdraw_magic]
      redirect_to action: 'invalid_call'
      return
    end

    @coinaddr = params[:coinaddr]
    @amount   = params[:amount]

    begin
      Float(@amount)
    rescue ArgumentError, TypeError
      redirect_to action: 'invalid_call'
      return
    end

  end

  def invalid_call
  end
end
