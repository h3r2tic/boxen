#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <assert.h>
#include <limits.h>

#include "Platform.h"

#include "Scintilla.h"
#include "SString.h"
#ifdef SCI_LEXER
#include "SciLexer.h"
#include "PropSet.h"
#include "Accessor.h"
#include "KeyWords.h"
#endif
#include "SplitVector.h"
#include "Partitioning.h"
#include "RunStyles.h"
#include "ContractionState.h"
#include "CellBuffer.h"
#include "CallTip.h"
#include "KeyMap.h"
#include "Indicator.h"
#include "XPM.h"
#include "LineMarker.h"
#include "Style.h"
#include "AutoComplete.h"
#include "ViewStyle.h"
#include "CharClassify.h"
#include "Decoration.h"
#include "Document.h"
#include "PositionCache.h"
#include "Editor.h"
#include "ScintillaBase.h"
#include "UniConversion.h"

#ifdef SCI_LEXER
#include "ExternalLexer.h"
#endif

#define null 0



struct DeeEditor_Funcs {
	__stdcall void (*Initialise)(void* dctx);
	__stdcall void (*Finalise)(void* dctx);
//	__stdcall void (*RefreshColourPalette)(void* dctx, Palette* pal, bool want);
	__stdcall PRectangle (*GetClientRectangle)(void* dctx);
	__stdcall void (*ScrollText)(void* dctx, int linesToMove);
	__stdcall void (*UpdateSystemCaret)(void* dctx);
	__stdcall void (*SetVerticalScrollPos)(void* dctx);
	__stdcall void (*SetHorizontalScrollPos)(void* dctx);
	__stdcall bool (*ModifyScrollBars)(void* dctx, int nMax, int nPage);
	__stdcall void (*ReconfigureScrollBars)(void* dctx);
//	__stdcall void (*AddCharUTF)(void* dctx, char *s, unsigned int len, bool treatAsDBCS);
	__stdcall void (*Copy)(void* dctx);
	__stdcall void (*CopyAllowLine)(void* dctx);
	__stdcall bool (*CanPaste)(void* dctx);
	__stdcall void (*Paste)(void* dctx);
	__stdcall void (*ClaimSelection)(void* dctx);
	__stdcall void (*NotifyChange)(void* dctx);
	__stdcall void (*NotifyFocus)(void* dctx, bool focus);
	__stdcall int (*GetCtrlID)(void* dctx);
	__stdcall void (*NotifyParent)(void* dctx, SCNotification scn);
//	__stdcall void (*NotifyStyleToNeeded)(void* dctx, int endStyleNeeded);
	__stdcall void (*NotifyDoubleClick)(void* dctx, Point pt, bool shift, bool ctrl, bool alt);
	__stdcall void (*CancelModes)(void* dctx);
//	__stdcall int (*KeyCommand)(void* dctx, unsigned int iMessage);
	__stdcall int (*KeyDefault)(void* dctx, int /* key */, int /*modifiers*/);
	__stdcall void (*CopyToClipboard)(void* dctx, const SelectionText* selectedText);
	__stdcall void (*DisplayCursor)(void* dctx, Window::Cursor c);
	__stdcall bool (*DragThreshold)(void* dctx, Point ptStart, Point ptNow);
	__stdcall void (*StartDrag)(void* dctx);
//	__stdcall void (*ButtonDown)(void* dctx, Point pt, unsigned int curTime, bool shift, bool ctrl, bool alt);
	__stdcall void (*SetTicking)(void* dctx, bool on);
	__stdcall bool (*SetIdle)(void* dctx, bool);
	__stdcall void (*SetMouseCapture)(void* dctx, bool on);
	__stdcall bool (*HaveMouseCapture)(void* dctx);
	__stdcall bool (*PaintContains)(void* dctx, PRectangle rc);
	__stdcall bool (*ValidCodePage)(void* dctx, int /* codePage */);
	__stdcall sptr_t (*DefWndProc)(void* dctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam);
//	__stdcall sptr_t (*WndProc)(void* dctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam);
};


struct DeeSurface_Funcs {
	__stdcall void (*Release)(void* dxtx);
	__stdcall bool (*Initialised)(void* dxtx);
	__stdcall void (*PenColour)(void* dxtx, ColourAllocated fore);
	__stdcall int (*LogPixelsY)(void* dxtx);
	__stdcall int (*DeviceHeightFont)(void* dxtx, int points);
	__stdcall void (*MoveTo)(void* dxtx, int x_, int y_);
	__stdcall void (*LineTo)(void* dxtx, int x_, int y_);
	__stdcall void (*Polygon)(void* dxtx, Point *pts, int npts, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*RectangleDraw)(void* dxtx, PRectangle rc, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*FillRectangle)(void* dxtx, PRectangle rc, ColourAllocated back);
	__stdcall void (*FillRectanglePattern)(void* dxtx, PRectangle rc, void* surfacePattern);
	__stdcall void (*RoundedRectangle)(void* dxtx, PRectangle rc, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*AlphaRectangle)(void* dxtx, PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags);
	__stdcall void (*Ellipse)(void* dxtx, PRectangle rc, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*Copy)(void* dxtx, PRectangle rc, Point from, void* surfaceSource);

	__stdcall void (*DrawTextCommon)(void* dxtx, PRectangle rc, void* font_, int ybase, const char *s, int len, unsigned int fuOptions);
	__stdcall void (*DrawTextNoClip)(void* dxtx, PRectangle rc, void* font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*DrawTextClipped)(void* dxtx, PRectangle rc, void* font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back);
	__stdcall void (*DrawTextTransparent)(void* dxtx, PRectangle rc, void* font_, int ybase, const char *s, int len, ColourAllocated fore);
	__stdcall void (*MeasureWidths)(void* dxtx, void* font_, const char *s, int len, int *positions);
	__stdcall int (*WidthText)(void* dxtx, void* font_, const char *s, int len);
	__stdcall int (*WidthChar)(void* dxtx, void* font_, char ch);
	__stdcall int (*Ascent)(void* dxtx, void* font_);
	__stdcall int (*Descent)(void* dxtx, void* font_);
	__stdcall int (*InternalLeading)(void* dxtx, void* font_);
	__stdcall int (*ExternalLeading)(void* dxtx, void* font_);
	__stdcall int (*Height)(void* dxtx, void* font_);
	__stdcall int (*AverageCharWidth)(void* dxtx, void* font_);

//	__stdcall int (*SetPalette)(void* dxtx, Palette *pal, bool inBackGround);
	__stdcall void (*SetClip)(void* dxtx, PRectangle rc);
	__stdcall void (*FlushCachedState)(void* dxtx);

	__stdcall void (*SetUnicodeMode)(void* dxtx, bool unicodeMode_);
	__stdcall void (*SetDBCSMode)(void* dxtx, int codePage_);
};



struct DeeFuncsStruct {
	DeeEditor_Funcs		Editor;
	DeeSurface_Funcs	Surface;
} deeFuncs;


struct DeeFactoriesStruct {
	__stdcall FontID (*createFont)(const char *faceName, int characterSet, int size, bool bold, bool italic, bool extraFontFlag);
	__stdcall void (*releaseFont)(FontID);

