-- Examples and explanations start with '--'
local data = {
	Title = "",
	--		Title = "Book Template",

	AuthorIds = {},
	--		AuthorIds = {false, 1},
	-- The list of Roblox user ids for each author.
	-- Use false for anonymous users or if the author elects for an author name other than their username.

	AuthorNames = {},
	--		AuthorNames = {"Anonymous", "ROBLOX"},
	-- This must be in the same order as authorIds.

	CustomAuthorLine = "",
	--		CustomAuthorLine = "Mystery Person (author) & Roblox (editor)"
	-- This example would show up on the cover page as "By: Mystery Person (author) & Roblox (editor)".
	-- If left blank, the cover page would (in this example) display "By: Anonymous and ROBLOX"
	-- Note: always list the authorNames, regardless of if you have a customAuthorLine.

	AuthorsNote = [=[]=],
	--		AuthorsNote = [=[This is my _cool_ book!]=],
	-- Can be left blank. Supports all formatting used for Content below. This can span multiple pages.

	Genres = {},
	--		Genres = {"Roblox Groups", "History"},
	-- Refer to the Genre Catalog script for a list of available genres

	Cover = 0,
	--		Cover = 428733812,
	-- This example refers to the image at http://www.roblox.com/asset/?id=428733812
	-- Leaving this as 0 will result in a transparent cover.

	Librarian = "",
	--		Librarian = "ClanDrone",
	-- Your username/nickname

	PublishDate = "",
	--		PublishDate = "01/30/2020",
	-- Always in MM/DD/YYYY format.

	-- You can also customize the book's Part Color (or BrickColor), as well as the TitleColor and TitleOutlineColor Color3Values.

	-- You may have any number of Image# lines:
	Image1 = 0,
	Image2 = 0,
	-- For example,
	--		Image1 = 5230133461,
	-- They work just like "Cover" and can be referenced using the tag <image1> or <image2>.
	-- You can also skip using Image1/Image2 and just specify <image,5230133461> instead.

	UseLineCommands = false,
	-- If UseLineCommands is true, newlines are ignored and you must specify <line> or <dline> to put words on a new line.
	-- If UseLineCommands is false, you aren't allowed to use <line> / <dline> and every newline is part of the book. It is recommended to turn word wrapping on in this case.

	-- To enable word wrap in Studio, go to File > Studio Settings > Type 'Wrap' in the search bar > Check the "Text Wrapping" box.

	--[=[
	"Content" is where the book content goes.
	Example:

	Content = [==[
First page of book content<page>Second page
]==],

	------------------------
	-- Formatting Options --
	------------------------

*Italics*
**Bold**
__Underline__
~~Strikethrough~~

	-------------------------
	-- Escaping Characters --
	-------------------------
	If you want to use the characters *, _, ~, <, or >, you should escape them by putting a \ before it. If you want to have a \ character show up, use two of them in a row. Examples:

This is normal text
*This is italicized*
\*This line just has \*s on it; it has no italics\*
Here is a single backslash: \\

	Other than italics, here is how the above text would appear:

This is normal text
This is italicized
*This line just has *s on it; it has no italics*
Here is a single backslash: \

	----------
	-- Tags --
	----------

	There are a few types of tags:
	1. Tags that insert something at the current location (such as an image)
	2. Tags that do something at the current location (such as start a new page)
	3. Tags that affect all future text until another tag of the same type says otherwise (font name, color, and size are like this)
	4. Tags that affect all text until you close them.

	To specify a tag, wrap the tag name in <>. The tag name is case-insensitive (so "<Page>" means the same thing as "<page>"). Some tags accept arguments, which are separated by commas. If the tag needs to be closed, use </tag name>.

	-------------------------
	-- Tags : Font Options --
	-------------------------

<font name>
	applies that font until a new font is specified, or until </font>, which sets the font back to the book's default. Valid names are any Roblox font name (including Arial, Cartoon, SourceSans, etc).

<color option>
	applies that color, or its dark mode equivalent, both of which come from a preset list (<pink>, <green>, etc), to the rest of the text until a new color tag is specified, or until </color>, which sets the color back to the book's default.
	Options:
		<default>
		<red>
		<orange>
		<yellow>
		<green>
		<blue>
		<indigo>
		<purple>
		<violet>
		<pink>
		<brown>
		<gray> / <grey>
		<nearblack>
		<black>
	(In dark mode, dark colors show up light; for instance, black shows up as white.)

<tiny>, <small>, <normal>, <large>, and <huge>
	Specify the size of the text. All books should use "normal" for the majority of their text. Only use "tiny"/"huge" for small amounts of text (for the sake of the readers).

<header,text>
	Creates a header (will always be on its own line). The "text" can be formatted with bold/italics/etc and colors, but nothing else.

<sub,text> and <sup,text>
	Makes "text" subscript/superscript
<sub> and <sup>
	Makes the text following it subscript/superscript until "</sub>" or "</sup>" respectively.

	-------------------------------
	-- Tags: Sections / Chapters --
	-------------------------------

Sections and chapters are the same thing, except that chapters start on a new page and are always centered.

<section>
	Creates a new section/chapter with name "Chapter 1", "Chapter 2", etc
<section,name>
	Creates a new section/chapter with the specified name
	The name supports formatting with bold/italics/etc and colors, but nothing else.
<section2,name,text>
	Creates a new section/chapter
	"name" is what shows up in navigation
	"text" is what shows up on the page.
	The name and text support formatting with bold/italics/etc and colors, but nothing else.
	Note that all commas within the name and text arguments must be escaped. For example, if the name is to be "Well, maybe?" and the text is to be "Well, maybe!" Then the correct command (with a diagram of explanation beneath it) is:
<section2,Well\, maybe?,Well\, maybe!>
 ^^^^^^^^     ^^       ^    ^^
  tag name     |       |     another escaped comma
               |       |
    escaped comma,     |
    part of 'name'     |
                comma separating 'name'
                from 'text'

	You can also use "chapter" instead of "section" if you want to start on a new page:
<chapter,Chapter 1: The Beginning>

	If you want to start the chapter on the next *left* page, use:

<turn><chapter,Chapter 1: The Beginning>

	-------------------------------
	-- Tags: Spacing / Alignment --
	-------------------------------

<page>
	Goes to the next page

<turn>
	Goes to the next left page (requiring the reader to turn the page)

<line> and <dline>
	<line> starts a new line; <dline> starts a new line after skipping a line.
	These are only valid if you have set UseLineCommands to true.

<left>, <center> / <centre>, <right>
	Creates a new line/paragraph with the specified alignment

<indent,tab> or <indent,newline> or <indent,none> / <indent>
	Sets the indent for future paragraphs (the default being a tab).
	You can use any one of these options:
	tab: paragraphs are indented 5 spaces
	newline: paragraphs have no indent but are automatically separated by a newline
	none: paragraphs have no indent and aren't separated by anything automatically
	You can also specify an arbitrary indent. For instance, if you wanted each paragraph to start with ">", you'd use:
<indent,\>>
	(The "\" is to escape the ">")
	Similarly, if you wanted each paragraph to start with " ~ ", you'd use:
<indent, ~ >

	-----------------
	-- Tags: Other --
	-----------------

<bar>
	Fills the current line with a solid horizontal line
<bar,string>
	Fills the current line with the specified string
	For example,
<bar,->
	would produce a line filled with ----------

<pagenumbering,style>
	Indicates what format page numbers should be displayed from this page onward. Valid style options and an example beside each:
	<pagenumbering,number> 1
	<pagenumbering,dash> -1-
	<pagenumbering,page> Page 1
	<pagenumbering,pg> Pg 1

<imageX,widthxheight,alignment,nowrap,ratior> or <imageX,widthw,heighth,alignment,nowrap,ratior>
	Creates an image. Arguments can be in any order and most are optional. Explanation of each part of the command:
	imageX refers to Image1, Image2, etc (only valid if you have specified such an image above).
		Alternatively, you can say <image,id> where 'id' is the number at the end of the image link.

	widthxheight (ex: 100x50) and widthw,heighth (ex: 100w,50h) specifies the percentage of the width and height of a page they take up. The examples above of 100x50 would be 100% the width of a page and 50% the height of a page.
		Default: 100% of the page

	alignment can be either left, right, or center
		Default: center

	nowrap: If an image is left or right aligned and has wrap enabled, any remaining space in the horizontal lines it takes up will be filled with text. (This argument does nothing for center alignment, which never wraps text.)
		Default: false (that is, the default is to allow wrapping)

	ratior: aspect ratio (ex 1r). You can also say "square" to mean "1r". An aspect ratio of 1.5 means that the image is 50% wider than it is high. Note that the aspect ratio is applied after the size has been set.

	Examples:
<image1,50x50,right>
	This creates a right-aligned image displaying the Image1 specified above with a width and height of 50%. The image will be stretched to fit the 50% width and height.
<image,12113484,50x50,left,2r>
	This creates a left-aligned image with max size of 50% and an aspect ratio of 2 (twice as wide as it is high) showing http://www.roblox.com/asset/?id=12113484
	Note that the text will be positioned as if the image were 50% of the page width and 50% of the page height, even though the image will maintain the aspect ratio specified.

<clear>
	This indicates to move past any images that are to the left or right; it also starts a new paragraph.
	Example usage:
<image1,25x50,left>Text to the side of the image
<clear>Text underneath the image

	-- Note: Text Wrapping Limitations --
	The system supports up to 2 images on the same line if one is left-aligned and the other is right-aligned. Text can be between them (with any alignment) if the images aren't too wide.

	]=]--

	Content = [=[

]=],
}





-- Never modify this line:
require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, data)