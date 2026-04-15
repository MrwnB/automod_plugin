import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { isSupportedApplicationCategory } from "discourse/lib/application-topic-category";
import { i18n } from "discourse-i18n";

async function applyDecision(api, topic, decision) {
  const toasts = api.container.lookup("service:toasts");

  try {
    await ajax(`/automod/application-topics/${topic.id}/${decision}`, {
      type: "POST",
    });

    toasts.success({
      duration: "long",
      data: {
        message: i18n(`automod_plugin.${decision}.success`),
      },
    });

    globalThis.setTimeout(() => globalThis.location.reload(), 300);
  } catch (error) {
    const errorMessage =
      error.jqXHR?.responseJSON?.errors?.[0] ||
      i18n("automod_plugin.errors.generic");

    toasts.error({
      duration: "long",
      data: {
        message: errorMessage,
      },
    });
  }
}

function buildDecisionButton(api, topic, decision, icon) {
  return {
    action: () => applyDecision(api, topic, decision),
    icon,
    className: `automod-plugin-${decision}-application`,
    label: `automod_plugin.${decision}.label`,
  };
}

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.automod_plugin_enabled) {
    return;
  }

  api.addTopicAdminMenuButton((topic) => {
    const currentUser = api.getCurrentUser();

    if (
      !currentUser?.staff ||
      topic.closed ||
      !isSupportedApplicationCategory(topic)
    ) {
      return;
    }

    return buildDecisionButton(api, topic, "accept", "check");
  });

  api.addTopicAdminMenuButton((topic) => {
    const currentUser = api.getCurrentUser();

    if (
      !currentUser?.staff ||
      topic.closed ||
      !isSupportedApplicationCategory(topic)
    ) {
      return;
    }

    return buildDecisionButton(api, topic, "decline", "xmark");
  });
});