	__stdcall void* (*createSurface)();
	__stdcall void (*releaseSurface)(void*);
} deeFactories;





extern "C" {
	__declspec(dllexport) void Editor_InvalidateStyleData(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->InvalidateStyleData(); }
	__declspec(dllexport) void Editor_InvalidateStyleRedraw(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->InvalidateStyleRedraw(); }
	__declspec(dllexport) void Editor_RefreshStyleData(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->RefreshStyleData(); }
	__declspec(dllexport) void Editor_DropGraphics(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->DropGraphics(); }
	__declspec(dllexport) PRectangle Editor_GetTextRectangle(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->GetTextRectangle(); }
	__declspec(dllexport) int Editor_LinesOnScreen(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->LinesOnScreen(); }
	__declspec(dllexport) int Editor_LinesToScroll(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->LinesToScroll(); }
	__declspec(dllexport) int Editor_MaxScrollPos(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->MaxScrollPos(); }
	__declspec(dllexport) Point Editor_LocationFromPosition(void* cctx, int pos) { return reinterpret_cast<ScintillaBase*>(cctx)->LocationFromPosition(pos); }
	__declspec(dllexport) int Editor_XFromPosition(void* cctx, int pos) { return reinterpret_cast<ScintillaBase*>(cctx)->XFromPosition(pos); }
	__declspec(dllexport) int Editor_PositionFromLocation(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->PositionFromLocation(pt); }
	__declspec(dllexport) int Editor_PositionFromLocationClose(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->PositionFromLocationClose(pt); }
	__declspec(dllexport) int Editor_PositionFromLineX(void* cctx, int line, int x) { return reinterpret_cast<ScintillaBase*>(cctx)->PositionFromLineX(line, x); }
	__declspec(dllexport) int Editor_LineFromLocation(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->LineFromLocation(pt); }
	__declspec(dllexport) void Editor_SetTopLine(void* cctx, int topLineNew) { reinterpret_cast<ScintillaBase*>(cctx)->SetTopLine(topLineNew); }
	__declspec(dllexport) bool Editor_AbandonPaint(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->AbandonPaint(); }
	__declspec(dllexport) void Editor_RedrawRect(void* cctx, PRectangle rc) { reinterpret_cast<ScintillaBase*>(cctx)->RedrawRect(rc); }
	__declspec(dllexport) void Editor_Redraw(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Redraw(); }
	__declspec(dllexport) void Editor_RedrawSelMargin(void* cctx, int line) { reinterpret_cast<ScintillaBase*>(cctx)->RedrawSelMargin(line); }
	__declspec(dllexport) PRectangle Editor_RectangleFromRange(void* cctx, int start, int end) { return reinterpret_cast<ScintillaBase*>(cctx)->RectangleFromRange(start, end); }
	__declspec(dllexport) void Editor_InvalidateRange(void* cctx, int start, int end) { reinterpret_cast<ScintillaBase*>(cctx)->InvalidateRange(start, end); }
	__declspec(dllexport) int Editor_CurrentPosition(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->CurrentPosition(); }
	__declspec(dllexport) bool Editor_SelectionEmpty(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->SelectionEmpty(); }
	__declspec(dllexport) int Editor_SelectionStart(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->SelectionStart(); }
	__declspec(dllexport) int Editor_SelectionEnd(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->SelectionEnd(); }
	__declspec(dllexport) void Editor_SetRectangularRange(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->SetRectangularRange(); }
	__declspec(dllexport) void Editor_InvalidateSelection(void* cctx, int currentPos_, int anchor_, bool invalidateWholeSelection) { reinterpret_cast<ScintillaBase*>(cctx)->InvalidateSelection(currentPos_, anchor_, invalidateWholeSelection); }
	__declspec(dllexport) void Editor_SetSelection(void* cctx, int currentPos_, int anchor_) { reinterpret_cast<ScintillaBase*>(cctx)->SetSelection(currentPos_, anchor_); }
	__declspec(dllexport) void Editor_SetSelection2(void* cctx, int currentPos_) { reinterpret_cast<ScintillaBase*>(cctx)->SetSelection(currentPos_); }
	__declspec(dllexport) void Editor_SetEmptySelection(void* cctx, int currentPos_) { reinterpret_cast<ScintillaBase*>(cctx)->SetEmptySelection(currentPos_); }
	__declspec(dllexport) bool Editor_RangeContainsProtected(void* cctx, int start, int end) { return reinterpret_cast<ScintillaBase*>(cctx)->RangeContainsProtected(start, end); }
	__declspec(dllexport) bool Editor_SelectionContainsProtected(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->SelectionContainsProtected(); }
	__declspec(dllexport) int Editor_MovePositionOutsideChar(void* cctx, int pos, int moveDir, bool checkLineEnd) { return reinterpret_cast<ScintillaBase*>(cctx)->MovePositionOutsideChar(pos, moveDir, checkLineEnd); }
	__declspec(dllexport) int Editor_MovePositionTo(void* cctx, int newPos, Editor::selTypes sel, bool ensureVisible) { return reinterpret_cast<ScintillaBase*>(cctx)->MovePositionTo(newPos, sel, ensureVisible); }
	__declspec(dllexport) int Editor_MovePositionSoVisible(void* cctx, int pos, int moveDir) { return reinterpret_cast<ScintillaBase*>(cctx)->MovePositionSoVisible(pos, moveDir); }
	__declspec(dllexport) void Editor_SetLastXChosen(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->SetLastXChosen(); }
	__declspec(dllexport) void Editor_ScrollTo(void* cctx, int line, bool moveThumb) { reinterpret_cast<ScintillaBase*>(cctx)->ScrollTo(line, moveThumb); }
	__declspec(dllexport) void Editor_HorizontalScrollTo(void* cctx, int xPos) { reinterpret_cast<ScintillaBase*>(cctx)->HorizontalScrollTo(xPos); }
	__declspec(dllexport) void Editor_MoveCaretInsideView(void* cctx, bool ensureVisible) { reinterpret_cast<ScintillaBase*>(cctx)->MoveCaretInsideView(ensureVisible); }
	__declspec(dllexport) int Editor_DisplayFromPosition(void* cctx, int pos) { return reinterpret_cast<ScintillaBase*>(cctx)->DisplayFromPosition(pos); }
	__declspec(dllexport) void Editor_EnsureCaretVisible(void* cctx, bool useMargin, bool vert, bool horiz) { reinterpret_cast<ScintillaBase*>(cctx)->EnsureCaretVisible(useMargin, vert, horiz); }
	__declspec(dllexport) void Editor_ShowCaretAtCurrentPosition(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->ShowCaretAtCurrentPosition(); }
	__declspec(dllexport) void Editor_DropCaret(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->DropCaret(); }
	__declspec(dllexport) void Editor_InvalidateCaret(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->InvalidateCaret(); }
	__declspec(dllexport) void Editor_NeedWrapping(void* cctx, int docLineStart, int docLineEnd) { reinterpret_cast<ScintillaBase*>(cctx)->NeedWrapping(docLineStart, docLineEnd); }
	__declspec(dllexport) bool Editor_WrapOneLine(void* cctx, Surface* surface, int lineToWrap) { return reinterpret_cast<ScintillaBase*>(cctx)->WrapOneLine(surface, lineToWrap); }
	__declspec(dllexport) bool Editor_WrapLines(void* cctx, bool fullWrap, int priorityWrapLineStart) { return reinterpret_cast<ScintillaBase*>(cctx)->WrapLines(fullWrap, priorityWrapLineStart); }
	__declspec(dllexport) void Editor_LinesJoin(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->LinesJoin(); }
	__declspec(dllexport) void Editor_LinesSplit(void* cctx, int pixelWidth) { reinterpret_cast<ScintillaBase*>(cctx)->LinesSplit(pixelWidth); }
	__declspec(dllexport) int Editor_SubstituteMarkerIfEmpty(void* cctx, int markerCheck, int markerDefault) { return reinterpret_cast<ScintillaBase*>(cctx)->SubstituteMarkerIfEmpty(markerCheck, markerDefault); }
	__declspec(dllexport) void Editor_PaintSelMargin(void* cctx, Surface* surface, PRectangle* rc) { reinterpret_cast<ScintillaBase*>(cctx)->PaintSelMargin(surface, *rc); }
	__declspec(dllexport) LineLayout* Editor_RetrieveLineLayout(void* cctx, int lineNumber) { return reinterpret_cast<ScintillaBase*>(cctx)->RetrieveLineLayout(lineNumber); }
	__declspec(dllexport) void Editor_LayoutLine(void* cctx, int line, Surface* surface, ViewStyle* vstyle, LineLayout* ll, int width) { reinterpret_cast<ScintillaBase*>(cctx)->LayoutLine(line, surface, *vstyle, ll, width); }
	__declspec(dllexport) ColourAllocated Editor_SelectionBackground(void* cctx, ViewStyle* vsDraw) { return reinterpret_cast<ScintillaBase*>(cctx)->SelectionBackground(*vsDraw); }
	__declspec(dllexport) ColourAllocated Editor_TextBackground(void* cctx, ViewStyle* vsDraw, bool overrideBackground, ColourAllocated background, bool inSelection, bool inHotspot, int styleMain, int i, LineLayout* ll) { return reinterpret_cast<ScintillaBase*>(cctx)->TextBackground(*vsDraw, overrideBackground, background, inSelection, inHotspot, styleMain, i, ll); }
	__declspec(dllexport) void Editor_DrawIndentGuide(void* cctx, Surface* surface, int lineVisible, int lineHeight, int start, PRectangle rcSegment, bool highlight) { reinterpret_cast<ScintillaBase*>(cctx)->DrawIndentGuide(surface, lineVisible, lineHeight, start, rcSegment, highlight); }
	__declspec(dllexport) void Editor_DrawWrapMarker(void* cctx, Surface* surface, PRectangle rcPlace, bool isEndMarker, ColourAllocated wrapColour) { reinterpret_cast<ScintillaBase*>(cctx)->DrawWrapMarker(surface, rcPlace, isEndMarker, wrapColour); }
	__declspec(dllexport) void Editor_DrawEOL(void* cctx, Surface* surface, ViewStyle* vsDraw, PRectangle rcLine, LineLayout* ll, int line, int lineEnd, int xStart, int subLine, int subLineStart, bool overrideBackground, ColourAllocated background, bool drawWrapMark, ColourAllocated wrapColour) { reinterpret_cast<ScintillaBase*>(cctx)->DrawEOL(surface, *vsDraw, rcLine, ll, line, lineEnd, xStart, subLine, subLineStart, overrideBackground, background, drawWrapMark, wrapColour); }
	__declspec(dllexport) void Editor_DrawIndicators(void* cctx, Surface* surface, ViewStyle* vsDraw, int line, int xStart, PRectangle rcLine, LineLayout* ll, int subLine, int lineEnd, bool under) { reinterpret_cast<ScintillaBase*>(cctx)->DrawIndicators(surface, *vsDraw, line, xStart, rcLine, ll, subLine, lineEnd, under); }
	__declspec(dllexport) void Editor_DrawLine(void* cctx, Surface* surface, ViewStyle* vsDraw, int line, int lineVisible, int xStart, PRectangle rcLine, LineLayout* ll, int subLine) { reinterpret_cast<ScintillaBase*>(cctx)->DrawLine(surface, *vsDraw, line, lineVisible, xStart, rcLine, ll, subLine); }
	__declspec(dllexport) void Editor_DrawBlockCaret(void* cctx, Surface* surface, ViewStyle* vsDraw, LineLayout* ll, int subLine, int xStart, int offset, int posCaret, PRectangle rcCaret) { reinterpret_cast<ScintillaBase*>(cctx)->DrawBlockCaret(surface, *vsDraw, ll, subLine, xStart, offset, posCaret, rcCaret); }
	__declspec(dllexport) void Editor_RefreshPixMaps(void* cctx, Surface* surfaceWindow) { reinterpret_cast<ScintillaBase*>(cctx)->RefreshPixMaps(surfaceWindow); }
	__declspec(dllexport) void Editor_Paint(void* cctx, Surface* surfaceWindow, PRectangle rcArea) { reinterpret_cast<ScintillaBase*>(cctx)->Paint(surfaceWindow, rcArea); }
	__declspec(dllexport) long Editor_FormatRange(void* cctx, bool draw, RangeToFormat* pfr) { return reinterpret_cast<ScintillaBase*>(cctx)->FormatRange(draw, pfr); }
	__declspec(dllexport) int Editor_TextWidth(void* cctx, int style, const char* text) { return reinterpret_cast<ScintillaBase*>(cctx)->TextWidth(style, text); }
	__declspec(dllexport) void Editor_SetScrollBars(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->SetScrollBars(); }
	__declspec(dllexport) void Editor_ChangeSize(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->ChangeSize(); }
	__declspec(dllexport) void Editor_AddChar(void* cctx, char ch) { reinterpret_cast<ScintillaBase*>(cctx)->AddChar(ch); }
	__declspec(dllexport) void Editor_ClearSelection(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->ClearSelection(); }
	__declspec(dllexport) void Editor_ClearAll(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->ClearAll(); }
	__declspec(dllexport) void Editor_ClearDocumentStyle(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->ClearDocumentStyle(); }
	__declspec(dllexport) void Editor_Cut(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Cut(); }
	__declspec(dllexport) void Editor_PasteRectangular(void* cctx, int pos, const char* ptr, int len) { reinterpret_cast<ScintillaBase*>(cctx)->PasteRectangular(pos, ptr, len); }
	__declspec(dllexport) void Editor_Clear(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Clear(); }
	__declspec(dllexport) void Editor_SelectAll(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->SelectAll(); }
	__declspec(dllexport) void Editor_Undo(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Undo(); }
	__declspec(dllexport) void Editor_Redo(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Redo(); }
	__declspec(dllexport) void Editor_DelChar(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->DelChar(); }
	__declspec(dllexport) void Editor_DelCharBack(void* cctx, bool allowLineStartDeletion) { reinterpret_cast<ScintillaBase*>(cctx)->DelCharBack(allowLineStartDeletion); }
	__declspec(dllexport) void Editor_NotifyChar(void* cctx, int ch) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyChar(ch); }
	__declspec(dllexport) void Editor_NotifyMove(void* cctx, int position) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyMove(position); }
	__declspec(dllexport) void Editor_NotifySavePoint(void* cctx, bool isSavePoint) { reinterpret_cast<ScintillaBase*>(cctx)->NotifySavePoint(isSavePoint); }
	__declspec(dllexport) void Editor_NotifyModifyAttempt(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyModifyAttempt(); }
	__declspec(dllexport) void Editor_NotifyHotSpotClicked(void* cctx, int position, bool shift, bool ctrl, bool alt) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyHotSpotClicked(position, shift, ctrl, alt); }
	__declspec(dllexport) void Editor_NotifyHotSpotDoubleClicked(void* cctx, int position, bool shift, bool ctrl, bool alt) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyHotSpotDoubleClicked(position, shift, ctrl, alt); }
	__declspec(dllexport) void Editor_NotifyUpdateUI(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyUpdateUI(); }
	__declspec(dllexport) void Editor_NotifyPainted(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyPainted(); }
	__declspec(dllexport) void Editor_NotifyIndicatorClick(void* cctx, bool click, int position, bool shift, bool ctrl, bool alt) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyIndicatorClick(click, position, shift, ctrl, alt); }
	__declspec(dllexport) bool Editor_NotifyMarginClick(void* cctx, Point pt, bool shift, bool ctrl, bool alt) { return reinterpret_cast<ScintillaBase*>(cctx)->NotifyMarginClick(pt, shift, ctrl, alt); }
	__declspec(dllexport) void Editor_NotifyNeedShown(void* cctx, int pos, int len) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyNeedShown(pos, len); }
	__declspec(dllexport) void Editor_NotifyDwelling(void* cctx, Point pt, bool state) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyDwelling(pt, state); }
	__declspec(dllexport) void Editor_NotifyZoom(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyZoom(); }
	__declspec(dllexport) void Editor_NotifyModifyAttempt2(void* cctx, Document* document, void* userData) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyModifyAttempt(document, userData); }
	__declspec(dllexport) void Editor_NotifySavePoint2(void* cctx, Document* document, void* userData, bool atSavePoint) { reinterpret_cast<ScintillaBase*>(cctx)->NotifySavePoint(document, userData, atSavePoint); }
	__declspec(dllexport) void Editor_CheckModificationForWrap(void* cctx, DocModification mh) { reinterpret_cast<ScintillaBase*>(cctx)->CheckModificationForWrap(mh); }
	__declspec(dllexport) void Editor_NotifyModified(void* cctx, Document* document, DocModification mh, void* userData) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyModified(document, mh, userData); }
	__declspec(dllexport) void Editor_NotifyDeleted(void* cctx, Document* document, void* userData) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyDeleted(document, userData); }
	__declspec(dllexport) void Editor_NotifyStyleNeeded(void* cctx, Document* doc, void* userData, int endPos) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyStyleNeeded(doc, userData, endPos); }
	__declspec(dllexport) void Editor_NotifyMacroRecord(void* cctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam) { reinterpret_cast<ScintillaBase*>(cctx)->NotifyMacroRecord(iMessage, wParam, lParam); }
	__declspec(dllexport) void Editor_PageMove(void* cctx, int direction, Editor::selTypes sel, bool stuttered) { reinterpret_cast<ScintillaBase*>(cctx)->PageMove(direction, sel, stuttered); }
	__declspec(dllexport) void Editor_ChangeCaseOfSelection(void* cctx, bool makeUpperCase) { reinterpret_cast<ScintillaBase*>(cctx)->ChangeCaseOfSelection(makeUpperCase); }
	__declspec(dllexport) void Editor_LineTranspose(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->LineTranspose(); }
	__declspec(dllexport) void Editor_Duplicate(void* cctx, bool forLine) { reinterpret_cast<ScintillaBase*>(cctx)->Duplicate(forLine); }
	__declspec(dllexport) void Editor_NewLine(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->NewLine(); }
	__declspec(dllexport) void Editor_CursorUpOrDown(void* cctx, int direction, Editor::selTypes sel) { reinterpret_cast<ScintillaBase*>(cctx)->CursorUpOrDown(direction, sel); }
	__declspec(dllexport) void Editor_ParaUpOrDown(void* cctx, int direction, Editor::selTypes sel) { reinterpret_cast<ScintillaBase*>(cctx)->ParaUpOrDown(direction, sel); }
	__declspec(dllexport) int Editor_StartEndDisplayLine(void* cctx, int pos, bool start) { return reinterpret_cast<ScintillaBase*>(cctx)->StartEndDisplayLine(pos, start); }
	__declspec(dllexport) int Editor_KeyDown(void* cctx, int key, bool shift, bool ctrl, bool alt, bool* consumed) { return reinterpret_cast<ScintillaBase*>(cctx)->KeyDown(key, shift, ctrl, alt, consumed); }
	__declspec(dllexport) int Editor_GetWhitespaceVisible(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->GetWhitespaceVisible(); }
	__declspec(dllexport) void Editor_SetWhitespaceVisible(void* cctx, int view) { reinterpret_cast<ScintillaBase*>(cctx)->SetWhitespaceVisible(view); }
	__declspec(dllexport) void Editor_Indent(void* cctx, bool forwards) { reinterpret_cast<ScintillaBase*>(cctx)->Indent(forwards); }
	__declspec(dllexport) long Editor_FindText(void* cctx, uptr_t wParam, sptr_t lParam) { return reinterpret_cast<ScintillaBase*>(cctx)->FindText(wParam, lParam); }
	__declspec(dllexport) void Editor_SearchAnchor(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->SearchAnchor(); }
	__declspec(dllexport) long Editor_SearchText(void* cctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam) { return reinterpret_cast<ScintillaBase*>(cctx)->SearchText(iMessage, wParam, lParam); }
	__declspec(dllexport) long Editor_SearchInTarget(void* cctx, const char* text, int length) { return reinterpret_cast<ScintillaBase*>(cctx)->SearchInTarget(text, length); }
	__declspec(dllexport) void Editor_GoToLine(void* cctx, int lineNo) { reinterpret_cast<ScintillaBase*>(cctx)->GoToLine(lineNo); }
	__declspec(dllexport) char* Editor_CopyRange(void* cctx, int start, int end) { return reinterpret_cast<ScintillaBase*>(cctx)->CopyRange(start, end); }
	__declspec(dllexport) void Editor_CopySelectionFromRange(void* cctx, SelectionText* ss, bool allowLineCopy, int start, int end) { reinterpret_cast<ScintillaBase*>(cctx)->CopySelectionFromRange(ss, allowLineCopy, start, end); }
	__declspec(dllexport) void Editor_CopySelectionRange(void* cctx, SelectionText* ss, bool allowLineCopy) { reinterpret_cast<ScintillaBase*>(cctx)->CopySelectionRange(ss, allowLineCopy); }
	__declspec(dllexport) void Editor_CopyRangeToClipboard(void* cctx, int start, int end) { reinterpret_cast<ScintillaBase*>(cctx)->CopyRangeToClipboard(start, end); }
	__declspec(dllexport) void Editor_CopyText(void* cctx, int length, const char* text) { reinterpret_cast<ScintillaBase*>(cctx)->CopyText(length, text); }
	__declspec(dllexport) void Editor_SetDragPosition(void* cctx, int newPos) { reinterpret_cast<ScintillaBase*>(cctx)->SetDragPosition(newPos); }
	__declspec(dllexport) void Editor_DropAt(void* cctx, int position, const char* value, bool moving, bool rectangular) { reinterpret_cast<ScintillaBase*>(cctx)->DropAt(position, value, moving, rectangular); }
	__declspec(dllexport) int Editor_PositionInSelection(void* cctx, int pos) { return reinterpret_cast<ScintillaBase*>(cctx)->PositionInSelection(pos); }
	__declspec(dllexport) bool Editor_PointInSelection(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->PointInSelection(pt); }
	__declspec(dllexport) bool Editor_PointInSelMargin(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->PointInSelMargin(pt); }
	__declspec(dllexport) void Editor_LineSelection(void* cctx, int lineCurrent_, int lineAnchor_) { reinterpret_cast<ScintillaBase*>(cctx)->LineSelection(lineCurrent_, lineAnchor_); }
	__declspec(dllexport) void Editor_DwellEnd(void* cctx, bool mouseMoved) { reinterpret_cast<ScintillaBase*>(cctx)->DwellEnd(mouseMoved); }
	__declspec(dllexport) void Editor_ButtonMove(void* cctx, Point pt) { reinterpret_cast<ScintillaBase*>(cctx)->ButtonMove(pt); }
	__declspec(dllexport) void Editor_ButtonUp(void* cctx, Point pt, unsigned int curTime, bool ctrl) { reinterpret_cast<ScintillaBase*>(cctx)->ButtonUp(pt, curTime, ctrl); }
	__declspec(dllexport) void Editor_Tick(void* cctx) { reinterpret_cast<ScintillaBase*>(cctx)->Tick(); }
	__declspec(dllexport) bool Editor_Idle(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->Idle(); }
	__declspec(dllexport) void Editor_SetFocusState(void* cctx, bool focusState) { reinterpret_cast<ScintillaBase*>(cctx)->SetFocusState(focusState); }
	__declspec(dllexport) bool Editor_PaintContainsMargin(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->PaintContainsMargin(); }
	__declspec(dllexport) void Editor_CheckForChangeOutsidePaint(void* cctx, Range r) { reinterpret_cast<ScintillaBase*>(cctx)->CheckForChangeOutsidePaint(r); }
	__declspec(dllexport) void Editor_SetBraceHighlight(void* cctx, Position pos0, Position pos1, int matchStyle) { reinterpret_cast<ScintillaBase*>(cctx)->SetBraceHighlight(pos0, pos1, matchStyle); }
	__declspec(dllexport) void Editor_SetDocPointer(void* cctx, Document* document) { reinterpret_cast<ScintillaBase*>(cctx)->SetDocPointer(document); }
	__declspec(dllexport) void Editor_Expand(void* cctx, int* line, bool doExpand) { reinterpret_cast<ScintillaBase*>(cctx)->Expand(*line, doExpand); }
	__declspec(dllexport) void Editor_ToggleContraction(void* cctx, int line) { reinterpret_cast<ScintillaBase*>(cctx)->ToggleContraction(line); }
	__declspec(dllexport) void Editor_EnsureLineVisible(void* cctx, int lineDoc, bool enforcePolicy) { reinterpret_cast<ScintillaBase*>(cctx)->EnsureLineVisible(lineDoc, enforcePolicy); }
	__declspec(dllexport) int Editor_ReplaceTarget(void* cctx, bool replacePatterns, const char* text, int length) { return reinterpret_cast<ScintillaBase*>(cctx)->ReplaceTarget(replacePatterns, text, length); }
	__declspec(dllexport) bool Editor_PositionIsHotspot(void* cctx, int position) { return reinterpret_cast<ScintillaBase*>(cctx)->PositionIsHotspot(position); }
	__declspec(dllexport) bool Editor_PointIsHotspot(void* cctx, Point pt) { return reinterpret_cast<ScintillaBase*>(cctx)->PointIsHotspot(pt); }
	__declspec(dllexport) void Editor_SetHotSpotRange(void* cctx, Point* pt) { reinterpret_cast<ScintillaBase*>(cctx)->SetHotSpotRange(pt); }
	__declspec(dllexport) void Editor_GetHotSpotRange(void* cctx, int* hsStart, int* hsEnd) { reinterpret_cast<ScintillaBase*>(cctx)->GetHotSpotRange(*hsStart, *hsEnd); }
	__declspec(dllexport) int Editor_CodePage(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->CodePage(); }
	__declspec(dllexport) int Editor_WrapCount(void* cctx, int line) { return reinterpret_cast<ScintillaBase*>(cctx)->WrapCount(line); }
	__declspec(dllexport) void Editor_AddStyledText(void* cctx, char* buffer, int appendLength) { reinterpret_cast<ScintillaBase*>(cctx)->AddStyledText(buffer, appendLength); }
	__declspec(dllexport) void Editor_StyleSetMessage(void* cctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam) { reinterpret_cast<ScintillaBase*>(cctx)->StyleSetMessage(iMessage, wParam, lParam); }
	__declspec(dllexport) sptr_t Editor_StyleGetMessage(void* cctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam) { return reinterpret_cast<ScintillaBase*>(cctx)->StyleGetMessage(iMessage, wParam, lParam); }
	__declspec(dllexport) bool Editor_IsUnicodeMode(void* cctx) { return reinterpret_cast<ScintillaBase*>(cctx)->IsUnicodeMode(); }

	// virtuals
	__declspec(dllexport) void Editor_AddCharUTF(void* cctx, char *s, unsigned int len, bool treatAsDBCS) { reinterpret_cast<ScintillaBase*>(cctx)->AddCharUTF(s, len, treatAsDBCS); }
	__declspec(dllexport) int Editor_KeyCommand(void* cctx, unsigned int iMessage) { return reinterpret_cast<ScintillaBase*>(cctx)->KeyCommand(iMessage); }
	__declspec(dllexport) void Editor_ButtonDown(void* cctx, Point pt, unsigned int curTime, bool shift, bool ctrl, bool alt) { return reinterpret_cast<ScintillaBase*>(cctx)->ButtonDown(pt, curTime, shift, ctrl, alt); }
	__declspec(dllexport) sptr_t Editor_WndProc(void* cctx, unsigned int iMessage, uptr_t wParam, sptr_t lParam) { return reinterpret_cast<ScintillaBase*>(cctx)->WndProc(iMessage, wParam, lParam); }
}




