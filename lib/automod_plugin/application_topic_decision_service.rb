# frozen_string_literal: true

module ::AutomodPlugin
  class ApplicationTopicDecisionService
    class TopicAlreadyClosed < StandardError
    end

    APPLICATIONS_CATEGORY_NAME = "applications"
    SUPPORTED_SUBCATEGORIES = {
      "graduations" => :graduations,
      "apply for honoured" => :honoured_guardian,
      "apply for heroic" => :heroic_guardian,
      "become a master guardian" => :master_guardian,
      "become a grand guardian" => :grand_guardian,
    }.freeze
    STATUS_PREFIXES = {
      accept: "[Accepted]",
      decline: "[Declined]",
    }.freeze
    STATUS_PREFIX_REGEX = /\A\[(accepted|declined)\]\s*/i

    BASE_APPLICATION_ACCEPTED = <<~TEXT.rstrip
      Congratulations, you have been accepted into our community!

      You are now an Initiate Guardian and have 3 weeks to attend 3 events, reply to at least 10 posts and graduate.


      Here are some useful links:

          Graduations - you have 3 weeks to post your graduation form. You can post it before you reach all the requirements and fill them in later.
          Unread content - gives you the latest posts. Keeps you up to date.
          Important Announcements - check frequently for major updates.
          Calendar - all events are here, listed in your own time zone. You can even host your own.
          Discord - keep notifications on for #osrs_announcements. We'll never spam you.
          Recruitment Tips - help expand our clan
          New to PvM or PvP? Check out the #pvm-help and #pvp-help channels on Discord.
          Use #pvm-help on Discord to assign yourself roles to get pings for groups
          Use !pvp to get pings for PK trips.


      Important: Please do not talk about PvP events in our Clan Chat. Use Discord.


      I and the staff are happy to answer any further questions.

      Welcome to our clan!


      P.S. Got two minutes spare? Take this optional survey to help us with our recruitment process.

      P.P.S. Are you a Discord Nitro subscriber or have a lot of IRL money? 🤑 Consider giving us your Nitro Server Boost. See #nitro-boost on Discord for info.
    TEXT

    BASE_APPLICATION_DECLINED = <<~TEXT.rstrip
      [center]
      Your application has been declined as you did not request your application review from an Application Manager or Leader.

      Feel free to apply again if you feel you can be active.
      [/center]
    TEXT

    GRADUATION_ACCEPTED = <<~TEXT.rstrip
      Congratulations! Your graduation has been accepted.


      We now suggest that you work towards the next rank, Honoured Guardian.

      This is a more prestigious rank and gives you benefits such as the ability to apply for vacant staff positions and the ability to work towards the bronze and silver star ranks in CC.

      Achieving Honoured Guardian also allows you the option to apply to join our dedicated elite PvP/PvM unit, the Master Guardians/Grand Guardians

      Find out how to do that by viewing this board. You can post your application before you reach all the requirements and edit them in later.


      We hope you will continue the level of activity, dedication and commitment you have already displayed for the remainder of your career with us.


      All the best!
    TEXT

    GRADUATION_DECLINED = <<~TEXT.rstrip
      This graduation has been declined.

      A reason may or may not be provided above.

      The applicant usually cannot see a declined graduation so we don't always post a reason.
    TEXT

    HONOURED_GUARDIAN_ACCEPTED = <<~TEXT.rstrip
      Congratulations! Your application for Honoured Guardian has been accepted.


      You have reached a prestigious rank within WG and we thank you for all your effort and dedication so far.


      You can now see this forum where we occasionally seek new staff members.


      Don't stop there though, there are still three more ranks that normal members can achieve: Heroic, High then Elite.

      These are not awarded by applying but chosen by staff every so often.


      Thank you for your continued passion and commitment.

      All the best!
    TEXT

    HONOURED_GUARDIAN_DECLINED = <<~TEXT.rstrip
      This application for Honoured has been declined.

      A reason may or may not be provided above.

      The applicant usually cannot see a declined application so we don't always post a reason.
    TEXT

    HEROIC_GUARDIAN_ACCEPTED = <<~TEXT.rstrip
      Congratulations! Your application for Heroic Guardian has been accepted.


      You have reached a prestigious rank within WG and we thank you for all your effort and dedication so far.


      You can now see this forum where we occasionally seek new staff members.


      Don't stop there though, there are still two more ranks that normal members can achieve: High then Elite.

      These are not awarded by applying but chosen by staff every so often.


      Thank you for your continued passion and commitment.

      All the best!
    TEXT

    HEROIC_GUARDIAN_DECLINED = <<~TEXT.rstrip
      This application for Heroic Guardian has been declined.

      A reason may or may not be provided above.

      The applicant usually cannot see a declined application so we don't always post a reason.
    TEXT

    MASTER_GUARDIAN_ACCEPTED = <<~TEXT.rstrip
      Congratulations! Your application for Master Guardian has been accepted.


      Your journey as a member of our dedicated elite PvP unit begins now.

      Please carefully read through all the pinned topics in this forum. This is your new forum to discuss PvP with fellow Master Guardians.

      You also now have access to #master-guardians on Discord.


      Thank you for your contributions to PvP so far and we look forward to your development as a Master Guardian.

      All the best!
    TEXT

    MASTER_GUARDIAN_DECLINED = <<~TEXT.rstrip
      This application for Master Guardian has been declined.

      A reason may or may not be provided above.

      The applicant usually cannot see a declined application so we don't always post a reason.
    TEXT

    GRAND_GUARDIAN_ACCEPTED = <<~TEXT.rstrip
      Congratulations! Your application for Grand Guardian has been accepted.


      Your journey as a member of our esteemed PvM unit begins now.


      Thank you for your contributions to PvM so far and we look forward to your development as a Grand Guardian.

      All the best!
    TEXT

    GRAND_GUARDIAN_DECLINED = <<~TEXT.rstrip
      This application for Grand Guardian has been declined.

      A reason may or may not be provided above.

      The applicant usually cannot see a declined application so we don't always post a reason.
    TEXT

    DECISION_MESSAGES = {
      base_application: {
        accept: BASE_APPLICATION_ACCEPTED,
        decline: BASE_APPLICATION_DECLINED,
      },
      graduations: {
        accept: GRADUATION_ACCEPTED,
        decline: GRADUATION_DECLINED,
      },
      honoured_guardian: {
        accept: HONOURED_GUARDIAN_ACCEPTED,
        decline: HONOURED_GUARDIAN_DECLINED,
      },
      heroic_guardian: {
        accept: HEROIC_GUARDIAN_ACCEPTED,
        decline: HEROIC_GUARDIAN_DECLINED,
      },
      master_guardian: {
        accept: MASTER_GUARDIAN_ACCEPTED,
        decline: MASTER_GUARDIAN_DECLINED,
      },
      grand_guardian: {
        accept: GRAND_GUARDIAN_ACCEPTED,
        decline: GRAND_GUARDIAN_DECLINED,
      },
    }.freeze

    def initialize(topic:, user:)
      @topic = topic
      @user = user
    end

    def supported?
      category_key.present?
    end

    def call(decision)
      decision_key = normalize_decision(decision)
      raise Discourse::InvalidParameters.new(:decision) if decision_key.blank?
      raise Discourse::InvalidAccess.new if !@user&.staff?
      raise Discourse::InvalidAccess.new if !supported?
      raise TopicAlreadyClosed if @topic.closed?

      @topic.with_lock do
        raise TopicAlreadyClosed if @topic.closed?

        revise_title!(prefixed_title(decision_key))
        create_reply!(message_for(decision_key))
        @topic.update_status("closed", true, @user)
      end

      {
        topic_title: @topic.reload.title,
        closed: @topic.closed?,
      }
    end

    private

    def category_key
      return @category_key if defined?(@category_key)

      category = @topic.category
      return @category_key = nil if category.blank?

      category_name = normalize_name(category.name)
      parent_name = normalize_name(category.parent_category&.name)

      @category_key =
        if parent_name == APPLICATIONS_CATEGORY_NAME
          SUPPORTED_SUBCATEGORIES[category_name]
        elsif parent_name.blank? && category_name == APPLICATIONS_CATEGORY_NAME
          :base_application
        end
    end

    def create_reply!(raw)
      PostCreator.create!(@user, topic_id: @topic.id, raw:)
    end

    def message_for(decision_key)
      DECISION_MESSAGES.fetch(category_key).fetch(decision_key)
    end

    def normalize_decision(decision)
      case decision.to_s.strip.downcase
      when "accept"
        :accept
      when "decline"
        :decline
      end
    end

    def normalize_name(value)
      value.to_s.strip.downcase
    end

    def prefixed_title(decision_key)
      title_without_status = @topic.title.sub(STATUS_PREFIX_REGEX, "").strip

      [STATUS_PREFIXES.fetch(decision_key), title_without_status]
        .reject(&:blank?)
        .join(" ")
    end

    def revise_title!(new_title)
      revisor = PostRevisor.new(@topic.first_post, @topic)
      result = revisor.revise!(@user, { title: new_title })

      raise Discourse::InvalidParameters.new(:title) if !result
    end
  end
end
