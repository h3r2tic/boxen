module xf.hybrid.Scintilla;

private {
	import tango.sys.SharedLib;
	import tango.util.log.Trace;
	import tango.stdc.stringz;
	import tango.text.convert.Format;
	import tango.stdc.stdio : printf;
}



alias uint uptr_t;
alias uint sptr_t;

enum {
	INVALID_POSITION = -1,
	SCI_START = 2000,
	SCI_OPTIONAL_START = 3000,
	SCI_LEXER_START = 4000,
	SCI_ADDTEXT = 2001,
	SCI_ADDSTYLEDTEXT = 2002,
	SCI_INSERTTEXT = 2003,
	SCI_CLEARALL = 2004,
	SCI_CLEARDOCUMENTSTYLE = 2005,
	SCI_GETLENGTH = 2006,
	SCI_GETCHARAT = 2007,
	SCI_GETCURRENTPOS = 2008,
	SCI_GETANCHOR = 2009,
	SCI_GETSTYLEAT = 2010,
	SCI_REDO = 2011,
	SCI_SETUNDOCOLLECTION = 2012,
	SCI_SELECTALL = 2013,
	SCI_SETSAVEPOINT = 2014,
	SCI_GETSTYLEDTEXT = 2015,
	SCI_CANREDO = 2016,
	SCI_MARKERLINEFROMHANDLE = 2017,
	SCI_MARKERDELETEHANDLE = 2018,
	SCI_GETUNDOCOLLECTION = 2019,
	SCWS_INVISIBLE = 0,
	SCWS_VISIBLEALWAYS = 1,
	SCWS_VISIBLEAFTERINDENT = 2,
	SCI_GETVIEWWS = 2020,
	SCI_SETVIEWWS = 2021,
	SCI_POSITIONFROMPOINT = 2022,
	SCI_POSITIONFROMPOINTCLOSE = 2023,
	SCI_GOTOLINE = 2024,
	SCI_GOTOPOS = 2025,
	SCI_SETANCHOR = 2026,
	SCI_GETCURLINE = 2027,
	SCI_GETENDSTYLED = 2028,
	SC_EOL_CRLF = 0,
	SC_EOL_CR = 1,
	SC_EOL_LF = 2,
	SCI_CONVERTEOLS = 2029,
	SCI_GETEOLMODE = 2030,
	SCI_SETEOLMODE = 2031,
	SCI_STARTSTYLING = 2032,
	SCI_SETSTYLING = 2033,
	SCI_GETBUFFEREDDRAW = 2034,
	SCI_SETBUFFEREDDRAW = 2035,
	SCI_SETTABWIDTH = 2036,
	SCI_GETTABWIDTH = 2121,
	SC_CP_UTF8 = 65001,
	SC_CP_DBCS = 1,
	SCI_SETCODEPAGE = 2037,
	SCI_SETUSEPALETTE = 2039,
	MARKER_MAX = 31,
	SC_MARK_CIRCLE = 0,
	SC_MARK_ROUNDRECT = 1,
	SC_MARK_ARROW = 2,
	SC_MARK_SMALLRECT = 3,
	SC_MARK_SHORTARROW = 4,
	SC_MARK_EMPTY = 5,
	SC_MARK_ARROWDOWN = 6,
	SC_MARK_MINUS = 7,
	SC_MARK_PLUS = 8,
	SC_MARK_VLINE = 9,
	SC_MARK_LCORNER = 10,
	SC_MARK_TCORNER = 11,
	SC_MARK_BOXPLUS = 12,
	SC_MARK_BOXPLUSCONNECTED = 13,
	SC_MARK_BOXMINUS = 14,
	SC_MARK_BOXMINUSCONNECTED = 15,
	SC_MARK_LCORNERCURVE = 16,
	SC_MARK_TCORNERCURVE = 17,
	SC_MARK_CIRCLEPLUS = 18,
	SC_MARK_CIRCLEPLUSCONNECTED = 19,
	SC_MARK_CIRCLEMINUS = 20,
	SC_MARK_CIRCLEMINUSCONNECTED = 21,
	SC_MARK_BACKGROUND = 22,
	SC_MARK_DOTDOTDOT = 23,
	SC_MARK_ARROWS = 24,
	SC_MARK_PIXMAP = 25,
	SC_MARK_FULLRECT = 26,
	SC_MARK_LEFTRECT = 27,
	SC_MARK_CHARACTER = 10000,
	SC_MARKNUM_FOLDEREND = 25,
	SC_MARKNUM_FOLDEROPENMID = 26,
	SC_MARKNUM_FOLDERMIDTAIL = 27,
	SC_MARKNUM_FOLDERTAIL = 28,
	SC_MARKNUM_FOLDERSUB = 29,
	SC_MARKNUM_FOLDER = 30,
	SC_MARKNUM_FOLDEROPEN = 31,
	SC_MASK_FOLDERS = 0xFE000000,
	SCI_MARKERDEFINE = 2040,
	SCI_MARKERSETFORE = 2041,
	SCI_MARKERSETBACK = 2042,
	SCI_MARKERADD = 2043,
	SCI_MARKERDELETE = 2044,
	SCI_MARKERDELETEALL = 2045,
	SCI_MARKERGET = 2046,
	SCI_MARKERNEXT = 2047,
	SCI_MARKERPREVIOUS = 2048,
	SCI_MARKERDEFINEPIXMAP = 2049,
	SCI_MARKERADDSET = 2466,
	SCI_MARKERSETALPHA = 2476,
	SC_MARGIN_SYMBOL = 0,
	SC_MARGIN_NUMBER = 1,
	SC_MARGIN_BACK = 2,
	SC_MARGIN_FORE = 3,
	SCI_SETMARGINTYPEN = 2240,
	SCI_GETMARGINTYPEN = 2241,
	SCI_SETMARGINWIDTHN = 2242,
	SCI_GETMARGINWIDTHN = 2243,
	SCI_SETMARGINMASKN = 2244,
	SCI_GETMARGINMASKN = 2245,
	SCI_SETMARGINSENSITIVEN = 2246,
	SCI_GETMARGINSENSITIVEN = 2247,
	STYLE_DEFAULT = 32,
	STYLE_LINENUMBER = 33,
	STYLE_BRACELIGHT = 34,
	STYLE_BRACEBAD = 35,
	STYLE_CONTROLCHAR = 36,
	STYLE_INDENTGUIDE = 37,
	STYLE_CALLTIP = 38,
	STYLE_LASTPREDEFINED = 39,
	STYLE_MAX = 255,
	SC_CHARSET_ANSI = 0,
	SC_CHARSET_DEFAULT = 1,
	SC_CHARSET_BALTIC = 186,
	SC_CHARSET_CHINESEBIG5 = 136,
	SC_CHARSET_EASTEUROPE = 238,
	SC_CHARSET_GB2312 = 134,
	SC_CHARSET_GREEK = 161,
	SC_CHARSET_HANGUL = 129,
	SC_CHARSET_MAC = 77,
	SC_CHARSET_OEM = 255,
	SC_CHARSET_RUSSIAN = 204,
	SC_CHARSET_CYRILLIC = 1251,
	SC_CHARSET_SHIFTJIS = 128,
	SC_CHARSET_SYMBOL = 2,
	SC_CHARSET_TURKISH = 162,
	SC_CHARSET_JOHAB = 130,
	SC_CHARSET_HEBREW = 177,
	SC_CHARSET_ARABIC = 178,
	SC_CHARSET_VIETNAMESE = 163,
	SC_CHARSET_THAI = 222,
	SC_CHARSET_8859_15 = 1000,
	SCI_STYLECLEARALL = 2050,
	SCI_STYLESETFORE = 2051,
	SCI_STYLESETBACK = 2052,
	SCI_STYLESETBOLD = 2053,
	SCI_STYLESETITALIC = 2054,
	SCI_STYLESETSIZE = 2055,
	SCI_STYLESETFONT = 2056,
	SCI_STYLESETEOLFILLED = 2057,
	SCI_STYLERESETDEFAULT = 2058,
	SCI_STYLESETUNDERLINE = 2059,
	SC_CASE_MIXED = 0,
	SC_CASE_UPPER = 1,
	SC_CASE_LOWER = 2,
	SCI_STYLEGETFORE = 2481,
	SCI_STYLEGETBACK = 2482,
	SCI_STYLEGETBOLD = 2483,
	SCI_STYLEGETITALIC = 2484,
	SCI_STYLEGETSIZE = 2485,
	SCI_STYLEGETFONT = 2486,
	SCI_STYLEGETEOLFILLED = 2487,
	SCI_STYLEGETUNDERLINE = 2488,
	SCI_STYLEGETCASE = 2489,
	SCI_STYLEGETCHARACTERSET = 2490,
	SCI_STYLEGETVISIBLE = 2491,
	SCI_STYLEGETCHANGEABLE = 2492,
	SCI_STYLEGETHOTSPOT = 2493,
	SCI_STYLESETCASE = 2060,
	SCI_STYLESETCHARACTERSET = 2066,
	SCI_STYLESETHOTSPOT = 2409,
	SCI_SETSELFORE = 2067,
	SCI_SETSELBACK = 2068,
	SCI_GETSELALPHA = 2477,
	SCI_SETSELALPHA = 2478,
	SCI_GETSELEOLFILLED = 2479,
	SCI_SETSELEOLFILLED = 2480,
	SCI_SETCARETFORE = 2069,
	SCI_ASSIGNCMDKEY = 2070,
	SCI_CLEARCMDKEY = 2071,
	SCI_CLEARALLCMDKEYS = 2072,
	SCI_SETSTYLINGEX = 2073,
	SCI_STYLESETVISIBLE = 2074,
	SCI_GETCARETPERIOD = 2075,
	SCI_SETCARETPERIOD = 2076,
	SCI_SETWORDCHARS = 2077,
	SCI_BEGINUNDOACTION = 2078,
	SCI_ENDUNDOACTION = 2079,
	INDIC_PLAIN = 0,
	INDIC_SQUIGGLE = 1,
	INDIC_TT = 2,
	INDIC_DIAGONAL = 3,
	INDIC_STRIKE = 4,
	INDIC_HIDDEN = 5,
	INDIC_BOX = 6,
	INDIC_ROUNDBOX = 7,
	INDIC_MAX = 31,
	INDIC_CONTAINER = 8,
	INDIC0_MASK = 0x20,
	INDIC1_MASK = 0x40,
	INDIC2_MASK = 0x80,
	INDICS_MASK = 0xE0,
	SCI_INDICSETSTYLE = 2080,
	SCI_INDICGETSTYLE = 2081,
	SCI_INDICSETFORE = 2082,
	SCI_INDICGETFORE = 2083,
	SCI_INDICSETUNDER = 2510,
	SCI_INDICGETUNDER = 2511,
	SCI_SETWHITESPACEFORE = 2084,
	SCI_SETWHITESPACEBACK = 2085,
	SCI_SETSTYLEBITS = 2090,
	SCI_GETSTYLEBITS = 2091,
	SCI_SETLINESTATE = 2092,
	SCI_GETLINESTATE = 2093,
	SCI_GETMAXLINESTATE = 2094,
	SCI_GETCARETLINEVISIBLE = 2095,
	SCI_SETCARETLINEVISIBLE = 2096,
	SCI_GETCARETLINEBACK = 2097,
	SCI_SETCARETLINEBACK = 2098,
	SCI_STYLESETCHANGEABLE = 2099,
	SCI_AUTOCSHOW = 2100,
	SCI_AUTOCCANCEL = 2101,
	SCI_AUTOCACTIVE = 2102,
	SCI_AUTOCPOSSTART = 2103,
	SCI_AUTOCCOMPLETE = 2104,
	SCI_AUTOCSTOPS = 2105,
	SCI_AUTOCSETSEPARATOR = 2106,
	SCI_AUTOCGETSEPARATOR = 2107,
	SCI_AUTOCSELECT = 2108,
	SCI_AUTOCSETCANCELATSTART = 2110,
	SCI_AUTOCGETCANCELATSTART = 2111,
	SCI_AUTOCSETFILLUPS = 2112,
	SCI_AUTOCSETCHOOSESINGLE = 2113,
	SCI_AUTOCGETCHOOSESINGLE = 2114,
	SCI_AUTOCSETIGNORECASE = 2115,
	SCI_AUTOCGETIGNORECASE = 2116,
	SCI_USERLISTSHOW = 2117,
	SCI_AUTOCSETAUTOHIDE = 2118,
	SCI_AUTOCGETAUTOHIDE = 2119,
	SCI_AUTOCSETDROPRESTOFWORD = 2270,
	SCI_AUTOCGETDROPRESTOFWORD = 2271,
	SCI_REGISTERIMAGE = 2405,
	SCI_CLEARREGISTEREDIMAGES = 2408,
	SCI_AUTOCGETTYPESEPARATOR = 2285,
	SCI_AUTOCSETTYPESEPARATOR = 2286,
	SCI_AUTOCSETMAXWIDTH = 2208,
	SCI_AUTOCGETMAXWIDTH = 2209,
	SCI_AUTOCSETMAXHEIGHT = 2210,
	SCI_AUTOCGETMAXHEIGHT = 2211,
	SCI_SETINDENT = 2122,
	SCI_GETINDENT = 2123,
	SCI_SETUSETABS = 2124,
	SCI_GETUSETABS = 2125,
	SCI_SETLINEINDENTATION = 2126,
	SCI_GETLINEINDENTATION = 2127,
	SCI_GETLINEINDENTPOSITION = 2128,
	SCI_GETCOLUMN = 2129,
	SCI_SETHSCROLLBAR = 2130,
	SCI_GETHSCROLLBAR = 2131,
	SC_IV_NONE = 0,
	SC_IV_REAL = 1,
	SC_IV_LOOKFORWARD = 2,
	SC_IV_LOOKBOTH = 3,
	SCI_SETINDENTATIONGUIDES = 2132,
	SCI_GETINDENTATIONGUIDES = 2133,
	SCI_SETHIGHLIGHTGUIDE = 2134,
	SCI_GETHIGHLIGHTGUIDE = 2135,
	SCI_GETLINEENDPOSITION = 2136,
	SCI_GETCODEPAGE = 2137,
	SCI_GETCARETFORE = 2138,
	SCI_GETUSEPALETTE = 2139,
	SCI_GETREADONLY = 2140,
	SCI_SETCURRENTPOS = 2141,
	SCI_SETSELECTIONSTART = 2142,
	SCI_GETSELECTIONSTART = 2143,
	SCI_SETSELECTIONEND = 2144,
	SCI_GETSELECTIONEND = 2145,
	SCI_SETPRINTMAGNIFICATION = 2146,
	SCI_GETPRINTMAGNIFICATION = 2147,
	SC_PRINT_NORMAL = 0,
	SC_PRINT_INVERTLIGHT = 1,
	SC_PRINT_BLACKONWHITE = 2,
	SC_PRINT_COLOURONWHITE = 3,
	SC_PRINT_COLOURONWHITEDEFAULTBG = 4,
	SCI_SETPRINTCOLOURMODE = 2148,
	SCI_GETPRINTCOLOURMODE = 2149,
	SCFIND_WHOLEWORD = 2,
	SCFIND_MATCHCASE = 4,
	SCFIND_WORDSTART = 0x00100000,
	SCFIND_REGEXP = 0x00200000,
	SCFIND_POSIX = 0x00400000,
	SCI_FINDTEXT = 2150,
	SCI_FORMATRANGE = 2151,
	SCI_GETFIRSTVISIBLELINE = 2152,
	SCI_GETLINE = 2153,
	SCI_GETLINECOUNT = 2154,
	SCI_SETMARGINLEFT = 2155,
	SCI_GETMARGINLEFT = 2156,
	SCI_SETMARGINRIGHT = 2157,
	SCI_GETMARGINRIGHT = 2158,
	SCI_GETMODIFY = 2159,
	SCI_SETSEL = 2160,
	SCI_GETSELTEXT = 2161,
	SCI_GETTEXTRANGE = 2162,
	SCI_HIDESELECTION = 2163,
	SCI_POINTXFROMPOSITION = 2164,
	SCI_POINTYFROMPOSITION = 2165,
	SCI_LINEFROMPOSITION = 2166,
	SCI_POSITIONFROMLINE = 2167,
	SCI_LINESCROLL = 2168,
	SCI_SCROLLCARET = 2169,
	SCI_REPLACESEL = 2170,
	SCI_SETREADONLY = 2171,
	SCI_NULL = 2172,
	SCI_CANPASTE = 2173,
	SCI_CANUNDO = 2174,
	SCI_EMPTYUNDOBUFFER = 2175,
	SCI_UNDO = 2176,
	SCI_CUT = 2177,
	SCI_COPY = 2178,
	SCI_PASTE = 2179,
	SCI_CLEAR = 2180,
	SCI_SETTEXT = 2181,
	SCI_GETTEXT = 2182,
	SCI_GETTEXTLENGTH = 2183,
	SCI_GETDIRECTFUNCTION = 2184,
	SCI_GETDIRECTPOINTER = 2185,
	SCI_SETOVERTYPE = 2186,
	SCI_GETOVERTYPE = 2187,
	SCI_SETCARETWIDTH = 2188,
	SCI_GETCARETWIDTH = 2189,
	SCI_SETTARGETSTART = 2190,
	SCI_GETTARGETSTART = 2191,
	SCI_SETTARGETEND = 2192,
	SCI_GETTARGETEND = 2193,
	SCI_REPLACETARGET = 2194,
	SCI_REPLACETARGETRE = 2195,
	SCI_SEARCHINTARGET = 2197,
	SCI_SETSEARCHFLAGS = 2198,
	SCI_GETSEARCHFLAGS = 2199,
	SCI_CALLTIPSHOW = 2200,
	SCI_CALLTIPCANCEL = 2201,
	SCI_CALLTIPACTIVE = 2202,
	SCI_CALLTIPPOSSTART = 2203,
	SCI_CALLTIPSETHLT = 2204,
	SCI_CALLTIPSETBACK = 2205,
	SCI_CALLTIPSETFORE = 2206,
	SCI_CALLTIPSETFOREHLT = 2207,
	SCI_CALLTIPUSESTYLE = 2212,
	SCI_VISIBLEFROMDOCLINE = 2220,
	SCI_DOCLINEFROMVISIBLE = 2221,
	SCI_WRAPCOUNT = 2235,
	SC_FOLDLEVELBASE = 0x400,
	SC_FOLDLEVELWHITEFLAG = 0x1000,
	SC_FOLDLEVELHEADERFLAG = 0x2000,
	SC_FOLDLEVELBOXHEADERFLAG = 0x4000,
	SC_FOLDLEVELBOXFOOTERFLAG = 0x8000,
	SC_FOLDLEVELCONTRACTED = 0x10000,
	SC_FOLDLEVELUNINDENT = 0x20000,
	SC_FOLDLEVELNUMBERMASK = 0x0FFF,
	SCI_SETFOLDLEVEL = 2222,
	SCI_GETFOLDLEVEL = 2223,
	SCI_GETLASTCHILD = 2224,
	SCI_GETFOLDPARENT = 2225,
	SCI_SHOWLINES = 2226,
	SCI_HIDELINES = 2227,
	SCI_GETLINEVISIBLE = 2228,
	SCI_SETFOLDEXPANDED = 2229,
	SCI_GETFOLDEXPANDED = 2230,
	SCI_TOGGLEFOLD = 2231,
	SCI_ENSUREVISIBLE = 2232,
	SC_FOLDFLAG_LINEBEFORE_EXPANDED = 0x0002,
	SC_FOLDFLAG_LINEBEFORE_CONTRACTED = 0x0004,
	SC_FOLDFLAG_LINEAFTER_EXPANDED = 0x0008,
	SC_FOLDFLAG_LINEAFTER_CONTRACTED = 0x0010,
	SC_FOLDFLAG_LEVELNUMBERS = 0x0040,
	SC_FOLDFLAG_BOX = 0x0001,
	SCI_SETFOLDFLAGS = 2233,
	SCI_ENSUREVISIBLEENFORCEPOLICY = 2234,
	SCI_SETTABINDENTS = 2260,
	SCI_GETTABINDENTS = 2261,
	SCI_SETBACKSPACEUNINDENTS = 2262,
	SCI_GETBACKSPACEUNINDENTS = 2263,
	SC_TIME_FOREVER = 10000000,
	SCI_SETMOUSEDWELLTIME = 2264,
	SCI_GETMOUSEDWELLTIME = 2265,
	SCI_WORDSTARTPOSITION = 2266,
	SCI_WORDENDPOSITION = 2267,
	SC_WRAP_NONE = 0,
	SC_WRAP_WORD = 1,
	SC_WRAP_CHAR = 2,
	SCI_SETWRAPMODE = 2268,
	SCI_GETWRAPMODE = 2269,
	SC_WRAPVISUALFLAG_NONE = 0x0000,
	SC_WRAPVISUALFLAG_END = 0x0001,
	SC_WRAPVISUALFLAG_START = 0x0002,
	SCI_SETWRAPVISUALFLAGS = 2460,
	SCI_GETWRAPVISUALFLAGS = 2461,
	SC_WRAPVISUALFLAGLOC_DEFAULT = 0x0000,
	SC_WRAPVISUALFLAGLOC_END_BY_TEXT = 0x0001,
	SC_WRAPVISUALFLAGLOC_START_BY_TEXT = 0x0002,
	SCI_SETWRAPVISUALFLAGSLOCATION = 2462,
	SCI_GETWRAPVISUALFLAGSLOCATION = 2463,
	SCI_SETWRAPSTARTINDENT = 2464,
	SCI_GETWRAPSTARTINDENT = 2465,
	SC_CACHE_NONE = 0,
	SC_CACHE_CARET = 1,
	SC_CACHE_PAGE = 2,
	SC_CACHE_DOCUMENT = 3,
	SCI_SETLAYOUTCACHE = 2272,
	SCI_GETLAYOUTCACHE = 2273,
	SCI_SETSCROLLWIDTH = 2274,
	SCI_GETSCROLLWIDTH = 2275,
	SCI_SETSCROLLWIDTHTRACKING = 2516,
	SCI_GETSCROLLWIDTHTRACKING = 2517,
	SCI_TEXTWIDTH = 2276,
	SCI_SETENDATLASTLINE = 2277,
	SCI_GETENDATLASTLINE = 2278,
	SCI_TEXTHEIGHT = 2279,
	SCI_SETVSCROLLBAR = 2280,
	SCI_GETVSCROLLBAR = 2281,
	SCI_APPENDTEXT = 2282,
	SCI_GETTWOPHASEDRAW = 2283,
	SCI_SETTWOPHASEDRAW = 2284,
	SCI_TARGETFROMSELECTION = 2287,
	SCI_LINESJOIN = 2288,
	SCI_LINESSPLIT = 2289,
	SCI_SETFOLDMARGINCOLOUR = 2290,
	SCI_SETFOLDMARGINHICOLOUR = 2291,
	SCI_LINEDOWN = 2300,
	SCI_LINEDOWNEXTEND = 2301,
	SCI_LINEUP = 2302,
	SCI_LINEUPEXTEND = 2303,
	SCI_CHARLEFT = 2304,
	SCI_CHARLEFTEXTEND = 2305,
	SCI_CHARRIGHT = 2306,
	SCI_CHARRIGHTEXTEND = 2307,
	SCI_WORDLEFT = 2308,
	SCI_WORDLEFTEXTEND = 2309,
	SCI_WORDRIGHT = 2310,
	SCI_WORDRIGHTEXTEND = 2311,
	SCI_HOME = 2312,
	SCI_HOMEEXTEND = 2313,
	SCI_LINEEND = 2314,
	SCI_LINEENDEXTEND = 2315,
	SCI_DOCUMENTSTART = 2316,
	SCI_DOCUMENTSTARTEXTEND = 2317,
	SCI_DOCUMENTEND = 2318,
	SCI_DOCUMENTENDEXTEND = 2319,
	SCI_PAGEUP = 2320,
	SCI_PAGEUPEXTEND = 2321,
	SCI_PAGEDOWN = 2322,
	SCI_PAGEDOWNEXTEND = 2323,
	SCI_EDITTOGGLEOVERTYPE = 2324,
	SCI_CANCEL = 2325,
	SCI_DELETEBACK = 2326,
	SCI_TAB = 2327,
	SCI_BACKTAB = 2328,
	SCI_NEWLINE = 2329,
	SCI_FORMFEED = 2330,
	SCI_VCHOME = 2331,
	SCI_VCHOMEEXTEND = 2332,
	SCI_ZOOMIN = 2333,
	SCI_ZOOMOUT = 2334,
	SCI_DELWORDLEFT = 2335,
	SCI_DELWORDRIGHT = 2336,
	SCI_DELWORDRIGHTEND = 2518,
	SCI_LINECUT = 2337,
	SCI_LINEDELETE = 2338,
	SCI_LINETRANSPOSE = 2339,
	SCI_LINEDUPLICATE = 2404,
	SCI_LOWERCASE = 2340,
	SCI_UPPERCASE = 2341,
	SCI_LINESCROLLDOWN = 2342,
	SCI_LINESCROLLUP = 2343,
	SCI_DELETEBACKNOTLINE = 2344,
	SCI_HOMEDISPLAY = 2345,
	SCI_HOMEDISPLAYEXTEND = 2346,
	SCI_LINEENDDISPLAY = 2347,
	SCI_LINEENDDISPLAYEXTEND = 2348,
	SCI_HOMEWRAP = 2349,
	SCI_HOMEWRAPEXTEND = 2450,
	SCI_LINEENDWRAP = 2451,
	SCI_LINEENDWRAPEXTEND = 2452,
	SCI_VCHOMEWRAP = 2453,
	SCI_VCHOMEWRAPEXTEND = 2454,
	SCI_LINECOPY = 2455,
	SCI_MOVECARETINSIDEVIEW = 2401,
	SCI_LINELENGTH = 2350,
	SCI_BRACEHIGHLIGHT = 2351,
	SCI_BRACEBADLIGHT = 2352,
	SCI_BRACEMATCH = 2353,
	SCI_GETVIEWEOL = 2355,
	SCI_SETVIEWEOL = 2356,
	SCI_GETDOCPOINTER = 2357,
	SCI_SETDOCPOINTER = 2358,
	SCI_SETMODEVENTMASK = 2359,
	EDGE_NONE = 0,
	EDGE_LINE = 1,
	EDGE_BACKGROUND = 2,
	SCI_GETEDGECOLUMN = 2360,
	SCI_SETEDGECOLUMN = 2361,
	SCI_GETEDGEMODE = 2362,
	SCI_SETEDGEMODE = 2363,
	SCI_GETEDGECOLOUR = 2364,
	SCI_SETEDGECOLOUR = 2365,
	SCI_SEARCHANCHOR = 2366,
	SCI_SEARCHNEXT = 2367,
	SCI_SEARCHPREV = 2368,
	SCI_LINESONSCREEN = 2370,
	SCI_USEPOPUP = 2371,
	SCI_SELECTIONISRECTANGLE = 2372,
	SCI_SETZOOM = 2373,
	SCI_GETZOOM = 2374,
	SCI_CREATEDOCUMENT = 2375,
	SCI_ADDREFDOCUMENT = 2376,
	SCI_RELEASEDOCUMENT = 2377,
	SCI_GETMODEVENTMASK = 2378,
	SCI_SETFOCUS = 2380,
	SCI_GETFOCUS = 2381,
	SCI_SETSTATUS = 2382,
	SCI_GETSTATUS = 2383,
	SCI_SETMOUSEDOWNCAPTURES = 2384,
	SCI_GETMOUSEDOWNCAPTURES = 2385,
	SC_CURSORNORMAL = -1,
	SC_CURSORWAIT = 4,
	SCI_SETCURSOR = 2386,
	SCI_GETCURSOR = 2387,
	SCI_SETCONTROLCHARSYMBOL = 2388,
	SCI_GETCONTROLCHARSYMBOL = 2389,
	SCI_WORDPARTLEFT = 2390,
	SCI_WORDPARTLEFTEXTEND = 2391,
	SCI_WORDPARTRIGHT = 2392,
	SCI_WORDPARTRIGHTEXTEND = 2393,
	VISIBLE_SLOP = 0x01,
	VISIBLE_STRICT = 0x04,
	SCI_SETVISIBLEPOLICY = 2394,
	SCI_DELLINELEFT = 2395,
	SCI_DELLINERIGHT = 2396,
	SCI_SETXOFFSET = 2397,
	SCI_GETXOFFSET = 2398,
	SCI_CHOOSECARETX = 2399,
	SCI_GRABFOCUS = 2400,
	CARET_SLOP = 0x01,
	CARET_STRICT = 0x04,
	CARET_JUMPS = 0x10,
	CARET_EVEN = 0x08,
	SCI_SETXCARETPOLICY = 2402,
	SCI_SETYCARETPOLICY = 2403,
	SCI_SETPRINTWRAPMODE = 2406,
	SCI_GETPRINTWRAPMODE = 2407,
	SCI_SETHOTSPOTACTIVEFORE = 2410,
	SCI_GETHOTSPOTACTIVEFORE = 2494,
	SCI_SETHOTSPOTACTIVEBACK = 2411,
	SCI_GETHOTSPOTACTIVEBACK = 2495,
	SCI_SETHOTSPOTACTIVEUNDERLINE = 2412,
	SCI_GETHOTSPOTACTIVEUNDERLINE = 2496,
	SCI_SETHOTSPOTSINGLELINE = 2421,
	SCI_GETHOTSPOTSINGLELINE = 2497,
	SCI_PARADOWN = 2413,
	SCI_PARADOWNEXTEND = 2414,
	SCI_PARAUP = 2415,
	SCI_PARAUPEXTEND = 2416,
	SCI_POSITIONBEFORE = 2417,
	SCI_POSITIONAFTER = 2418,
	SCI_COPYRANGE = 2419,
	SCI_COPYTEXT = 2420,
	SC_SEL_STREAM = 0,
	SC_SEL_RECTANGLE = 1,
	SC_SEL_LINES = 2,
	SCI_SETSELECTIONMODE = 2422,
	SCI_GETSELECTIONMODE = 2423,
	SCI_GETLINESELSTARTPOSITION = 2424,
	SCI_GETLINESELENDPOSITION = 2425,
	SCI_LINEDOWNRECTEXTEND = 2426,
	SCI_LINEUPRECTEXTEND = 2427,
	SCI_CHARLEFTRECTEXTEND = 2428,
	SCI_CHARRIGHTRECTEXTEND = 2429,
	SCI_HOMERECTEXTEND = 2430,
	SCI_VCHOMERECTEXTEND = 2431,
	SCI_LINEENDRECTEXTEND = 2432,
	SCI_PAGEUPRECTEXTEND = 2433,
	SCI_PAGEDOWNRECTEXTEND = 2434,
	SCI_STUTTEREDPAGEUP = 2435,
	SCI_STUTTEREDPAGEUPEXTEND = 2436,
	SCI_STUTTEREDPAGEDOWN = 2437,
	SCI_STUTTEREDPAGEDOWNEXTEND = 2438,
	SCI_WORDLEFTEND = 2439,
	SCI_WORDLEFTENDEXTEND = 2440,
	SCI_WORDRIGHTEND = 2441,
	SCI_WORDRIGHTENDEXTEND = 2442,
	SCI_SETWHITESPACECHARS = 2443,
	SCI_SETCHARSDEFAULT = 2444,
	SCI_AUTOCGETCURRENT = 2445,
	SCI_ALLOCATE = 2446,
	SCI_TARGETASUTF8 = 2447,
	SCI_SETLENGTHFORENCODE = 2448,
	SCI_ENCODEDFROMUTF8 = 2449,
	SCI_FINDCOLUMN = 2456,
	SCI_GETCARETSTICKY = 2457,
	SCI_SETCARETSTICKY = 2458,
	SCI_TOGGLECARETSTICKY = 2459,
	SCI_SETPASTECONVERTENDINGS = 2467,
	SCI_GETPASTECONVERTENDINGS = 2468,
	SCI_SELECTIONDUPLICATE = 2469,
	SC_ALPHA_TRANSPARENT = 0,
	SC_ALPHA_OPAQUE = 255,
	SC_ALPHA_NOALPHA = 256,
	SCI_SETCARETLINEBACKALPHA = 2470,
	SCI_GETCARETLINEBACKALPHA = 2471,
	CARETSTYLE_INVISIBLE = 0,
	CARETSTYLE_LINE = 1,
	CARETSTYLE_BLOCK = 2,
	SCI_SETCARETSTYLE = 2512,
	SCI_GETCARETSTYLE = 2513,
	SCI_SETINDICATORCURRENT = 2500,
	SCI_GETINDICATORCURRENT = 2501,
	SCI_SETINDICATORVALUE = 2502,
	SCI_GETINDICATORVALUE = 2503,
	SCI_INDICATORFILLRANGE = 2504,
	SCI_INDICATORCLEARRANGE = 2505,
	SCI_INDICATORALLONFOR = 2506,
	SCI_INDICATORVALUEAT = 2507,
	SCI_INDICATORSTART = 2508,
	SCI_INDICATOREND = 2509,
	SCI_SETPOSITIONCACHE = 2514,
	SCI_GETPOSITIONCACHE = 2515,
	SCI_COPYALLOWLINE = 2519,
	SCI_STARTRECORD = 3001,
	SCI_STOPRECORD = 3002,
	SCI_SETLEXER = 4001,
	SCI_GETLEXER = 4002,
	SCI_COLOURISE = 4003,
	SCI_SETPROPERTY = 4004,
	KEYWORDSET_MAX = 8,
	SCI_SETKEYWORDS = 4005,
	SCI_SETLEXERLANGUAGE = 4006,
	SCI_LOADLEXERLIBRARY = 4007,
	SCI_GETPROPERTY = 4008,
	SCI_GETPROPERTYEXPANDED = 4009,
	SCI_GETPROPERTYINT = 4010,
	SCI_GETSTYLEBITSNEEDED = 4011,
	SC_MOD_INSERTTEXT = 0x1,
	SC_MOD_DELETETEXT = 0x2,
	SC_MOD_CHANGESTYLE = 0x4,
	SC_MOD_CHANGEFOLD = 0x8,
	SC_PERFORMED_USER = 0x10,
	SC_PERFORMED_UNDO = 0x20,
	SC_PERFORMED_REDO = 0x40,
	SC_MULTISTEPUNDOREDO = 0x80,
	SC_LASTSTEPINUNDOREDO = 0x100,
	SC_MOD_CHANGEMARKER = 0x200,
	SC_MOD_BEFOREINSERT = 0x400,
	SC_MOD_BEFOREDELETE = 0x800,
	SC_MULTILINEUNDOREDO = 0x1000,
	SC_STARTACTION = 0x2000,
	SC_MOD_CHANGEINDICATOR = 0x4000,
	SC_MOD_CHANGELINESTATE = 0x8000,
	SC_MODEVENTMASKALL = 0xFFFF,
	SCEN_CHANGE = 768,
	SCEN_SETFOCUS = 512,
	SCEN_KILLFOCUS = 256,
	SCK_DOWN = 300,
	SCK_UP = 301,
	SCK_LEFT = 302,
	SCK_RIGHT = 303,
	SCK_HOME = 304,
	SCK_END = 305,
	SCK_PRIOR = 306,
	SCK_NEXT = 307,
	SCK_DELETE = 308,
	SCK_INSERT = 309,
	SCK_ESCAPE = 7,
	SCK_BACK = 8,
	SCK_TAB = 9,
	SCK_RETURN = 13,
	SCK_ADD = 310,
	SCK_SUBTRACT = 311,
	SCK_DIVIDE = 312,
	SCK_WIN = 313,
	SCK_RWIN = 314,
	SCK_MENU = 315,
	SCMOD_NORM = 0,
	SCMOD_SHIFT = 1,
	SCMOD_CTRL = 2,
	SCMOD_ALT = 4,
	SCN_STYLENEEDED = 2000,
	SCN_CHARADDED = 2001,
	SCN_SAVEPOINTREACHED = 2002,
	SCN_SAVEPOINTLEFT = 2003,
	SCN_MODIFYATTEMPTRO = 2004,
	SCN_KEY = 2005,
	SCN_DOUBLECLICK = 2006,
	SCN_UPDATEUI = 2007,
	SCN_MODIFIED = 2008,
	SCN_MACRORECORD = 2009,
	SCN_MARGINCLICK = 2010,
	SCN_NEEDSHOWN = 2011,
	SCN_PAINTED = 2013,
	SCN_USERLISTSELECTION = 2014,
	SCN_URIDROPPED = 2015,
	SCN_DWELLSTART = 2016,
	SCN_DWELLEND = 2017,
	SCN_ZOOM = 2018,
	SCN_HOTSPOTCLICK = 2019,
	SCN_HOTSPOTDOUBLECLICK = 2020,
	SCN_CALLTIPCLICK = 2021,
	SCN_AUTOCSELECTION = 2022,
	SCN_INDICATORCLICK = 2023,
	SCN_INDICATORRELEASE = 2024,
}

