# Discourse Automod Plugin

Adds staff-only `Accept` and `Decline` actions to the topic admin menu for supported application categories.

When a staff user clicks either action, the plugin:

- prepends or replaces a topic status prefix with `[Accepted]` or `[Declined]`
- posts the matching canned reply for the topic's application category
- locks the topic

Supported category scope:

- `Applications`
- `Join Us`
- `Applications > Graduations`
- `Applications > Apply For Honoured`
- `Applications > Apply For Heroic`
- `Applications > Become a Master Guardian`
- `Applications > Become a Grand Guardian`
