#!/usr/bin/env python3
"""mujo-wallpaper-engine — Wallpaper Engine management, Steam Workshop browser,
thumbnail pre-caching, and streaming wallpaper downloader for Mujo (無常).

Provides:
  - Steam Workshop browsing & search for Wallpaper Engine (App ID: 431960)
  - Purity filters (SFW / Everyone, Sketchy / Questionable, NSFW / Mature)
  - Fast multi-threaded disk pre-caching for wallpaper thumbnails
  - Real-time streaming wallpaper download progress (bytes, speed, ETA)
  - Full workshop item details & metadata retrieval via Steam API & HTML scraper
  - Local installed Wallpaper Engine project scanning (Steam + Flatpak + custom dirs)
  - Steam client integration, status, and direct workshop subscription
  - Wallpaper Engine application and wallpaper.json configuration
  - Process lifecycle management for scene/web wallpaper renderers

Commands:
  search [json_or_query] [--type <t>] [--sort <s>] [--tags <tags>] [--page <p>] [--purity <sfw,sketchy,nsfw>]
  details <id_or_path>
  list
  steam-status
  subscribe <id>
  download <id>
  download-progress <url> [dest]
  cache-thumbnails [urls_json]
  apply <id_or_path> [--monitor <name>]
  status
  stop
  config [--fps <fps>] [--volume <vol>] [--silent <true|false>] [--automute <true|false>]
"""

import concurrent.futures
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

APP_ID = "431960"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
STEAM_COOKIE = "wants_mature_content=1; birthtime=788918401; lastagecheckage=1-0-1995; mature_content=1; timezoneOffset=0,0"

HOME = Path(os.environ.get("HOME", "/tmp"))
CONF_PATH = HOME / ".config" / "quickshell" / "wallpaper.json"
SETTINGS_CONF = HOME / ".config" / "qsshell" / "settings.json"
WALLPAPER_DIR = Path(os.environ.get("XDG_PICTURES_DIR", str(HOME / "Pictures"))) / "Wallpapers" / "WallpaperEngine"
THUMBNAIL_CACHE_DIR = HOME / ".cache" / "mujo" / "thumbnails"
THUMBNAIL_CACHE_DIR.mkdir(parents=True, exist_ok=True)


def _read_settings():
    if SETTINGS_CONF.is_file():
        try:
            with open(SETTINGS_CONF, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def _read_wallpaper_conf():
    if CONF_PATH.is_file():
        try:
            with open(CONF_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "background": "#111111",
        "effects": {"motion": False},
        "engine": {"fps": 30, "silent": True, "volume": 50, "automute": True},
        "default": {},
        "monitors": {},
    }


def _write_wallpaper_conf(data):
    CONF_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp_path = CONF_PATH.with_suffix(".tmp")
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(temp_path, CONF_PATH)


# ── Thumbnail Cache & Pre-fetching Engine ───────────────────────────────────

def _get_thumbnail_cache_path(url):
    """Return local disk path for a cached thumbnail."""
    if not url:
        return None
    h = hashlib.md5(url.encode("utf-8")).hexdigest()
    return THUMBNAIL_CACHE_DIR / f"{h}.jpg"


def _cache_single_thumbnail(url):
    """Download a single thumbnail into local disk cache."""
    if not url or url.startswith("file://") or url.startswith("/"):
        return url
    try:
        dest = _get_thumbnail_cache_path(url)
        if dest and dest.is_file() and dest.stat().st_size > 0:
            return f"file://{dest}"

        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        }
        if "steam" in url or "steamusercontent" in url:
            headers["Cookie"] = STEAM_COOKIE

        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = resp.read()
            if data:
                tmp = dest.with_suffix(".tmp")
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, dest)
                return f"file://{dest}"
    except Exception:
        pass
    return url


def prefetch_thumbnails(urls, max_workers=12):
    """Pre-fetch list of URLs concurrently in background thread pool."""
    if not urls:
        return {}
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_url = {executor.submit(_cache_single_thumbnail, u): u for u in urls if u}
        for future in concurrent.futures.as_completed(future_to_url, timeout=12):
            u = future_to_url[future]
            try:
                res = future.result()
                results[u] = res
            except Exception:
                results[u] = u
    return results


def cmd_cache_thumbnails(args):
    """CLI handler to cache thumbnail URLs passed as JSON argument or stdin."""
    urls = []
    if args:
        try:
            urls = json.loads(args[0])
        except Exception:
            urls = args
    elif not sys.stdin.isatty():
        try:
            urls = json.load(sys.stdin)
        except Exception:
            urls = [line.strip() for line in sys.stdin if line.strip()]

    if not isinstance(urls, list):
        urls = [urls]

    res = prefetch_thumbnails(urls)
    print(json.dumps(res))