enum {
	SCLEX_CPP = 3,
	SCLEX_D = 79,

	SCE_C_DEFAULT = 0,
	SCE_C_COMMENT = 1,
	SCE_C_COMMENTLINE = 2,
	SCE_C_COMMENTDOC = 3,
	SCE_C_NUMBER = 4,
	SCE_C_WORD = 5,
	SCE_C_STRING = 6,
	SCE_C_CHARACTER = 7,
	SCE_C_UUID = 8,
	SCE_C_PREPROCESSOR = 9,
	SCE_C_OPERATOR = 10,
	SCE_C_IDENTIFIER = 11,
	SCE_C_STRINGEOL = 12,
	SCE_C_VERBATIM = 13,
	SCE_C_REGEX = 14,
	SCE_C_COMMENTLINEDOC = 15,
	SCE_C_WORD2 = 16,
	SCE_C_COMMENTDOCKEYWORD = 17,
	SCE_C_COMMENTDOCKEYWORDERROR = 18,
	SCE_C_GLOBALCLASS = 19,
	SCE_D_DEFAULT = 0,
	SCE_D_COMMENT = 1,
	SCE_D_COMMENTLINE = 2,
	SCE_D_COMMENTDOC = 3,
	SCE_D_COMMENTNESTED = 4,
	SCE_D_NUMBER = 5,
	SCE_D_WORD = 6,
	SCE_D_WORD2 = 7,
	SCE_D_WORD3 = 8,
	SCE_D_TYPEDEF = 9,
	SCE_D_STRING = 10,
	SCE_D_STRINGEOL = 11,
	SCE_D_CHARACTER = 12,
	SCE_D_OPERATOR = 13,
	SCE_D_IDENTIFIER = 14,
	SCE_D_COMMENTLINEDOC = 15,
	SCE_D_COMMENTDOCKEYWORD = 16,
	SCE_D_COMMENTDOCKEYWORDERROR = 17,
}



