require_dependency 'guardian/category_guardian'
require_dependency 'guardian/ensure_magic'
require_dependency 'guardian/post_guardian'
require_dependency 'guardian/topic_guardian'
require_dependency 'guardian/user_guardian'
require_dependency 'guardian/post_revision_guardian'

# The guardian is responsible for confirming access to various site resources and operations
class Guardian
  include EnsureMagic
  include CategoryGuardian
  include PostGuardian
  include TopicGuardian
  include UserGuardian
  include PostRevisionGuardian

  class AnonymousUser
    def blank?; true; end
    def admin?; false; end
    def staff?; false; end
    def moderator?; false; end
    def approved?; false; end
    def secure_category_ids; []; end
    def topic_create_allowed_category_ids; []; end
    def has_trust_level?(level); false; end
    def email; nil; end
  end

  attr_accessor :can_see_emails

  def initialize(user=nil)
    @user = user.presence || AnonymousUser.new
  end

  def user
    @user.presence
  end
  alias :current_user :user

  def anonymous?
    !authenticated?
  end

  def authenticated?
    @user.present?
  end

  def is_admin?
    @user.admin?
  end

  def is_staff?
    @user.staff?
  end

  def is_user_basic?
    user.has_trust_level?(TrustLevel[1])
  end

  def is_user_member?
    user.has_trust_level?(TrustLevel[2])
  end

  def is_user_regular?
    user.has_trust_level?(TrustLevel[2])
  end

  def is_user_leader?
    user.has_trust_level?(TrustLevel[4])
  end

  def is_moderator?
    @user.moderator?
  end

  def is_developer?
    @user &&
    is_admin? &&
    (Rails.env.development? ||
      (
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(@user.email)
      )
    )
  end

  # Can the user see the object?
  def can_see?(obj)
    if obj
      see_method = method_name_for :see, obj
      return (see_method ? send(see_method, obj) : true)
    end
  end

  def can_create?(klass, parent=nil)
    return false unless authenticated? && klass

    # If no parent is provided, we look for a can_create_klass?
    # custom method.
    #
    # If a parent is provided, we look for a method called
    # can_create_klass_on_parent?
    target = klass.name.underscore
    if parent.present?
      return false unless can_see?(parent)
      target << "_on_#{parent.class.name.underscore}"
    end
    create_method = :"can_create_#{target}?"

    return send(create_method, parent) if respond_to?(create_method)

    true
  end

  # Can the user edit the obj
  def can_edit?(obj)
    can_do?(:edit, obj)
  end

  # Can we delete the object
  def can_delete?(obj)
    can_do?(:delete, obj)
  end

  def can_moderate_obj?(obj)
    case obj
    when Topic
      is_user_leader? || user.doth_moderate?(obj.category)
    when Category
      is_user_leader? || user.doth_moderate?(obj)
    else
      false
    end
  end

  def can_moderate?(obj)
    obj && authenticated? && (is_staff? || can_moderate_obj?(obj))
  end
  alias :can_move_posts? :can_moderate?
  alias :can_see_flags? :can_moderate?
  alias :can_send_activation_email? :can_moderate?

  def can_grant_badges?(_user)
    SiteSetting.enable_badges && is_staff?
  end

  def can_see_group?(group)
    group.present? && (is_admin? || group.visible?)
  end

  # Can we impersonate this user?
  def can_impersonate?(target)
    target &&

    # You must be an admin to impersonate
    is_admin? &&

    # You may not impersonate other admins unless you are a dev
    (!target.admin? || is_developer?)

    # Additionally, you may not impersonate yourself;
    # but the two tests for different admin statuses
    # make it impossible to be the same user.
  end

  # Can we approve it?
  def can_approve?(target)
    is_staff? && target && not(target.approved?)
  end

  def can_activate?(target)
    is_staff? && target && not(target.active?)
  end

  def can_suspend?(another_user)
    another_user && is_staff? && another_user.regular?
  end
  alias :can_deactivate? :can_suspend?

  def can_revoke_admin?(admin)
    can_administer_user?(admin) && admin.admin?
  end

  def can_grant_admin?(user)
    can_administer_user?(user) && not(user.admin?)
  end

  def can_revoke_moderation?(moderator)
    can_administer?(moderator) && moderator.moderator?
  end

  def can_grant_moderation?(user)
    can_administer?(user) && not(user.moderator?)
  end

  def can_grant_title?(user)
    user && is_staff?
  end

  def can_change_primary_group?(user)
    user && is_staff?
  end

  def can_change_trust_level?(user)
    user && is_staff?
  end

  # Support sites that have to approve users
  def can_access_forum?
    return true unless SiteSetting.must_approve_users?
    return false unless @user

    # Staff can't lock themselves out of a site
    return true if is_staff?

    @user.approved?
  end

  def can_see_invite_details?(user)
    is_me?(user)
  end

  def can_invite_to_forum?(groups=nil)
    authenticated? &&
    !SiteSetting.enable_sso &&
    SiteSetting.enable_local_logins &&
    (
      (!SiteSetting.must_approve_users? && is_user_member?) ||
      is_staff? ||
      user.moderating?
    ) &&
    (groups.blank? || is_admin?)
  end

  def can_invite_to?(object, group_ids=nil)
    can_invite = can_see?(object) && can_invite_to_forum? && ( group_ids.blank? || is_admin? )
    #TODO how should invite to PM work?
    can_invite = can_invite && ( !object.category.read_restricted || is_admin? ) if object.is_a?(Topic) && object.category
    can_invite
  end

  def can_bulk_invite_to_forum?(user)
    user.admin?
  end

  def can_create_disposable_invite?(user)
    user.admin?
  end

  def can_send_multiple_invites?(user)
    user.staff?
  end

  def can_see_private_messages?(user_id)
    is_admin? || (authenticated? && @user.id == user_id)
  end

  def can_send_private_message?(target)
    (target.is_a?(Group) || target.is_a?(User)) &&
    # User is authenticated
    authenticated? &&
    # Can't send message to yourself
    is_not_me?(target) &&
    # Have to be a basic level at least
    is_user_basic? &&
    # PMs are enabled
    (SiteSetting.enable_private_messages ||
      @user.username == SiteSetting.site_contact_username ||
      @user == Discourse.system_user) &&
    # Can't send PMs to suspended users
    (is_staff? || target.is_a?(Group) || !target.suspended?)
  end

  def can_see_emails?
    @can_see_emails
  end

  def can_upload_for_category?
    is_staff? || user.moderating?
  end

  private

  def is_my_own?(obj)

    unless anonymous?
      return obj.user_id == @user.id if obj.respond_to?(:user_id) && obj.user_id && @user.id
      return obj.user == @user if obj.respond_to?(:user)
    end

    false
  end

  def is_me?(other)
    other && authenticated? && other.is_a?(User) && @user == other
  end

  def is_not_me?(other)
    @user.blank? || !is_me?(other)
  end

  def can_administer?(obj)
    is_admin? && obj.present?
  end

  def can_administer_user?(other_user)
    can_administer?(other_user) && is_not_me?(other_user)
  end

  def method_name_for(action, obj)
    method_name = :"can_#{action}_#{obj.class.name.underscore}?"
    return method_name if respond_to?(method_name)
  end

  def can_do?(action, obj)
    if obj && authenticated?
      action_method = method_name_for action, obj
      return (action_method ? send(action_method, obj) : true)
    else
      false
    end
  end
end
