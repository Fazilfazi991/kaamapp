# KAAM analytics rules

- A **visitor** is a browser carrying KAAM's first-party anonymous UUID. It is not a person and is not derived from an IP address.
- A **session** is a session-storage UUID. A new one is created after approximately 30 minutes without tracked activity.
- A **page view** is one asynchronous route-change event. The tracker keeps the last pathname in memory so React renders and route prefetches do not create additional views.
- A **registration conversion** is a linked candidate or employer account divided by unique tracked visitors in the selected period.
- The first observed UTM/referrer/landing-page values are preserved as first-touch attribution. Later sessions update only the latest-touch fields.
- Browser bot user agents and browsers that request Do Not Track are skipped. Analytics is best-effort: failure never blocks navigation, authentication, onboarding, or payment.
- Country/city are optional and intentionally absent unless a privacy-safe, reliable server integration is added. Raw IP addresses are never collected or displayed.