extern (C) {
	typedef void *FontID;
	typedef void *SurfaceID;
	typedef void *WindowID;
	typedef void *MenuID;
	typedef void *TickerID;
	typedef void *Function;
	typedef void *IdlerID;
	
	
	class Window {
		enum Cursor {
			cursorInvalid,
			cursorText,
			cursorArrow,
			cursorUp,
			cursorWait,
			cursorHoriz,
			cursorVert,
			cursorReverseArrow,
			cursorHand
		}
	}	

	struct Point {
		int x;
		int y;
	}

	struct PRectangle {
		int left;
		int top;
		int right;
		int bottom;
		
		char[] toString() {
			return Format("l:{} t:{} r:{} b:{}", left, top, right, bottom);
		}
	}

	struct ColourDesired {
		int co;
	}

	struct ColourAllocated {
		int coAllocated;
	}

	struct ColourPair {
		ColourDesired desired;
		ColourAllocated allocated;
	}

	struct LineMarker {
		int markType;
		ColourPair fore;
		ColourPair back;
		int alpha;
		void* pxpm;
	}

	struct Indicator {
		int style;
		bool under;
	}

	struct Palette {
		int used;
		int size;
		ColourPair *entries;
		bool allowRealization;
	}

	struct Caret {
		bool active;
		bool on;
		int period;
	}

	struct Timer {
		bool ticking;
		int ticksToWait;
		enum { tickSize = 100 }
		TickerID tickerID;
	}

	struct Idler {
		bool state;
		IdlerID idlerID;
	}

	struct SelectionText {
		char *s;
		int len;
		bool rectangular;
		bool lineCopy;
		int codePage;
		int characterSet;
	}

	struct CharacterRange {
		int cpMin;
		int cpMax;
	}

	struct TextRange {
		CharacterRange chrg;
		char *lpstrText;
	}

	struct TextToFind {
		CharacterRange chrg;
		char *lpstrText;
		CharacterRange chrgText;
	}

	struct RangeToFormat {
		SurfaceID hdc;
		SurfaceID hdcTarget;
		PRectangle rc;
		PRectangle rcPage;
		CharacterRange chrg;
	}

	struct NotifyHeader {
		void *hwndFrom;
		uint idFrom;
		uint code;
	}
	
	struct SCNotification {
		NotifyHeader nmhdr;
		int position;	// SCN_STYLENEEDED, SCN_MODIFIED, SCN_DWELLSTART, SCN_DWELLEND
		int ch;		// SCN_CHARADDED, SCN_KEY
		int modifiers;	// SCN_KEY
		int modificationType;	// SCN_MODIFIED
		char *text;	// SCN_MODIFIED, SCN_USERLISTSELECTION, SCN_AUTOCSELECTION
		int length;		// SCN_MODIFIED
		int linesAdded;	// SCN_MODIFIED
		int message;	// SCN_MACRORECORD
		uint wParam;	// SCN_MACRORECORD
		uint lParam;	// SCN_MACRORECORD
		int line;		// SCN_MODIFIED
		int foldLevelNow;	// SCN_MODIFIED
		int foldLevelPrev;	// SCN_MODIFIED
		int margin;		// SCN_MARGINCLICK
		int listType;	// SCN_USERLISTSELECTION
		int x;			// SCN_DWELLSTART, SCN_DWELLEND
		int y;		// SCN_DWELLSTART, SCN_DWELLEND
	}
	

	struct DocModification {
		int modificationType;
		int position;
		int length;
		int linesAdded;	/**< Negative if lines deleted. */
		char *text;	/**< Only valid for changes to text, not for changes to style. */
		int line;
		int foldLevelNow;
		int foldLevelPrev;
	}


	struct LineLayout {
	private:
		int *lineStarts;
		int lenLineStarts;
		/// Drawing is only performed for @a maxLineLength characters on each line.
		int lineNumber;
		bool inCache;
	public:
		enum { wrapWidthInfinite = 0x7ffffff }
		int maxLineLength;
		int numCharsInLine;
		enum validLevel { llInvalid, llCheckTextAndStyle, llPositions, llLines };
		validLevel validity;
		int xHighlightGuide;
		bool highlightColumn;
		int selStart;
		int selEnd;
		bool containsCaret;
		int edgeColumn;
		char *chars;
		ubyte *styles;
		int styleBitsSet;
		char *indicators;
		int *positions;
		char[2] bracePreviousStyles;

		// Hotspot support
		int hsStart;
		int hsEnd;

		// Wrapped line support
		int widthLine;
		int lines;
	}


	struct MarginStyle {
		int style;
		int width;
		int mask;
		bool sensitive;
	}


	struct FontNames {
		char **names;
		int size;
		int max;
	}


	typedef int Position;
	const Position invalidPosition = -1;


	struct Range {
		Position start;
		Position end;
	}

	enum IndentView {ivNone, ivReal, ivLookForward, ivLookBoth}
	enum WhiteSpaceVisibility {wsInvisible=0, wsVisibleAlways=1, wsVisibleAfterIndent=2}


	struct ViewStyle {
		FontNames fontNames;
		size_t stylesSize;
		void *styles;
		LineMarker[MARKER_MAX + 1] markers;
		Indicator[INDIC_MAX + 1] indicators;
		int lineHeight;
		uint maxAscent;
		uint maxDescent;
		uint aveCharWidth;
		uint spaceWidth;
		bool selforeset;
		ColourPair selforeground;
		bool selbackset;
		ColourPair selbackground;
		ColourPair selbackground2;
		int selAlpha;
		bool selEOLFilled;
		bool whitespaceForegroundSet;
		ColourPair whitespaceForeground;
		bool whitespaceBackgroundSet;
		ColourPair whitespaceBackground;
		ColourPair selbar;
		ColourPair selbarlight;
		bool foldmarginColourSet;
		ColourPair foldmarginColour;
		bool foldmarginHighlightColourSet;
		ColourPair foldmarginHighlightColour;
		bool hotspotForegroundSet;
		ColourPair hotspotForeground;
		bool hotspotBackgroundSet;
		ColourPair hotspotBackground;
		bool hotspotUnderline;
		bool hotspotSingleLine;
		/// Margins are ordered: Line Numbers, Selection Margin, Spacing Margin
		enum { margins=5 };
		int leftMarginWidth;	///< Spacing margin on left of text
		int rightMarginWidth;	///< Spacing margin on left of text
		bool symbolMargin;
		int maskInLine;	///< Mask for markers to be put into text because there is nowhere for them to go in margin
		MarginStyle[margins] ms;
		int fixedColumnWidth;
		int zoomLevel;
		WhiteSpaceVisibility viewWhitespace;
		IndentView viewIndentationGuides;
		bool viewEOL;
		bool showMarkedLines;
		ColourPair caretcolour;
		bool showCaretLineBackground;
		ColourPair caretLineBackground;
		int caretLineAlpha;
		ColourPair edgecolour;
		int edgeState;
		int caretStyle;
		int caretWidth;
		bool someStylesProtected;
		bool extraFontFlag;
	}


	struct DeeEditor_Funcs {
		void function(void* dctx) Initialise;
		void function(void* dctx) Finalise;
//		void function(void* dctx, Palette* pal, bool want) RefreshColourPalette;
		PRectangle function(void* dctx) GetClientRectangle;
		void function(void* dctx, int linesToMove) ScrollText;
		void function(void* dctx) UpdateSystemCaret;
		void function(void* dctx) SetVerticalScrollPos;
		void function(void* dctx) SetHorizontalScrollPos;
		bool function(void* dctx, int nMax, int nPage) ModifyScrollBars;
		void function(void* dctx) ReconfigureScrollBars;
		//void function(void* dctx, char *s, uint len, bool treatAsDBCS) AddCharUTF;
		void function(void* dctx) Copy;
		void function(void* dctx) CopyAllowLine;
		bool function(void* dctx) CanPaste;
		void function(void* dctx) Paste;
		void function(void* dctx) ClaimSelection;
		void function(void* dctx) NotifyChange;
		void function(void* dctx, bool focus) NotifyFocus;
		int function(void* dctx) GetCtrlID;
		void function(void* dctx, SCNotification scn) NotifyParent;
		//void function(void* dctx, int endStyleNeeded) NotifyStyleToNeeded;
		void function(void* dctx, Point pt, bool shift, bool ctrl, bool alt) NotifyDoubleClick;
		void function(void* dctx) CancelModes;
		//int function(void* dctx, uint iMessage) KeyCommand;
		int function(void* dctx, int /* key */, int /*modifiers*/) KeyDefault;
		void function(void* dctx, SelectionText* selectedText) CopyToClipboard;
		void function(void* dctx, Window.Cursor c) DisplayCursor;
		bool function(void* dctx, Point ptStart, Point ptNow) DragThreshold;
		void function(void* dctx) StartDrag;
		//void function(void* dctx, Point pt, uint curTime, bool shift, bool ctrl, bool alt) ButtonDown;
		void function(void* dctx, bool on) SetTicking;
		bool function(void* dctx, bool) SetIdle;
		void function(void* dctx, bool on) SetMouseCapture;
		bool function(void* dctx) HaveMouseCapture;
		bool function(void* dctx, PRectangle rc) PaintContains;
		bool function(void* dctx, int /* codePage */) ValidCodePage;
		uint function(void* dctx, uint iMessage, uint wParam, uint lParam) DefWndProc;
//		uint function(void* dctx, uint iMessage, uint wParam, uint lParam) WndProc;
	}


	void DeeEditor_Initialise(void* dctx) { return (cast(DeeEditor)dctx).Initialise(); }
	void DeeEditor_Finalise(void* dctx) { return (cast(DeeEditor)dctx).Finalise(); }
//	void DeeEditor_RefreshColourPalette(void* dctx, Palette* pal, bool want) { return (cast(DeeEditor)dctx).RefreshColourPalette(pal, want); }
	PRectangle DeeEditor_GetClientRectangle(void* dctx) { return (cast(DeeEditor)dctx).GetClientRectangle(); }
	void DeeEditor_ScrollText(void* dctx, int linesToMove) { return (cast(DeeEditor)dctx).ScrollText(linesToMove); }
	void DeeEditor_UpdateSystemCaret(void* dctx) { return (cast(DeeEditor)dctx).UpdateSystemCaret(); }
	void DeeEditor_SetVerticalScrollPos(void* dctx) { return (cast(DeeEditor)dctx).SetVerticalScrollPos(); }
	void DeeEditor_SetHorizontalScrollPos(void* dctx) { return (cast(DeeEditor)dctx).SetHorizontalScrollPos(); }
	bool DeeEditor_ModifyScrollBars(void* dctx, int nMax, int nPage) { return (cast(DeeEditor)dctx).ModifyScrollBars(nMax, nPage); }
	void DeeEditor_ReconfigureScrollBars(void* dctx) { return (cast(DeeEditor)dctx).ReconfigureScrollBars(); }
	//void DeeEditor_AddCharUTF(void* dctx, char *s, uint len, bool treatAsDBCS) { return (cast(DeeEditor)dctx).AddCharUTF(s, len, treatAsDBCS); }
	void DeeEditor_Copy(void* dctx) { return (cast(DeeEditor)dctx).Copy(); }
	void DeeEditor_CopyAllowLine(void* dctx) { return (cast(DeeEditor)dctx).CopyAllowLine(); }
	bool DeeEditor_CanPaste(void* dctx) { return (cast(DeeEditor)dctx).CanPaste(); }
	void DeeEditor_Paste(void* dctx) { return (cast(DeeEditor)dctx).Paste(); }
	void DeeEditor_ClaimSelection(void* dctx) { return (cast(DeeEditor)dctx).ClaimSelection(); }
	void DeeEditor_NotifyChange(void* dctx) { return (cast(DeeEditor)dctx).NotifyChange(); }
	void DeeEditor_NotifyFocus(void* dctx, bool focus) { return (cast(DeeEditor)dctx).NotifyFocus(focus); }
	int DeeEditor_GetCtrlID(void* dctx) { return (cast(DeeEditor)dctx).GetCtrlID(); }
	void DeeEditor_NotifyParent(void* dctx, SCNotification scn) { return (cast(DeeEditor)dctx).NotifyParent(scn); }
	//void DeeEditor_NotifyStyleToNeeded(void* dctx, int endStyleNeeded) { return (cast(DeeEditor)dctx).NotifyStyleToNeeded(endStyleNeeded); }
	void DeeEditor_NotifyDoubleClick(void* dctx, Point pt, bool shift, bool ctrl, bool alt) { return (cast(DeeEditor)dctx).NotifyDoubleClick(pt, shift, ctrl, alt); }
	void DeeEditor_CancelModes(void* dctx) { return (cast(DeeEditor)dctx).CancelModes(); }
	//int DeeEditor_KeyCommand(void* dctx, uint iMessage) { return (cast(DeeEditor)dctx).KeyCommand(iMessage); }
	int DeeEditor_KeyDefault(void* dctx, int key, int modifiers) { return (cast(DeeEditor)dctx).KeyDefault(key, modifiers); }
	void DeeEditor_CopyToClipboard(void* dctx, SelectionText* selectedText) { return (cast(DeeEditor)dctx).CopyToClipboard(selectedText); }
	void DeeEditor_DisplayCursor(void* dctx, Window.Cursor c) { return (cast(DeeEditor)dctx).DisplayCursor(c); }
	bool DeeEditor_DragThreshold(void* dctx, Point ptStart, Point ptNow) { return (cast(DeeEditor)dctx).DragThreshold(ptStart, ptNow); }
	void DeeEditor_StartDrag(void* dctx) { return (cast(DeeEditor)dctx).StartDrag(); }
	//void DeeEditor_ButtonDown(void* dctx, Point pt, uint curTime, bool shift, bool ctrl, bool alt) { return (cast(DeeEditor)dctx).ButtonDown(pt, curTime, shift, ctrl, alt); }
	void DeeEditor_SetTicking(void* dctx, bool on) { return (cast(DeeEditor)dctx).SetTicking(on); }
	bool DeeEditor_SetIdle(void* dctx, bool on) { return (cast(DeeEditor)dctx).SetIdle(on); }
	void DeeEditor_SetMouseCapture(void* dctx, bool on) { return (cast(DeeEditor)dctx).SetMouseCapture(on); }
	bool DeeEditor_HaveMouseCapture(void* dctx) { return (cast(DeeEditor)dctx).HaveMouseCapture(); }
	bool DeeEditor_PaintContains(void* dctx, PRectangle rc) { return (cast(DeeEditor)dctx).PaintContains(rc); }
	bool DeeEditor_ValidCodePage(void* dctx, int codePage) { return (cast(DeeEditor)dctx).ValidCodePage(codePage); }
	uint DeeEditor_DefWndProc(void* dctx, uint iMessage, uint wParam, uint lParam) { return (cast(DeeEditor)dctx).DefWndProc(iMessage, wParam, lParam); }
	//uint DeeEditor_WndProc(void* dctx, uint iMessage, uint wParam, uint lParam) { return (cast(DeeEditor)dctx).WndProc(iMessage, wParam, lParam); }





	struct DeeSurface_Funcs {
		void function(void* dctx) Release;
		bool function(void* dctx) Initialised;
		void function(void* dctx, ColourAllocated fore) PenColour;
		int function(void* dctx) LogPixelsY;
		int function(void* dctx, int points) DeviceHeightFont;
		void function(void* dctx, int x_, int y_) MoveTo;
		void function(void* dctx, int x_, int y_) LineTo;
		void function(void* dctx, Point *pts, int npts, ColourAllocated fore, ColourAllocated back) Polygon;
		void function(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) RectangleDraw;
		void function(void* dctx, PRectangle rc, ColourAllocated back) FillRectangle;
		void function(void* dctx, PRectangle rc, DeeSurface surfacePattern) FillRectanglePattern;
		void function(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) RoundedRectangle;
		void function(void* dctx, PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags) AlphaRectangle;
		void function(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) Ellipse;
		void function(void* dctx, PRectangle rc, Point from, DeeSurface surfaceSource) Copy;

		void function(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, uint fuOptions) DrawTextCommon;
		void function(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) DrawTextNoClip;
		void function(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) DrawTextClipped;
		void function(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore) DrawTextTransparent;
		void function(void* dctx, void* font_, char *s, int len, int *positions) MeasureWidths;
		int function(void* dctx, void* font_, char *s, int len) WidthText;
		int function(void* dctx, void* font_, char ch) WidthChar;
		int function(void* dctx, void* font_) Ascent;
		int function(void* dctx, void* font_) Descent;
		int function(void* dctx, void* font_) InternalLeading;
		int function(void* dctx, void* font_) ExternalLeading;
		int function(void* dctx, void* font_) Height;
		int function(void* dctx, void* font_) AverageCharWidth;

		//int function(void* dctx, Palette *pal, bool inBackGround) SetPalette;
		void function(void* dctx, PRectangle rc) SetClip;
		void function(void* dctx) FlushCachedState;

		void function(void* dctx, bool unicodeMode_) SetUnicodeMode;
		void function(void* dctx, int codePage_) SetDBCSMode;
	}


	void DeeSurface_Release(void* dctx) { return (cast(DeeSurface)dctx).Release(); }
	bool DeeSurface_Initialised(void* dctx) { return (cast(DeeSurface)dctx).Initialised(); }
	void DeeSurface_PenColour(void* dctx, ColourAllocated fore) { return (cast(DeeSurface)dctx).PenColour(fore); }
	int DeeSurface_LogPixelsY(void* dctx) { return (cast(DeeSurface)dctx).LogPixelsY(); }
	int DeeSurface_DeviceHeightFont(void* dctx, int points) { return (cast(DeeSurface)dctx).DeviceHeightFont(points); }
	void DeeSurface_MoveTo(void* dctx, int x_, int y_) { return (cast(DeeSurface)dctx).MoveTo(x_, y_); }
	void DeeSurface_LineTo(void* dctx, int x_, int y_) { return (cast(DeeSurface)dctx).LineTo(x_, y_); }
	void DeeSurface_Polygon(void* dctx, Point *pts, int npts, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).Polygon(pts, npts, fore, back); }
	void DeeSurface_RectangleDraw(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).RectangleDraw(rc, fore, back); }
	void DeeSurface_FillRectangle(void* dctx, PRectangle rc, ColourAllocated back) { assert (dctx !is null); return (cast(DeeSurface)dctx).FillRectangle(rc, back); }
	void DeeSurface_FillRectanglePattern(void* dctx, PRectangle rc, DeeSurface surfacePattern) { return (cast(DeeSurface)dctx).FillRectanglePattern(rc, surfacePattern); }
	void DeeSurface_RoundedRectangle(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).RoundedRectangle(rc, fore, back); }
	void DeeSurface_AlphaRectangle(void* dctx, PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags) { return (cast(DeeSurface)dctx).AlphaRectangle(rc, cornerSize, fill, alphaFill, outline, alphaOutline, flags); }
	void DeeSurface_Ellipse(void* dctx, PRectangle rc, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).Ellipse(rc, fore, back); }
	void DeeSurface_Copy(void* dctx, PRectangle rc, Point from, DeeSurface surfaceSource) { return (cast(DeeSurface)dctx).Copy(rc, from, surfaceSource); }

	void DeeSurface_DrawTextCommon(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, uint fuOptions) { return (cast(DeeSurface)dctx).DrawTextCommon(rc, font_, ybase, s, len, fuOptions); }
	void DeeSurface_DrawTextNoClip(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).DrawTextNoClip(rc, font_, ybase, s, len, fore, back); }
	void DeeSurface_DrawTextClipped(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) { return (cast(DeeSurface)dctx).DrawTextClipped(rc, font_, ybase, s, len, fore, back); }
	void DeeSurface_DrawTextTransparent(void* dctx, PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore) { return (cast(DeeSurface)dctx).DrawTextTransparent(rc, font_, ybase, s, len, fore); }
	void DeeSurface_MeasureWidths(void* dctx, void* font_, char *s, int len, int *positions) { return (cast(DeeSurface)dctx).MeasureWidths(font_, s, len, positions); }
	int DeeSurface_WidthText(void* dctx, void* font_, char *s, int len) { return (cast(DeeSurface)dctx).WidthText(font_, s, len); }
	int DeeSurface_WidthChar(void* dctx, void* font_, char ch) { return (cast(DeeSurface)dctx).WidthChar(font_, ch); }
	int DeeSurface_Ascent(void* dctx, void* font_) { return (cast(DeeSurface)dctx).Ascent(font_); }
	int DeeSurface_Descent(void* dctx, void* font_) { return (cast(DeeSurface)dctx).Descent(font_); }
	int DeeSurface_InternalLeading(void* dctx, void* font_) { return (cast(DeeSurface)dctx).InternalLeading(font_); }
	int DeeSurface_ExternalLeading(void* dctx, void* font_) { return (cast(DeeSurface)dctx).ExternalLeading(font_); }
	int DeeSurface_Height(void* dctx, void* font_) { return (cast(DeeSurface)dctx).Height(font_); }
	int DeeSurface_AverageCharWidth(void* dctx, void* font_) { return (cast(DeeSurface)dctx).AverageCharWidth(font_); }

	//int DeeSurface_SetPalette(void* dctx, Palette *pal, bool inBackGround) { assert(dctx !is null); return (cast(DeeSurface)dctx).SetPalette(pal, inBackGround); }
	void DeeSurface_SetClip(void* dctx, PRectangle rc) { return (cast(DeeSurface)dctx).SetClip(rc); }
	void DeeSurface_FlushCachedState(void* dctx) { return (cast(DeeSurface)dctx).FlushCachedState(); }

	void DeeSurface_SetUnicodeMode(void* dctx, bool unicodeMode_) { return (cast(DeeSurface)dctx).SetUnicodeMode(unicodeMode_); }
	void DeeSurface_SetDBCSMode(void* dctx, int codePage_) { return (cast(DeeSurface)dctx).SetDBCSMode(codePage_); }




	struct DeeFuncsStruct {
		DeeEditor_Funcs	Editor;
		DeeSurface_Funcs	Surface;
	}


	struct DeeFactoriesStruct {
		FontID function(char *faceName, int characterSet, int size, bool bold, bool italic, bool extraFontFlag) createFont;
		void function(FontID) releaseFont;

		void* function() createSurface;
		void function(void*) releaseSurface;
	}


	template DFactories(FontImpl, SurfaceImpl) {
		FontID createFontImpl(char *faceName, int characterSet, int size, bool bold, bool italic, bool extraFontFlag) {
			return cast(FontID)new FontImpl;
		}
		
		void releaseFontImpl(FontID ptr) {
			delete ptr;
		}

		void* createSurfaceImpl() {
			return cast(void*)SurfaceImpl.intrusivePooledAlloc(false);
		}
		
		void releaseSurfaceImpl(void* p) {
			(cast(SurfaceImpl)p).Release();
		}
	}
	
	alias void* function(void* dctx) createDeeEditor_fp;
	alias void* function(void* dctx) createDeeSurface_fp;
	alias DeeFuncsStruct* function() getDeeFuncsStruct_fp;
	alias DeeFactoriesStruct* function() getDeeFactoriesStruct_fp;
}



