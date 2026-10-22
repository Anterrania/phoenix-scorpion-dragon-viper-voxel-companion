# Governance (LIFE-5)

Status: built and headless-tested (`Governance`, `data/living/governance.json`). It is a game system only. **Fictional nations only**:
names of real countries and parties are refused, and there is no real-world political content.

- **Nations:** founding needs creator tier (`Tiers.can group_create`). Government types: monarchy, constitutional monarchy, republic, council,
  direct democracy, guild charter, technocracy.
- **Territory:** a leader claims an Estate region or parcel, and also needs `Tiers.can(actor, "land", region)` (owner or estate manager). Estate stays the
  land authority. Frontier org claims (feature/spacesim-parity Territory) sit inside nation regions.
- **Citizenship:** granted by the leader. Citizens can renounce.
- **Laws:** per-territory toggles for mining, build_permit, pvp, trade, open_borders, quarantine, vaccination_required, hunting and curfew_quiet.
  pvp also needs Estate `allow_damage`: laws can restrict, never unlock.
- **Elections:** one vote per citizen. The winner of a leader election becomes leader.
- **Embassies:** request and accept, mutual. **Borders:** open / visa / citizens_only / closed. Quarantine and vaccination laws are checked in `can_cross`.
- **Taxes:** an in-game hook (sales / land / mining, max 30%) in civic credits. **Aethel Coin taxes: LEGAL REVIEW REQUIRED** (`AETHEL_TAX_ACTIVE = false`).
- **Owner exemption:** an unlocked owner ignores laws and borders. A locked owner does not.
