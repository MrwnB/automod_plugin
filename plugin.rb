# frozen_string_literal: true

# name: automod_plugin
# about: Staff accept and decline actions for application topics
# version: 0.1
# authors: GoreDef
# url: https://www.wildernessguardians.com
# required_version: 2.7.0

enabled_site_setting :automod_plugin_enabled

module ::AutomodPlugin
  PLUGIN_NAME = "automod_plugin"
end

require_relative "lib/automod_plugin/engine"

after_initialize do
  # Plugin boot is handled by the engine, controller, and frontend initializers.
end
