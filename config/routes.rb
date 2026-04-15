# frozen_string_literal: true

AutomodPlugin::Engine.routes.draw do
  post "/application-topics/:topic_id/:decision" => "application_decisions#create"
end

Discourse::Application.routes.draw { mount ::AutomodPlugin::Engine, at: "/automod" }
