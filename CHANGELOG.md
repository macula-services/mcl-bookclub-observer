# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The verification pin is now the ONLY path: the observer builds against
  mcl_om 0.28.2, so `call_capability/5` with the advertiser pin is called
  directly and the `function_exported/3` gate is gone (dead code -- the
  deployed observer was the one production user of the unpinned fallback).
  With the Phoenix twin live as a second club under the same org, an
  unpinned call reaches whichever node the DHT lists first and every club
  verified "no"; the pin is what makes the many-club scoreboard correct.
  The scoreboard tests now stub the /5 arity and assert the pin equals the
  fact's publisher.

### Added

- The observer: a storeless mcl service that subscribes to mcl-bookclub's
  three fact topics, folds them into its own sqlite read model through the
  listener -> policy -> projection shape, and serves `get_scoreboard`.
- The scoreboard capability verifies the bookclub over the mesh
  (`mcl-bookclub/get_bookclub_by_id`) and reports the answer.
- The scoreboard groups by club and pins its verification call to the
  node that published each club's facts (the many-club model; the pin
  activates with mcl_om 0.28.2).
