# VideoChapter

This is a cli based program for showing the timestamps and chapter names in a
media file with embedded chapters.

It's quite useful for previewing media files in a file browser.

## Usage
The program reads json from stdin, specifically the JSON output from running
`mediainfo --output=JSON`.

```
> mediainfo --output=JSON haskell-tutorial.mp4 | videoChapter

01:02:45

- 00:00     intro
- 01:13     installation
- 03:12     comments
- 03:46     data types
- 06:46     math functions
- 08:52     t
- 12:23     lists
- 13:07     operator
- 14:52     operator
- 15:10     head / last
- 15:43     take
- 16:14     elem
- 17:24     create range
- 19:50     cycle
- 20:10     operator
```