# ── Streaming Wallpaper Downloader ──────────────────────────────────────────

def cmd_download_progress(args):
    """Download any wallpaper URL with real-time JSON progress streaming on stdout."""
    if not args:
        sys.stdout.write(json.dumps({"type": "error", "error": "Missing URL argument", "success": False}) + "\n")
        sys.stdout.flush()
        return 1

    url = args[0].strip()
    dest = args[1].strip() if len(args) > 1 and args[1].strip() else None

    # Handle local / non-http URLs
    if not url.startswith("http://") and not url.startswith("https://"):
        sys.stdout.write(json.dumps({"type": "done", "url": url, "dest": url, "total_bytes": 0, "success": True}) + "\n")
        sys.stdout.flush()
        return 0

    if not dest:
        clean_url = url.split("?")[0]
        fname = os.path.basename(clean_url)
        if not fname or "." not in fname:
            fname = f"wallpaper-{int(time.time())}.jpg"
        dest_dir = Path(os.environ.get("XDG_PICTURES_DIR", str(HOME / "Pictures"))) / "Wallpapers"
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = str(dest_dir / fname)

    dest_path = Path(dest)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = dest_path.with_suffix(f".part-{os.getpid()}")

    req_headers = {
        "User-Agent": USER_AGENT,
        "Accept": "*/*",
        "Referer": "https://wallhaven.cc/",
    }
    if "steam" in url or "steamusercontent" in url:
        req_headers["Cookie"] = STEAM_COOKIE

    req = urllib.request.Request(url, headers=req_headers)
    t_start = time.time()
    last_emit = 0

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            total_size = int(resp.headers.get("Content-Length", 0))
            sys.stdout.write(json.dumps({
                "type": "start",
                "url": url,
                "dest": str(dest_path),
                "total_bytes": total_size,
            }) + "\n")
            sys.stdout.flush()

            downloaded = 0
            chunk_size = 64 * 1024
            with open(tmp_path, "wb") as f:
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    now = time.time()
                    if now - last_emit >= 0.08 or (total_size > 0 and downloaded == total_size):
                        last_emit = now
                        elapsed = max(0.001, now - t_start)
                        speed_bps = downloaded / elapsed
                        if speed_bps >= 1024 * 1024:
                            speed_str = f"{speed_bps / (1024*1024):.1f} MB/s"
                        else:
                            speed_str = f"{speed_bps / 1024:.0f} KB/s"

                        pct = (downloaded / total_size * 100) if total_size > 0 else (100.0 if downloaded > 0 else 0.0)
                        rem_bytes = max(0, total_size - downloaded)
                        eta_sec = int(rem_bytes / speed_bps) if speed_bps > 0 and total_size > 0 else 0
                        eta_str = f"{eta_sec}s" if eta_sec < 60 else f"{eta_sec//60}m {eta_sec%60}s"

                        sys.stdout.write(json.dumps({
                            "type": "progress",
                            "url": url,
                            "downloaded_bytes": downloaded,
                            "total_bytes": total_size,
                            "percent": round(pct, 1),
                            "speed": speed_str,
                            "eta": eta_str,
                        }) + "\n")
                        sys.stdout.flush()

            os.replace(tmp_path, dest_path)
            sys.stdout.write(json.dumps({
                "type": "done",
                "url": url,
                "dest": str(dest_path),
                "total_bytes": downloaded,
                "success": True,
            }) + "\n")
            sys.stdout.flush()
            return 0
    except Exception as e:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except Exception:
                pass
        sys.stdout.write(json.dumps({
            "type": "error",
            "url": url,
            "error": str(e),
            "success": False,
        }) + "\n")
        sys.stdout.flush()
        return 1


# ── Steam Discovery & Library Management ────────────────────────────────────

def _discover_steam_client():
    """Detect Steam installation type and running status."""
    is_native = shutil.which("steam") is not None
    flatpak_dir = HOME / ".var" / "app" / "com.valvesoftware.Steam"
    is_flatpak = flatpak_dir.is_dir() or (shutil.which("flatpak") is not None and flatpak_dir.exists())

    is_running = False
    try:
        res = subprocess.run(["pgrep", "-f", "steam"], capture_output=True)
        if res.returncode == 0:
            is_running = True
    except Exception:
        pass

    steam_type = "none"
    if is_native:
        steam_type = "native"
    elif is_flatpak:
        steam_type = "flatpak"

    return {
        "installed": is_native or is_flatpak,
        "type": steam_type,
        "is_native": is_native,
        "is_flatpak": is_flatpak,
        "running": is_running,
    }


