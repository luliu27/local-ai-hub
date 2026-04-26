#!/usr/bin/env python3
"""Convert a web article to EPUB format with embedded images."""

import sys
import requests
from bs4 import BeautifulSoup
from ebooklib import epub
from urllib.parse import urljoin, urlparse
import os
import re
import hashlib
import shutil


def slugify(text):
    """Convert text to a safe filename: lowercase, replace spaces/wild chars with hyphens."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return re.sub(r'-+', '-', text) or "untitled"


def main():
    if len(sys.argv) < 2:
        print("Usage: uv run convert.py <URL>")
        sys.exit(1)

    URL = sys.argv[1]

    # Download the article page
    r = requests.get(URL)
    soup = BeautifulSoup(r.content, "html.parser")

    # Resolve relative image URLs
    def resolve_url(src):
        if not src:
            return src
        if src.startswith("data:") or src.startswith("//"):
            return src
        if src.startswith("http://") or src.startswith("https://"):
            return src
        return urljoin(URL, src)

    # Extract title — try Ghost class, then h1, then og:title, then <title>
    title_tag = soup.find("h1", class_="gh-article-title")
    if not title_tag:
        title_tag = soup.find("h1")
    if not title_tag:
        og_title = soup.find("meta", attrs={"property": "og:title"}) or soup.find("meta", attrs={"name": "twitter:title"})
        if og_title and og_title.get("content"):
            TITLE = og_title["content"].strip()
        else:
            title_tag = soup.find("title")
            TITLE = title_tag.get_text(strip=True) if title_tag else "Untitled"
    else:
        TITLE = title_tag.get_text(strip=True) or "Untitled"

    OUTPUT = f"{slugify(TITLE)}.epub"

    # Find article content — try Ghost, then article/main/body fallbacks
    content_section = soup.find("section", class_="gh-content")
    if not content_section:
        for tag_name in ["article", "main"]:
            for cls in [None, "post-content", "article-content", "newsletter-content", "blog-content"]:
                kwargs = {"class": cls} if cls else {}
                content_section = soup.find(tag_name, kwargs)
                if content_section and len(content_section.find_all("p")) >= 3:
                    break
            if content_section:
                break
    if not content_section:
        # Last resort: pick body or largest element with 5+ paragraphs
        best = None
        for el in soup.find_all(True):
            paras = len(el.find_all("p"))
            if paras >= 5 and (best is None or paras > len(best.find_all("p"))):
                best = el
        content_section = best or soup.find("section") or (soup.body if soup else None)
    if not content_section:
        raise ValueError("Could not find article content on this page")
    for el in content_section.find_all(["script", "style", "nav", "footer", "header"]):
        el.decompose()

    # Download images and build mapping of original src -> EPUB filename
    IMG_DIR = "images"
    os.makedirs(IMG_DIR, exist_ok=True)
    image_map = {}

    try:
        for img in content_section.find_all("img"):
            src = img.get("src") or img.get("data-src") or ""
            if not src or src.startswith("data:"):
                continue

            ext = ".png"
            for e in [".webp", ".jpg", ".jpeg", ".svg", ".gif", ".avif"]:
                if e in src.lower():
                    ext = e
                    break

            full_url = resolve_url(src)
            hash_id = hashlib.md5(full_url.encode()).hexdigest()[:8]
            fname = f"img_{hash_id}{ext}"

            img_r = requests.get(full_url, timeout=15)
            with open(os.path.join(IMG_DIR, fname), "wb") as f:
                f.write(img_r.content)

            image_map[full_url] = fname

            # Remove small dimension attributes from lazy-load placeholders
            for attr in ["height", "width"]:
                if attr in img.attrs:
                    val = img[attr].strip()
                    if "." not in val:
                        try:
                            v = int(val)
                            if 0 <= v < 20:
                                del img[attr]
                        except ValueError:
                            del img[attr]

            # Set src to flat path matching the EPUB manifest entry
            img["src"] = f"images/{fname}"

        # Unwrap figure/figcaption while preserving children
        for tag in ["figure", "figcaption"]:
            for el in content_section.find_all(tag):
                el.unwrap()

        for iframe in content_section.find_all("iframe"):
            iframe.decompose()

        cleaned_html = str(content_section)

        # Verify all image references use correct paths
        html_check = BeautifulSoup(cleaned_html, "html.parser")
        for img in html_check.find_all("img"):
            s = img.get("src", "")
            assert s.startswith("images/"), f"Bad image src: {s}"

        # --- Build EPUB ---
        book = epub.EpubBook()
        book.set_identifier(slugify(TITLE))
        book.set_title(TITLE)
        book.set_language("en")
        book.add_author("Unknown", file_as="Unknown", role="auth")

        css = """
            @namespace epub "http://www.idpf.org/2007/ops";
            body { font-family: Georgia, 'Times New Roman', serif; line-height: 1.8; margin: 1em; }
            h1, h2, h3 { font-family: Georgia, 'Times New Roman', serif; margin-top: 1.5em; margin-bottom: 0.5em; }
            h1 { font-size: 1.8em; } h2 { font-size: 1.4em; } h3 { font-size: 1.2em; }
            p { margin-top: 0.8em; margin-bottom: 0.8em; text-align: justify; }
            img { max-width: 100%; height: auto; display: block; margin: 1em auto; }
            a { color: #0034F6; text-decoration: none; } ul, ol { padding-left: 1.5em; }
        """

        style = epub.EpubItem(
            uid="style",
            file_name="css/style.css",
            media_type="text/css",
            content=css.encode("utf-8"),
        )
        book.add_item(style)

        chapter = epub.EpubHtml(title=TITLE, file_name="article.xhtml", lang="en")
        safe_title = re.sub(
            r'[&<>"]',
            lambda m: {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[m.group(0)],
            TITLE,
        )
        chapter.content = f"""<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>{safe_title}</title>
<link rel="stylesheet" type="text/css" href="css/style.css"/></head>
<body>{cleaned_html}</body>
</html>"""
        book.add_item(chapter)

        # Add images to EPUB manifest
        for orig_src, fname in image_map.items():
            img_id = hashlib.md5(orig_src.encode()).hexdigest()[:8]
            with open(os.path.join(IMG_DIR, fname), "rb") as f:
                img_data = f.read()
            media_type = {
                "png": "image/png",
                "jpg": "image/jpeg",
                "jpeg": "image/jpeg",
                "webp": "image/webp",
                "gif": "image/gif",
            }.get(fname.rsplit(".", 1)[-1], "image/png")
            epub_img = epub.EpubItem(
                uid=f"img_{img_id}",
                file_name=f"images/{fname}",
                media_type=media_type,
                content=img_data,
            )
            book.add_item(epub_img)

        book.spine = ["nav", chapter]
        epub.write_epub(OUTPUT, book, {})

        print(f"Title: {TITLE}")
        print(f"Saved: {OUTPUT}")
    finally:
        # Always clean up temp files, even if EPUB creation failed
        shutil.rmtree(IMG_DIR, ignore_errors=True)


if __name__ == "__main__":
    main()
