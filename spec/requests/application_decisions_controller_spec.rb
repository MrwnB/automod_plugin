# frozen_string_literal: true

RSpec.describe AutomodPlugin::ApplicationDecisionsController do
  before { enable_current_plugin }

  fab!(:admin)
  fab!(:member, :user)
  fab!(:applications_category) { Fabricate(:category, name: "Applications") }
  fab!(:graduations_category) do
    Fabricate(:category, name: "Graduations", parent_category: applications_category)
  end
  fab!(:honoured_category) do
    Fabricate(:category, name: "Apply For Honoured", parent_category: applications_category)
  end
  fab!(:heroic_category) do
    Fabricate(:category, name: "Apply For Heroic", parent_category: applications_category)
  end
  fab!(:master_category) do
    Fabricate(:category, name: "Become a Master Guardian", parent_category: applications_category)
  end
  fab!(:grand_category) do
    Fabricate(:category, name: "Become a Grand Guardian", parent_category: applications_category)
  end

  def perform_decision(topic, decision)
    post "/automod/application-topics/#{topic.id}/#{decision}.json"
  end

  shared_examples "applies a decision and locks the topic" do |
    category_name:,
    decision:,
    initial_title:,
    expected_title:,
    expected_message:
  |
    it "posts the #{decision} reply for #{category_name} topics" do
      topic = Fabricate(:topic_with_op, title: initial_title, category: public_send(category_name))

      sign_in(admin)

      perform_decision(topic, decision)

      expect(response.status).to eq(200)
      expect(topic.reload.title).to eq(expected_title)
      expect(topic.closed?).to eq(true)
      expect(topic.posts.order(:post_number).last.raw).to eq(expected_message)
    end
  end

  describe "POST /automod/application-topics/:topic_id/:decision" do
    include_examples "applies a decision and locks the topic",
                     category_name: :applications_category,
                     decision: :accept,
                     initial_title: "My application for review",
                     expected_title: "[Accepted] My application for review",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::BASE_APPLICATION_ACCEPTED

    include_examples "applies a decision and locks the topic",
                     category_name: :graduations_category,
                     decision: :decline,
                     initial_title: "[Accepted] Ready for graduation review",
                     expected_title: "[Declined] Ready for graduation review",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::GRADUATION_DECLINED

    include_examples "applies a decision and locks the topic",
                     category_name: :honoured_category,
                     decision: :accept,
                     initial_title: "Honoured Guardian application",
                     expected_title: "[Accepted] Honoured Guardian application",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::HONOURED_GUARDIAN_ACCEPTED

    include_examples "applies a decision and locks the topic",
                     category_name: :heroic_category,
                     decision: :decline,
                     initial_title: "Heroic Guardian application",
                     expected_title: "[Declined] Heroic Guardian application",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::HEROIC_GUARDIAN_DECLINED

    include_examples "applies a decision and locks the topic",
                     category_name: :master_category,
                     decision: :accept,
                     initial_title: "Master Guardian application",
                     expected_title: "[Accepted] Master Guardian application",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::MASTER_GUARDIAN_ACCEPTED

    include_examples "applies a decision and locks the topic",
                     category_name: :grand_category,
                     decision: :decline,
                     initial_title: "Grand Guardian application",
                     expected_title: "[Declined] Grand Guardian application",
                     expected_message:
                       AutomodPlugin::ApplicationTopicDecisionService::GRAND_GUARDIAN_DECLINED

    it "rejects unsupported categories" do
      unsupported_category = Fabricate(:category, name: "General")
      topic = Fabricate(
        :topic_with_op,
        title: "General discussion topic",
        category: unsupported_category,
      )

      sign_in(admin)

      perform_decision(topic, :accept)

      expect(response.status).to eq(422)
      expect(topic.reload.title).to eq("General discussion topic")
      expect(topic.closed?).to eq(false)
      expect(topic.posts.count).to eq(1)
    end

    it "rejects non-staff users" do
      topic = Fabricate(
        :topic_with_op,
        title: "My application for review",
        category: applications_category,
      )

      sign_in(member)

      perform_decision(topic, :accept)

      expect(response.status).to eq(403)
      expect(topic.reload.title).to eq("My application for review")
      expect(topic.closed?).to eq(false)
      expect(topic.posts.count).to eq(1)
    end

    it "rejects topics that are already closed" do
      topic = Fabricate(
        :topic_with_op,
        title: "Already reviewed application",
        category: applications_category,
        closed: true,
      )

      sign_in(admin)

      perform_decision(topic, :decline)

      expect(response.status).to eq(422)
      expect(topic.reload.title).to eq("Already reviewed application")
      expect(topic.closed?).to eq(true)
      expect(topic.posts.count).to eq(1)
    end
  end
end