def _discover_steam_libraries():
    """Parse libraryfolders.vdf across all Steam installs to discover all Steam library roots."""
    vdf_candidates = [
        HOME / ".local" / "share" / "Steam" / "steamapps" / "libraryfolders.vdf",
        HOME / ".local" / "share" / "Steam" / "config" / "libraryfolders.vdf",
        HOME / ".var" / "app" / "com.valvesoftware.Steam" / ".local" / "share" / "Steam" / "steamapps" / "libraryfolders.vdf",
        HOME / ".var" / "app" / "com.valvesoftware.Steam" / ".local" / "share" / "Steam" / "config" / "libraryfolders.vdf",
        HOME / ".steam" / "steam" / "steamapps" / "libraryfolders.vdf",
        HOME / ".steam" / "root" / "steamapps" / "libraryfolders.vdf",
    ]

    libraries = []
    seen = set()

    for vdf in vdf_candidates:
        if vdf.is_file():
            try:
                content = vdf.read_text(encoding="utf-8", errors="replace")
                for m in re.finditer(r'"path"\s+"([^"]+)"', content):
                    p_str = m.group(1).replace("\\\\", "/")
                    p = Path(p_str)
                    if p.is_dir() and str(p.resolve()) not in seen:
                        seen.add(str(p.resolve()))
                        libraries.append(p.resolve())
            except Exception:
                continue

    default_dirs = [
        HOME / ".local" / "share" / "Steam",
        HOME / ".var" / "app" / "com.valvesoftware.Steam" / ".local" / "share" / "Steam",
        HOME / ".steam" / "steam",
    ]
    for d in default_dirs:
        if d.is_dir() and str(d.resolve()) not in seen:
            seen.add(str(d.resolve()))
            libraries.append(d.resolve())

    return libraries


def _get_workshop_dirs():
    """Return all directories containing installed Wallpaper Engine workshop items and default projects."""
    dirs = []
    seen = set()

    # 1. Custom user directory
    if WALLPAPER_DIR.is_dir():
        dirs.append(WALLPAPER_DIR)
        seen.add(str(WALLPAPER_DIR))

    # 2. Discovered Steam libraries
    for lib in _discover_steam_libraries():
        ws = lib / "steamapps" / "workshop" / "content" / APP_ID
        if ws.is_dir() and str(ws) not in seen:
            dirs.append(ws)
            seen.add(str(ws))

        common_wp = lib / "steamapps" / "common" / "wallpaper_engine" / "projects" / "defaultprojects"
        if common_wp.is_dir() and str(common_wp) not in seen:
            dirs.append(common_wp)
            seen.add(str(common_wp))

        common_assets = lib / "steamapps" / "common" / "wallpaper_engine" / "assets"
        if common_assets.is_dir() and str(common_assets) not in seen:
            dirs.append(common_assets)
            seen.add(str(common_assets))

    return dirs


def _scan_local_project(project_dir):
    """Scan a Wallpaper Engine directory for project.json and assets."""
    p_json = project_dir / "project.json"
    if not p_json.is_file():
        return None

    try:
        with open(p_json, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except Exception:
        return None

    title = data.get("title", project_dir.name)
    description = data.get("description", "")
    w_type = data.get("type", "scene").lower()
    main_file = data.get("file", "")

    full_file = project_dir / main_file if main_file else None
    if not full_file or not full_file.exists():
        for candidate in ["scene.json", "scene.pkg", "index.html", "video.mp4", "preview.gif"]:
            if (project_dir / candidate).exists():
                full_file = project_dir / candidate
                if candidate.endswith(".json") or candidate.endswith(".pkg"):
                    w_type = "scene"
                elif candidate.endswith(".html"):
                    w_type = "web"
                elif candidate.endswith(".mp4"):
                    w_type = "video"
                break

    preview = data.get("preview", "preview.jpg")
    preview_file = project_dir / preview if preview else None
    if not preview_file or not preview_file.exists():
        for cand_prev in ["preview.gif", "preview.png", "preview.jpg", "thumb.jpg"]:
            if (project_dir / cand_prev).exists():
                preview_file = project_dir / cand_prev
                break

    tags = data.get("tags", [])
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",") if t.strip()]

    # Content purity evaluation
    purity = "sfw"
    age_rating = "Everyone"
    combined_text = (title + " " + description + " " + " ".join(str(t) for t in tags)).lower()
    if any(k in combined_text for k in ["mature", "nsfw", "18+", "r18", "nude", "hentai", "bikini", "ecchi", "erotic", "sexy", "lingerie"]):
        purity = "nsfw" if any(k in combined_text for k in ["nsfw", "18+", "r18", "nude", "hentai", "erotic"]) else "sketchy"
        age_rating = "Mature" if purity == "nsfw" else "Questionable"

    return {
        "id": project_dir.name,
        "title": title,
        "description": description,
        "type": w_type,
        "file": str(full_file) if full_file else "",
        "preview": str(preview_file) if preview_file else "",
        "tags": tags,
        "purity": purity,
        "age_rating": age_rating,
        "general": data.get("general", {}),
        "path": str(project_dir),
        "is_local": True,
    }


