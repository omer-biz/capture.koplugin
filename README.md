# KOReader Org-Capture Plugin

**Capture highlights from KOReader directly into Org-mode files.**

This plugin allows you to:

* Capture selected text from any book or document.
* Use templates to format captures with metadata (book, author, page, timestamp).
* Append captures to a global inbox or per-book Org files.
* Dynamically manage and edit templates from within KOReader.

## Features

* Template-based captures (`%i` for highlight, `%b` for book title, `%p` for page, etc.)
* Flexible target paths with variable expansion (same as above)
* Automatic folder creation and safe file appending
* Full-screen editable capture dialog
* Works with KOReader’s built-in highlights system

## Installation

1. Copy the plugin folder to `KOReader/plugins/`.
2. Restart KOReader.
3. Configure templates and capture targets via the plugin menu.

## Usage

1. Select text in a book.
2. Open the highlight dialog.
3. Choose **Capture (Org)**.
4. Edit or confirm your capture entry.
5. The plugin appends it to the configured Org file.

By default your captures will go into `koreader/org/inbox.org`.
To configure the plugin goto `tools -> Capture` usaually on the second page.

## Demo

[![Main](demo/main.gif)](demo/main.gif)

Main Workflow

[![Overview](demo/overview.gif)](demo/overview.gif)

Overview