class DeeEditor : public ScintillaBase {
protected:
	virtual void Initialise() { return deeFuncs.Editor.Initialise(dctx); }
	virtual void Finalise() { return deeFuncs.Editor.Finalise(dctx); }
//	virtual void RefreshColourPalette(Palette &pal, bool want) { return deeFuncs.Editor.RefreshColourPalette(dctx, &pal, want); }
	virtual PRectangle GetClientRectangle() { return deeFuncs.Editor.GetClientRectangle(dctx); }
	virtual void ScrollText(int linesToMove) { return deeFuncs.Editor.ScrollText(dctx, linesToMove); }
	virtual void UpdateSystemCaret() { return deeFuncs.Editor.UpdateSystemCaret(dctx); }
	virtual void SetVerticalScrollPos() { return deeFuncs.Editor.SetVerticalScrollPos(dctx); }
	virtual void SetHorizontalScrollPos() { return deeFuncs.Editor.SetHorizontalScrollPos(dctx); }
	virtual bool ModifyScrollBars(int nMax, int nPage) { return deeFuncs.Editor.ModifyScrollBars(dctx, nMax, nPage); }
	virtual void ReconfigureScrollBars() { return deeFuncs.Editor.ReconfigureScrollBars(dctx); }
//	virtual void AddCharUTF(char *s, unsigned int len, bool treatAsDBCS=false) { return deeFuncs.Editor.AddCharUTF(dctx, s, len, treatAsDBCS); }
	virtual void Copy() { return deeFuncs.Editor.Copy(dctx); }
	virtual void CopyAllowLine() { return deeFuncs.Editor.CopyAllowLine(dctx); }
	virtual bool CanPaste() { return deeFuncs.Editor.CanPaste(dctx); }
	virtual void Paste() { return deeFuncs.Editor.Paste(dctx); }
	virtual void ClaimSelection() { return deeFuncs.Editor.ClaimSelection(dctx); }
	virtual void NotifyChange() { return deeFuncs.Editor.NotifyChange(dctx); }
	virtual void NotifyFocus(bool focus) { return deeFuncs.Editor.NotifyFocus(dctx, focus); }
	virtual int GetCtrlID() { return deeFuncs.Editor.GetCtrlID(dctx); }
	virtual void NotifyParent(SCNotification scn) { return deeFuncs.Editor.NotifyParent(dctx, scn); }
//	virtual void NotifyStyleToNeeded(int endStyleNeeded) { return deeFuncs.Editor.NotifyStyleToNeeded(dctx, endStyleNeeded); }
	virtual void NotifyDoubleClick(Point pt, bool shift, bool ctrl, bool alt) { return deeFuncs.Editor.NotifyDoubleClick(dctx, pt, shift, ctrl, alt); }
	virtual void CancelModes() { return deeFuncs.Editor.CancelModes(dctx); }
//	virtual int KeyCommand(unsigned int iMessage) { return deeFuncs.Editor.KeyCommand(dctx, iMessage); }
	virtual int KeyDefault(int key, int modifiers) { return deeFuncs.Editor.KeyDefault(dctx, key, modifiers); }
	virtual void CopyToClipboard(const SelectionText &selectedText) { return deeFuncs.Editor.CopyToClipboard(dctx, &selectedText); }
	virtual void DisplayCursor(Window::Cursor c) { return deeFuncs.Editor.DisplayCursor(dctx, c); }
	virtual bool DragThreshold(Point ptStart, Point ptNow) { return deeFuncs.Editor.DragThreshold(dctx, ptStart, ptNow); }
	virtual void StartDrag() { return deeFuncs.Editor.StartDrag(dctx); }
//	virtual void ButtonDown(Point pt, unsigned int curTime, bool shift, bool ctrl, bool alt) { return deeFuncs.Editor.ButtonDown(dctx, pt, curTime, shift, ctrl, alt); }
	virtual void SetTicking(bool on) { return deeFuncs.Editor.SetTicking(dctx, on); }
	virtual bool SetIdle(bool on) { return deeFuncs.Editor.SetIdle(dctx, on); }
	virtual void SetMouseCapture(bool on) { return deeFuncs.Editor.SetMouseCapture(dctx, on); }
	virtual bool HaveMouseCapture() { return deeFuncs.Editor.HaveMouseCapture(dctx); }
	virtual bool PaintContains(PRectangle rc) { return deeFuncs.Editor.PaintContains(dctx, rc); }
	virtual bool ValidCodePage(int codePage) { return deeFuncs.Editor.ValidCodePage(dctx, codePage); }
	virtual sptr_t DefWndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam) { return deeFuncs.Editor.DefWndProc(dctx, iMessage, wParam, lParam); }

	// ScintillaBase

	virtual void CreateCallTipWindow(PRectangle rc) {}
	virtual void AddToPopUp(const char *label, int cmd=0, bool enabled=true) {}