def cmd_list():
    """Return JSON list of all locally installed Wallpaper Engine projects."""
    projects = []
    seen = set()

    for d in _get_workshop_dirs():
        if not d.is_dir():
            continue
        for child in d.iterdir():
            if child.is_dir() and str(child) not in seen:
                seen.add(str(child))
                item = _scan_local_project(child)
                if item:
                    projects.append(item)

    print(json.dumps(projects))


def cmd_steam_status():
    """Return detailed Steam status, detected libraries, and installed items count."""
    steam = _discover_steam_client()
    libs = _discover_steam_libraries()

    lib_details = []
    total_wp = 0

    for lib in libs:
        ws_dir = lib / "steamapps" / "workshop" / "content" / APP_ID
        count = 0
        if ws_dir.is_dir():
            for child in ws_dir.iterdir():
                if (child / "project.json").is_file():
                    count += 1
        total_wp += count
        lib_details.append({
            "path": str(lib),
            "workshop_dir": str(ws_dir) if ws_dir.is_dir() else "",
            "wallpaper_count": count,
        })

    status = {
        "installed": steam["installed"],
        "type": steam["type"],
        "running": steam["running"],
        "libraries": lib_details,
        "total_wallpapers": total_wp,
        "workshop_dirs": [str(d) for d in _get_workshop_dirs()],
    }
    print(json.dumps(status))


def _fetch_url(url, headers=None, timeout=20):
    req_headers = {
        "User-Agent": USER_AGENT,
        "Accept-Language": "en-US,en;q=0.9",
        "Cookie": STEAM_COOKIE,
    }
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, headers=req_headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


# ── Search & Browse Engine with Purity Filters ──────────────────────────────

