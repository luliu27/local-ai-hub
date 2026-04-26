---
name: web-to-epub
description: Convert blog posts, articles, and newsletter content from web URLs into clean EPUB files with embedded images. Use this skill whenever the user wants to save an article for offline reading, convert a URL to EPUB, export content to Apple Books/Kindle format, or read-later a web page as an ebook. Trigger on requests like "convert this to epub", "save this article as epub", "read this offline", "export to epub", or when the user provides a URL and mentions reading it in a book app.
---

# web-to-epub

## Overview

Convert blog/article webpage content into a clean EPUB file with embedded images, suitable for reading in Apple Books or any EPUB reader.

## When to Use This Skill

Use this skill whenever the user wants to:
- Save a blog post, article, or newsletter issue as an offline-readable EPUB
- Convert a URL (Ghost blogs, Medium-style sites, Substack-like newsletters, general article pages) into an epub file
- "Read later" format — download an article for reading in Apple Books/Kindle/PDF viewer without internet

## Prerequisites

Requires Python with these packages: `requests`, `beautifulsoup4`, `ebooklib`. If they are not available, install them via `uv pip install requests beautifulsoup4 ebooklib` (or use an existing `.venv`).

## Steps

### Determine the output filename

Fetch the webpage first to find its title. Extract the page `<title>` or the main `<h1>`. Sluggify it: lowercase, strip special characters, replace spaces with hyphens, collapse multiple hyphens. The EPUB filename is `{slugified-title}.epub` (e.g., `my-article-about-coffee.epub`).

### Download and parse the page

Use `requests.get()` to download the HTML. Parse it with BeautifulSoup (`html.parser`). Locate the main article body content. Ghost-based sites use `<section class="gh-content">`; fall back to `<article>`, `<main>`, or any element containing substantial paragraph text (5+ `<p>` tags). Remove all non-content elements: `<script>`, `<style>`, `<nav>`, `<header>`, `<footer>`.

### Download and embed images

For every `<img>` in the extracted article content:
1. Get the `src` attribute (try `data-src` as fallback; skip data URIs and relative URLs).
2. Determine file extension from URL (`png`, `jpg`, `jpeg`, `webp`, `svg`, `gif`, etc.). Default to `.png` if unclear.
3. Generate a deterministic filename using MD5 hash of the original URL: `img_{first8hex}.{ext}`.
4. Download the image and save it to a temp directory.
5. Remove spurious `height`/`width` attributes whose values are numeric single digits or zero (common when lazy-loading placeholders break).
6. Set the `<img src>` in the HTML to point to a flat path: `images/{filename}`.

After downloading images, unwrap `<figure>` and `<figcaption>` tags while preserving their children into the content flow. Remove any remaining `<iframe>` elements.

### Verify image links

Ensure every `<img>` tag in the cleaned HTML has an `src` starting with `images/`. If not, log a warning.

### Build the EPUB using ebooklib

1. Create an `epub.EpubBook()` and set metadata (identifier = sluggified title, language = "en", author = "Unknown").
2. Add inline CSS for readable serif rendering: Georgia/Times font family, 1.8 line-height, justified paragraphs, responsive images.
3. Create the EPUB content as a single XHTML chapter with the cleaned HTML body.
4. For each downloaded image, create an `EpubItem` with correct media type and add to manifest (href must match the `<img src>` paths).
5. Set spine = `["nav", <chapter>]`.
6. Write to `<slugified-title>.epub` using `epub.write_epub()`.

### Cleanup

Always remove temporary download directories after the EPUB is written, even if the write fails. Use `try/finally` to guarantee cleanup.

## Output

A single `.epub` file in the current working directory. Print both the article title and output filename on success.

<!--
Notes for future iterations:
- Ghost sites work particularly well; for other platforms (Substack, Medium), the gh-content fallback chain may need extension.
- The CSS hardcodes a blue link color (#0034F6). Consider making it configurable or extracting from the page's styles for better fidelity.
-->