public:
	virtual ~DeeEditor() {}
//	virtual sptr_t WndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam) { return deeFuncs.Editor.WndProc(dctx, iMessage, wParam, lParam); }

	DeeEditor(void* ctx) : dctx(ctx) {
		wMain = ctx;
	}


	void* dctx;
};


extern "C" __declspec(dllexport) DeeEditor* createDeeEditor(void* dctx) {
	return new DeeEditor(dctx);
}

extern "C" __declspec(dllexport) Surface* createDeeSurface(void* dctx) {
	return Surface::Allocate();
}

extern "C" __declspec(dllexport) DeeFuncsStruct* getDeeFuncsStruct() {
	return &deeFuncs;
}

extern "C" __declspec(dllexport) DeeFactoriesStruct* getDeeFactoriesStruct() {
	return &deeFactories;
}





// The Palette is just ignored
Palette::Palette() {
}

Palette::~Palette() {
}

void Palette::Release() {
}

// Do nothing if it "wants" a colour. Copy the colour from desired to allocated if it is "finding" a colour.
void Palette::WantFind(ColourPair &cp, bool want) {
    if (want) {
    } else {
        cp.allocated.Set(cp.desired.AsLong());
    }
}

void Palette::Allocate(Window &/*w*/) {
}





Font::Font() : id(0) {}
Font::~Font() {
	Release();
}