def cmd_search(args):
    """Search Steam Workshop for Wallpaper Engine items with purity filters and thumbnail caching."""
    query = ""
    page = 1
    sort = "trend"  # trend | mostrecent | toprated | totaluniquesubscribers | textsearch
    w_type = "all"  # all | scene | video | web | application
    tags = []
    purity_sfw = True
    purity_sketchy = True
    purity_nsfw = False

    if args and args[0].startswith("{") and args[0].endswith("}"):
        try:
            params = json.loads(args[0])
            query = params.get("q", params.get("query", ""))
            page = int(params.get("page", 1))
            sort = params.get("sort", params.get("sorting", "trend"))
            w_type = params.get("type", "all")
            tags = params.get("tags", [])
            if isinstance(tags, str):
                tags = [t.strip() for t in tags.split(",") if t.strip()]

            if "purity_sfw" in params:
                purity_sfw = bool(params["purity_sfw"])
            if "purity_sketchy" in params:
                purity_sketchy = bool(params["purity_sketchy"])
            if "purity_nsfw" in params:
                purity_nsfw = bool(params["purity_nsfw"])

            if "purity" in params:
                p_val = params["purity"]
                if isinstance(p_val, list):
                    purity_sfw = "sfw" in p_val or "everyone" in p_val
                    purity_sketchy = "sketchy" in p_val or "questionable" in p_val
                    purity_nsfw = "nsfw" in p_val or "mature" in p_val
        except Exception:
            pass
    else:
        i = 0
        while i < len(args):
            arg = args[i]
            if arg in ["--query", "-q"] and i + 1 < len(args):
                query = args[i + 1]
                i += 2
            elif arg in ["--page", "-p"] and i + 1 < len(args):
                try:
                    page = int(args[i + 1])
                except ValueError:
                    page = 1
                i += 2
            elif arg in ["--sort", "-s"] and i + 1 < len(args):
                sort = args[i + 1]
                i += 2
            elif arg in ["--type", "-t"] and i + 1 < len(args):
                w_type = args[i + 1]
                i += 2
            elif arg in ["--tags"] and i + 1 < len(args):
                tags = [t.strip() for t in args[i + 1].split(",") if t.strip()]
                i += 2
            elif arg in ["--purity"] and i + 1 < len(args):
                p_list = [x.strip().lower() for x in args[i + 1].split(",")]
                purity_sfw = "sfw" in p_list or "everyone" in p_list
                purity_sketchy = "sketchy" in p_list or "questionable" in p_list
                purity_nsfw = "nsfw" in p_list or "mature" in p_list
                i += 2
            else:
                if not query:
                    query = arg
                i += 1

    sort_map = {
        "trend": "trend",
        "trending": "trend",
        "toplist": "trend",
        "mostrecent": "mostrecent",
        "latest": "mostrecent",
        "toprated": "vote",
        "votes": "vote",
        "favorites": "vote",
        "subscribed": "totaluniquesubscribers",
        "subscribers": "totaluniquesubscribers",
        "relevance": "textsearch",
    }
    steam_sort = sort_map.get(sort.lower(), "trend")

    active_purities = []
    if purity_sfw:
        active_purities.append("Everyone")
    if purity_sketchy:
        active_purities.append("Questionable")
    if purity_nsfw:
        active_purities.append("Mature")

    if not active_purities:
        active_purities = ["Everyone", "Questionable"]

    type_tag_map = {
        "scene": "Scene",
        "video": "Video",
        "web": "Web",
        "application": "Application",
    }

    def fetch_browse_page(maturity_tag=None, target_page=1):
        url_params = [
            ("appid", APP_ID),
            ("browsesort", steam_sort),
            ("section", "readytouseitems"),
            ("p", str(target_page)),
        ]
        if query.strip():
            url_params.append(("searchtext", query.strip()))
        if w_type.lower() in type_tag_map:
            url_params.append(("requiredtags[]", type_tag_map[w_type.lower()]))
        for t in tags:
            if t:
                url_params.append(("requiredtags[]", t))
        if maturity_tag:
            url_params.append(("requiredtags[]", maturity_tag))

        b_url = "https://steamcommunity.com/workshop/browse/?" + urllib.parse.urlencode(url_params)
        return _fetch_url(b_url)

    items = []
    seen_ids = set()
    total_pages = 1
    thumbnails_to_cache = []

    def optimize_thumb_url(u):
        # Resize steam UGC thumbnails to 360x202 for fast decoding
        u = re.sub(r'imw=\d+&amp;imh=\d+', 'imw=360&amp;imh=202', u)
        u = re.sub(r'imw=\d+&imh=\d+', 'imw=360&imh=202', u)
        if "impolicy=" not in u:
            u += "&impolicy=Letterbox"
        return u

    if len(active_purities) == 1:
        target_maturity = active_purities[0]
        try:
            html_content = fetch_browse_page(target_maturity, page)
        except Exception as e:
            print(json.dumps({
                "data": [],
                "error": "network_error",
                "message": f"Failed to connect to Steam Workshop: {e}",
                "meta": {"current_page": page, "last_page": 1, "total": 0, "per_page": 30}
            }))
            return

        img_card_regex = re.compile(r'https://steamcommunity\.com/sharedfiles/filedetails/\?id=(\d+)[^>]*>.*?<img[^>]+src="([^"]+)"[^>]*alt="([^"]*)"', re.DOTALL)
        for match in img_card_regex.finditer(html_content):
            item_id = match.group(1)
            if item_id in seen_ids:
                continue
            seen_ids.add(item_id)

            preview_url = html.unescape(match.group(2))
            title = html.unescape(match.group(3)).strip() or f"Wallpaper #{item_id}"
            preview_url = optimize_thumb_url(preview_url)
            thumbnails_to_cache.append(preview_url)

            inferred_type = "scene"
            t_low = title.lower()
            if "video" in t_low or "60fps" in t_low or "4k" in t_low or "1080p" in t_low:
                inferred_type = "video"

            purity_key = "sfw" if target_maturity == "Everyone" else ("sketchy" if target_maturity == "Questionable" else "nsfw")
            cached_path = _get_thumbnail_cache_path(preview_url)
            cached_uri = f"file://{cached_path}" if cached_path and cached_path.is_file() else ""

            items.append({
                "id": item_id,
                "title": title,
                "author": "Steam Community",
                "preview": preview_url,
                "cached_preview": cached_uri,
                "rating": 5,
                "type": inferred_type,
                "purity": purity_key,
                "age_rating": target_maturity,
                "url": f"https://steamcommunity.com/sharedfiles/filedetails/?id={item_id}",
                "is_local": False,
            })

        pages_found = [int(p) for p in re.findall(r'class=["\'][^"\']*pagelink[^"\']*["\'][^>]*>(\d+)<', html_content)]
        total_pages = max(pages_found) if pages_found else (page + 1 if len(items) >= 20 else page)

    else:
        try:
            html_content = fetch_browse_page(None, page)
        except Exception as e:
            print(json.dumps({
                "data": [],
                "error": "network_error",
                "message": f"Failed to connect to Steam Workshop: {e}",
                "meta": {"current_page": page, "last_page": 1, "total": 0, "per_page": 30}
            }))
            return

        img_card_regex = re.compile(r'https://steamcommunity\.com/sharedfiles/filedetails/\?id=(\d+)[^>]*>.*?<img[^>]+src="([^"]+)"[^>]*alt="([^"]*)"', re.DOTALL)
        for match in img_card_regex.finditer(html_content):
            item_id = match.group(1)
            if item_id in seen_ids:
                continue
            seen_ids.add(item_id)

            preview_url = html.unescape(match.group(2))
            title = html.unescape(match.group(3)).strip() or f"Wallpaper #{item_id}"
            preview_url = optimize_thumb_url(preview_url)
            thumbnails_to_cache.append(preview_url)

            inferred_type = "scene"
            t_low = title.lower()
            if "video" in t_low or "60fps" in t_low or "4k" in t_low or "1080p" in t_low:
                inferred_type = "video"

            purity = "sfw"
            age_rating = "Everyone"
            if any(k in t_low for k in ["nsfw", "18+", "r18", "nude", "hentai", "bikini", "ecchi", "erotic", "sexy", "lingerie"]):
                purity = "nsfw" if any(k in t_low for k in ["nsfw", "18+", "r18", "nude", "hentai", "erotic"]) else "sketchy"
                age_rating = "Mature" if purity == "nsfw" else "Questionable"

            if purity == "sfw" and not purity_sfw:
                continue
            if purity == "sketchy" and not purity_sketchy:
                continue
            if purity == "nsfw" and not purity_nsfw:
                continue

            cached_path = _get_thumbnail_cache_path(preview_url)
            cached_uri = f"file://{cached_path}" if cached_path and cached_path.is_file() else ""

            items.append({
                "id": item_id,
                "title": title,
                "author": "Steam Community",
                "preview": preview_url,
                "cached_preview": cached_uri,
                "rating": 5,
                "type": inferred_type,
                "purity": purity,
                "age_rating": age_rating,
                "url": f"https://steamcommunity.com/sharedfiles/filedetails/?id={item_id}",
                "is_local": False,
            })

        pages_found = [int(p) for p in re.findall(r'class=["\'][^"\']*pagelink[^"\']*["\'][^>]*>(\d+)<', html_content)]
        total_pages = max(pages_found) if pages_found else (page + 1 if len(items) >= 20 else page)

    # Spawn fast thread pool in background to pre-cache thumbnails for instant rendering
    if thumbnails_to_cache:
        executor = concurrent.futures.ThreadPoolExecutor(max_workers=8)
        executor.map(_cache_single_thumbnail, thumbnails_to_cache)
        executor.shutdown(wait=False)

    print(json.dumps({
        "data": items,
        "meta": {
            "current_page": page,
            "last_page": max(1, total_pages),
            "total": len(items) * max(1, total_pages),
            "per_page": 30,
        },
        "query": query,
        "type": w_type,
        "sort": sort,
        "purity": {
            "sfw": purity_sfw,
            "sketchy": purity_sketchy,
            "nsfw": purity_nsfw,
        }
    }))


