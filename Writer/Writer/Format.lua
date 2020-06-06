--[[Book Format Description
The book format is a binary encoding. There is no formatting stack or "end bold" tags; the format simply indicates what will be used from now on.
All formatting is cleared to defaults after every page break (including chapters) and so non-default formatting must be repeated. This allows the scripts to not have to parse through the entire book to see what formatting to use on the last page (assuming that the writer used at least one page break).
	> If the book reader doesn't know whether a page should be on the left or right (ex because the user jumped to the middle from a bookmark), it should just put the content on the left page. If the user goes to the previous page until they hit the beginning of the book, this may cause a page to appear on the left when it should have been on the right, but this is okay.

A book is represented by a ModuleScript that will always have a source "return [==[bookFormattingAndContentHere]==]". In that string is the format being described in this file.

Format indicators are characters not used by the user for writing text (character bytes 0-8, 11-31, and 127), followed by any needed arguments.

Notes:
	A single ModuleScript can contain 199,999 characters. These characters can have any encoding (unlike the data stores which must be valid utf-8), with the exception that we mustn't end the text's block string prematurely (as everything must result in valid Lua). As a consequence, we can use any character from \0 to \255 via string.char/string.byte, so long as we replace every instance of ]==] (whether this appears in the formatting encoding or in the book's content) with an special sequence:
			What it is in the formatting or book content <-> What it is in the ModuleScript
			\31\31 <-> \31\31\0
			]==] <-> \31\31\1
			Note: ]==] is the same as \93\61\61\93
		Traditionally '\' is used as an escape character (like in '\n'). Here we use a character that is never seen in text and never starts a format indicator; it's repeated a second time to minimize overlap with format arguments.
		For example, if the format happened to have \3\31\31\5, we would replace that with \3\31\31\0\5 in the ModuleScript.
		Thus, when storing \31\5, to store this in the script, it would be replaced with \31\0\5. Whenever ]==] is detected, it is similarly converted to \31\1.
	A "flex" is a flexible integer storage type which uses 1 bit to indicate whether the integer continues into the next byte or not. A flex can use as many bytes as it needs, enabling it to encode arbitrarily large unsigned integers.
	String and list format arguments/descriptions are encoded with a flex length.

Header:
	encoding version (flex)
		If someone's working on a book with format v1, we don't want their work to be thrown out if we update the book formatting to v2. This lets the plugin know to update a book to the new format.
	authorId (flex)
	bookName (string)
	tags (list of string)
	#page breaks (flex), followed by the list of page breaks (3-byte index of where the chapter signifier or page break character starts) - this includes the first page (which is always a chapter of some kind)
		3 bytes supports a length of nearly 17 million characters, which far exceeds the maximum  allowed in a ModuleScript (or contained in any published book).
		A flex encoding 
		These indices are meant to let the reader script jump ahead and begin parsing at any page break.
	default formatting (string). This is automatically calculated to be the formatting that is needed the most frequently after the start of a page break. For example, if the author uses bold everywhere (and no other formatting), this string will indicate bold text, and there will not need to be any formatting after each page break to indicate that the text is bold.

Main text:
	Note: any time a new paragraph starts, this effectively adds a newline unless there's no text on the current line.
	"# name" indicates the string.char(#) and indicator name, followed by its "arguments"
	\0 font, font enum (can just use Enum.Font's values)
	\1 effect, effect enum (1 bit for bold, italics, underline, strikethrough, superscript, subscript, spoiler effect)
	\2 image, image ID length, image ID (flex encoding), 2-byte pixel width, 2-byte pixel height, (2 bit horizontal alignment, 1 bit for whether there is a border around the image, 1 bit indicates whether to open a "caption" box that must be ended with the "end" character [it would show up beneath the image], 1 bit for whether there's a border around that caption or not)
	\3 chapter signifier, chapter number or negative chapter name length followed by the chapter name in plain text
		> note: if someone jumps to a chapter (or bookmark), just start the chapter on the left page for simplicity
	\4 text size, desired text size (1 byte encoding since Roblox's max is 100 and we should cap it lower if we want to allow scaling)
	\5 text color [this is uncertain; ignore for now], 1 byte r, g, and b values (so 127 is max so have to * (255/127) and round)
		> Note that we might limit what we allow players to select; we might let them select multiple colors for light vs dark theme
	\6 footnote, footnote character (typically any number or letter) (in the reader, it will be wrapped in [] and superscripted)
	\7 horizontal line (considered its own paragraph)
	\8 block quote start (indent everything following this; this starts a new paragraph)
	\9 == "\t"
	\10 == "\n"
	\11 page break
	\12 paragraph formatting, paragraph enum (2 bits for alignment left/center/right/justified [if we want to support justified], 1 bit for block quote or not, remaining bits unused). This starts a new paragraph.
	\13 [normally "\r"] new list, list appearance enum (1 byte - differentiates between bullet points, numbers, letters, etc). If this appears inside of another list, it is indented until the sublist is ended.
	\14 new list item (not required immediately after the start of a new list); this implies a new line if not on a blank one. If a new line exists in the text, it is indented but doesn't start a new item.
		> Note that we do not want to support customizing line spacing as the author, but only as the reader.
	\15-30 unused; we can use for tables, math expressions, boxes of text/borders, diagrams, styles, etc.
	\31 starts an escape sequence
	\32-126 are the various characters and symbols we type with
	\127 [a "delete" character] ends a list or table; also ends a segment of text (to make it fast for the parser to skip segments of text - when the parser is done, we should do performance tests using a variety of book sizes and formats to see if ending text segments makes a difference).
	\128+ start of utf-8 (to be treated the same as \32-126). If not using an "end of text" signifier, these can be skipped using utf8.offset(text, 2, curIndex). Note that valid utf8 encoding does not have "continuation characters" in the \0-127 range, so searching for the "end" format indicator is safe.

If the user pastes in characters that form illegal utf8 (utf8.len(pastedInText) will return (nil, indexOfIllegalByte) if it's illegal), the illegal characters should be discarded by  deleting one byte at a time (from the index returned from utf8.len) until the remainder is valid.
]]