void bindDeeEditor(DeeEditor_Funcs* cfuncs) {
	cfuncs.Initialise = &DeeEditor_Initialise;
	cfuncs.Finalise = &DeeEditor_Finalise;
//	cfuncs.RefreshColourPalette = &DeeEditor_RefreshColourPalette;
	cfuncs.GetClientRectangle = &DeeEditor_GetClientRectangle;
	cfuncs.ScrollText = &DeeEditor_ScrollText;
	cfuncs.UpdateSystemCaret = &DeeEditor_UpdateSystemCaret;
	cfuncs.SetVerticalScrollPos = &DeeEditor_SetVerticalScrollPos;
	cfuncs.SetHorizontalScrollPos = &DeeEditor_SetHorizontalScrollPos;
	cfuncs.ModifyScrollBars = &DeeEditor_ModifyScrollBars;
	cfuncs.ReconfigureScrollBars = &DeeEditor_ReconfigureScrollBars;
	//cfuncs.AddCharUTF = &DeeEditor_AddCharUTF;
	cfuncs.Copy = &DeeEditor_Copy;
	cfuncs.CopyAllowLine = &DeeEditor_CopyAllowLine;
	cfuncs.CanPaste = &DeeEditor_CanPaste;
	cfuncs.Paste = &DeeEditor_Paste;
	cfuncs.ClaimSelection = &DeeEditor_ClaimSelection;
	cfuncs.NotifyChange = &DeeEditor_NotifyChange;
	cfuncs.NotifyFocus = &DeeEditor_NotifyFocus;
	cfuncs.GetCtrlID = &DeeEditor_GetCtrlID;
	cfuncs.NotifyParent = &DeeEditor_NotifyParent;
	//cfuncs.NotifyStyleToNeeded = &DeeEditor_NotifyStyleToNeeded;
	cfuncs.NotifyDoubleClick = &DeeEditor_NotifyDoubleClick;
	cfuncs.CancelModes = &DeeEditor_CancelModes;
	//cfuncs.KeyCommand = &DeeEditor_KeyCommand;
	cfuncs.KeyDefault = &DeeEditor_KeyDefault;
	cfuncs.CopyToClipboard = &DeeEditor_CopyToClipboard;
	cfuncs.DisplayCursor = &DeeEditor_DisplayCursor;
	cfuncs.DragThreshold = &DeeEditor_DragThreshold;
	cfuncs.StartDrag = &DeeEditor_StartDrag;
	//cfuncs.ButtonDown = &DeeEditor_ButtonDown;
	cfuncs.SetTicking = &DeeEditor_SetTicking;
	cfuncs.SetIdle = &DeeEditor_SetIdle;
	cfuncs.SetMouseCapture = &DeeEditor_SetMouseCapture;
	cfuncs.HaveMouseCapture = &DeeEditor_HaveMouseCapture;
	cfuncs.PaintContains = &DeeEditor_PaintContains;
	cfuncs.ValidCodePage = &DeeEditor_ValidCodePage;
	cfuncs.DefWndProc = &DeeEditor_DefWndProc;
	//cfuncs.WndProc = &DeeEditor_WndProc;
}


template MIntrusivePooled() {
	static typeof(this) intrusivePooled_tail;
	typeof(this) intrusivePooled_prev;
	
	
	static typeof(this) intrusivePooledAlloc(T ...)(T t) {
		typeof(this) res;
		
		synchronized (typeof(this).classinfo) {
			if (intrusivePooled_tail is null) {
				res = new typeof(this);
			} else {
				res = intrusivePooled_tail;
				intrusivePooled_tail = intrusivePooled_tail.intrusivePooled_prev;
				(cast(byte*)res)[size_t.sizeof*2..res.classinfo.init.length] = res.classinfo.init[size_t.sizeof*2..$];
			}
		}
		
		res.initialize(t);
		return res;
	}

	
	void intrusivePooledRelease() {
		synchronized (typeof(this).classinfo) {
			intrusivePooled_prev = intrusivePooled_tail;
			intrusivePooled_tail = this;
		}
	}
}


template MIntrusiveLinked() {
	static typeof(this) intrusiveLinked_head;
	static typeof(this) intrusiveLinked_tail;
	typeof(this) intrusiveLinked_prev;
	typeof(this) intrusiveLinked_next;
	
	void intrusiveLinkedInit() {
		synchronized (typeof(this).classinfo) {
			if (intrusiveLinked_tail is null) {
				intrusiveLinked_head = this;
			} else {
				intrusiveLinked_tail.intrusiveLinked_next = this;
			}
			intrusiveLinked_prev = intrusiveLinked_tail;
			intrusiveLinked_tail = this;
		}
	}

	void intrusiveLinkedUnlink() {
		synchronized (typeof(this).classinfo) {
			if (intrusiveLinked_prev) {
				intrusiveLinked_prev.intrusiveLinked_next = intrusiveLinked_next;
			}
			
			if (intrusiveLinked_next) {
				intrusiveLinked_next.intrusiveLinked_prev = intrusiveLinked_prev;
			}
		
			if (intrusiveLinked_head is this) {
				intrusiveLinked_head = intrusiveLinked_next;
			}
			
			if (intrusiveLinked_tail is this) {
				intrusiveLinked_tail = intrusiveLinked_prev;
			}
		}
		
		intrusiveLinked_prev = intrusiveLinked_next = null;
	}
}


