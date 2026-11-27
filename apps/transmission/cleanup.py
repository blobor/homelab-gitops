"""Remove *arr torrents whose files are no longer in a library.

A torrent qualifies when no file of it has a second hardlink (the library copy
was deleted or replaced) and the seeding rule of its tracker is met. With
DRY_RUN=true it only reports what it would do.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request

RPC_URL = os.environ["RPC_URL"]
AUTH = base64.b64encode(f"{os.environ['RPC_USER']}:{os.environ['RPC_PASS']}".encode()).decode()
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() != "false"
SCOPE = tuple(d.rstrip("/") for d in os.environ["SCOPE_DIRS"].split(","))
# host suffix -> minimum seed hours, e.g. "tracker-a.example:72,tracker-b.example:80"
RULES = {h: float(v) for h, v in (r.split(":") for r in os.environ["TRACKER_RULES"].split(","))}
LAST_SEEDER_EXTRA_H = float(os.environ.get("LAST_SEEDER_EXTRA_DAYS", "14")) * 24
UNREGISTERED = ("no record found", "unregistered", "not registered", "torrent not found")

session_id = ""


def rpc(method, arguments):
    global session_id
    body = json.dumps({"method": method, "arguments": arguments}).encode()
    for _ in range(2):
        req = urllib.request.Request(RPC_URL, data=body, headers={
            "Authorization": f"Basic {AUTH}",
            "X-Transmission-Session-Id": session_id,
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                reply = json.load(resp)
        except urllib.error.HTTPError as e:
            if e.code == 409:
                session_id = e.headers.get("X-Transmission-Session-Id", "")
                continue
            raise
        if reply.get("result") != "success":
            raise RuntimeError(f"{method}: {reply.get('result')}")
        return reply["arguments"]
    raise RuntimeError(f"{method}: no session id")


def rule_for(hosts):
    for host in hosts:
        host = host.rsplit(":", 1)[0]               # trackerStats host is "name:port"
        for suffix, hours in RULES.items():
            if host == suffix or host.endswith("." + suffix):
                return suffix, hours
    return None, None


def library_links(t):
    """Number of files with a second hardlink, and files that are missing."""
    linked = missing = 0
    for f in t["files"]:
        try:
            if os.stat(os.path.join(t["downloadDir"], f["name"])).st_nlink > 1:
                linked += 1
        except FileNotFoundError:
            missing += 1
    return linked, missing


def decide(t):
    """Return (action, reason) for one torrent."""
    if t["downloadDir"].rstrip("/") not in SCOPE:
        return "OUT", "not an *arr download"
    if t["percentDone"] < 1:
        return "KEEP", "not complete"
    stats = t["trackerStats"]
    suffix, min_hours = rule_for([s["host"] for s in stats])
    if suffix is None:
        return "SKIP", "unknown tracker " + ",".join(sorted({s["host"] for s in stats}))
    linked, missing = library_links(t)
    if linked:
        return "KEEP", "in library"
    seeded = t["secondsSeeding"] / 3600
    seeders = max([s["seederCount"] for s in stats] + [-1])
    unregistered = any(m in s["lastAnnounceResult"].lower() for s in stats for m in UNREGISTERED)
    note = f"{suffix}, seeded {seeded:.0f}h, seeders {seeders}"
    note += ", UNREGISTERED" if unregistered else ""
    note += f", {missing} file(s) missing" if missing else ""
    if seeded < min_hours:
        return "WAIT", f"{note}: {min_hours - seeded:.0f}h to the {min_hours:.0f}h rule"
    if seeders < 2 and seeded < min_hours + LAST_SEEDER_EXTRA_H:
        return "WAIT", f"{note}: last seeder, {min_hours + LAST_SEEDER_EXTRA_H - seeded:.0f}h to go"
    return "DELETE", note


def main():
    fields = ["id", "hashString", "name", "downloadDir", "percentDone", "secondsSeeding",
              "sizeWhenDone", "files", "trackerStats"]
    torrents = rpc("torrent-get", {"fields": fields})["torrents"]
    counts, freed = {}, 0
    for t in sorted(torrents, key=lambda t: t["name"]):
        action, reason = decide(t)
        if action == "DELETE":
            linked, _ = library_links(t)          # the library may have changed since decide()
            if linked:
                action, reason = "KEEP", "in library"
            else:
                freed += t["sizeWhenDone"]
                if not DRY_RUN:
                    rpc("torrent-remove", {"ids": [t["hashString"]], "delete-local-data": True})
        counts[action] = counts.get(action, 0) + 1
        if action != "OUT":
            print(f"{action:6} {t['sizeWhenDone'] / 1e9:7.1f} GB  {t['name']}  ({reason})")
    mode = "dry run, nothing removed" if DRY_RUN else "removed"
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    print(f"--- {summary}; DELETE {freed / 1e9:.1f} GB ({mode})")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