void Font::Create(const char *faceName, int characterSet, int size,	bool bold, bool italic, bool extraFontFlag) {
	id = deeFactories.createFont(faceName, characterSet, size, bold, italic, extraFontFlag);
}

void Font::Release() {
	if (id != 0) {
		deeFactories.releaseFont(id);
		id = 0;
	}
}



class SurfaceImpl : public Surface {
	// Private so SurfaceImpl objects can not be copied
	SurfaceImpl(const SurfaceImpl &) : Surface() {}
	SurfaceImpl &operator=(const SurfaceImpl &) { return *this; }
public:
	SurfaceImpl() : dctx(null) {}
	virtual ~SurfaceImpl() {
		if (Initialised()) {
			Release();
		}
	}

	void Init(WindowID wid);
	void Init(SurfaceID sid, WindowID wid);
	void InitPixMap(int width, int height, Surface *surface_, WindowID wid);

	void Release();
	bool Initialised();
	void PenColour(ColourAllocated fore);
	int LogPixelsY();
	int DeviceHeightFont(int points);
	void MoveTo(int x_, int y_);
	void LineTo(int x_, int y_);
	void Polygon(Point *pts, int npts, ColourAllocated fore, ColourAllocated back);
	void RectangleDraw(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	void FillRectangle(PRectangle rc, ColourAllocated back);
	void FillRectangle(PRectangle rc, Surface &surfacePattern);
	void RoundedRectangle(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	void AlphaRectangle(PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill,
		ColourAllocated outline, int alphaOutline, int flags);
	void Ellipse(PRectangle rc, ColourAllocated fore, ColourAllocated back);
	void Copy(PRectangle rc, Point from, Surface &surfaceSource);

	void DrawTextCommon(PRectangle rc, Font &font_, int ybase, const char *s, int len, unsigned int fuOptions);
	void DrawTextNoClip(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back);
	void DrawTextClipped(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back);
	void DrawTextTransparent(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore);
	void MeasureWidths(Font &font_, const char *s, int len, int *positions);
	int WidthText(Font &font_, const char *s, int len);
	int WidthChar(Font &font_, char ch);
	int Ascent(Font &font_);
	int Descent(Font &font_);
	int InternalLeading(Font &font_);
	int ExternalLeading(Font &font_);
	int Height(Font &font_);
	int AverageCharWidth(Font &font_);

	int SetPalette(Palette *pal, bool inBackGround);
	void SetClip(PRectangle rc);
	void FlushCachedState();

	void SetUnicodeMode(bool unicodeMode_);
	void SetDBCSMode(int codePage_);

	SurfaceImpl(void* ctx) : dctx(ctx) {
		assert (ctx != null);
	}


	void* dctx;
};



Surface* Surface::Allocate() {
	return new SurfaceImpl(deeFactories.createSurface());
}


void SurfaceImpl::Init(WindowID wid) {
	if (Initialised()) Release();
	dctx = deeFactories.createSurface();
//	assert (false);		// TODO
}

void SurfaceImpl::Init(SurfaceID sid, WindowID wid) {
	if (Initialised()) Release();
	dctx = deeFactories.createSurface();
//	assert (false);		// TODO
}

void SurfaceImpl::InitPixMap(int width, int height, Surface *surface_, WindowID wid) {
	if (Initialised()) Release();
	dctx = deeFactories.createSurface();
//	assert (false);		// TODO
}


void SurfaceImpl::Release() {
	if (dctx != null) {
		deeFactories.releaseSurface(dctx);
		dctx = null;
	}
}


bool SurfaceImpl::Initialised() {
	return dctx != null;
}


void SurfaceImpl::PenColour(ColourAllocated fore) { return deeFuncs.Surface.PenColour(dctx, fore); }
int SurfaceImpl::LogPixelsY() { return deeFuncs.Surface.LogPixelsY(dctx); }
int SurfaceImpl::DeviceHeightFont(int points) { return deeFuncs.Surface.DeviceHeightFont(dctx, points); }
void SurfaceImpl::MoveTo(int x_, int y_) { return deeFuncs.Surface.MoveTo(dctx, x_, y_); }
void SurfaceImpl::LineTo(int x_, int y_) { return deeFuncs.Surface.LineTo(dctx, x_, y_); }
void SurfaceImpl::Polygon(Point *pts, int npts, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.Polygon(dctx, pts, npts, fore, back); }
void SurfaceImpl::RectangleDraw(PRectangle rc, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.RectangleDraw(dctx, rc, fore, back); }
void SurfaceImpl::FillRectangle(PRectangle rc, ColourAllocated back) { return deeFuncs.Surface.FillRectangle(dctx, rc, back); }
void SurfaceImpl::FillRectangle(PRectangle rc, Surface &surfacePattern) { return deeFuncs.Surface.FillRectanglePattern(dctx, rc, dynamic_cast<SurfaceImpl*>(&surfacePattern)->dctx); }
void SurfaceImpl::RoundedRectangle(PRectangle rc, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.RoundedRectangle(dctx, rc, fore, back); }
void SurfaceImpl::AlphaRectangle(PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags) { return deeFuncs.Surface.AlphaRectangle(dctx, rc, cornerSize, fill, alphaFill, outline, alphaOutline, flags); }
void SurfaceImpl::Ellipse(PRectangle rc, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.Ellipse(dctx, rc, fore, back); }
void SurfaceImpl::Copy(PRectangle rc, Point from, Surface &surfaceSource) { return deeFuncs.Surface.Copy(dctx, rc, from, dynamic_cast<SurfaceImpl*>(&surfaceSource)->dctx); }

void SurfaceImpl::DrawTextNoClip(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.DrawTextNoClip(dctx, rc, font_.GetID(), ybase, s, len, fore, back); }
void SurfaceImpl::DrawTextClipped(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore, ColourAllocated back) { return deeFuncs.Surface.DrawTextClipped(dctx, rc, font_.GetID(), ybase, s, len, fore, back); }
void SurfaceImpl::DrawTextTransparent(PRectangle rc, Font &font_, int ybase, const char *s, int len, ColourAllocated fore) { return deeFuncs.Surface.DrawTextTransparent(dctx, rc, font_.GetID(), ybase, s, len, fore); }
void SurfaceImpl::MeasureWidths(Font &font_, const char *s, int len, int *positions) { return deeFuncs.Surface.MeasureWidths(dctx, font_.GetID(), s, len, positions); }
int SurfaceImpl::WidthText(Font &font_, const char *s, int len) { return deeFuncs.Surface.WidthText(dctx, font_.GetID(), s, len); }
int SurfaceImpl::WidthChar(Font &font_, char ch) { return deeFuncs.Surface.WidthChar(dctx, font_.GetID(), ch); }
int SurfaceImpl::Ascent(Font &font_) { return deeFuncs.Surface.Ascent(dctx, font_.GetID()); }
int SurfaceImpl::Descent(Font &font_) { return deeFuncs.Surface.Descent(dctx, font_.GetID()); }
int SurfaceImpl::InternalLeading(Font &font_) { return deeFuncs.Surface.InternalLeading(dctx, font_.GetID()); }
int SurfaceImpl::ExternalLeading(Font &font_) { return deeFuncs.Surface.ExternalLeading(dctx, font_.GetID()); }
int SurfaceImpl::Height(Font &font_) { return deeFuncs.Surface.Height(dctx, font_.GetID()); }
int SurfaceImpl::AverageCharWidth(Font &font_) { return deeFuncs.Surface.AverageCharWidth(dctx, font_.GetID()); }

//int SurfaceImpl::SetPalette(Palette *pal, bool inBackGround) { return deeFuncs.Surface.SetPalette(dctx, pal, inBackGround); }
void SurfaceImpl::SetClip(PRectangle rc) { return deeFuncs.Surface.SetClip(dctx, rc); }
void SurfaceImpl::FlushCachedState() { return deeFuncs.Surface.FlushCachedState(dctx); }

void SurfaceImpl::SetUnicodeMode(bool unicodeMode_) { return deeFuncs.Surface.SetUnicodeMode(dctx, unicodeMode_); }
void SurfaceImpl::SetDBCSMode(int codePage) { return deeFuncs.Surface.SetDBCSMode(dctx, codePage); }



int SurfaceImpl::SetPalette(Palette *pal, bool inBackGround) {
	return 0;
}


// TODO
	Window::~Window() { }
	void Window::Destroy() { }
	bool Window::HasFocus() { return false; }
	PRectangle Window::GetPosition() { return PRectangle(); }
	void Window::SetPosition(PRectangle rc) {  }
	void Window::SetPositionRelative(PRectangle rc, Window relativeTo) { }
	PRectangle Window::GetClientPosition() { return PRectangle(); }
	void Window::Show(bool show) { }
	void Window::InvalidateAll() { }
	void Window::InvalidateRectangle(PRectangle rc) { }
	void Window::SetFont(Font &font) { }
	void Window::SetCursor(Cursor curs) { }
	void Window::SetTitle(const char *s) { }
	PRectangle Window::GetMonitorRect(Point pt) { return PRectangle(); }



// TODO
class ListBoxImpl : ListBox {
	void Create(Window &parent, int ctrlID, Point location, int lineHeight_, bool unicodeMode_) {
		assert (false);
	}

	void SetFont(Font &font) {}
	void SetAverageCharWidth(int width) {}

	void SetVisibleRows(int rows) {}
	int GetVisibleRows() const { return 0; }
	PRectangle GetDesiredRect() { return PRectangle(); }
	int CaretFromEdge() { return 0; }
	void Clear() {}
	void Append(char *s, int type = -1) {}
	int Length() { return 0; }
	void Select(int n) {}
	int GetSelection() { return 0; }
	int Find(const char *prefix) { return 0; }
	void GetValue(int n, char *value, int len) {}
	void RegisterImage(int type, const char *xpm_data) {}
	void ClearRegisteredImages() {}
	void SetDoubleClickAction(CallBackAction, void *) {}
	void SetList(const char* list, char separator, char typesep) {}
};


ListBox::ListBox() { }
ListBox::~ListBox() { }
ListBox* ListBox::Allocate() { return null; }

	
	
Menu::Menu() {}
void Menu::CreatePopUp() {}
void Menu::Destroy() {}
void Menu::Show(Point pt, Window &w) {}



// TODO: non-windows

#ifdef __WIN32__

#define _WIN32_WINNT  0x0400
#include <windows.h>

static bool initialisedET = false;
static bool usePerformanceCounter = false;
static LARGE_INTEGER frequency;

ElapsedTime::ElapsedTime() {
	if (!initialisedET) {
		usePerformanceCounter = ::QueryPerformanceFrequency(&frequency) != 0;
		initialisedET = true;
	}
	if (usePerformanceCounter) {
		LARGE_INTEGER timeVal;
		::QueryPerformanceCounter(&timeVal);
		bigBit = timeVal.HighPart;
		littleBit = timeVal.LowPart;
	} else {
		assert (false);
		//bigBit = clock();
	}
}


double ElapsedTime::Duration(bool reset) {
	double result = 0.0;
	long endBigBit = 0;
	long endLittleBit = 0;

	if (usePerformanceCounter) {
		LARGE_INTEGER lEnd;
		::QueryPerformanceCounter(&lEnd);
		endBigBit = lEnd.HighPart;
		endLittleBit = lEnd.LowPart;
		LARGE_INTEGER lBegin;
		lBegin.HighPart = bigBit;
		lBegin.LowPart = littleBit;
		double elapsed = lEnd.QuadPart - lBegin.QuadPart;
		result = elapsed / static_cast<double>(frequency.QuadPart);
	} else {
		assert (false);
		/*endBigBit = clock();
		endLittleBit = 0;
		double elapsed = endBigBit - bigBit;
		result = elapsed / CLOCKS_PER_SEC;*/
	}
	if (reset) {
		bigBit = endBigBit;
		littleBit = endLittleBit;
	}
	return result;
}



class DynamicLibraryImpl : public DynamicLibrary {
protected:
	HMODULE h;
public:
	DynamicLibraryImpl(const char *modulePath) {
		h = ::LoadLibraryA(modulePath);
	}

	virtual ~DynamicLibraryImpl() {
		if (h != NULL)
			::FreeLibrary(h);
	}

	// Use GetProcAddress to get a pointer to the relevant function.
	virtual Function FindFunction(const char *name) {
		if (h != NULL) {
			return static_cast<Function>(
				(void *)(::GetProcAddress(h, name)));
		} else
			return NULL;
	}

	virtual bool IsValid() {
		return h != NULL;
	}
};

DynamicLibrary *DynamicLibrary::Load(const char *modulePath) {
	return static_cast<DynamicLibrary *>(new DynamicLibraryImpl(modulePath));
}
#endif	// __WIN32__




ColourDesired Platform::Chrome() {
    return ColourDesired(192, 192, 192);
}

ColourDesired Platform::ChromeHighlight() {
    return ColourDesired(255, 255, 255);
}


const char *Platform::DefaultFont() {
    return "Verdana";
}

int Platform::DefaultFontSize() {
    return 13;
}

unsigned int Platform::DoubleClickTime() {
	return 300;
}

bool Platform::MouseButtonBounce() {
    return false;
}

bool Platform::IsKeyDown(int keyCode) {
    return false;
}

long Platform::SendScintilla(WindowID w, unsigned int msg, unsigned long wParam, long lParam) {
    //return scintilla_send_message( w, msg, wParam, lParam );
	return 0;
}

bool Platform::IsDBCSLeadByte(int /*codePage*/, char /*ch*/) {
    // TODO: Implement this for code pages != UTF-8
    return false;
}

int Platform::DBCSCharLength(int /*codePage*/, const char* /*s*/) {
    // TODO: Implement this for code pages != UTF-8
    return 1;
}

int Platform::DBCSCharMaxLength() {
    // TODO: Implement this for code pages != UTF-8
    //return CFStringGetMaximumSizeForEncoding( 1, CFStringEncoding encoding );
    return 2;
}

// These are utility functions not really tied to a platform
int Platform::Minimum(int a, int b) {
    if (a < b)
        return a;
    else
        return b;
}

int Platform::Maximum(int a, int b) {
    if (a > b)
        return a;
    else
        return b;
}

//#define TRACE
#ifdef TRACE
	void Platform::DebugDisplay(const char *s) {
	    fprintf( stderr, s );
	}

	void Platform::DebugPrintf(const char *format, ...) {
	    const int BUF_SIZE = 2000;
	    char buffer[BUF_SIZE];

	    va_list pArguments;
	    va_start(pArguments, format);
	    vsnprintf(buffer, BUF_SIZE, format, pArguments);
	    va_end(pArguments);
	    Platform::DebugDisplay(buffer);
	}
#else
	void Platform::DebugDisplay(const char *) {}
	void Platform::DebugPrintf(const char *, ...) {}
#endif



static bool assertionPopUps = true;

bool Platform::ShowAssertionPopUps(bool assertionPopUps_) {
    bool ret = assertionPopUps;
    assertionPopUps = assertionPopUps_;
    return ret;
}

void Platform::Assert(const char *c, const char *file, int line) {
    char buffer[2000];
    sprintf(buffer, "Assertion [%s] failed at %s %d", c, file, line);
    strcat(buffer, "\r\n");
    Platform::DebugDisplay(buffer);
}

int Platform::Clamp(int val, int minVal, int maxVal) {
    if (val > maxVal)
        val = maxVal;
    if (val < minVal)
        val = minVal;
    return val;
}

