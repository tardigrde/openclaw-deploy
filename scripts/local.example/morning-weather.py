#!/usr/bin/env python3
"""Morning weather report → Telegram.

Fetches wttr.in JSON, formats a 3-line summary, and sends it
to a Telegram chat via the Bot API. No third-party dependencies — stdlib only.

Required env vars:
  TELEGRAM_BOT_TOKEN   Telegram bot token (from @BotFather)
  TELEGRAM_CHAT_ID     Target chat/user ID

Optional env vars:
  WTTR_LOCATION        Location to fetch weather for (default: "Berlin")
  TZ                   IANA timezone for the date header (default: "UTC")
"""

import json
import os
import sys
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

LOCATION = os.environ.get("WTTR_LOCATION", "Berlin")
BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")

TZ = ZoneInfo(os.environ.get("TZ", "UTC"))


def fetch(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "curl/7.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def send_telegram(text: str) -> None:
    if not BOT_TOKEN or not CHAT_ID:
        print("ERROR: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set", file=sys.stderr)
        sys.exit(1)

    payload = json.dumps({"chat_id": CHAT_ID, "text": text}).encode()
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read().decode())
        if not result.get("ok"):
            print(f"ERROR: Telegram API returned: {result}", file=sys.stderr)
            sys.exit(1)


def format_message(data: dict) -> str:
    today = datetime.now(TZ)
    date_str = today.strftime("%Y. %m. %d., %A")

    current = data["current_condition"][0]
    temp_c = current["temp_C"]
    feels_c = current["FeelsLikeC"]

    weather_today = data["weather"][0]
    max_c = weather_today["maxtempC"]
    min_c = weather_today["mintempC"]

    # Rain: sum of hourly precipitation (mm)
    hourly = weather_today.get("hourly", [])
    total_rain_mm = sum(float(h.get("precipMM", 0)) for h in hourly)
    rain_chance = max(int(h.get("chanceofrain", 0)) for h in hourly) if hourly else 0

    line1 = f"🌅 Good morning! {date_str}"
    line2 = f"☀️ Now: {temp_c}°C (feels like: {feels_c}°C)"
    line3 = f"📊 Max: {max_c}°C / Min: {min_c}°C"

    if rain_chance >= 20:
        line3 += f" | 🌧 Rain: {rain_chance}% ({total_rain_mm:.1f} mm)"

    return "\n".join([line1, line2, line3])


def main() -> None:
    url = f"https://wttr.in/{LOCATION}?format=j1&m"
    try:
        data = fetch(url)
    except Exception as e:
        print(f"ERROR: Failed to fetch weather: {e}", file=sys.stderr)
        sys.exit(1)

    message = format_message(data)
    print(message)  # also log to stdout (visible in cron logs)
    send_telegram(message)


if __name__ == "__main__":
    main()