template MDeeEditor() {
	mixin MIntrusiveLinked;
	
	static createDeeEditor_fp _createDeeEditor;
	
	protected override void _backendInit() {
		assert (_createDeeEditor !is null);
		this.cctx = _createDeeEditor(cast(void*)this);
		intrusiveLinkedInit();
	}
	
	protected static extern(C) {
		void function(void* cctx) Editor_InvalidateStyleData;
		void function(void* cctx) Editor_InvalidateStyleRedraw;
		void function(void* cctx) Editor_RefreshStyleData;
		void function(void* cctx) Editor_DropGraphics;
		PRectangle function(void* cctx) Editor_GetTextRectangle;
		int function(void* cctx) Editor_LinesOnScreen;
		int function(void* cctx) Editor_LinesToScroll;
		int function(void* cctx) Editor_MaxScrollPos;
		Point function(void* cctx, int pos) Editor_LocationFromPosition;
		int function(void* cctx, int pos) Editor_XFromPosition;
		int function(void* cctx, Point pt) Editor_PositionFromLocation;
		int function(void* cctx, Point pt) Editor_PositionFromLocationClose;
		int function(void* cctx, int line, int x) Editor_PositionFromLineX;
		int function(void* cctx, Point pt) Editor_LineFromLocation;
		void function(void* cctx, int topLineNew) Editor_SetTopLine;
		bool function(void* cctx) Editor_AbandonPaint;
		void function(void* cctx, PRectangle rc) Editor_RedrawRect;
		void function(void* cctx) Editor_Redraw;
		void function(void* cctx, int line) Editor_RedrawSelMargin;
		PRectangle function(void* cctx, int start, int end) Editor_RectangleFromRange;
		void function(void* cctx, int start, int end) Editor_InvalidateRange;
		int function(void* cctx) Editor_CurrentPosition;
		bool function(void* cctx) Editor_SelectionEmpty;
		int function(void* cctx) Editor_SelectionStart;
		int function(void* cctx) Editor_SelectionEnd;
		void function(void* cctx) Editor_SetRectangularRange;
		void function(void* cctx, int currentPos_, int anchor_, bool invalidateWholeSelection) Editor_InvalidateSelection;
		void function(void* cctx, int currentPos_, int anchor_) Editor_SetSelection;
		void function(void* cctx, int currentPos_) Editor_SetSelection2;
		void function(void* cctx, int currentPos_) Editor_SetEmptySelection;
		bool function(void* cctx, int start, int end) Editor_RangeContainsProtected;
		bool function(void* cctx) Editor_SelectionContainsProtected;
		int function(void* cctx, int pos, int moveDir, bool checkLineEnd) Editor_MovePositionOutsideChar;
		int function(void* cctx, int newPos, selTypes sel, bool ensureVisible) Editor_MovePositionTo;
		int function(void* cctx, int pos, int moveDir) Editor_MovePositionSoVisible;
		void function(void* cctx) Editor_SetLastXChosen;
		void function(void* cctx, int line, bool moveThumb) Editor_ScrollTo;
		void function(void* cctx, int xPos) Editor_HorizontalScrollTo;
		void function(void* cctx, bool ensureVisible) Editor_MoveCaretInsideView;
		int function(void* cctx, int pos) Editor_DisplayFromPosition;
		void function(void* cctx, bool useMargin, bool vert, bool horiz) Editor_EnsureCaretVisible;
		void function(void* cctx) Editor_ShowCaretAtCurrentPosition;
		void function(void* cctx) Editor_DropCaret;
		void function(void* cctx) Editor_InvalidateCaret;
		void function(void* cctx, int docLineStart, int docLineEnd) Editor_NeedWrapping;
		bool function(void* cctx, void* surface, int lineToWrap) Editor_WrapOneLine;
		bool function(void* cctx, bool fullWrap, int priorityWrapLineStart) Editor_WrapLines;
		void function(void* cctx) Editor_LinesJoin;
		void function(void* cctx, int pixelWidth) Editor_LinesSplit;
		int function(void* cctx, int markerCheck, int markerDefault) Editor_SubstituteMarkerIfEmpty;
		void function(void* cctx, void* surface, PRectangle* rc) Editor_PaintSelMargin;
		LineLayout* function(void* cctx, int lineNumber) Editor_RetrieveLineLayout;
		void function(void* cctx, int line, void* surface, ViewStyle* vstyle, LineLayout* ll, int width) Editor_LayoutLine;
		ColourAllocated function(void* cctx, ViewStyle* vsDraw) Editor_SelectionBackground;
		ColourAllocated function(void* cctx, ViewStyle* vsDraw, bool overrideBackground, ColourAllocated background, bool inSelection, bool inHotspot, int styleMain, int i, LineLayout* ll) Editor_TextBackground;
		void function(void* cctx, void* surface, int lineVisible, int lineHeight, int start, PRectangle rcSegment, bool highlight) Editor_DrawIndentGuide;
		void function(void* cctx, void* surface, PRectangle rcPlace, bool isEndMarker, ColourAllocated wrapColour) Editor_DrawWrapMarker;
		void function(void* cctx, void* surface, ViewStyle* vsDraw, PRectangle rcLine, LineLayout* ll, int line, int lineEnd, int xStart, int subLine, int subLineStart, bool overrideBackground, ColourAllocated background, bool drawWrapMark, ColourAllocated wrapColour) Editor_DrawEOL;
		void function(void* cctx, void* surface, ViewStyle* vsDraw, int line, int xStart, PRectangle rcLine, LineLayout* ll, int subLine, int lineEnd, bool under) Editor_DrawIndicators;
		void function(void* cctx, void* surface, ViewStyle* vsDraw, int line, int lineVisible, int xStart, PRectangle rcLine, LineLayout* ll, int subLine) Editor_DrawLine;
		void function(void* cctx, void* surface, ViewStyle* vsDraw, LineLayout* ll, int subLine, int xStart, int offset, int posCaret, PRectangle rcCaret) Editor_DrawBlockCaret;
		void function(void* cctx, void* surfaceWindow) Editor_RefreshPixMaps;
		void function(void* cctx, void* surfaceWindow, PRectangle rcArea) Editor_Paint;
		long function(void* cctx, bool draw, RangeToFormat* pfr) Editor_FormatRange;
		int function(void* cctx, int style,  char* text) Editor_TextWidth;
		void function(void* cctx) Editor_SetScrollBars;
		void function(void* cctx) Editor_ChangeSize;
		void function(void* cctx, char ch) Editor_AddChar;
		void function(void* cctx) Editor_ClearSelection;
		void function(void* cctx) Editor_ClearAll;
		void function(void* cctx) Editor_ClearDocumentStyle;
		void function(void* cctx) Editor_Cut;
		void function(void* cctx, int pos,  char* ptr, int len) Editor_PasteRectangular;
		void function(void* cctx) Editor_Clear;
		void function(void* cctx) Editor_SelectAll;
		void function(void* cctx) Editor_Undo;
		void function(void* cctx) Editor_Redo;
		void function(void* cctx) Editor_DelChar;
		void function(void* cctx, bool allowLineStartDeletion) Editor_DelCharBack;
		void function(void* cctx, int ch) Editor_NotifyChar;
		void function(void* cctx, int position) Editor_NotifyMove;
		void function(void* cctx, bool isSavePoint) Editor_NotifySavePoint;
		void function(void* cctx) Editor_NotifyModifyAttempt;
		void function(void* cctx, int position, bool shift, bool ctrl, bool alt) Editor_NotifyHotSpotClicked;
		void function(void* cctx, int position, bool shift, bool ctrl, bool alt) Editor_NotifyHotSpotDoubleClicked;
		void function(void* cctx) Editor_NotifyUpdateUI;
		void function(void* cctx) Editor_NotifyPainted;
		void function(void* cctx, bool click, int position, bool shift, bool ctrl, bool alt) Editor_NotifyIndicatorClick;
		bool function(void* cctx, Point pt, bool shift, bool ctrl, bool alt) Editor_NotifyMarginClick;
		void function(void* cctx, int pos, int len) Editor_NotifyNeedShown;
		void function(void* cctx, Point pt, bool state) Editor_NotifyDwelling;
		void function(void* cctx) Editor_NotifyZoom;
		void function(void* cctx, void* document, void* userData) Editor_NotifyModifyAttempt2;
		void function(void* cctx, void* document, void* userData, bool atSavePoint) Editor_NotifySavePoint2;
		void function(void* cctx, DocModification mh) Editor_CheckModificationForWrap;
		void function(void* cctx, void* document, DocModification mh, void* userData) Editor_NotifyModified;
		void function(void* cctx, void* document, void* userData) Editor_NotifyDeleted;
		void function(void* cctx, void* doc, void* userData, int endPos) Editor_NotifyStyleNeeded;
		void function(void* cctx, uint iMessage, uptr_t wParam, sptr_t lParam) Editor_NotifyMacroRecord;
		void function(void* cctx, int direction, selTypes sel, bool stuttered) Editor_PageMove;
		void function(void* cctx, bool makeUpperCase) Editor_ChangeCaseOfSelection;
		void function(void* cctx) Editor_LineTranspose;
		void function(void* cctx, bool forLine) Editor_Duplicate;
		void function(void* cctx) Editor_NewLine;
		void function(void* cctx, int direction, selTypes sel) Editor_CursorUpOrDown;
		void function(void* cctx, int direction, selTypes sel) Editor_ParaUpOrDown;
		int function(void* cctx, int pos, bool start) Editor_StartEndDisplayLine;
		int function(void* cctx, int key, bool shift, bool ctrl, bool alt, bool* consumed) Editor_KeyDown;
		int function(void* cctx) Editor_GetWhitespaceVisible;
		void function(void* cctx, int view) Editor_SetWhitespaceVisible;
		void function(void* cctx, bool forwards) Editor_Indent;
		long function(void* cctx, uptr_t wParam, sptr_t lParam) Editor_FindText;
		void function(void* cctx) Editor_SearchAnchor;
		long function(void* cctx, uint iMessage, uptr_t wParam, sptr_t lParam) Editor_SearchText;
		long function(void* cctx,  char* text, int length) Editor_SearchInTarget;
		void function(void* cctx, int lineNo) Editor_GoToLine;
		char* function(void* cctx, int start, int end) Editor_CopyRange;
		void function(void* cctx, SelectionText* ss, bool allowLineCopy, int start, int end) Editor_CopySelectionFromRange;
		void function(void* cctx, SelectionText* ss, bool allowLineCopy) Editor_CopySelectionRange;
		void function(void* cctx, int start, int end) Editor_CopyRangeToClipboard;
		void function(void* cctx, int length,  char* text) Editor_CopyText;
		void function(void* cctx, int newPos) Editor_SetDragPosition;
		void function(void* cctx, int position,  char* value, bool moving, bool rectangular) Editor_DropAt;
		int function(void* cctx, int pos) Editor_PositionInSelection;
		bool function(void* cctx, Point pt) Editor_PointInSelection;
		bool function(void* cctx, Point pt) Editor_PointInSelMargin;
		void function(void* cctx, int lineCurrent_, int lineAnchor_) Editor_LineSelection;
		void function(void* cctx, bool mouseMoved) Editor_DwellEnd;
		void function(void* cctx, Point pt) Editor_ButtonMove;
		void function(void* cctx, Point pt, uint curTime, bool ctrl) Editor_ButtonUp;
		void function(void* cctx) Editor_Tick;
		bool function(void* cctx) Editor_Idle;
		void function(void* cctx, bool focusState) Editor_SetFocusState;
		bool function(void* cctx) Editor_PaintContainsMargin;
		void function(void* cctx, Range r) Editor_CheckForChangeOutsidePaint;
		void function(void* cctx, Position pos0, Position pos1, int matchStyle) Editor_SetBraceHighlight;
		void function(void* cctx, void* document) Editor_SetDocPointer;
		void function(void* cctx, int* line, bool doExpand) Editor_Expand;
		void function(void* cctx, int line) Editor_ToggleContraction;
		void function(void* cctx, int lineDoc, bool enforcePolicy) Editor_EnsureLineVisible;
		int function(void* cctx, bool replacePatterns,  char* text, int length) Editor_ReplaceTarget;
		bool function(void* cctx, int position) Editor_PositionIsHotspot;
		bool function(void* cctx, Point pt) Editor_PointIsHotspot;
		void function(void* cctx, Point* pt) Editor_SetHotSpotRange;
		void function(void* cctx, int* hsStart, int* hsEnd) Editor_GetHotSpotRange;
		int function(void* cctx) Editor_CodePage;
		int function(void* cctx, int line) Editor_WrapCount;
		void function(void* cctx, char* buffer, int appendLength) Editor_AddStyledText;
		void function(void* cctx, uint iMessage, uptr_t wParam, sptr_t lParam) Editor_StyleSetMessage;
		sptr_t function(void* cctx, uint iMessage, uptr_t wParam, sptr_t lParam) Editor_StyleGetMessage;
		bool function(void* cctx) Editor_IsUnicodeMode;
		void function(void* cctx, char* s, uint len, bool treatAsDBCS) Editor_AddCharUTF;
		int function(void* cctx, uint iMessage) Editor_KeyCommand;
		void function(void* cctx, Point pt, uint curTime, bool shift, bool ctrl, bool alt) Editor_ButtonDown;
		sptr_t function(void* cctx, uint iMessage, uptr_t wParam, sptr_t lParam) Editor_WndProc;
	}

	override void InvalidateStyleData() { return Editor_InvalidateStyleData(cctx); }
	override void InvalidateStyleRedraw() { return Editor_InvalidateStyleRedraw(cctx); }
	override void RefreshStyleData() { return Editor_RefreshStyleData(cctx); }
	override void DropGraphics() { return Editor_DropGraphics(cctx); }
	override PRectangle GetTextRectangle() { return Editor_GetTextRectangle(cctx); }
	override int LinesOnScreen() { return Editor_LinesOnScreen(cctx); }
	override int LinesToScroll() { return Editor_LinesToScroll(cctx); }
	override int MaxScrollPos() { return Editor_MaxScrollPos(cctx); }
	override Point LocationFromPosition(int pos) { return Editor_LocationFromPosition(cctx, pos); }
	override int XFromPosition(int pos) { return Editor_XFromPosition(cctx, pos); }
	override int PositionFromLocation(Point pt) { return Editor_PositionFromLocation(cctx, pt); }
	override int PositionFromLocationClose(Point pt) { return Editor_PositionFromLocationClose(cctx, pt); }
	override int PositionFromLineX(int line, int x) { return Editor_PositionFromLineX(cctx, line, x); }
	override int LineFromLocation(Point pt) { return Editor_LineFromLocation(cctx, pt); }
	override void SetTopLine(int topLineNew) { return Editor_SetTopLine(cctx, topLineNew); }
	override bool AbandonPaint() { return Editor_AbandonPaint(cctx); }
	override void RedrawRect(PRectangle rc) { return Editor_RedrawRect(cctx, rc); }
	override void Redraw() { return Editor_Redraw(cctx); }
	override void RedrawSelMargin(int line) { return Editor_RedrawSelMargin(cctx, line); }
	override PRectangle RectangleFromRange(int start, int end) { return Editor_RectangleFromRange(cctx, start, end); }
	override void InvalidateRange(int start, int end) { return Editor_InvalidateRange(cctx, start, end); }
	override int CurrentPosition() { return Editor_CurrentPosition(cctx); }
	override bool SelectionEmpty() { return Editor_SelectionEmpty(cctx); }
	override int SelectionStart() { return Editor_SelectionStart(cctx); }
	override int SelectionEnd() { return Editor_SelectionEnd(cctx); }
	override void SetRectangularRange() { return Editor_SetRectangularRange(cctx); }
	override void InvalidateSelection(int currentPos_, int anchor_, bool invalidateWholeSelection) { return Editor_InvalidateSelection(cctx, currentPos_, anchor_, invalidateWholeSelection); }
	override void SetSelection(int currentPos_, int anchor_) { return Editor_SetSelection(cctx, currentPos_, anchor_); }
	override void SetSelection(int currentPos_) { return Editor_SetSelection2(cctx, currentPos_); }
	override void SetEmptySelection(int currentPos_) { return Editor_SetEmptySelection(cctx, currentPos_); }
	override bool RangeContainsProtected(int start, int end) { return Editor_RangeContainsProtected(cctx, start, end); }
	override bool SelectionContainsProtected() { return Editor_SelectionContainsProtected(cctx); }
	override int MovePositionOutsideChar(int pos, int moveDir, bool checkLineEnd) { return Editor_MovePositionOutsideChar(cctx, pos, moveDir, checkLineEnd); }
	override int MovePositionTo(int newPos, selTypes sel, bool ensureVisible) { return Editor_MovePositionTo(cctx, newPos, sel, ensureVisible); }
	override int MovePositionSoVisible(int pos, int moveDir) { return Editor_MovePositionSoVisible(cctx, pos, moveDir); }
	override void SetLastXChosen() { return Editor_SetLastXChosen(cctx); }
	override void ScrollTo(int line, bool moveThumb) { return Editor_ScrollTo(cctx, line, moveThumb); }
	override void HorizontalScrollTo(int xPos) { return Editor_HorizontalScrollTo(cctx, xPos); }
	override void MoveCaretInsideView(bool ensureVisible) { return Editor_MoveCaretInsideView(cctx, ensureVisible); }
	override int DisplayFromPosition(int pos) { return Editor_DisplayFromPosition(cctx, pos); }
	override void EnsureCaretVisible(bool useMargin, bool vert, bool horiz) { return Editor_EnsureCaretVisible(cctx, useMargin, vert, horiz); }
	override void ShowCaretAtCurrentPosition() { return Editor_ShowCaretAtCurrentPosition(cctx); }
	override void DropCaret() { return Editor_DropCaret(cctx); }
	override void InvalidateCaret() { return Editor_InvalidateCaret(cctx); }
	override void NeedWrapping(int docLineStart, int docLineEnd) { return Editor_NeedWrapping(cctx, docLineStart, docLineEnd); }
	override bool WrapOneLine(void* surface, int lineToWrap) { return Editor_WrapOneLine(cctx, surface, lineToWrap); }
	override bool WrapLines(bool fullWrap, int priorityWrapLineStart) { return Editor_WrapLines(cctx, fullWrap, priorityWrapLineStart); }
	override void LinesJoin() { return Editor_LinesJoin(cctx); }
	override void LinesSplit(int pixelWidth) { return Editor_LinesSplit(cctx, pixelWidth); }
	override int SubstituteMarkerIfEmpty(int markerCheck, int markerDefault) { return Editor_SubstituteMarkerIfEmpty(cctx, markerCheck, markerDefault); }
	override void PaintSelMargin(void* surface, ref PRectangle  rc) { return Editor_PaintSelMargin(cctx, surface, &rc); }
	override LineLayout* RetrieveLineLayout(int lineNumber) { return Editor_RetrieveLineLayout(cctx, lineNumber); }
	override void LayoutLine(int line, void* surface, ref ViewStyle  vstyle, LineLayout* ll, int width) { return Editor_LayoutLine(cctx, line, surface, &vstyle, ll, width); }
	override ColourAllocated SelectionBackground(ref ViewStyle  vsDraw) { return Editor_SelectionBackground(cctx, &vsDraw); }
	override ColourAllocated TextBackground(ref ViewStyle  vsDraw, bool overrideBackground, ColourAllocated background, bool inSelection, bool inHotspot, int styleMain, int i, LineLayout* ll) { return Editor_TextBackground(cctx, &vsDraw, overrideBackground, background, inSelection, inHotspot, styleMain, i, ll); }
	override void DrawIndentGuide(void* surface, int lineVisible, int lineHeight, int start, PRectangle rcSegment, bool highlight) { return Editor_DrawIndentGuide(cctx, surface, lineVisible, lineHeight, start, rcSegment, highlight); }
	override void DrawWrapMarker(void* surface, PRectangle rcPlace, bool isEndMarker, ColourAllocated wrapColour) { return Editor_DrawWrapMarker(cctx, surface, rcPlace, isEndMarker, wrapColour); }
	override void DrawEOL(void* surface, ref ViewStyle  vsDraw, PRectangle rcLine, LineLayout* ll, int line, int lineEnd, int xStart, int subLine, int subLineStart, bool overrideBackground, ColourAllocated background, bool drawWrapMark, ColourAllocated wrapColour) { return Editor_DrawEOL(cctx, surface, &vsDraw, rcLine, ll, line, lineEnd, xStart, subLine, subLineStart, overrideBackground, background, drawWrapMark, wrapColour); }
	override void DrawIndicators(void* surface, ref ViewStyle  vsDraw, int line, int xStart, PRectangle rcLine, LineLayout* ll, int subLine, int lineEnd, bool under) { return Editor_DrawIndicators(cctx, surface, &vsDraw, line, xStart, rcLine, ll, subLine, lineEnd, under); }
	override void DrawLine(void* surface, ref ViewStyle  vsDraw, int line, int lineVisible, int xStart, PRectangle rcLine, LineLayout* ll, int subLine) { return Editor_DrawLine(cctx, surface, &vsDraw, line, lineVisible, xStart, rcLine, ll, subLine); }
	override void DrawBlockCaret(void* surface, ref ViewStyle  vsDraw, LineLayout* ll, int subLine, int xStart, int offset, int posCaret, PRectangle rcCaret) { return Editor_DrawBlockCaret(cctx, surface, &vsDraw, ll, subLine, xStart, offset, posCaret, rcCaret); }
	override void RefreshPixMaps(void* surfaceWindow) { return Editor_RefreshPixMaps(cctx, surfaceWindow); }
	override void Paint(void* surfaceWindow, PRectangle rcArea) { return Editor_Paint(cctx, surfaceWindow, rcArea); }
	override long FormatRange(bool draw, RangeToFormat* pfr) { return Editor_FormatRange(cctx, draw, pfr); }
	override int TextWidth(int style,  char* text) { return Editor_TextWidth(cctx, style, text); }
	override void SetScrollBars() { return Editor_SetScrollBars(cctx); }
	override void ChangeSize() { return Editor_ChangeSize(cctx); }
	override void AddChar(char ch) { return Editor_AddChar(cctx, ch); }
	override void ClearSelection() { return Editor_ClearSelection(cctx); }
	override void ClearAll() { return Editor_ClearAll(cctx); }
	override void ClearDocumentStyle() { return Editor_ClearDocumentStyle(cctx); }
	override void Cut() { return Editor_Cut(cctx); }
	override void PasteRectangular(int pos,  char* ptr, int len) { return Editor_PasteRectangular(cctx, pos, ptr, len); }
	override void Clear() { return Editor_Clear(cctx); }
	override void SelectAll() { return Editor_SelectAll(cctx); }
	override void Undo() { return Editor_Undo(cctx); }
	override void Redo() { return Editor_Redo(cctx); }
	override void DelChar() { return Editor_DelChar(cctx); }
	override void DelCharBack(bool allowLineStartDeletion) { return Editor_DelCharBack(cctx, allowLineStartDeletion); }
	override void NotifyChar(int ch) { return Editor_NotifyChar(cctx, ch); }
	override void NotifyMove(int position) { return Editor_NotifyMove(cctx, position); }
	override void NotifySavePoint(bool isSavePoint) { return Editor_NotifySavePoint(cctx, isSavePoint); }
	override void NotifyModifyAttempt() { return Editor_NotifyModifyAttempt(cctx); }
	override void NotifyHotSpotClicked(int position, bool shift, bool ctrl, bool alt) { return Editor_NotifyHotSpotClicked(cctx, position, shift, ctrl, alt); }
	override void NotifyHotSpotDoubleClicked(int position, bool shift, bool ctrl, bool alt) { return Editor_NotifyHotSpotDoubleClicked(cctx, position, shift, ctrl, alt); }
	override void NotifyUpdateUI() { return Editor_NotifyUpdateUI(cctx); }
	override void NotifyPainted() { return Editor_NotifyPainted(cctx); }
	override void NotifyIndicatorClick(bool click, int position, bool shift, bool ctrl, bool alt) { return Editor_NotifyIndicatorClick(cctx, click, position, shift, ctrl, alt); }
	override bool NotifyMarginClick(Point pt, bool shift, bool ctrl, bool alt) { return Editor_NotifyMarginClick(cctx, pt, shift, ctrl, alt); }
	override void NotifyNeedShown(int pos, int len) { return Editor_NotifyNeedShown(cctx, pos, len); }
	override void NotifyDwelling(Point pt, bool state) { return Editor_NotifyDwelling(cctx, pt, state); }
	override void NotifyZoom() { return Editor_NotifyZoom(cctx); }
	override void NotifyModifyAttempt(void* document, void* userData) { return Editor_NotifyModifyAttempt2(cctx, document, userData); }
	override void NotifySavePoint(void* document, void* userData, bool atSavePoint) { return Editor_NotifySavePoint2(cctx, document, userData, atSavePoint); }
	override void CheckModificationForWrap(DocModification mh) { return Editor_CheckModificationForWrap(cctx, mh); }
	override void NotifyModified(void* document, DocModification mh, void* userData) { return Editor_NotifyModified(cctx, document, mh, userData); }
	override void NotifyDeleted(void* document, void* userData) { return Editor_NotifyDeleted(cctx, document, userData); }
	override void NotifyStyleNeeded(void* doc, void* userData, int endPos) { return Editor_NotifyStyleNeeded(cctx, doc, userData, endPos); }
	override void NotifyMacroRecord(uint iMessage, uptr_t wParam, sptr_t lParam) { return Editor_NotifyMacroRecord(cctx, iMessage, wParam, lParam); }
	override void PageMove(int direction, selTypes sel, bool stuttered) { return Editor_PageMove(cctx, direction, sel, stuttered); }
	override void ChangeCaseOfSelection(bool makeUpperCase) { return Editor_ChangeCaseOfSelection(cctx, makeUpperCase); }
	override void LineTranspose() { return Editor_LineTranspose(cctx); }
	override void Duplicate(bool forLine) { return Editor_Duplicate(cctx, forLine); }
	override void NewLine() { return Editor_NewLine(cctx); }
	override void CursorUpOrDown(int direction, selTypes sel) { return Editor_CursorUpOrDown(cctx, direction, sel); }
	override void ParaUpOrDown(int direction, selTypes sel) { return Editor_ParaUpOrDown(cctx, direction, sel); }
	override int StartEndDisplayLine(int pos, bool start) { return Editor_StartEndDisplayLine(cctx, pos, start); }
	override int KeyDown(int key, bool shift, bool ctrl, bool alt, bool* consumed) { return Editor_KeyDown(cctx, key, shift, ctrl, alt, consumed); }
	override int GetWhitespaceVisible() { return Editor_GetWhitespaceVisible(cctx); }
	override void SetWhitespaceVisible(int view) { return Editor_SetWhitespaceVisible(cctx, view); }
	override void Indent(bool forwards) { return Editor_Indent(cctx, forwards); }
	override long FindText(uptr_t wParam, sptr_t lParam) { return Editor_FindText(cctx, wParam, lParam); }
	override void SearchAnchor() { return Editor_SearchAnchor(cctx); }
	override long SearchText(uint iMessage, uptr_t wParam, sptr_t lParam) { return Editor_SearchText(cctx, iMessage, wParam, lParam); }
	override long SearchInTarget( char* text, int length) { return Editor_SearchInTarget(cctx, text, length); }
	override void GoToLine(int lineNo) { return Editor_GoToLine(cctx, lineNo); }
	override char* CopyRange(int start, int end) { return Editor_CopyRange(cctx, start, end); }
	override void CopySelectionFromRange(SelectionText* ss, bool allowLineCopy, int start, int end) { return Editor_CopySelectionFromRange(cctx, ss, allowLineCopy, start, end); }
	override void CopySelectionRange(SelectionText* ss, bool allowLineCopy) { return Editor_CopySelectionRange(cctx, ss, allowLineCopy); }
	override void CopyRangeToClipboard(int start, int end) { return Editor_CopyRangeToClipboard(cctx, start, end); }
	override void CopyText(int length,  char* text) { return Editor_CopyText(cctx, length, text); }
	override void SetDragPosition(int newPos) { return Editor_SetDragPosition(cctx, newPos); }
	override void DropAt(int position,  char* value, bool moving, bool rectangular) { return Editor_DropAt(cctx, position, value, moving, rectangular); }
	override int PositionInSelection(int pos) { return Editor_PositionInSelection(cctx, pos); }
	override bool PointInSelection(Point pt) { return Editor_PointInSelection(cctx, pt); }
	override bool PointInSelMargin(Point pt) { return Editor_PointInSelMargin(cctx, pt); }
	override void LineSelection(int lineCurrent_, int lineAnchor_) { return Editor_LineSelection(cctx, lineCurrent_, lineAnchor_); }
	override void DwellEnd(bool mouseMoved) { return Editor_DwellEnd(cctx, mouseMoved); }
	override void ButtonMove(Point pt) { return Editor_ButtonMove(cctx, pt); }
	override void ButtonUp(Point pt, uint curTime, bool ctrl) { return Editor_ButtonUp(cctx, pt, curTime, ctrl); }
	override void Tick() { return Editor_Tick(cctx); }
	override bool Idle() { return Editor_Idle(cctx); }
	override void SetFocusState(bool focusState) { return Editor_SetFocusState(cctx, focusState); }
	override bool PaintContainsMargin() { return Editor_PaintContainsMargin(cctx); }
	override void CheckForChangeOutsidePaint(Range r) { return Editor_CheckForChangeOutsidePaint(cctx, r); }
	override void SetBraceHighlight(Position pos0, Position pos1, int matchStyle) { return Editor_SetBraceHighlight(cctx, pos0, pos1, matchStyle); }
	override void SetDocPointer(void* document) { return Editor_SetDocPointer(cctx, document); }
	override void Expand(ref int  line, bool doExpand) { return Editor_Expand(cctx, &line, doExpand); }
	override void ToggleContraction(int line) { return Editor_ToggleContraction(cctx, line); }
	override void EnsureLineVisible(int lineDoc, bool enforcePolicy) { return Editor_EnsureLineVisible(cctx, lineDoc, enforcePolicy); }
	override int ReplaceTarget(bool replacePatterns,  char* text, int length) { return Editor_ReplaceTarget(cctx, replacePatterns, text, length); }
	override bool PositionIsHotspot(int position) { return Editor_PositionIsHotspot(cctx, position); }
	override bool PointIsHotspot(Point pt) { return Editor_PointIsHotspot(cctx, pt); }
	override void SetHotSpotRange(Point* pt) { return Editor_SetHotSpotRange(cctx, pt); }
	override void GetHotSpotRange(ref int hsStart, ref int hsEnd) { return Editor_GetHotSpotRange(cctx, &hsStart, &hsEnd); }
	override int CodePage() { return Editor_CodePage(cctx); }
	override int WrapCount(int line) { return Editor_WrapCount(cctx, line); }
	override void AddStyledText(char* buffer, int appendLength) { return Editor_AddStyledText(cctx, buffer, appendLength); }
	override void StyleSetMessage(uint iMessage, uptr_t wParam, sptr_t lParam) { return Editor_StyleSetMessage(cctx, iMessage, wParam, lParam); }
	override sptr_t StyleGetMessage(uint iMessage, uptr_t wParam, sptr_t lParam) { return Editor_StyleGetMessage(cctx, iMessage, wParam, lParam); }
	override bool IsUnicodeMode() { return Editor_IsUnicodeMode(cctx); }
	override void AddCharUTF(char* s, uint len, bool treatAsDBCS) { return Editor_AddCharUTF(cctx, s, len, treatAsDBCS); }
	override int KeyCommand(uint iMessage) { return Editor_KeyCommand(cctx, iMessage); }
	override void ButtonDown(Point pt, uint curTime, bool shift, bool ctrl, bool alt) { return Editor_ButtonDown(cctx, pt, curTime, shift, ctrl, alt); }
	override sptr_t WndProc(uint iMessage, uptr_t wParam, sptr_t lParam) { return Editor_WndProc(cctx, iMessage, wParam, lParam); }
}


class DeeEditor {
	this() {
		_backendInit();
	}
	
	protected abstract	void _backendInit();
	protected void*		cctx;
	
	// ----