# ── Metadata & Details Fetcher ──────────────────────────────────────────────

def cmd_details(item_id_or_path):
    """Fetch complete metadata for a workshop item or local project."""
    target_path = Path(item_id_or_path)
    if target_path.is_dir() and (target_path / "project.json").is_file():
        info = _scan_local_project(target_path)
        if info:
            print(json.dumps({"data": info}))
            return

    for d in _get_workshop_dirs():
        cand = d / item_id_or_path
        if cand.is_dir() and (cand / "project.json").is_file():
            info = _scan_local_project(cand)
            if info:
                print(json.dumps({"data": info}))
                return

    item_id = item_id_or_path.strip()
    api_url = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"
    api_data = {
        "itemcount": "1",
        "publishedfileids[0]": item_id,
    }
    encoded_data = urllib.parse.urlencode(api_data).encode("utf-8")
    req = urllib.request.Request(api_url, data=encoded_data, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            api_res = json.loads(resp.read().decode("utf-8"))
            details_list = api_res.get("response", {}).get("publishedfiledetails", [])
            if details_list and details_list[0].get("result") == 1:
                item = details_list[0]
                tags_raw = [t.get("tag", "") for t in item.get("tags", [])]
                w_type = "scene"
                for t in tags_raw:
                    t_low = t.lower()
                    if t_low in ["video", "web", "application", "scene"]:
                        w_type = t_low
                        break

                purity = "sfw"
                age_rating = "Everyone"
                for t in tags_raw:
                    if t == "Mature":
                        purity = "nsfw"
                        age_rating = "Mature"
                        break
                    elif t == "Questionable":
                        purity = "sketchy"
                        age_rating = "Questionable"

                file_size_bytes = int(item.get("file_size", 0))
                file_size_str = f"{file_size_bytes / (1024*1024):.1f} MB" if file_size_bytes > 0 else ""

                created_ts = item.get("time_created", 0)
                updated_ts = item.get("time_updated", 0)
                posted_str = datetime.fromtimestamp(created_ts).strftime("%b %d, %Y") if created_ts else ""
                updated_str = datetime.fromtimestamp(updated_ts).strftime("%b %d, %Y") if updated_ts else ""

                preview_url = item.get("preview_url", "")
                cached_path = _get_thumbnail_cache_path(preview_url)
                cached_uri = f"file://{cached_path}" if cached_path and cached_path.is_file() else ""

                data_out = {
                    "id": item_id,
                    "title": item.get("title", f"Workshop #{item_id}"),
                    "author": f"Steam ID {item.get('creator', 'Community')}",
                    "description": item.get("description", ""),
                    "preview": preview_url,
                    "cached_preview": cached_uri,
                    "rating": 5,
                    "subscriptions": item.get("subscriptions", 0),
                    "views": item.get("views", 0),
                    "file_size": file_size_str,
                    "posted": posted_str,
                    "updated": updated_str,
                    "tags": [{"name": t} for t in tags_raw if t],
                    "type": w_type,
                    "purity": purity,
                    "age_rating": age_rating,
                    "url": f"https://steamcommunity.com/sharedfiles/filedetails/?id={item_id}",
                    "is_local": False,
                }
                print(json.dumps({"data": data_out}))
                return
    except Exception:
        pass

    # Fallback to HTML scraping
    item_url = f"https://steamcommunity.com/sharedfiles/filedetails/?id={item_id}"
    try:
        page_html = _fetch_url(item_url, timeout=12)
        title_m = re.search(r'<div class="workshopItemTitle">([^<]+)</div>', page_html)
        title = html.unescape(title_m.group(1).strip()) if title_m else f"Workshop #{item_id}"

        desc_m = re.search(r'<div class="workshopItemDescription" id="highlightContent">([\s\S]*?)</div>', page_html)
        description = html.unescape(re.sub(r'<[^>]+>', '', desc_m.group(1))).strip() if desc_m else ""

        preview_m = re.search(r'id="previewImage"[^>]+src="([^"]+)"', page_html) or re.search(r'id="previewImageMain"[^>]+src="([^"]+)"', page_html)
        preview = html.unescape(preview_m.group(1)) if preview_m else ""

        tags = []
        for tm in re.finditer(r'<div class="workshopTagsTitle">([^<]+)</div>', page_html):
            tags.append({"name": html.unescape(tm.group(1).strip())})

        author_m = re.search(r'<div class="friendBlockContent">([^<]+)<br>', page_html)
        author = html.unescape(author_m.group(1).strip()) if author_m else "Steam Community"

        data_out = {
            "id": item_id,
            "title": title,
            "author": author,
            "description": description,
            "preview": preview,
            "rating": 5,
            "tags": tags,
            "type": "scene",
            "purity": "sfw",
            "age_rating": "Everyone",
            "url": item_url,
            "is_local": False,
        }
        print(json.dumps({"data": data_out}))
    except Exception as e:
        print(json.dumps({"data": None, "error": str(e)}))


# ── Wallpaper Application & Control ─────────────────────────────────────────

def cmd_apply(target, monitor=None):
    """Apply a Wallpaper Engine project or media file to the desktop."""
    target_path = Path(target)
    resolved_path = None

    if target_path.exists():
        resolved_path = target_path.resolve()
    else:
        for d in _get_workshop_dirs():
            cand = d / target
            if cand.exists():
                resolved_path = cand.resolve()
                break

    if not resolved_path:
        print(json.dumps({"success": False, "error": f"Wallpaper not found: {target}"}))
        return 1

    project_info = _scan_local_project(resolved_path) if resolved_path.is_dir() else None
    conf = _read_wallpaper_conf()

    if project_info:
        main_file = project_info.get("file", "")
        w_type = project_info.get("type", "scene")
        target_entry = {
            "engine": str(resolved_path),
            "type": w_type,
            "title": project_info.get("title", resolved_path.name),
        }
        if w_type == "video" and main_file and Path(main_file).is_file():
            target_entry["video"] = main_file
        elif project_info.get("preview") and Path(project_info["preview"]).is_file():
            target_entry["image"] = project_info["preview"]
    else:
        target_entry = {
            "image": str(resolved_path) if resolved_path.suffix.lower() in [".jpg", ".png", ".webp"] else "",
            "video": str(resolved_path) if resolved_path.suffix.lower() in [".mp4", ".webm", ".mkv"] else "",
            "engine": str(resolved_path.parent) if resolved_path.is_file() and (resolved_path.parent / "project.json").exists() else "",
        }

    if monitor:
        if "monitors" not in conf:
            conf["monitors"] = {}
        conf["monitors"][monitor] = target_entry
    else:
        conf["default"] = target_entry

    _write_wallpaper_conf(conf)
    print(json.dumps({"success": True, "applied": target_entry, "monitor": monitor or "default"}))
    return 0


def cmd_subscribe(item_id):
    """Open Steam subscription or download link."""
    target_id = str(item_id).strip()
    steam_url = f"steam://url/CommunityFilePage/{target_id}"
    web_url = f"https://steamcommunity.com/sharedfiles/filedetails/?id={target_id}"

    steam_info = _discover_steam_client()
    try:
        if steam_info["is_flatpak"]:
            subprocess.Popen(["flatpak", "run", "com.valvesoftware.Steam", steam_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            method_used = "steam_flatpak"
        elif steam_info["is_native"]:
            subprocess.Popen(["steam", steam_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            method_used = "steam_native"
        else:
            subprocess.Popen(["xdg-open", steam_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            method_used = "steam_url_handler"

        print(json.dumps({"success": True, "method": method_used, "url": steam_url, "item_id": target_id}))
        return
    except Exception:
        pass

    try:
        subprocess.Popen(["xdg-open", web_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"success": True, "method": "browser", "url": web_url, "item_id": target_id}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))


def cmd_status():
    """Return status of wallpaper engine and active configurations."""
    conf = _read_wallpaper_conf()
    steam_info = _discover_steam_client()
    installed = []
    for d in _get_workshop_dirs():
        if d.is_dir():
            for child in d.iterdir():
                if (child / "project.json").is_file():
                    installed.append(child.name)

    lwe_running = False
    try:
        res = subprocess.run(["pgrep", "-f", "linux-wallpaperengine"], capture_output=True)
        lwe_running = res.returncode == 0
    except Exception:
        pass

    status = {
        "config": conf,
        "steam": steam_info,
        "installed_count": len(installed),
        "workshop_dirs": [str(d) for d in _get_workshop_dirs()],
        "lwe_installed": shutil.which("linux-wallpaperengine") is not None,
        "lwe_running": lwe_running,
    }
    print(json.dumps(status))


def cmd_stop():
    """Stop running wallpaper engine processes."""
    try:
        subprocess.run(["pkill", "-f", "linux-wallpaperengine"], capture_output=True)
    except Exception:
        pass
    print(json.dumps({"success": True, "message": "Wallpaper engine processes stopped"}))


def cmd_config(args):
    """Update engine config options (fps, volume, silent, automute)."""
    conf = _read_wallpaper_conf()
    engine = conf.get("engine", {"fps": 30, "silent": True, "volume": 50, "automute": True})

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--fps" and i + 1 < len(args):
            try:
                engine["fps"] = int(args[i + 1])
            except ValueError:
                pass
            i += 2
        elif arg == "--volume" and i + 1 < len(args):
            try:
                engine["volume"] = max(0, min(100, int(args[i + 1])))
            except ValueError:
                pass
            i += 2
        elif arg == "--silent" and i + 1 < len(args):
            engine["silent"] = args[i + 1].lower() in ["true", "1", "on", "yes"]
            i += 2
        elif arg == "--automute" and i + 1 < len(args):
            engine["automute"] = args[i + 1].lower() in ["true", "1", "on", "yes"]
            i += 2
        else:
            i += 1

    conf["engine"] = engine
    _write_wallpaper_conf(conf)
    print(json.dumps({"success": True, "engine": engine}))


def main():
    argv = sys.argv[1:]
    if not argv:
        print(
            "Usage: mujo-wallpaper-engine list|search|details|steam-status|subscribe|download-progress|cache-thumbnails|apply|status|stop|config",
            file=sys.stderr,
        )
        return 1

    cmd = argv[0].lower()
    rest = argv[1:]

    try:
        if cmd == "list":
            cmd_list()
        elif cmd == "search":
            cmd_search(rest)
        elif cmd == "details" and rest:
            cmd_details(rest[0])
        elif cmd == "steam-status":
            cmd_steam_status()
        elif cmd in ["subscribe", "download"] and rest:
            cmd_subscribe(rest[0])
        elif cmd == "download-progress":
            cmd_download_progress(rest)
        elif cmd == "cache-thumbnails":
            cmd_cache_thumbnails(rest)
        elif cmd == "apply" and rest:
            mon = None
            if "--monitor" in rest:
                m_idx = rest.index("--monitor")
                if m_idx + 1 < len(rest):
                    mon = rest[m_idx + 1]
            cmd_apply(rest[0], mon)
        elif cmd == "status":
            cmd_status()
        elif cmd == "stop":
            cmd_stop()
        elif cmd == "config":
            cmd_config(rest)
        else:
            print(f"Unknown command: {cmd}", file=sys.stderr)
            return 1
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
