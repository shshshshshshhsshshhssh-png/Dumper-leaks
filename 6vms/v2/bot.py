import asyncio
import os
import re
import time
import pathlib
import subprocess
from datetime import datetime

import aiohttp
import discord

# ------------------------------------------------------------------ config
TOKEN      = "ur bot token"
CHANNEL_ID = 1511155261770043422
PREFIX     = ".l"
TIMEOUT    = 100            # seconds per script before it gets skipped
MAX_DL     = 8 * 1024 * 1024  # max bytes to pull from a raw link

ROOT = pathlib.Path(__file__).resolve().parent
LUTE = ROOT / "lute.exe"
TMP  = ROOT / "bot_tmp"
TMP.mkdir(exist_ok=True)

ACCENT  = 0x5865F2
GOOD    = 0x57F287
BAD     = 0xED4245
WARN    = 0xFEE75C

URL_RE  = re.compile(r"https?://[^\s<>()]+", re.I)
TIME_RE = re.compile(r"Finished processing in ([\d.]+) seconds", re.I)
OK_EXT  = (".lua", ".txt")

# ------------------------------------------------------------------ engine
def _kill_tree(pid: int):
    subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)],
                   capture_output=True)

def _dump_blocking(in_rel: str, out_rel: str):
    """Run the exact same pipeline as the CLI. Returns (ok, reason, took)."""
    env = os.environ.copy()
    env["HOOKOP_BIN"] = str(LUTE)

    started = time.perf_counter()
    proc = subprocess.Popen(
        ["lune", "run", "main.luau", in_rel, f"out={out_rel}"],
        cwd=str(ROOT), env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
    )
    try:
        log, _ = proc.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        _kill_tree(proc.pid)
        try: proc.communicate(timeout=5)
        except Exception: pass
        return False, "timeout", TIMEOUT

    took = time.perf_counter() - started
    m = TIME_RE.search(log or "")
    if m:
        took = float(m.group(1))

    out_path = ROOT / out_rel
    if proc.returncode != 0 or not out_path.exists():
        tail = (log or "").strip().splitlines()[-1:] or ["unknown error"]
        return False, tail[-1][:300], took

    head = out_path.read_text(errors="ignore")[:6]
    if head.startswith("--err"):
        reason = out_path.read_text(errors="ignore")[5:].strip()
        return False, reason[:300] or "engine error", took

    return True, None, took

# ------------------------------------------------------------------ bot
intents = discord.Intents.default()
intents.message_content = True
bot = discord.Client(intents=intents)
queue: "asyncio.Queue[dict]" = asyncio.Queue()
http: aiohttp.ClientSession | None = None


async def react(msg, emoji):
    try: await msg.add_reaction(emoji)
    except discord.HTTPException: pass

async def unreact(msg, emoji):
    try: await msg.remove_reaction(emoji, bot.user)
    except discord.HTTPException: pass


async def gather_jobs(message) -> list[dict]:
    """Pull every dumpable script out of a message (and the one it replies to)."""
    sources = [message]
    if message.reference and message.reference.resolved:
        sources.append(message.reference.resolved)

    jobs, seen = [], set()
    for src in sources:
        for att in getattr(src, "attachments", []):
            if att.filename.lower().endswith(OK_EXT) and att.id not in seen:
                seen.add(att.id)
                jobs.append({"name": att.filename, "att": att, "url": None})

        text = getattr(src, "content", "") or ""
        for url in URL_RE.findall(text):
            url = url.rstrip(".,)`'\"")
            if url == PREFIX or url in seen:
                continue
            seen.add(url)
            name = url.split("?")[0].rstrip("/").split("/")[-1] or "script"
            if not name.lower().endswith(OK_EXT):
                name += ".lua"
            jobs.append({"name": name, "att": None, "url": url})
    return jobs


async def fetch_source(job) -> str:
    if job["att"] is not None:
        return (await job["att"].read()).decode("utf-8", "ignore")
    async with http.get(job["url"], timeout=aiohttp.ClientTimeout(total=30)) as r:
        r.raise_for_status()
        chunks, total = [], 0
        async for part in r.content.iter_chunked(65536):
            total += len(part)
            if total > MAX_DL:
                raise ValueError("file too large")
            chunks.append(part)
        return b"".join(chunks).decode("utf-8", "ignore")


