# frozen_string_literal: true

module ::AutomodPlugin
  class ApplicationDecisionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_staff

    def create
      topic = Topic.find_by(id: params[:topic_id])
      if !topic
        return render json: { errors: ["Topic not found."] }, status: :not_found
      end

      service = ApplicationTopicDecisionService.new(topic:, user: current_user)

      if !service.supported?
        return(
          render json: {
                   errors: ["This topic is not in a supported application category."],
                 },
                 status: :unprocessable_entity
        )
      end

      if topic.closed?
        return render json: { errors: ["This topic is already locked."] }, status: :unprocessable_entity
      end

      result = service.call(params[:decision])

      render json: success_json.merge(result)
    rescue ApplicationTopicDecisionService::TopicAlreadyClosed
      render json: { errors: ["This topic is already locked."] }, status: :unprocessable_entity
    rescue Discourse::InvalidParameters
      render json: { errors: ["Invalid application decision."] }, status: :unprocessable_entity
    end
  end
end
