class User < ActiveRecord::Base
  has_many :identities
  has_many :bts_accounts
  has_many :dvs_accounts
  has_many :widgets

  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :confirmable, :omniauthable, :omniauth_providers => [:facebook, :twitter, :linkedin, :google_oauth2, :github, :reddit, :weibo, :qq]

  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update
  validates :name, presence: true
  validates :password, presence: true, length: {minimum: 6}, on: :create
  validates :password, length: {minimum: 6}, allow_blank: true, on: :update
  validates_confirmation_of :password

  def self.find_for_oauth(auth, signed_in_resource, uid)
    identity = Identity.find_for_oauth(auth)
    user = signed_in_resource || identity.user
    user = User.where(:email => auth.info.email).first if user.nil? && auth.info.email

    # Create the user if it's a new registration
    if user.nil?
      user = User.create!(
          name: auth.info.name || auth.extra.raw_info.name,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          password: Devise.friendly_token[0, 20],
          uid: uid
      )
    end

    # Associate the identity with the user if needed
    identity.update_attribute(:user, user) unless identity.user == user

    user
  end

  def register_account(account_name, account_key, referrer=nil)
    logger.debug "---------> registering account #{account_name}, key: #{account_key}"
    sleep(0.4) # this is to prevent bots abuse

    account = self.bts_accounts.where(name: account_name).first
    AccountRegistrator.new(self, account).register(account_name, account_key, referrer)
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  # skipping devise confirmation to allow our own in after_sign_in_path_for
  def confirmation_required?
    false
  end

  def subscribe(subscription_status)
    return unless self.email

    gb = Gibbon::API.new
    list_id = Rails.application.config.bitshares.mailchimp['list_id']

    begin
      result = if subscription_status
                 gb.lists.subscribe({:id => list_id, :email => {:email => self.email}, :merge_vars => {:FNAME => self.name}, :double_optin => false})
               else
                 gb.lists.unsubscribe(:id => list_id, :email => {:email => self.email}, :delete_member => true, :send_notify => true)
               end
    rescue Gibbon::MailChimpError => e
      result = e
    end

    result
  end

end
