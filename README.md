
# OnRecord

A free, open-source, nonpartisan record of what elected officials say and what they do.

## What it does
OnRecord connects statements, votes, sponsored bills, and campaign finance for members of Congress, so anyone can check whether actions match words. Every item links to a primary source.

## Principles
- **Nonpartisan:** the same data and the same rules for every member, party, and topic.
- **Sourced:** every claim cites a public record (roll call, FEC filing, transcript, bill text).
- **Records, not labels:** we show votes, amounts, and quotes. We don't characterize intent.
- **Transparent:** the methodology is public, and corrections are logged.

## Current status
Early development. v1 scope: current members of Congress, with a focus on mental health, sleep, and epilepsy legislation.

## Planned features
- [ ] Member profiles (votes, sponsorships, committees)
- [ ] Campaign finance data (FEC)
- [ ] Documented stances with sources
- [ ] Flagged conflicts between stated positions and later votes
- [ ] Bill progress tracking
- [ ] Topic pages and search

## Data sources
Congress.gov API, FEC API, and other public government records. See `docs/methodology.md`.

## Tech
Python, SQLite, static site generation. Hosted free.

## Contributing
Corrections and contributions are welcome. If you find an error, open an issue with a link to the correct source.

## Disclaimer
OnRecord reports public records and does not endorse any candidate, party, or position. Always verify against the primary source.