	enum { autoScrollDelay = 200 }
	enum SelectionType { selChar, selWord, selLine }
	enum InDragDrop { ddNone, ddInitial, ddDragging }
	enum PaintState { notPainting, painting, paintAbandoned }
	enum selTypes { noSel, selStream, selRectangle, selLines }
	enum WrapState { eWrapNone, eWrapWord, eWrapChar }
	enum { wrapLineLarge = 0x7ffffff }
	
	// ----
	
	abstract void Initialise();
	abstract void Finalise();
//	abstract void RefreshColourPalette(Palette* pal, bool want);
	abstract PRectangle GetClientRectangle();
	abstract void ScrollText(int linesToMove);
	abstract void UpdateSystemCaret();
	abstract void SetVerticalScrollPos();
	abstract void SetHorizontalScrollPos();
	abstract bool ModifyScrollBars(int nMax, int nPage);
	abstract void ReconfigureScrollBars();
	//abstract void AddCharUTF(char *s, uint len, bool treatAsDBCS);
	abstract void Copy();
	abstract void CopyAllowLine();
	abstract bool CanPaste();
	abstract void Paste();
	abstract void ClaimSelection();
	abstract void NotifyChange();
	abstract void NotifyFocus(bool focus);
	abstract int GetCtrlID();
	abstract void NotifyParent(SCNotification scn);
	//abstract void NotifyStyleToNeeded(int endStyleNeeded);
	abstract void NotifyDoubleClick(Point pt, bool shift, bool ctrl, bool alt);
	abstract void CancelModes();
	//abstract int KeyCommand(uint iMessage);
	abstract int KeyDefault(int key, int modifiers);
	abstract void CopyToClipboard(SelectionText* selectedText);
	abstract void DisplayCursor(Window.Cursor c);
	abstract bool DragThreshold(Point ptStart, Point ptNow);
	abstract void StartDrag();
	//abstract void ButtonDown(Point pt, uint curTime, bool shift, bool ctrl, bool alt);
	abstract void SetTicking(bool on);
	abstract bool SetIdle(bool);
	abstract void SetMouseCapture(bool on);
	abstract bool HaveMouseCapture();
	abstract bool PaintContains(PRectangle rc);
	abstract bool ValidCodePage(int codePage);
	abstract uint DefWndProc(uint iMessage, uint wParam, uint lParam);
	//abstract uint WndProc(uint iMessage, uint wParam, uint lParam);
	
	
	// ----
	// impl in C

	abstract void InvalidateStyleData();
	abstract void InvalidateStyleRedraw();
	abstract void RefreshStyleData();
	abstract void DropGraphics();
	abstract PRectangle GetTextRectangle();
	abstract int LinesOnScreen();
	abstract int LinesToScroll();
	abstract int MaxScrollPos();
	abstract Point LocationFromPosition(int pos);
	abstract int XFromPosition(int pos);
	abstract int PositionFromLocation(Point pt);
	abstract int PositionFromLocationClose(Point pt);
	abstract int PositionFromLineX(int line, int x);
	abstract int LineFromLocation(Point pt);
	abstract void SetTopLine(int topLineNew);
	abstract bool AbandonPaint();
	abstract void RedrawRect(PRectangle rc);
	abstract void Redraw();
	abstract void RedrawSelMargin(int line);
	abstract PRectangle RectangleFromRange(int start, int end);
	abstract void InvalidateRange(int start, int end);
	abstract int CurrentPosition();
	abstract bool SelectionEmpty();
	abstract int SelectionStart();
	abstract int SelectionEnd();
	abstract void SetRectangularRange();
	abstract void InvalidateSelection(int currentPos_, int anchor_, bool invalidateWholeSelection);
	abstract void SetSelection(int currentPos_, int anchor_);
	abstract void SetSelection(int currentPos_);
	abstract void SetEmptySelection(int currentPos_);
	abstract bool RangeContainsProtected(int start, int end);
	abstract bool SelectionContainsProtected();
	abstract int MovePositionOutsideChar(int pos, int moveDir, bool checkLineEnd);
	abstract int MovePositionTo(int newPos, selTypes sel, bool ensureVisible);
	abstract int MovePositionSoVisible(int pos, int moveDir);
	abstract void SetLastXChosen();
	abstract void ScrollTo(int line, bool moveThumb);
	abstract void HorizontalScrollTo(int xPos);
	abstract void MoveCaretInsideView(bool ensureVisible);
	abstract int DisplayFromPosition(int pos);
	abstract void EnsureCaretVisible(bool useMargin, bool vert, bool horiz);
	abstract void ShowCaretAtCurrentPosition();
	abstract void DropCaret();
	abstract void InvalidateCaret();
	abstract void NeedWrapping(int docLineStart, int docLineEnd);
	abstract bool WrapOneLine(void* surface, int lineToWrap);
	abstract bool WrapLines(bool fullWrap, int priorityWrapLineStart);
	abstract void LinesJoin();
	abstract void LinesSplit(int pixelWidth);
	abstract int SubstituteMarkerIfEmpty(int markerCheck, int markerDefault);
	abstract void PaintSelMargin(void* surface, ref PRectangle  rc);
	abstract LineLayout* RetrieveLineLayout(int lineNumber);
	abstract void LayoutLine(int line, void* surface, ref ViewStyle  vstyle, LineLayout* ll, int width);
	abstract ColourAllocated SelectionBackground(ref ViewStyle  vsDraw);
	abstract ColourAllocated TextBackground(ref ViewStyle  vsDraw, bool overrideBackground, ColourAllocated background, bool inSelection, bool inHotspot, int styleMain, int i, LineLayout* ll);
	abstract void DrawIndentGuide(void* surface, int lineVisible, int lineHeight, int start, PRectangle rcSegment, bool highlight);
	abstract void DrawWrapMarker(void* surface, PRectangle rcPlace, bool isEndMarker, ColourAllocated wrapColour);
	abstract void DrawEOL(void* surface, ref ViewStyle  vsDraw, PRectangle rcLine, LineLayout* ll, int line, int lineEnd, int xStart, int subLine, int subLineStart, bool overrideBackground, ColourAllocated background, bool drawWrapMark, ColourAllocated wrapColour);
	abstract void DrawIndicators(void* surface, ref ViewStyle  vsDraw, int line, int xStart, PRectangle rcLine, LineLayout* ll, int subLine, int lineEnd, bool under);
	abstract void DrawLine(void* surface, ref ViewStyle  vsDraw, int line, int lineVisible, int xStart, PRectangle rcLine, LineLayout* ll, int subLine);
	abstract void DrawBlockCaret(void* surface, ref ViewStyle  vsDraw, LineLayout* ll, int subLine, int xStart, int offset, int posCaret, PRectangle rcCaret);
	abstract void RefreshPixMaps(void* surfaceWindow);
	abstract void Paint(void* surfaceWindow, PRectangle rcArea);
	abstract long FormatRange(bool draw, RangeToFormat* pfr);
	abstract int TextWidth(int style,  char* text);
	abstract void SetScrollBars();
	abstract void ChangeSize();
	abstract void AddChar(char ch);
	abstract void ClearSelection();
	abstract void ClearAll();
	abstract void ClearDocumentStyle();
	abstract void Cut();
	abstract void PasteRectangular(int pos,  char* ptr, int len);
	abstract void Clear();
	abstract void SelectAll();
	abstract void Undo();
	abstract void Redo();
	abstract void DelChar();
	abstract void DelCharBack(bool allowLineStartDeletion);
	abstract void NotifyChar(int ch);
	abstract void NotifyMove(int position);
	abstract void NotifySavePoint(bool isSavePoint);
	abstract void NotifyModifyAttempt();
	abstract void NotifyHotSpotClicked(int position, bool shift, bool ctrl, bool alt);
	abstract void NotifyHotSpotDoubleClicked(int position, bool shift, bool ctrl, bool alt);
	abstract void NotifyUpdateUI();
	abstract void NotifyPainted();
	abstract void NotifyIndicatorClick(bool click, int position, bool shift, bool ctrl, bool alt);
	abstract bool NotifyMarginClick(Point pt, bool shift, bool ctrl, bool alt);
	abstract void NotifyNeedShown(int pos, int len);
	abstract void NotifyDwelling(Point pt, bool state);
	abstract void NotifyZoom();
	abstract void NotifyModifyAttempt(void* document, void* userData);
	abstract void NotifySavePoint(void* document, void* userData, bool atSavePoint);
	abstract void CheckModificationForWrap(DocModification mh);
	abstract void NotifyModified(void* document, DocModification mh, void* userData);
	abstract void NotifyDeleted(void* document, void* userData);
	abstract void NotifyStyleNeeded(void* doc, void* userData, int endPos);
	abstract void NotifyMacroRecord(uint iMessage, uptr_t wParam, sptr_t lParam);
	abstract void PageMove(int direction, selTypes sel, bool stuttered);
	abstract void ChangeCaseOfSelection(bool makeUpperCase);
	abstract void LineTranspose();
	abstract void Duplicate(bool forLine);
	abstract void NewLine();
	abstract void CursorUpOrDown(int direction, selTypes sel);
	abstract void ParaUpOrDown(int direction, selTypes sel);
	abstract int StartEndDisplayLine(int pos, bool start);
	abstract int KeyDown(int key, bool shift, bool ctrl, bool alt, bool* consumed);
	abstract int GetWhitespaceVisible();
	abstract void SetWhitespaceVisible(int view);
	abstract void Indent(bool forwards);
	abstract long FindText(uptr_t wParam, sptr_t lParam);
	abstract void SearchAnchor();
	abstract long SearchText(uint iMessage, uptr_t wParam, sptr_t lParam);
	abstract long SearchInTarget( char* text, int length);
	abstract void GoToLine(int lineNo);
	abstract char* CopyRange(int start, int end);
	abstract void CopySelectionFromRange(SelectionText* ss, bool allowLineCopy, int start, int end);
	abstract void CopySelectionRange(SelectionText* ss, bool allowLineCopy);
	abstract void CopyRangeToClipboard(int start, int end);
	abstract void CopyText(int length,  char* text);
	abstract void SetDragPosition(int newPos);
	abstract void DropAt(int position,  char* value, bool moving, bool rectangular);
	abstract int PositionInSelection(int pos);
	abstract bool PointInSelection(Point pt);
	abstract bool PointInSelMargin(Point pt);
	abstract void LineSelection(int lineCurrent_, int lineAnchor_);
	abstract void DwellEnd(bool mouseMoved);
	abstract void ButtonMove(Point pt);
	abstract void ButtonUp(Point pt, uint curTime, bool ctrl);
	abstract void Tick();
	abstract bool Idle();
	abstract void SetFocusState(bool focusState);
	abstract bool PaintContainsMargin();
	abstract void CheckForChangeOutsidePaint(Range r);
	abstract void SetBraceHighlight(Position pos0, Position pos1, int matchStyle);
	abstract void SetDocPointer(void* document);
	abstract void Expand(ref int  line, bool doExpand);
	abstract void ToggleContraction(int line);
	abstract void EnsureLineVisible(int lineDoc, bool enforcePolicy);
	abstract int ReplaceTarget(bool replacePatterns,  char* text, int length);
	abstract bool PositionIsHotspot(int position);
	abstract bool PointIsHotspot(Point pt);
	abstract void SetHotSpotRange(Point* pt);
	abstract void GetHotSpotRange(ref int hsStart, ref int hsEnd);
	abstract int CodePage();
	abstract int WrapCount(int line);
	abstract void AddStyledText(char* buffer, int appendLength);
	abstract void StyleSetMessage(uint iMessage, uptr_t wParam, sptr_t lParam);
	abstract sptr_t StyleGetMessage(uint iMessage, uptr_t wParam, sptr_t lParam);
	abstract bool IsUnicodeMode();
	abstract void AddCharUTF(char* s, uint len, bool treatAsDBCS);
	abstract int KeyCommand(uint iMessage);
	abstract void ButtonDown(Point pt, uint curTime, bool shift, bool ctrl, bool alt);
	abstract sptr_t WndProc(uint iMessage, uptr_t wParam, sptr_t lParam);
}



template MDeeSurface() {
	static createDeeSurface_fp _createDeeSurface;
	
	protected override void _backendInit() {
		assert (_createDeeSurface !is null);
		this.cctx = _createDeeSurface(cast(void*)this);
	}
}


class DeeSurface {
	mixin MIntrusiveLinked;
	
	
	void initialize(bool createNewBackend = false) {
		intrusiveLinkedInit();
		if (createNewBackend) {
			_backendInit();
		}
	}
	
		
	abstract void _backendInit();
	void* cctx;
	
	// ----
	
