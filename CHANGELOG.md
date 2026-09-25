# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The observer: a storeless mcl service that subscribes to mcl-bookclub's
  three fact topics, folds them into its own sqlite read model through the
  listener -> policy -> projection shape, and serves `get_scoreboard`.
- The scoreboard capability verifies the bookclub over the mesh
  (`mcl-bookclub/get_bookclub_by_id`) and reports the answer.
- The scoreboard groups by club and pins its verification call to the
  node that published each club's facts (the many-club model; the pin
  activates with mcl_om 0.28.2).
