# Next-Train
A lightweight iOS app and widget for real-time SL (Stockholms Lokaltrafik) departures. Pick your station, filter by transport type and
  direction, and see when your next ride leaves — right from your home screen.

  Features

  - Real-time departures from any SL station using the open SL Transport API (no API key required)
  - Transport type filtering — toggle between tunnelbana, bus, spårvagn, pendeltåg and båt
  - Direction filtering — pick a via station to only see departures heading your way (e.g. "Via Centralen" from Gärdet only shows southbound
  trains)
  - Home screen widget — glance at your next departures without opening the app
  - Pull to refresh — swipe down to get updated times
  - Searchable station picker — find any station across the SL network
  - Persisted preferences — your station, direction and transport filters are saved between sessions

  How it works

  The app fetches live departure data from the SL Transport API via Trafiklab. Direction filtering works by matching journey IDs across
  stations — if the same journey departs from both your origin and your via station, and the via station comes after, the departure is shown.

  Tech

  - SwiftUI
  - WidgetKit
  - SL Transport REST API
  - No third-party dependencies