	abstract void Release();
	abstract bool Initialised();
	abstract void PenColour(ColourAllocated fore);
	abstract int LogPixelsY();
	abstract int DeviceHeightFont(int points);
	abstract void MoveTo(int x_, int y_);
	abstract void LineTo(int x_, int y_);
	abstract void Polygon(Point *pts, int npts, ColourAllocated fore, ColourAllocated back);
	abstract void RectangleDraw(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	abstract void FillRectangle(PRectangle rc, ColourAllocated back);
	abstract void FillRectanglePattern(PRectangle rc, DeeSurface surfacePattern);
	abstract void RoundedRectangle(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	abstract void AlphaRectangle(PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags);
	abstract void Ellipse(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	abstract void Copy(PRectangle rc, Point from, DeeSurface surfaceSource);

	abstract void DrawTextCommon(PRectangle rc, void* font_, int ybase, char *s, int len, uint fuOptions);
	abstract void DrawTextNoClip(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back);
	abstract void DrawTextClipped(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back);
	abstract void DrawTextTransparent(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore);
	abstract void MeasureWidths(void* font_, char *s, int len, int *positions);
	abstract int WidthText(void* font_, char *s, int len);
	abstract int WidthChar(void* font_, char ch);
	abstract int Ascent(void* font_);
	abstract int Descent(void* font_);
	abstract int InternalLeading(void* font_);
	abstract int ExternalLeading(void* font_);
	abstract int Height(void* font_);
	abstract int AverageCharWidth(void* font_);

	//abstract int SetPalette(Palette *pal, bool inBackGround);
	abstract void SetClip(PRectangle rc);
	abstract void FlushCachedState();

	abstract void SetUnicodeMode(bool unicodeMode_);
	abstract void SetDBCSMode(int codePage_);
}


void bindDeeSurface(DeeSurface_Funcs* cfuncs) {
	cfuncs.Release = &DeeSurface_Release;
	cfuncs.Initialised = &DeeSurface_Initialised;
	cfuncs.PenColour = &DeeSurface_PenColour;
	cfuncs.LogPixelsY = &DeeSurface_LogPixelsY;
	cfuncs.DeviceHeightFont = &DeeSurface_DeviceHeightFont;
	cfuncs.MoveTo = &DeeSurface_MoveTo;
	cfuncs.LineTo = &DeeSurface_LineTo;
	cfuncs.Polygon = &DeeSurface_Polygon;
	cfuncs.RectangleDraw = &DeeSurface_RectangleDraw;
	cfuncs.FillRectangle = &DeeSurface_FillRectangle;
	cfuncs.FillRectanglePattern = &DeeSurface_FillRectanglePattern;
	cfuncs.RoundedRectangle = &DeeSurface_RoundedRectangle;
	cfuncs.AlphaRectangle = &DeeSurface_AlphaRectangle;
	cfuncs.Ellipse = &DeeSurface_Ellipse;
	cfuncs.Copy = &DeeSurface_Copy;

	cfuncs.DrawTextCommon = &DeeSurface_DrawTextCommon;
	cfuncs.DrawTextNoClip = &DeeSurface_DrawTextNoClip;
	cfuncs.DrawTextClipped = &DeeSurface_DrawTextClipped;
	cfuncs.DrawTextTransparent = &DeeSurface_DrawTextTransparent;
	cfuncs.MeasureWidths = &DeeSurface_MeasureWidths;
	cfuncs.WidthText = &DeeSurface_WidthText;
	cfuncs.WidthChar = &DeeSurface_WidthChar;
	cfuncs.Ascent = &DeeSurface_Ascent;
	cfuncs.Descent = &DeeSurface_Descent;
	cfuncs.InternalLeading = &DeeSurface_InternalLeading;
	cfuncs.ExternalLeading = &DeeSurface_ExternalLeading;
	cfuncs.Height = &DeeSurface_Height;
	cfuncs.AverageCharWidth = &DeeSurface_AverageCharWidth;

	//cfuncs.SetPalette = &DeeSurface_SetPalette;
	cfuncs.SetClip = &DeeSurface_SetClip;
	cfuncs.FlushCachedState = &DeeSurface_FlushCachedState;

	cfuncs.SetUnicodeMode = &DeeSurface_SetUnicodeMode;
	cfuncs.SetDBCSMode = &DeeSurface_SetDBCSMode;
}


void bindEditorCFuncs(EditorImpl)(SharedLib lib) {
	EditorImpl.Editor_InvalidateStyleData = cast(typeof(EditorImpl.Editor_InvalidateStyleData))lib.getSymbol("Editor_InvalidateStyleData");
	assert(EditorImpl.Editor_InvalidateStyleData !is null, "Editor_InvalidateStyleData");

	EditorImpl.Editor_InvalidateStyleRedraw = cast(typeof(EditorImpl.Editor_InvalidateStyleRedraw))lib.getSymbol("Editor_InvalidateStyleRedraw");
	assert(EditorImpl.Editor_InvalidateStyleRedraw !is null, "Editor_InvalidateStyleRedraw");

	EditorImpl.Editor_RefreshStyleData = cast(typeof(EditorImpl.Editor_RefreshStyleData))lib.getSymbol("Editor_RefreshStyleData");
	assert(EditorImpl.Editor_RefreshStyleData !is null, "Editor_RefreshStyleData");

	EditorImpl.Editor_DropGraphics = cast(typeof(EditorImpl.Editor_DropGraphics))lib.getSymbol("Editor_DropGraphics");
	assert(EditorImpl.Editor_DropGraphics !is null, "Editor_DropGraphics");

	EditorImpl.Editor_GetTextRectangle = cast(typeof(EditorImpl.Editor_GetTextRectangle))lib.getSymbol("Editor_GetTextRectangle");
	assert(EditorImpl.Editor_GetTextRectangle !is null, "Editor_GetTextRectangle");

	EditorImpl.Editor_LinesOnScreen = cast(typeof(EditorImpl.Editor_LinesOnScreen))lib.getSymbol("Editor_LinesOnScreen");
	assert(EditorImpl.Editor_LinesOnScreen !is null, "Editor_LinesOnScreen");

	EditorImpl.Editor_LinesToScroll = cast(typeof(EditorImpl.Editor_LinesToScroll))lib.getSymbol("Editor_LinesToScroll");
	assert(EditorImpl.Editor_LinesToScroll !is null, "Editor_LinesToScroll");

	EditorImpl.Editor_MaxScrollPos = cast(typeof(EditorImpl.Editor_MaxScrollPos))lib.getSymbol("Editor_MaxScrollPos");
	assert(EditorImpl.Editor_MaxScrollPos !is null, "Editor_MaxScrollPos");

	EditorImpl.Editor_LocationFromPosition = cast(typeof(EditorImpl.Editor_LocationFromPosition))lib.getSymbol("Editor_LocationFromPosition");
	assert(EditorImpl.Editor_LocationFromPosition !is null, "Editor_LocationFromPosition");

	EditorImpl.Editor_XFromPosition = cast(typeof(EditorImpl.Editor_XFromPosition))lib.getSymbol("Editor_XFromPosition");
	assert(EditorImpl.Editor_XFromPosition !is null, "Editor_XFromPosition");

	EditorImpl.Editor_PositionFromLocation = cast(typeof(EditorImpl.Editor_PositionFromLocation))lib.getSymbol("Editor_PositionFromLocation");
	assert(EditorImpl.Editor_PositionFromLocation !is null, "Editor_PositionFromLocation");

	EditorImpl.Editor_PositionFromLocationClose = cast(typeof(EditorImpl.Editor_PositionFromLocationClose))lib.getSymbol("Editor_PositionFromLocationClose");
	assert(EditorImpl.Editor_PositionFromLocationClose !is null, "Editor_PositionFromLocationClose");

	EditorImpl.Editor_PositionFromLineX = cast(typeof(EditorImpl.Editor_PositionFromLineX))lib.getSymbol("Editor_PositionFromLineX");
	assert(EditorImpl.Editor_PositionFromLineX !is null, "Editor_PositionFromLineX");

	EditorImpl.Editor_LineFromLocation = cast(typeof(EditorImpl.Editor_LineFromLocation))lib.getSymbol("Editor_LineFromLocation");
	assert(EditorImpl.Editor_LineFromLocation !is null, "Editor_LineFromLocation");

	EditorImpl.Editor_SetTopLine = cast(typeof(EditorImpl.Editor_SetTopLine))lib.getSymbol("Editor_SetTopLine");
	assert(EditorImpl.Editor_SetTopLine !is null, "Editor_SetTopLine");

	EditorImpl.Editor_AbandonPaint = cast(typeof(EditorImpl.Editor_AbandonPaint))lib.getSymbol("Editor_AbandonPaint");
	assert(EditorImpl.Editor_AbandonPaint !is null, "Editor_AbandonPaint");

	EditorImpl.Editor_RedrawRect = cast(typeof(EditorImpl.Editor_RedrawRect))lib.getSymbol("Editor_RedrawRect");
	assert(EditorImpl.Editor_RedrawRect !is null, "Editor_RedrawRect");

	EditorImpl.Editor_Redraw = cast(typeof(EditorImpl.Editor_Redraw))lib.getSymbol("Editor_Redraw");
	assert(EditorImpl.Editor_Redraw !is null, "Editor_Redraw");

	EditorImpl.Editor_RedrawSelMargin = cast(typeof(EditorImpl.Editor_RedrawSelMargin))lib.getSymbol("Editor_RedrawSelMargin");
	assert(EditorImpl.Editor_RedrawSelMargin !is null, "Editor_RedrawSelMargin");

	EditorImpl.Editor_RectangleFromRange = cast(typeof(EditorImpl.Editor_RectangleFromRange))lib.getSymbol("Editor_RectangleFromRange");
	assert(EditorImpl.Editor_RectangleFromRange !is null, "Editor_RectangleFromRange");

	EditorImpl.Editor_InvalidateRange = cast(typeof(EditorImpl.Editor_InvalidateRange))lib.getSymbol("Editor_InvalidateRange");
	assert(EditorImpl.Editor_InvalidateRange !is null, "Editor_InvalidateRange");

	EditorImpl.Editor_CurrentPosition = cast(typeof(EditorImpl.Editor_CurrentPosition))lib.getSymbol("Editor_CurrentPosition");
	assert(EditorImpl.Editor_CurrentPosition !is null, "Editor_CurrentPosition");

	EditorImpl.Editor_SelectionEmpty = cast(typeof(EditorImpl.Editor_SelectionEmpty))lib.getSymbol("Editor_SelectionEmpty");
	assert(EditorImpl.Editor_SelectionEmpty !is null, "Editor_SelectionEmpty");

	EditorImpl.Editor_SelectionStart = cast(typeof(EditorImpl.Editor_SelectionStart))lib.getSymbol("Editor_SelectionStart");
	assert(EditorImpl.Editor_SelectionStart !is null, "Editor_SelectionStart");

	EditorImpl.Editor_SelectionEnd = cast(typeof(EditorImpl.Editor_SelectionEnd))lib.getSymbol("Editor_SelectionEnd");
	assert(EditorImpl.Editor_SelectionEnd !is null, "Editor_SelectionEnd");

	EditorImpl.Editor_SetRectangularRange = cast(typeof(EditorImpl.Editor_SetRectangularRange))lib.getSymbol("Editor_SetRectangularRange");
	assert(EditorImpl.Editor_SetRectangularRange !is null, "Editor_SetRectangularRange");

	EditorImpl.Editor_InvalidateSelection = cast(typeof(EditorImpl.Editor_InvalidateSelection))lib.getSymbol("Editor_InvalidateSelection");
	assert(EditorImpl.Editor_InvalidateSelection !is null, "Editor_InvalidateSelection");

	EditorImpl.Editor_SetSelection = cast(typeof(EditorImpl.Editor_SetSelection))lib.getSymbol("Editor_SetSelection");
	assert(EditorImpl.Editor_SetSelection !is null, "Editor_SetSelection");

	EditorImpl.Editor_SetSelection2 = cast(typeof(EditorImpl.Editor_SetSelection2))lib.getSymbol("Editor_SetSelection2");
	assert(EditorImpl.Editor_SetSelection2 !is null, "Editor_SetSelection2");

	EditorImpl.Editor_SetEmptySelection = cast(typeof(EditorImpl.Editor_SetEmptySelection))lib.getSymbol("Editor_SetEmptySelection");
	assert(EditorImpl.Editor_SetEmptySelection !is null, "Editor_SetEmptySelection");

	EditorImpl.Editor_RangeContainsProtected = cast(typeof(EditorImpl.Editor_RangeContainsProtected))lib.getSymbol("Editor_RangeContainsProtected");
	assert(EditorImpl.Editor_RangeContainsProtected !is null, "Editor_RangeContainsProtected");

	EditorImpl.Editor_SelectionContainsProtected = cast(typeof(EditorImpl.Editor_SelectionContainsProtected))lib.getSymbol("Editor_SelectionContainsProtected");
	assert(EditorImpl.Editor_SelectionContainsProtected !is null, "Editor_SelectionContainsProtected");

	EditorImpl.Editor_MovePositionOutsideChar = cast(typeof(EditorImpl.Editor_MovePositionOutsideChar))lib.getSymbol("Editor_MovePositionOutsideChar");
	assert(EditorImpl.Editor_MovePositionOutsideChar !is null, "Editor_MovePositionOutsideChar");

	EditorImpl.Editor_MovePositionTo = cast(typeof(EditorImpl.Editor_MovePositionTo))lib.getSymbol("Editor_MovePositionTo");
	assert(EditorImpl.Editor_MovePositionTo !is null, "Editor_MovePositionTo");

	EditorImpl.Editor_MovePositionSoVisible = cast(typeof(EditorImpl.Editor_MovePositionSoVisible))lib.getSymbol("Editor_MovePositionSoVisible");
	assert(EditorImpl.Editor_MovePositionSoVisible !is null, "Editor_MovePositionSoVisible");

	EditorImpl.Editor_SetLastXChosen = cast(typeof(EditorImpl.Editor_SetLastXChosen))lib.getSymbol("Editor_SetLastXChosen");
	assert(EditorImpl.Editor_SetLastXChosen !is null, "Editor_SetLastXChosen");

	EditorImpl.Editor_ScrollTo = cast(typeof(EditorImpl.Editor_ScrollTo))lib.getSymbol("Editor_ScrollTo");
	assert(EditorImpl.Editor_ScrollTo !is null, "Editor_ScrollTo");

	EditorImpl.Editor_HorizontalScrollTo = cast(typeof(EditorImpl.Editor_HorizontalScrollTo))lib.getSymbol("Editor_HorizontalScrollTo");
	assert(EditorImpl.Editor_HorizontalScrollTo !is null, "Editor_HorizontalScrollTo");

	EditorImpl.Editor_MoveCaretInsideView = cast(typeof(EditorImpl.Editor_MoveCaretInsideView))lib.getSymbol("Editor_MoveCaretInsideView");
	assert(EditorImpl.Editor_MoveCaretInsideView !is null, "Editor_MoveCaretInsideView");

	EditorImpl.Editor_DisplayFromPosition = cast(typeof(EditorImpl.Editor_DisplayFromPosition))lib.getSymbol("Editor_DisplayFromPosition");
	assert(EditorImpl.Editor_DisplayFromPosition !is null, "Editor_DisplayFromPosition");

	EditorImpl.Editor_EnsureCaretVisible = cast(typeof(EditorImpl.Editor_EnsureCaretVisible))lib.getSymbol("Editor_EnsureCaretVisible");
	assert(EditorImpl.Editor_EnsureCaretVisible !is null, "Editor_EnsureCaretVisible");

	EditorImpl.Editor_ShowCaretAtCurrentPosition = cast(typeof(EditorImpl.Editor_ShowCaretAtCurrentPosition))lib.getSymbol("Editor_ShowCaretAtCurrentPosition");
	assert(EditorImpl.Editor_ShowCaretAtCurrentPosition !is null, "Editor_ShowCaretAtCurrentPosition");

	EditorImpl.Editor_DropCaret = cast(typeof(EditorImpl.Editor_DropCaret))lib.getSymbol("Editor_DropCaret");
	assert(EditorImpl.Editor_DropCaret !is null, "Editor_DropCaret");

	EditorImpl.Editor_InvalidateCaret = cast(typeof(EditorImpl.Editor_InvalidateCaret))lib.getSymbol("Editor_InvalidateCaret");
	assert(EditorImpl.Editor_InvalidateCaret !is null, "Editor_InvalidateCaret");

	EditorImpl.Editor_NeedWrapping = cast(typeof(EditorImpl.Editor_NeedWrapping))lib.getSymbol("Editor_NeedWrapping");
	assert(EditorImpl.Editor_NeedWrapping !is null, "Editor_NeedWrapping");

	EditorImpl.Editor_WrapOneLine = cast(typeof(EditorImpl.Editor_WrapOneLine))lib.getSymbol("Editor_WrapOneLine");
	assert(EditorImpl.Editor_WrapOneLine !is null, "Editor_WrapOneLine");

	EditorImpl.Editor_WrapLines = cast(typeof(EditorImpl.Editor_WrapLines))lib.getSymbol("Editor_WrapLines");
	assert(EditorImpl.Editor_WrapLines !is null, "Editor_WrapLines");

	EditorImpl.Editor_LinesJoin = cast(typeof(EditorImpl.Editor_LinesJoin))lib.getSymbol("Editor_LinesJoin");
	assert(EditorImpl.Editor_LinesJoin !is null, "Editor_LinesJoin");

	EditorImpl.Editor_LinesSplit = cast(typeof(EditorImpl.Editor_LinesSplit))lib.getSymbol("Editor_LinesSplit");
	assert(EditorImpl.Editor_LinesSplit !is null, "Editor_LinesSplit");

	EditorImpl.Editor_SubstituteMarkerIfEmpty = cast(typeof(EditorImpl.Editor_SubstituteMarkerIfEmpty))lib.getSymbol("Editor_SubstituteMarkerIfEmpty");
	assert(EditorImpl.Editor_SubstituteMarkerIfEmpty !is null, "Editor_SubstituteMarkerIfEmpty");

	EditorImpl.Editor_PaintSelMargin = cast(typeof(EditorImpl.Editor_PaintSelMargin))lib.getSymbol("Editor_PaintSelMargin");
	assert(EditorImpl.Editor_PaintSelMargin !is null, "Editor_PaintSelMargin");

	EditorImpl.Editor_RetrieveLineLayout = cast(typeof(EditorImpl.Editor_RetrieveLineLayout))lib.getSymbol("Editor_RetrieveLineLayout");
	assert(EditorImpl.Editor_RetrieveLineLayout !is null, "Editor_RetrieveLineLayout");

	EditorImpl.Editor_LayoutLine = cast(typeof(EditorImpl.Editor_LayoutLine))lib.getSymbol("Editor_LayoutLine");
	assert(EditorImpl.Editor_LayoutLine !is null, "Editor_LayoutLine");

	EditorImpl.Editor_SelectionBackground = cast(typeof(EditorImpl.Editor_SelectionBackground))lib.getSymbol("Editor_SelectionBackground");
	assert(EditorImpl.Editor_SelectionBackground !is null, "Editor_SelectionBackground");

	EditorImpl.Editor_TextBackground = cast(typeof(EditorImpl.Editor_TextBackground))lib.getSymbol("Editor_TextBackground");
	assert(EditorImpl.Editor_TextBackground !is null, "Editor_TextBackground");

	EditorImpl.Editor_DrawIndentGuide = cast(typeof(EditorImpl.Editor_DrawIndentGuide))lib.getSymbol("Editor_DrawIndentGuide");
	assert(EditorImpl.Editor_DrawIndentGuide !is null, "Editor_DrawIndentGuide");

	EditorImpl.Editor_DrawWrapMarker = cast(typeof(EditorImpl.Editor_DrawWrapMarker))lib.getSymbol("Editor_DrawWrapMarker");
	assert(EditorImpl.Editor_DrawWrapMarker !is null, "Editor_DrawWrapMarker");

	EditorImpl.Editor_DrawEOL = cast(typeof(EditorImpl.Editor_DrawEOL))lib.getSymbol("Editor_DrawEOL");
	assert(EditorImpl.Editor_DrawEOL !is null, "Editor_DrawEOL");

	EditorImpl.Editor_DrawIndicators = cast(typeof(EditorImpl.Editor_DrawIndicators))lib.getSymbol("Editor_DrawIndicators");
	assert(EditorImpl.Editor_DrawIndicators !is null, "Editor_DrawIndicators");

	EditorImpl.Editor_DrawLine = cast(typeof(EditorImpl.Editor_DrawLine))lib.getSymbol("Editor_DrawLine");
	assert(EditorImpl.Editor_DrawLine !is null, "Editor_DrawLine");

	EditorImpl.Editor_DrawBlockCaret = cast(typeof(EditorImpl.Editor_DrawBlockCaret))lib.getSymbol("Editor_DrawBlockCaret");
	assert(EditorImpl.Editor_DrawBlockCaret !is null, "Editor_DrawBlockCaret");

	EditorImpl.Editor_RefreshPixMaps = cast(typeof(EditorImpl.Editor_RefreshPixMaps))lib.getSymbol("Editor_RefreshPixMaps");
	assert(EditorImpl.Editor_RefreshPixMaps !is null, "Editor_RefreshPixMaps");

	EditorImpl.Editor_Paint = cast(typeof(EditorImpl.Editor_Paint))lib.getSymbol("Editor_Paint");
	assert(EditorImpl.Editor_Paint !is null, "Editor_Paint");

	EditorImpl.Editor_FormatRange = cast(typeof(EditorImpl.Editor_FormatRange))lib.getSymbol("Editor_FormatRange");
	assert(EditorImpl.Editor_FormatRange !is null, "Editor_FormatRange");

	EditorImpl.Editor_TextWidth = cast(typeof(EditorImpl.Editor_TextWidth))lib.getSymbol("Editor_TextWidth");
	assert(EditorImpl.Editor_TextWidth !is null, "Editor_TextWidth");

	EditorImpl.Editor_SetScrollBars = cast(typeof(EditorImpl.Editor_SetScrollBars))lib.getSymbol("Editor_SetScrollBars");
	assert(EditorImpl.Editor_SetScrollBars !is null, "Editor_SetScrollBars");

	EditorImpl.Editor_ChangeSize = cast(typeof(EditorImpl.Editor_ChangeSize))lib.getSymbol("Editor_ChangeSize");
	assert(EditorImpl.Editor_ChangeSize !is null, "Editor_ChangeSize");

	EditorImpl.Editor_AddChar = cast(typeof(EditorImpl.Editor_AddChar))lib.getSymbol("Editor_AddChar");
	assert(EditorImpl.Editor_AddChar !is null, "Editor_AddChar");

	EditorImpl.Editor_ClearSelection = cast(typeof(EditorImpl.Editor_ClearSelection))lib.getSymbol("Editor_ClearSelection");
	assert(EditorImpl.Editor_ClearSelection !is null, "Editor_ClearSelection");

	EditorImpl.Editor_ClearAll = cast(typeof(EditorImpl.Editor_ClearAll))lib.getSymbol("Editor_ClearAll");
	assert(EditorImpl.Editor_ClearAll !is null, "Editor_ClearAll");

	EditorImpl.Editor_ClearDocumentStyle = cast(typeof(EditorImpl.Editor_ClearDocumentStyle))lib.getSymbol("Editor_ClearDocumentStyle");
	assert(EditorImpl.Editor_ClearDocumentStyle !is null, "Editor_ClearDocumentStyle");

	EditorImpl.Editor_Cut = cast(typeof(EditorImpl.Editor_Cut))lib.getSymbol("Editor_Cut");
	assert(EditorImpl.Editor_Cut !is null, "Editor_Cut");

	EditorImpl.Editor_PasteRectangular = cast(typeof(EditorImpl.Editor_PasteRectangular))lib.getSymbol("Editor_PasteRectangular");
	assert(EditorImpl.Editor_PasteRectangular !is null, "Editor_PasteRectangular");

	EditorImpl.Editor_Clear = cast(typeof(EditorImpl.Editor_Clear))lib.getSymbol("Editor_Clear");
	assert(EditorImpl.Editor_Clear !is null, "Editor_Clear");

	EditorImpl.Editor_SelectAll = cast(typeof(EditorImpl.Editor_SelectAll))lib.getSymbol("Editor_SelectAll");
	assert(EditorImpl.Editor_SelectAll !is null, "Editor_SelectAll");

	EditorImpl.Editor_Undo = cast(typeof(EditorImpl.Editor_Undo))lib.getSymbol("Editor_Undo");
	assert(EditorImpl.Editor_Undo !is null, "Editor_Undo");

	EditorImpl.Editor_Redo = cast(typeof(EditorImpl.Editor_Redo))lib.getSymbol("Editor_Redo");
	assert(EditorImpl.Editor_Redo !is null, "Editor_Redo");

	EditorImpl.Editor_DelChar = cast(typeof(EditorImpl.Editor_DelChar))lib.getSymbol("Editor_DelChar");
	assert(EditorImpl.Editor_DelChar !is null, "Editor_DelChar");

	EditorImpl.Editor_DelCharBack = cast(typeof(EditorImpl.Editor_DelCharBack))lib.getSymbol("Editor_DelCharBack");
	assert(EditorImpl.Editor_DelCharBack !is null, "Editor_DelCharBack");

	EditorImpl.Editor_NotifyChar = cast(typeof(EditorImpl.Editor_NotifyChar))lib.getSymbol("Editor_NotifyChar");
	assert(EditorImpl.Editor_NotifyChar !is null, "Editor_NotifyChar");

	EditorImpl.Editor_NotifyMove = cast(typeof(EditorImpl.Editor_NotifyMove))lib.getSymbol("Editor_NotifyMove");
	assert(EditorImpl.Editor_NotifyMove !is null, "Editor_NotifyMove");

	EditorImpl.Editor_NotifySavePoint = cast(typeof(EditorImpl.Editor_NotifySavePoint))lib.getSymbol("Editor_NotifySavePoint");
	assert(EditorImpl.Editor_NotifySavePoint !is null, "Editor_NotifySavePoint");

	EditorImpl.Editor_NotifyModifyAttempt = cast(typeof(EditorImpl.Editor_NotifyModifyAttempt))lib.getSymbol("Editor_NotifyModifyAttempt");
	assert(EditorImpl.Editor_NotifyModifyAttempt !is null, "Editor_NotifyModifyAttempt");

	EditorImpl.Editor_NotifyHotSpotClicked = cast(typeof(EditorImpl.Editor_NotifyHotSpotClicked))lib.getSymbol("Editor_NotifyHotSpotClicked");
	assert(EditorImpl.Editor_NotifyHotSpotClicked !is null, "Editor_NotifyHotSpotClicked");

	EditorImpl.Editor_NotifyHotSpotDoubleClicked = cast(typeof(EditorImpl.Editor_NotifyHotSpotDoubleClicked))lib.getSymbol("Editor_NotifyHotSpotDoubleClicked");
	assert(EditorImpl.Editor_NotifyHotSpotDoubleClicked !is null, "Editor_NotifyHotSpotDoubleClicked");

	EditorImpl.Editor_NotifyUpdateUI = cast(typeof(EditorImpl.Editor_NotifyUpdateUI))lib.getSymbol("Editor_NotifyUpdateUI");
	assert(EditorImpl.Editor_NotifyUpdateUI !is null, "Editor_NotifyUpdateUI");

	EditorImpl.Editor_NotifyPainted = cast(typeof(EditorImpl.Editor_NotifyPainted))lib.getSymbol("Editor_NotifyPainted");
	assert(EditorImpl.Editor_NotifyPainted !is null, "Editor_NotifyPainted");

	EditorImpl.Editor_NotifyIndicatorClick = cast(typeof(EditorImpl.Editor_NotifyIndicatorClick))lib.getSymbol("Editor_NotifyIndicatorClick");
	assert(EditorImpl.Editor_NotifyIndicatorClick !is null, "Editor_NotifyIndicatorClick");

	EditorImpl.Editor_NotifyMarginClick = cast(typeof(EditorImpl.Editor_NotifyMarginClick))lib.getSymbol("Editor_NotifyMarginClick");
	assert(EditorImpl.Editor_NotifyMarginClick !is null, "Editor_NotifyMarginClick");

	EditorImpl.Editor_NotifyNeedShown = cast(typeof(EditorImpl.Editor_NotifyNeedShown))lib.getSymbol("Editor_NotifyNeedShown");
	assert(EditorImpl.Editor_NotifyNeedShown !is null, "Editor_NotifyNeedShown");

	EditorImpl.Editor_NotifyDwelling = cast(typeof(EditorImpl.Editor_NotifyDwelling))lib.getSymbol("Editor_NotifyDwelling");
	assert(EditorImpl.Editor_NotifyDwelling !is null, "Editor_NotifyDwelling");

	EditorImpl.Editor_NotifyZoom = cast(typeof(EditorImpl.Editor_NotifyZoom))lib.getSymbol("Editor_NotifyZoom");
	assert(EditorImpl.Editor_NotifyZoom !is null, "Editor_NotifyZoom");

	EditorImpl.Editor_NotifyModifyAttempt2 = cast(typeof(EditorImpl.Editor_NotifyModifyAttempt2))lib.getSymbol("Editor_NotifyModifyAttempt2");
	assert(EditorImpl.Editor_NotifyModifyAttempt2 !is null, "Editor_NotifyModifyAttempt2");

	EditorImpl.Editor_NotifySavePoint2 = cast(typeof(EditorImpl.Editor_NotifySavePoint2))lib.getSymbol("Editor_NotifySavePoint2");
	assert(EditorImpl.Editor_NotifySavePoint2 !is null, "Editor_NotifySavePoint2");

	EditorImpl.Editor_CheckModificationForWrap = cast(typeof(EditorImpl.Editor_CheckModificationForWrap))lib.getSymbol("Editor_CheckModificationForWrap");
	assert(EditorImpl.Editor_CheckModificationForWrap !is null, "Editor_CheckModificationForWrap");

	EditorImpl.Editor_NotifyModified = cast(typeof(EditorImpl.Editor_NotifyModified))lib.getSymbol("Editor_NotifyModified");
	assert(EditorImpl.Editor_NotifyModified !is null, "Editor_NotifyModified");

	EditorImpl.Editor_NotifyDeleted = cast(typeof(EditorImpl.Editor_NotifyDeleted))lib.getSymbol("Editor_NotifyDeleted");
	assert(EditorImpl.Editor_NotifyDeleted !is null, "Editor_NotifyDeleted");

	EditorImpl.Editor_NotifyStyleNeeded = cast(typeof(EditorImpl.Editor_NotifyStyleNeeded))lib.getSymbol("Editor_NotifyStyleNeeded");
	assert(EditorImpl.Editor_NotifyStyleNeeded !is null, "Editor_NotifyStyleNeeded");

	EditorImpl.Editor_NotifyMacroRecord = cast(typeof(EditorImpl.Editor_NotifyMacroRecord))lib.getSymbol("Editor_NotifyMacroRecord");
	assert(EditorImpl.Editor_NotifyMacroRecord !is null, "Editor_NotifyMacroRecord");

	EditorImpl.Editor_PageMove = cast(typeof(EditorImpl.Editor_PageMove))lib.getSymbol("Editor_PageMove");
	assert(EditorImpl.Editor_PageMove !is null, "Editor_PageMove");

	EditorImpl.Editor_ChangeCaseOfSelection = cast(typeof(EditorImpl.Editor_ChangeCaseOfSelection))lib.getSymbol("Editor_ChangeCaseOfSelection");
	assert(EditorImpl.Editor_ChangeCaseOfSelection !is null, "Editor_ChangeCaseOfSelection");

	EditorImpl.Editor_LineTranspose = cast(typeof(EditorImpl.Editor_LineTranspose))lib.getSymbol("Editor_LineTranspose");
	assert(EditorImpl.Editor_LineTranspose !is null, "Editor_LineTranspose");

	EditorImpl.Editor_Duplicate = cast(typeof(EditorImpl.Editor_Duplicate))lib.getSymbol("Editor_Duplicate");
	assert(EditorImpl.Editor_Duplicate !is null, "Editor_Duplicate");

	EditorImpl.Editor_NewLine = cast(typeof(EditorImpl.Editor_NewLine))lib.getSymbol("Editor_NewLine");
	assert(EditorImpl.Editor_NewLine !is null, "Editor_NewLine");

	EditorImpl.Editor_CursorUpOrDown = cast(typeof(EditorImpl.Editor_CursorUpOrDown))lib.getSymbol("Editor_CursorUpOrDown");
	assert(EditorImpl.Editor_CursorUpOrDown !is null, "Editor_CursorUpOrDown");

	EditorImpl.Editor_ParaUpOrDown = cast(typeof(EditorImpl.Editor_ParaUpOrDown))lib.getSymbol("Editor_ParaUpOrDown");
	assert(EditorImpl.Editor_ParaUpOrDown !is null, "Editor_ParaUpOrDown");

	EditorImpl.Editor_StartEndDisplayLine = cast(typeof(EditorImpl.Editor_StartEndDisplayLine))lib.getSymbol("Editor_StartEndDisplayLine");
	assert(EditorImpl.Editor_StartEndDisplayLine !is null, "Editor_StartEndDisplayLine");

	EditorImpl.Editor_KeyDown = cast(typeof(EditorImpl.Editor_KeyDown))lib.getSymbol("Editor_KeyDown");
	assert(EditorImpl.Editor_KeyDown !is null, "Editor_KeyDown");

	EditorImpl.Editor_GetWhitespaceVisible = cast(typeof(EditorImpl.Editor_GetWhitespaceVisible))lib.getSymbol("Editor_GetWhitespaceVisible");
	assert(EditorImpl.Editor_GetWhitespaceVisible !is null, "Editor_GetWhitespaceVisible");

	EditorImpl.Editor_SetWhitespaceVisible = cast(typeof(EditorImpl.Editor_SetWhitespaceVisible))lib.getSymbol("Editor_SetWhitespaceVisible");
	assert(EditorImpl.Editor_SetWhitespaceVisible !is null, "Editor_SetWhitespaceVisible");

	EditorImpl.Editor_Indent = cast(typeof(EditorImpl.Editor_Indent))lib.getSymbol("Editor_Indent");
	assert(EditorImpl.Editor_Indent !is null, "Editor_Indent");

	EditorImpl.Editor_FindText = cast(typeof(EditorImpl.Editor_FindText))lib.getSymbol("Editor_FindText");
	assert(EditorImpl.Editor_FindText !is null, "Editor_FindText");

	EditorImpl.Editor_SearchAnchor = cast(typeof(EditorImpl.Editor_SearchAnchor))lib.getSymbol("Editor_SearchAnchor");
	assert(EditorImpl.Editor_SearchAnchor !is null, "Editor_SearchAnchor");

	EditorImpl.Editor_SearchText = cast(typeof(EditorImpl.Editor_SearchText))lib.getSymbol("Editor_SearchText");
	assert(EditorImpl.Editor_SearchText !is null, "Editor_SearchText");

	EditorImpl.Editor_SearchInTarget = cast(typeof(EditorImpl.Editor_SearchInTarget))lib.getSymbol("Editor_SearchInTarget");
	assert(EditorImpl.Editor_SearchInTarget !is null, "Editor_SearchInTarget");

	EditorImpl.Editor_GoToLine = cast(typeof(EditorImpl.Editor_GoToLine))lib.getSymbol("Editor_GoToLine");
	assert(EditorImpl.Editor_GoToLine !is null, "Editor_GoToLine");

	EditorImpl.Editor_CopyRange = cast(typeof(EditorImpl.Editor_CopyRange))lib.getSymbol("Editor_CopyRange");
	assert(EditorImpl.Editor_CopyRange !is null, "Editor_CopyRange");

	EditorImpl.Editor_CopySelectionFromRange = cast(typeof(EditorImpl.Editor_CopySelectionFromRange))lib.getSymbol("Editor_CopySelectionFromRange");
	assert(EditorImpl.Editor_CopySelectionFromRange !is null, "Editor_CopySelectionFromRange");

	EditorImpl.Editor_CopySelectionRange = cast(typeof(EditorImpl.Editor_CopySelectionRange))lib.getSymbol("Editor_CopySelectionRange");
	assert(EditorImpl.Editor_CopySelectionRange !is null, "Editor_CopySelectionRange");

	EditorImpl.Editor_CopyRangeToClipboard = cast(typeof(EditorImpl.Editor_CopyRangeToClipboard))lib.getSymbol("Editor_CopyRangeToClipboard");
	assert(EditorImpl.Editor_CopyRangeToClipboard !is null, "Editor_CopyRangeToClipboard");

	EditorImpl.Editor_CopyText = cast(typeof(EditorImpl.Editor_CopyText))lib.getSymbol("Editor_CopyText");
	assert(EditorImpl.Editor_CopyText !is null, "Editor_CopyText");

	EditorImpl.Editor_SetDragPosition = cast(typeof(EditorImpl.Editor_SetDragPosition))lib.getSymbol("Editor_SetDragPosition");
	assert(EditorImpl.Editor_SetDragPosition !is null, "Editor_SetDragPosition");

	EditorImpl.Editor_DropAt = cast(typeof(EditorImpl.Editor_DropAt))lib.getSymbol("Editor_DropAt");
	assert(EditorImpl.Editor_DropAt !is null, "Editor_DropAt");

	EditorImpl.Editor_PositionInSelection = cast(typeof(EditorImpl.Editor_PositionInSelection))lib.getSymbol("Editor_PositionInSelection");
	assert(EditorImpl.Editor_PositionInSelection !is null, "Editor_PositionInSelection");

	EditorImpl.Editor_PointInSelection = cast(typeof(EditorImpl.Editor_PointInSelection))lib.getSymbol("Editor_PointInSelection");
	assert(EditorImpl.Editor_PointInSelection !is null, "Editor_PointInSelection");

	EditorImpl.Editor_PointInSelMargin = cast(typeof(EditorImpl.Editor_PointInSelMargin))lib.getSymbol("Editor_PointInSelMargin");
	assert(EditorImpl.Editor_PointInSelMargin !is null, "Editor_PointInSelMargin");

	EditorImpl.Editor_LineSelection = cast(typeof(EditorImpl.Editor_LineSelection))lib.getSymbol("Editor_LineSelection");
	assert(EditorImpl.Editor_LineSelection !is null, "Editor_LineSelection");

	EditorImpl.Editor_DwellEnd = cast(typeof(EditorImpl.Editor_DwellEnd))lib.getSymbol("Editor_DwellEnd");
	assert(EditorImpl.Editor_DwellEnd !is null, "Editor_DwellEnd");

	EditorImpl.Editor_ButtonMove = cast(typeof(EditorImpl.Editor_ButtonMove))lib.getSymbol("Editor_ButtonMove");
	assert(EditorImpl.Editor_ButtonMove !is null, "Editor_ButtonMove");

	EditorImpl.Editor_ButtonUp = cast(typeof(EditorImpl.Editor_ButtonUp))lib.getSymbol("Editor_ButtonUp");
	assert(EditorImpl.Editor_ButtonUp !is null, "Editor_ButtonUp");

	EditorImpl.Editor_Tick = cast(typeof(EditorImpl.Editor_Tick))lib.getSymbol("Editor_Tick");
	assert(EditorImpl.Editor_Tick !is null, "Editor_Tick");

	EditorImpl.Editor_Idle = cast(typeof(EditorImpl.Editor_Idle))lib.getSymbol("Editor_Idle");
	assert(EditorImpl.Editor_Idle !is null, "Editor_Idle");

	EditorImpl.Editor_SetFocusState = cast(typeof(EditorImpl.Editor_SetFocusState))lib.getSymbol("Editor_SetFocusState");
	assert(EditorImpl.Editor_SetFocusState !is null, "Editor_SetFocusState");

	EditorImpl.Editor_PaintContainsMargin = cast(typeof(EditorImpl.Editor_PaintContainsMargin))lib.getSymbol("Editor_PaintContainsMargin");
	assert(EditorImpl.Editor_PaintContainsMargin !is null, "Editor_PaintContainsMargin");

	EditorImpl.Editor_CheckForChangeOutsidePaint = cast(typeof(EditorImpl.Editor_CheckForChangeOutsidePaint))lib.getSymbol("Editor_CheckForChangeOutsidePaint");
	assert(EditorImpl.Editor_CheckForChangeOutsidePaint !is null, "Editor_CheckForChangeOutsidePaint");

	EditorImpl.Editor_SetBraceHighlight = cast(typeof(EditorImpl.Editor_SetBraceHighlight))lib.getSymbol("Editor_SetBraceHighlight");
	assert(EditorImpl.Editor_SetBraceHighlight !is null, "Editor_SetBraceHighlight");

	EditorImpl.Editor_SetDocPointer = cast(typeof(EditorImpl.Editor_SetDocPointer))lib.getSymbol("Editor_SetDocPointer");
	assert(EditorImpl.Editor_SetDocPointer !is null, "Editor_SetDocPointer");

	EditorImpl.Editor_Expand = cast(typeof(EditorImpl.Editor_Expand))lib.getSymbol("Editor_Expand");
	assert(EditorImpl.Editor_Expand !is null, "Editor_Expand");

	EditorImpl.Editor_ToggleContraction = cast(typeof(EditorImpl.Editor_ToggleContraction))lib.getSymbol("Editor_ToggleContraction");
	assert(EditorImpl.Editor_ToggleContraction !is null, "Editor_ToggleContraction");

	EditorImpl.Editor_EnsureLineVisible = cast(typeof(EditorImpl.Editor_EnsureLineVisible))lib.getSymbol("Editor_EnsureLineVisible");
	assert(EditorImpl.Editor_EnsureLineVisible !is null, "Editor_EnsureLineVisible");

	EditorImpl.Editor_ReplaceTarget = cast(typeof(EditorImpl.Editor_ReplaceTarget))lib.getSymbol("Editor_ReplaceTarget");
	assert(EditorImpl.Editor_ReplaceTarget !is null, "Editor_ReplaceTarget");

	EditorImpl.Editor_PositionIsHotspot = cast(typeof(EditorImpl.Editor_PositionIsHotspot))lib.getSymbol("Editor_PositionIsHotspot");
	assert(EditorImpl.Editor_PositionIsHotspot !is null, "Editor_PositionIsHotspot");

	EditorImpl.Editor_PointIsHotspot = cast(typeof(EditorImpl.Editor_PointIsHotspot))lib.getSymbol("Editor_PointIsHotspot");
	assert(EditorImpl.Editor_PointIsHotspot !is null, "Editor_PointIsHotspot");

	EditorImpl.Editor_SetHotSpotRange = cast(typeof(EditorImpl.Editor_SetHotSpotRange))lib.getSymbol("Editor_SetHotSpotRange");
	assert(EditorImpl.Editor_SetHotSpotRange !is null, "Editor_SetHotSpotRange");

	EditorImpl.Editor_GetHotSpotRange = cast(typeof(EditorImpl.Editor_GetHotSpotRange))lib.getSymbol("Editor_GetHotSpotRange");
	assert(EditorImpl.Editor_GetHotSpotRange !is null, "Editor_GetHotSpotRange");

	EditorImpl.Editor_CodePage = cast(typeof(EditorImpl.Editor_CodePage))lib.getSymbol("Editor_CodePage");
	assert(EditorImpl.Editor_CodePage !is null, "Editor_CodePage");

	EditorImpl.Editor_WrapCount = cast(typeof(EditorImpl.Editor_WrapCount))lib.getSymbol("Editor_WrapCount");
	assert(EditorImpl.Editor_WrapCount !is null, "Editor_WrapCount");

	EditorImpl.Editor_AddStyledText = cast(typeof(EditorImpl.Editor_AddStyledText))lib.getSymbol("Editor_AddStyledText");
	assert(EditorImpl.Editor_AddStyledText !is null, "Editor_AddStyledText");

	EditorImpl.Editor_StyleSetMessage = cast(typeof(EditorImpl.Editor_StyleSetMessage))lib.getSymbol("Editor_StyleSetMessage");
	assert(EditorImpl.Editor_StyleSetMessage !is null, "Editor_StyleSetMessage");

	EditorImpl.Editor_StyleGetMessage = cast(typeof(EditorImpl.Editor_StyleGetMessage))lib.getSymbol("Editor_StyleGetMessage");
	assert(EditorImpl.Editor_StyleGetMessage !is null, "Editor_StyleGetMessage");

	EditorImpl.Editor_IsUnicodeMode = cast(typeof(EditorImpl.Editor_IsUnicodeMode))lib.getSymbol("Editor_IsUnicodeMode");
	assert(EditorImpl.Editor_IsUnicodeMode !is null, "Editor_IsUnicodeMode");

	EditorImpl.Editor_AddCharUTF = cast(typeof(EditorImpl.Editor_AddCharUTF))lib.getSymbol("Editor_AddCharUTF");
	assert(EditorImpl.Editor_AddCharUTF !is null, "Editor_AddCharUTF");

	EditorImpl.Editor_KeyCommand = cast(typeof(EditorImpl.Editor_KeyCommand))lib.getSymbol("Editor_KeyCommand");
	assert(EditorImpl.Editor_KeyCommand !is null, "Editor_KeyCommand");

	EditorImpl.Editor_ButtonDown = cast(typeof(EditorImpl.Editor_ButtonDown))lib.getSymbol("Editor_ButtonDown");
	assert(EditorImpl.Editor_ButtonDown !is null, "Editor_ButtonDown");

	EditorImpl.Editor_WndProc = cast(typeof(EditorImpl.Editor_WndProc))lib.getSymbol("Editor_WndProc");
	assert(EditorImpl.Editor_WndProc !is null, "Editor_WndProc");
}


void bindScintilla(EditorImpl, SurfaceImpl, FontImpl)(char[] libPath) {
	auto lib = SharedLib.load(libPath);
	
	EditorImpl._createDeeEditor = cast(createDeeEditor_fp)lib.getSymbol("createDeeEditor");
	assert (EditorImpl._createDeeEditor !is null);
	
	SurfaceImpl._createDeeSurface = cast(createDeeSurface_fp)lib.getSymbol("createDeeSurface");
	assert (SurfaceImpl._createDeeSurface !is null);

	auto getDeeFuncsStruct = cast(getDeeFuncsStruct_fp)lib.getSymbol("getDeeFuncsStruct");
	assert (getDeeFuncsStruct !is null);
	
	auto getDeeFactoriesStruct = cast(getDeeFactoriesStruct_fp)lib.getSymbol("getDeeFactoriesStruct");
	assert (getDeeFactoriesStruct !is null);
	
	auto dFuncs = getDeeFuncsStruct();
	auto dFactories = getDeeFactoriesStruct();
	
	bindDeeEditor(&dFuncs.Editor);
	bindDeeSurface(&dFuncs.Surface);
	
	alias DFactories!(FontImpl, SurfaceImpl) Factories;

	dFactories.createFont = &Factories.createFontImpl;
	dFactories.releaseFont = &Factories.releaseFontImpl;
	dFactories.createSurface = &Factories.createSurfaceImpl;
	dFactories.releaseSurface = &Factories.releaseSurfaceImpl;
	
	bindEditorCFuncs!(EditorImpl)(lib);
}
