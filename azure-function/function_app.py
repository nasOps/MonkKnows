import logging
import os
import re
import time
from urllib.parse import quote

import azure.functions as func
import requests
from bs4 import BeautifulSoup

app = func.FunctionApp()

APP_URL = os.environ.get("APP_URL", "").rstrip("/")
CRAWLER_API_KEY = os.environ.get("CRAWLER_API_KEY", "")

SUPPORTED_LANGUAGES = {"en", "da", "de", "fr", "es"}

SEED_URLS = [
    "https://en.wikipedia.org/wiki/Ruby_(programming_language)",
    "https://en.wikipedia.org/wiki/PostgreSQL",
    "https://en.wikipedia.org/wiki/Docker_(software)",
    "https://en.wikipedia.org/wiki/DevOps",
    "https://en.wikipedia.org/wiki/Copenhagen",
    "https://da.wikipedia.org/wiki/Danmark",
    "https://en.wikipedia.org/wiki/Sinatra_(software)",
    "https://en.wikipedia.org/wiki/Nginx",
]


# Timer trigger — runs on schedule (e.g. every Sunday at 02:00 UTC).
# Uncomment schedule and set run_on_startup=False when ready for production.
@app.timer_trigger(
    schedule="0 0 2 * * 0",
    arg_name="my_timer",
    run_on_startup=False,
    use_monitor=False,
)
def crawler_timer(my_timer: func.TimerRequest) -> None:
    logging.info("Crawler triggered by timer")
    run_crawler()


# HTTP trigger — manual invocation via POST request.
# Useful for testing and on-demand crawls before enabling the schedule.
@app.route(route="crawl", methods=["POST"])
def crawler_http(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Crawler triggered by HTTP")
    try:
        count = run_crawler()
        return func.HttpResponse(f"Crawl complete: {count} pages indexed", status_code=200)
    except Exception as e:
        logging.error("Crawler failed: %s", e)
        return func.HttpResponse(f"Crawler failed: {e}", status_code=500)


def run_crawler() -> int:
    urls = _build_url_list()
    pages = []

    for url in urls:
        try:
            page = _scrape(url)
            if page:
                pages.append(page)
            else:
                logging.warning("Skipped (no content): %s", url)
        except Exception as e:
            logging.warning("Failed to scrape %s: %s", url, e)
        time.sleep(1)

    if pages:
        _post_pages(pages)

    logging.info("Crawl complete: %d pages indexed", len(pages))
    return len(pages)


def _build_url_list() -> list[str]:
    top_terms = _fetch_top_search_terms()
    dynamic_urls = [_wikipedia_url(term) for term in top_terms]
    seen = set()
    result = []
    for url in dynamic_urls + SEED_URLS:
        if url not in seen:
            seen.add(url)
            result.append(url)
    return result


def _fetch_top_search_terms(limit: int = 10) -> list[str]:
    try:
        response = requests.get(
            f"{APP_URL}/api/search-logs/top",
            params={"limit": limit},
            headers={"Authorization": f"Bearer {CRAWLER_API_KEY}"},
            timeout=10,
        )
        response.raise_for_status()
        return response.json().get("data", [])
    except Exception as e:
        logging.warning("Failed to fetch top search terms: %s", e)
        return []


def _wikipedia_url(term: str, lang: str = "en") -> str:
    encoded = quote(term.strip().replace(" ", "_"), safe="")
    return f"https://{lang}.wikipedia.org/wiki/{encoded}"


def _scrape(url: str) -> dict | None:
    response = requests.get(
        url,
        timeout=15,
        headers={"User-Agent": "MonkKnows-Crawler/1.0"},
        allow_redirects=True,
    )
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "lxml")

    title = _extract_title(soup, url)
    if not title:
        return None

    content = _extract_content(soup)
    if not content:
        return None

    return {
        "title": title,
        "url": url,
        "language": _detect_language(soup, url),
        "content": content[:50_000],
    }


def _extract_title(soup: BeautifulSoup, url: str) -> str | None:
    if "wikipedia.org" in url:
        heading = soup.find("h1", {"id": "firstHeading"})
        if heading:
            return heading.get_text(strip=True)

    title_tag = soup.find("title")
    if title_tag:
        return title_tag.get_text(strip=True).replace(" - Wikipedia", "").strip()

    return None


def _extract_content(soup: BeautifulSoup) -> str | None:
    for tag in soup.find_all(["script", "style", "nav", "footer"]):
        tag.decompose()

    main = (
        soup.find("div", class_="mw-parser-output")
        or soup.find("main")
        or soup.find("article")
        or soup.find("body")
    )

    if not main:
        return None

    return " ".join(main.get_text(separator=" ").split()) or None


def _detect_language(soup: BeautifulSoup, url: str) -> str:
    html_tag = soup.find("html")
    if html_tag:
        lang = html_tag.get("lang", "").split("-")[0].lower()
        if lang in SUPPORTED_LANGUAGES:
            return lang

    m = re.match(r"https?://(\w{2,3})\.wikipedia\.org", url)
    if m and m.group(1) in SUPPORTED_LANGUAGES:
        return m.group(1)

    return "en"


def _post_pages(pages: list[dict]) -> None:
    response = requests.post(
        f"{APP_URL}/api/pages",
        json={"pages": pages},
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {CRAWLER_API_KEY}",
        },
        timeout=30,
    )
    response.raise_for_status()
    logging.info("Posted %d pages: %s", len(pages), response.json())
