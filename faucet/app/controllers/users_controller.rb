class UsersController < ApplicationController
  before_action :authenticate_user!
  skip_before_filter :authenticate_user!, only: [:finish_signup, :referral_login]

  def profile
    @user = current_user
    @referral = ReferralCode.new
  end

  def bitshares_account
    @reg_status = nil
    @subscription_status = current_user.newsletter_subscribed

    if current_user.pending_intention and current_user.pending_intention[:pending_registration]
      reg = current_user.pending_intention[:pending_registration]
      do_register(reg['account_name'], reg['account_key'], reg['owner_key'])
      current_user.set_pending_registration(nil)
    end
    if params[:account]
      do_register(params[:account][:name], params[:account][:key], nil)
    end
  end

  def finish_signup
    @hide_sign_in = true
    user = User.find(params[:id])

    if user.email_verified? && user.confirmed_at
      redirect_to root_path, notice: 'You have already confirmed your email.'
    else
      if request.patch? && params[:user] && params[:user][:email]
        if user.update_attribute(:email, params[:user][:email])
          sign_in(user, :bypass => true)
          redirect_to profile_path, notice: "We've sent you a confirmation link."
        end
      end
    end
  end

  def subscribe
    new_status = !current_user.newsletter_subscribed
    status = params[:status] == new_status ? params[:status] : new_status
    subscription = current_user.subscribe(status)

    if subscription.is_a?(Hash)
      current_user.update_attribute(:newsletter_subscribed, status)
      render json: {res: render_to_string('_subscribe', layout: false, locals: {status: status})}
    else
      render json: {res: subscription.to_s}
    end
  end

  def referral_login
    # todo: move to ReferralRegistrator
    if params[:login_hash] && params[:login_hash] == ReferralCode.find_by(sent_to: params[:email]).login_hash
      generated_password = Devise.friendly_token.first(8)
      user = User.create!(name: params[:email], email: params[:email], password: generated_password)
      sign_in(:user, user)
      redirect_to after_referral_login_path
    else
      redirect_to root_path, alert: 'Wrong login hash'
    end
  end

  private

  def do_register(name, key, owner_key)
    @reg_status = current_user.register_account(name, key, owner_key, cookies[:_ref_account])
    if @reg_status[:error]
      flash[:alert] = "We were unable to register account '#{name}' - #{@reg_status[:error]}"
      @account = OpenStruct.new(name: name, key: key, owner_key: owner_key)
    end
  end
end