async def worker():
    await bot.wait_until_ready()
    while True:
        job = await queue.get()
        message, name = job["message"], job["name"]
        stamp = f"{int(time.time()*1000)}_{os.getpid()}"
        in_rel  = f"bot_tmp/{stamp}.lua"
        out_rel = f"bot_tmp/{stamp}_out.lua"
        in_path, out_path = ROOT / in_rel, ROOT / out_rel

        await unreact(message, "🕓")
        await react(message, "⏳")
        try:
            src = await fetch_source(job)
            in_path.write_text(src, encoding="utf-8", errors="ignore")

            ok, reason, took = await asyncio.to_thread(_dump_blocking, in_rel, out_rel)

            if ok:
                data = out_path.read_text(errors="ignore")
                lines = data.count("\n") + 1
                e = discord.Embed(color=GOOD, timestamp=datetime.now())
                e.description = (
                    f"**`{name}`**\n"
                    f"`{lines:,} lines` · `{len(data)/1024:.1f} KB` · `{took:.2f}s`"
                )
                e.set_footer(text="69ms")
                out_name = re.sub(r"\.(lua|txt)$", "", name, flags=re.I) + ".dump.lua"
                with open(out_path, "rb") as fh:
                    await message.reply(
                        content=message.author.mention,
                        embed=e,
                        file=discord.File(fh, filename=out_name),
                        mention_author=True,
                    )
                await unreact(message, "⏳")
                await react(message, "✅")
            else:
                label = "skipped — took over 100s" if reason == "timeout" else reason
                e = discord.Embed(color=WARN if reason == "timeout" else BAD,
                                  timestamp=datetime.now())
                e.description = f"**`{name}`**\n{label}"
                e.set_footer(text="69ms")
                await message.reply(content=message.author.mention, embed=e,
                                    mention_author=True)
                await unreact(message, "⏳")
                await react(message, "⏱️" if reason == "timeout" else "❌")

        except Exception as ex:
            e = discord.Embed(color=BAD, timestamp=datetime.now())
            e.description = f"**`{name}`**\ncouldn't grab that — {ex}"
            e.set_footer(text="69ms")
            try:
                await message.reply(content=message.author.mention, embed=e,
                                    mention_author=True)
            except discord.HTTPException:
                pass
            await unreact(message, "⏳")
            await react(message, "❌")
        finally:
            for p in (in_path, out_path):
                try: p.unlink()
                except OSError: pass
            queue.task_done()


@bot.event
async def on_ready():
    global http
    if http is None:
        http = aiohttp.ClientSession()
    bot.loop.create_task(worker())
    await bot.change_presence(activity=discord.Activity(
        type=discord.ActivityType.watching, name=f"{PREFIX} · dumps"))
    print(f"online as {bot.user} · channel {CHANNEL_ID}")


@bot.event
async def on_message(message):
    if message.author.bot or message.channel.id != CHANNEL_ID:
        return

    content = message.content.strip()
    if not (content == PREFIX or content.lower().startswith(PREFIX + " ")
            or content.lower().startswith(PREFIX + "\n")):
        return

    jobs = await gather_jobs(message)
    if not jobs:
        e = discord.Embed(color=ACCENT, description=(
            f"attach a `.lua`/`.txt`, drop a raw link, or reply to one with `{PREFIX}`."
        ))
        e.set_footer(text="69ms")
        await message.reply(embed=e, mention_author=False)
        return

    await react(message, "🕓")
    pos = queue.qsize()
    for j in jobs:
        j["message"] = message
        await queue.put(j)
    if pos or len(jobs) > 1:
        note = f"queued `{len(jobs)}` · `{pos}` ahead" if pos else f"queued `{len(jobs)}`"
        try: await message.reply(note, mention_author=False, delete_after=6)
        except discord.HTTPException: pass


if __name__ == "__main__":
    bot.run(TOKEN)
