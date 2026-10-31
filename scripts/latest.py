#!/usr/bin/env python3
"""Select the latest *published stable* KDE Plasma source version."""
from __future__ import annotations

import os
import re
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

INDEX = "https://download.kde.org/stable/plasma/"
ARCHIVE = "plasma-login-manager-{ver}.tar.xz"
VERSION_PATTERN = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)/?")


class Versions(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.versions: set[tuple[int, int, int]] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        for key, value in attrs:
            if key == "href" and value:
                candidate = value.strip("./")
                if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", candidate):
                    a, b, c = (int(p) for p in candidate.split("."))
                    self.versions.add((a, b, c))


def download(url: str, method: str = "GET") -> bytes:
    request = Request(url, headers={"User-Agent": "plasma-login-manager-opensuse-ci/1.0"}, method=method)
    with urlopen(request, timeout=30) as response:
        return response.read()


def latest() -> str:
    parser = Versions()
    parser.feed(download(INDEX).decode("utf-8", errors="replace"))
    if not parser.versions:
        raise RuntimeError("Official KDE Plasma release index returned no stable versions")

    for parts in sorted(parser.versions, reverse=True):
        version = ".".join(str(x) for x in parts)
        name = ARCHIVE.format(ver=version)
        try:
            # Do not pick an incomplete release directory without the login manager
            # or its KDE signature; earlier stable versions can still be chosen.
            download(f"{INDEX}{version}/{name}", "HEAD")
            download(f"{INDEX}{version}/{name}.sig", "HEAD")
            return version
        except (HTTPError, URLError):
            continue
    raise RuntimeError("No signed, published Plasma Login Manager stable release found")


if __name__ == "__main__":
    version = latest()
    print(version)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as file:
            file.write(f"version={version}\n")
