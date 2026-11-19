# win-kotofetch
a version of [kotofetch](https://github.com/hxpe-dev/kotofetch) but easier and only for windows.

***this thing is existing cuz the kotofetch.exe file was crashing on the real thing***

it uses WIFI to get the [quotes](https://github.com/hxpe-dev/kotofetch/tree/main/quotes)

## how to use it:

1. download the [.zip file](https://github.com/Shadowniko1/win-kotofetch/releases/download/win-kotofetch/win-kotofetch.zip)
2. unzip it
3. open powershell, get in the derictory where the both files are
4. type `./kotofetch.cmd` and it should start
5. you can get the modes when you type `./kotofetch.cmd -listmodes` (thoose are meaning what quote u get)

## commands:
| Option | Description | Default |
|---|---|---|
| `-Modes a,b` | Only use these quote files (names without `.toml`) | all |
| `-ListModes` | List the available quote files | |
| `-Translation x,y` | What to show under the quote: `none`, `english`, `romaji`, `furigana`. Combine with commas; they are shown in the order given | `english` |
| `-FuriganaPosition` | Show furigana `above` or `below` the Japanese text | `below` |
| `-QuoteColor` | Color of the Japanese text: a name or hex such as `"#a3be8c"` | `cyan` |
| `-TranslationColor` | Color of the translation, furigana and source | `dim` |
| `-BorderColor` | Color of the border | `dim` |
| `-NoBold` | Turn off bold Japanese text | bold |
| `-NoBorder` | Hide the border | border on |
| `-Square` | Square corners instead of rounded | rounded |
| `-NoSource` | Hide the source line | shown |
| `-Left` | Left-align instead of centering | centered |
| `-Width N` | Maximum text width before wrapping (`0` = automatic) | `0` |
| `-HorizontalPadding N` | Space left and right inside the border | `2` |
| `-VerticalPadding N` | Empty lines above and below inside the border | `0` |
| `-Seed N` | Fixed random seed, so you get the same quote every time (`0` = random) | `0` |
| `-Refresh` | Re-download the quotes from GitHub now | automatic, weekly |
| `-Offline` | Never use the network, only the cache | |
| `-Repo user/name` | Take quotes from a different GitHub repo | `hxpe-dev/kotofetch` |
| `-Branch name` | Branch to take quotes from | `main` || Option | Description | Default |
|---|---|---|
| `-Modes a,b` | Only use these quote files (names without `.toml`) | all |
| `-ListModes` | List the available quote files | |
| `-Translation x,y` | What to show under the quote: `none`, `english`, `romaji`, `furigana`. Combine with commas; they are shown in the order given | `english` |
| `-FuriganaPosition` | Show furigana `above` or `below` the Japanese text | `below` |
| `-QuoteColor` | Color of the Japanese text: a name or hex such as `"#a3be8c"` | `cyan` |
| `-TranslationColor` | Color of the translation, furigana and source | `dim` |
| `-BorderColor` | Color of the border | `dim` |
| `-NoBold` | Turn off bold Japanese text | bold |
| `-NoBorder` | Hide the border | border on |
| `-Square` | Square corners instead of rounded | rounded |
| `-NoSource` | Hide the source line | shown |
| `-Left` | Left-align instead of centering | centered |
| `-Width N` | Maximum text width before wrapping (`0` = automatic) | `0` |
| `-HorizontalPadding N` | Space left and right inside the border | `2` |
| `-VerticalPadding N` | Empty lines above and below inside the border | `0` |
| `-Seed N` | Fixed random seed, so you get the same quote every time (`0` = random) | `0` |
| `-Refresh` | Re-download the quotes from GitHub now | automatic, weekly |
| `-Offline` | Never use the network, only the cache | |
| `-Repo user/name` | Take quotes from a different GitHub repo | `hxpe-dev/kotofetch` |
| `-Branch name` | Branch to take quotes from | `main` |

###
[@hxpe-dev](https://github.com/hxpe-dev) sorry for taking the idea and using the quotes folder without permisson
