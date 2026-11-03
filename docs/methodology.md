# OnRecord Methodology

*Last updated: [date]*

## 1. Purpose
OnRecord is a free, open-source, nonpartisan tool that connects what elected officials say with what they do. It reports public records. It does not endorse candidates, parties, or positions, and it does not judge intent or motive.

## 2. Scope (v1)
- **Who:** current members of the U.S. Congress.
- **Topics:** mental health, sleep disorders, and epilepsy legislation first, with more topics added over time.
- **Not yet covered:** state legislatures, executive agencies, and local government.

## 3. Data sources
Every record links to its primary source and shows the date it was retrieved.

| Data | Source |
|---|---|
| Members, committees, bills, sponsorships | Congress.gov API |
| Roll-call votes | Congress.gov, cross-checked against House Clerk and Senate records |
| Campaign finance | Federal Election Commission (FEC) API |
| Statements | Official transcripts, floor speeches, hearings, press releases, and campaign materials |

Data is refreshed on a regular schedule. If a source is delayed or unavailable, OnRecord shows the last retrieved data with its date.

## 4. Definitions

**Vote:** a member's recorded position on a roll call, as published by official sources.

**Sponsorship:** a bill a member introduced or co-sponsored, as listed on Congress.gov.

**Progress:** the official status of a bill (introduced, in committee, passed one chamber, passed both, signed, failed). OnRecord reports status only and does not rate effectiveness.

**Stance:** a documented public statement of position by a member, with the exact quote, date, topic, and source link.

**Reversal (flagged conflict):** a stance followed by a later vote or action that directly conflicts with it. Both items are shown side by side with sources. If the connection is unclear, it is labeled "unclear" or not flagged.

## 5. Campaign finance
- Amounts come directly from FEC filings.
- OnRecord shows totals, share of total funds raised, and comparison to peers.
- All donors, PACs, and industries are treated by the same rules. No group is singled out or exempted.
- A donation is a recorded fact. It does not prove influence or agreement.

## 6. Neutrality rules
1. Every member gets the same profile fields, regardless of party, chamber, or topic.
2. OnRecord reports records, not labels. It shows votes, amounts, and quotes, and it does not characterize intent.
3. Topics and filters are applied the same way to every member.
4. Opinions are not presented as facts.

## 7. Verification
- Stances are entered or confirmed by a human before they are published.
- Any item extracted by software or AI is labeled **unverified** until reviewed.
- Every published claim must link to a primary source.

## 8. Corrections
If you find an error, open an issue on GitHub with a link to the correct source. Corrections are reviewed, and accepted fixes are recorded in a public changelog.

## 9. Limitations
- OnRecord cannot explain why a member voted a certain way.
- Statement coverage is incomplete and grows over time.
- Government data can be delayed, revised, or contain errors.
- Absence of a flagged conflict does not mean none exists.

## 10. Disclaimer
OnRecord reports public records and does not provide legal or political advice. Always verify against the primary source.

## 11. Contact
Open an issue on this repository.