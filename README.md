# VoidRecruit

A quality-first raid-recruiting companion for World of Warcraft (Retail, 12.0.x). It docks a
panel onto the **Guild & Communities** window and turns it into a recruiting cockpit — vet
prospects, broadcast a recruitment message, and track everyone you talk to.

Built for small **core teams that recruit for quality, not numbers.** No `/who` spam — it's an
*evaluation* tool.

## Install

Not on CurseForge (yet) — manual install:

1. Copy the `VoidRecruit` folder into
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Restart WoW (or, at character select, open **AddOns** and enable **VoidRecruit**).
3. In-game, type `/voidrecruit` to confirm it loaded, then press **J** (Guild & Communities).
   The panel docks to the side.

It's fully self-contained (VoidLib is embedded) — no other addons are *required*.

## Recommended companions

- **RaiderIO** (strongly recommended) — provides the M+ score, best timed key, and raid
  progress on the vetting card for basically any player. Without it those rows are blank.
- **VoidScout** (optional) — if you run it, the card also shows VoidScout's behavioral data
  (Util Score, interrupt %) for players you've logged. Without it, those rows stay blank and
  RaiderIO carries the vetting.

## Using it

The panel has three tabs:

- **Recruit** — write a recruitment message (`{guild}` / `{me}` auto-fill), tick which chat
  channels to post to, and **Broadcast** (throttled so you never flood). Or **Whisper target**
  to send it to whoever you have targeted.
- **Vet** — target any player to see their card: RaiderIO M+/key/raid, VoidScout data, gear,
  realm, and a **raid-overlap tag** showing your raid time in *their* local clock (green = good
  for them, red = their daytime/sleep). Buttons to **Vote** (Yes/No/?), **Track**, start a
  **Trial** (14-day clock), two-tier **Blacklist** (with reasons), **Link main** (vet an alt by
  its main), capture a **Timezone**, and copy **Raider.IO / Logs / Armory** links.
- **Contacts** — your pipeline: everyone you've tracked/messaged, with status, votes, trial age,
  blacklist flag, and timezone. Left-click cycles status, right-click removes.

**First thing to set:** on the Vet card, click the raid-overlap tag (top-right) and set *your*
raid time, e.g. `8pm ET`. Everything's computed relative to that.

## Permissions

Guild actions (invite/promote/note) mirror WoW's own rank permissions exactly — buttons only do
what your rank allows, and it never touches the protected guild-control APIs. Officers see the
full UI; rank-and-file see a read-only view.

## Notes

- Realm timezones are the realm's *home* zone (a baseline). For a player who lives in a different
  zone than their server, set their actual timezone with the **Timezone** button — it overrides.
- Officer sync (shared pipeline across officers) and the trial scorecard are planned.

Version 0.1.0 · Author: bughatti
