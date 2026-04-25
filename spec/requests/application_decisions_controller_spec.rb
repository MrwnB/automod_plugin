# frozen_string_literal: true

RSpec.describe AutomodPlugin::ApplicationDecisionsController do
  before { enable_current_plugin }

  fab!(:admin)
  fab!(:member, :user)
  fab!(:applications_category) { Fabricate(:category, name: "Applications") }
  fab!(:join_us_category) { Fabricate(:category, name: "Join Us") }
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

  def decision_reply_for(topic)
    topic
      .posts
      .where(post_type: Post.types[:regular])
      .where("post_number > 1")
      .order(:post_number)
      .last
  end

  describe "POST /automod/application-topics/:topic_id/:decision" do
    [
      {
        category_name: :join_us_category,
        decision: :accept,
        initial_title: "Example join application",
        expected_title: "[Accepted] Example join application",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::JOIN_APPLICATION_ACCEPTED,
      },
      {
        category_name: :join_us_category,
        decision: :decline,
        initial_title: "Example join application",
        expected_title: "[Declined] Example join application",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::JOIN_APPLICATION_DECLINED,
      },
      {
        category_name: :graduations_category,
        decision: :decline,
        initial_title: "[Accepted] Ready for graduation review",
        expected_title: "[Declined] Ready for graduation review",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::GRADUATION_DECLINED,
      },
      {
        category_name: :honoured_category,
        decision: :accept,
        initial_title: "Honoured Guardian application",
        expected_title: "[Accepted] Honoured Guardian application",
        expected_message:
          AutomodPlugin::ApplicationTopicDecisionService::HONOURED_GUARDIAN_ACCEPTED,
      },
      {
        category_name: :heroic_category,
        decision: :decline,
        initial_title: "Heroic Guardian application",
        expected_title: "[Declined] Heroic Guardian application",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::HEROIC_GUARDIAN_DECLINED,
      },
      {
        category_name: :master_category,
        decision: :accept,
        initial_title: "Master Guardian application",
        expected_title: "[Accepted] Master Guardian application",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::MASTER_GUARDIAN_ACCEPTED,
      },
      {
        category_name: :grand_category,
        decision: :decline,
        initial_title: "Grand Guardian application",
        expected_title: "[Declined] Grand Guardian application",
        expected_message: AutomodPlugin::ApplicationTopicDecisionService::GRAND_GUARDIAN_DECLINED,
      },
    ].each do |example|
      it "posts the #{example[:decision]} reply for #{example[:category_name]} topics" do
        topic =
          Fabricate(
            :topic_with_op,
            title: example[:initial_title],
            category: public_send(example[:category_name]),
          )

        sign_in(admin)

        perform_decision(topic, example[:decision])

        topic.reload
        reply = decision_reply_for(topic)

        expect(response.status).to eq(200)
        expect(topic.title).to eq(example[:expected_title])
        expect(topic.closed?).to eq(true)
        expect(reply).to be_present
        expect(reply.raw).to eq(example[:expected_message])
      end
    end

    [
      {
        category_name: :join_us_category,
        decision: :accept,
        setting_name: :automod_plugin_join_us_accept_message,
      },
      {
        category_name: :join_us_category,
        decision: :decline,
        setting_name: :automod_plugin_join_us_decline_message,
      },
      {
        category_name: :graduations_category,
        decision: :accept,
        setting_name: :automod_plugin_graduations_accept_message,
      },
      {
        category_name: :graduations_category,
        decision: :decline,
        setting_name: :automod_plugin_graduations_decline_message,
      },
      {
        category_name: :honoured_category,
        decision: :accept,
        setting_name: :automod_plugin_honoured_guardian_accept_message,
      },
      {
        category_name: :honoured_category,
        decision: :decline,
        setting_name: :automod_plugin_honoured_guardian_decline_message,
      },
      {
        category_name: :heroic_category,
        decision: :accept,
        setting_name: :automod_plugin_heroic_guardian_accept_message,
      },
      {
        category_name: :heroic_category,
        decision: :decline,
        setting_name: :automod_plugin_heroic_guardian_decline_message,
      },
      {
        category_name: :master_category,
        decision: :accept,
        setting_name: :automod_plugin_master_guardian_accept_message,
      },
      {
        category_name: :master_category,
        decision: :decline,
        setting_name: :automod_plugin_master_guardian_decline_message,
      },
      {
        category_name: :grand_category,
        decision: :accept,
        setting_name: :automod_plugin_grand_guardian_accept_message,
      },
      {
        category_name: :grand_category,
        decision: :decline,
        setting_name: :automod_plugin_grand_guardian_decline_message,
      },
    ].each do |example|
      it "uses the configured #{example[:decision]} reply for #{example[:category_name]} topics" do
        expected_message =
          "Custom #{example[:decision]} reply for #{example[:category_name]}\n\nWith markdown."
        SiteSetting.public_send("#{example[:setting_name]}=", expected_message)
        topic =
          Fabricate(
            :topic_with_op,
            title: "Application message override",
            category: public_send(example[:category_name]),
          )

        sign_in(admin)

        perform_decision(topic, example[:decision])

        expect(response.status).to eq(200)
        expect(decision_reply_for(topic).raw).to eq(expected_message)
      end
    end

    it "rejects unsupported categories" do
      unsupported_category = Fabricate(:category, name: "General")
      topic =
        Fabricate(:topic_with_op, title: "General discussion topic", category: unsupported_category)

      sign_in(admin)

      perform_decision(topic, :accept)

      expect(response.status).to eq(422)
      expect(topic.reload.title).to eq("General discussion topic")
      expect(topic.closed?).to eq(false)
      expect(topic.posts.count).to eq(1)
    end

    it "rejects the parent applications category" do
      topic =
        Fabricate(
          :topic_with_op,
          title: "Topic in parent applications category",
          category: applications_category,
        )

      sign_in(admin)

      perform_decision(topic, :accept)

      expect(response.status).to eq(422)
      expect(topic.reload.title).to eq("Topic in parent applications category")
      expect(topic.closed?).to eq(false)
      expect(topic.posts.count).to eq(1)
    end

    it "rejects non-staff users" do
      topic =
        Fabricate(:topic_with_op, title: "My application for review", category: join_us_category)

      sign_in(member)

      perform_decision(topic, :accept)

      expect(response.status).to eq(403)
      expect(topic.reload.title).to eq("My application for review")
      expect(topic.closed?).to eq(false)
      expect(topic.posts.count).to eq(1)
    end

    it "rejects topics that are already closed" do
      topic =
        Fabricate(
          :topic_with_op,
          title: "Already reviewed application",
          category: join_us_category,
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
