# frozen_string_literal: true

module ::AutomodPlugin
  class ApplicationDecisionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_staff

    def create
      topic = Topic.find_by(id: params[:topic_id])
      return render_topic_not_found unless topic

      service = ApplicationTopicDecisionService.new(topic:, user: current_user)

      return render_unsupported_category unless service.supported?
      return render_topic_locked if topic.closed?

      result = service.call(params[:decision])

      render json: success_json.merge(result)
    rescue ApplicationTopicDecisionService::TopicAlreadyClosed
      render_topic_locked
    rescue Discourse::InvalidParameters
      render json: { errors: ["Invalid application decision."] }, status: :unprocessable_entity
    end

    private

    def render_topic_locked
      render json: { errors: ["This topic is already locked."] }, status: :unprocessable_entity
    end

    def render_topic_not_found
      render json: { errors: ["Topic not found."] }, status: :not_found
    end

    def render_unsupported_category
      render json: { errors: ["This topic is not in a supported application category."] },
             status: :unprocessable_entity
    end
  end
end
