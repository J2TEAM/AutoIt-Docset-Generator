#Region AutoIt3Wrapper directives section
;~ #Autoit3Wrapper_Testing=Y;=> Change to N when compile
#AutoIt3Wrapper_Icon=E:\wamp\www\favicon.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=Y
;~ #AutoIt3Wrapper_Compile_both=Y;=> Compile both X86 and X64 in one run
#AutoIt3Wrapper_Res_Comment=Developed by Juno_okyo
#AutoIt3Wrapper_Res_Description=Developed by Juno_okyo
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=Y
#AutoIt3Wrapper_Res_ProductVersion=1.0.0.0;=>Edit
#AutoIt3Wrapper_Res_LegalCopyright=(C) 2015 Juno_okyo. All rights reserved.
#AutoIt3Wrapper_Res_Field=InternalName|%scriptfile%.exe;=>Edit
#AutoIt3Wrapper_Res_Field=OriginalFilename|%scriptfile%.exe;=>Edit
#AutoIt3Wrapper_Res_Field=ProductName|%scriptfile%;=>Edit
#AutoIt3Wrapper_Res_Field=CompanyName|J2TeaM
#AutoIt3Wrapper_Res_Field=Website|http://junookyo.blogspot.com/
#EndRegion AutoIt3Wrapper directives section

#NoTrayIcon

#Region Includes
#include <Misc.au3>
#include <SQLite.au3>
#include <File.au3>
#include <Array.au3>
#include <String.au3>
#EndRegion Includes

_Singleton(@ScriptName)

#Region Options
Opt('MustDeclareVars', 1)
Opt('WinTitleMatchMode', 2)
#EndRegion Options

; Script Start - Add your code below here
;~ OnAutoItExitRegister('clean_tasks')

If @Compiled Then
	MsgBox(64 + 262144, 'Info', 'Run this script on SciTE if you want to check log or debug!')
EndIf

Global Const $BASE_DIR = @ScriptDir & '\AutoIt.docset\'
Global Const $contents_dir = $BASE_DIR & 'Contents\'
Global Const $resources_dir = $contents_dir & 'Resources\'
Global Const $documents_dir = $resources_dir & 'Documents\'

Global $debug_total_queries = 0

;========== RUN TASKS =============
decompileCHM()
sqlite_init('sqlite3.dll', $resources_dir & 'docSet.dsidx')
prepare()
generate_index()
clean_tasks()
MsgBox(64 + 262144, 'Message', 'Done! Total queries: ' & $debug_total_queries)

;========== FUNCTIONS =============
Func decompileCHM()
	If FileExists($documents_dir & 'index.htm') Then Return

	Local $CHM = @ScriptDir & '\AutoIt.chm'

	If Not FileExists($CHM) Then
		;=> Try again with CHM from AutoIt install folder
		$CHM = StringReplace(@AutoItExe, 'autoit3.exe', '') & 'AutoIt.chm'
		If Not FileExists($CHM) Then Exit (-1)
	EndIf

	If Not FileExists($resources_dir) Then DirCreate($resources_dir)

	;=> Decompile CHM to HTML resources
	Local $cmd = 'hh.exe -decompile ' & $resources_dir & ' ' & $CHM
	Local $PID = Run(@ComSpec & ' /c "' & $cmd & '"', @ScriptDir)

	;=> Make sure process was exit, so we can rename folder
	ProcessWaitClose($PID)
	Do
		Sleep(5)
	Until Not ProcessExists($PID)

	;=> Check for unknow error
	If Not FileExists($resources_dir & 'html\') Then Exit (-1)

	;=> Clean (remove junk files)
	Local $rename
	Do
		;=> Try to rename again
		$rename = DirMove($resources_dir & 'html\', $documents_dir)
		Sleep(5)
	Until $rename = 1
	FileDelete($resources_dir & 'AutoIt3 Index.hhk')
	FileDelete($resources_dir & 'AutoIt3 TOC.hhc')
EndFunc   ;==>decompileCHM

Func sqlite_init($dll, $db)
	If Not $dll Or Not $db Then Return False

	_SQLite_Startup($dll)
	If @error Then
		MsgBox(16 + 262144, 'SQLite Error', "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf

	ConsoleWrite('_SQLite_LibVersion=' & _SQLite_LibVersion() & @CRLF)

	_SQLite_Open($db)
	If @error Then
		MsgBox(16 + 262144, 'SQLite Error', "Can't Load Database!")
		Exit -1
	EndIf
EndFunc   ;==>sqlite_init

Func prepare()
	;=> Drop exists table
	_SQLite_Exec(-1, "DROP TABLE IF EXISTS searchIndex;")
	If @error Then Exit (-1)

	;=> Create new table
	_SQLite_Exec(-1, "CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);")
	If @error Then Exit (-2)

	_SQLite_Exec(-1, "CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);")
	If @error Then Exit (-3)

	$debug_total_queries += 3
EndFunc   ;==>prepare

Func generate_index()
	insert_index('guiref', 'Interface') ; GUI Reference
	insert_index('keywords', 'Keyword', 9) ; Keywords (Remove "Keyword ")
	insert_index('macros', 'Macro', 19) ; Macros (Remove "Macros Reference - ")
	insert_index('functions', 'Function', 9, True) ; Functions (Remove "Function ")
	insert_index('libfunctions', 'User Defined Function', 9, True) ; UDF (Remove "Function ")
	insert_index('intro', 'Instruction') ; Using AutoIt
	insert_index('appendix', 'Section') ;=> Appendix

	;=> Manual insert
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('My First Script (Hello World)', 'Guide', 'tutorials/helloworld/helloworld.htm');")
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('Simple Notepad Automation', 'Guide', 'tutorials/notepad/notepad.htm');")
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('WinZip Installation', 'Guide', 'tutorials/winzip/winzip.htm');")
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('String Regular expression', 'Guide', 'tutorials/regexp/regexp.htm');")
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('Simple Calculator GUI', 'Guide', 'tutorials/simplecalc-josbe/simplecalc.htm');")
	_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('#pragma compile', 'Directive', 'directives/pragma-compile.htm');")
	$debug_total_queries += 6
EndFunc   ;==>generate_index

Func insert_index($folder, $type, $remove = 0, $skip = False)
	; Get all HTML files in folder
	Local $aFiles = _FileListToArray($documents_dir & $folder & '\')

	; Remove first element (counter)
	_ArrayDelete($aFiles, 0)

	For $file In $aFiles
		If $skip Then
			If StringInStr($file, ' ') Then ContinueLoop
		EndIf

		Local $path = $documents_dir & $folder & '\' & $file
		Local $name = get_name($path)

		If $remove > 0 Then
			$name = StringMid($name, $remove)
		EndIf

		_SQLite_Exec(-1, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('" & $name & "', '" & $type & "', '" & $folder & "/" & $file & "');")
		$debug_total_queries += 1
		ConsoleWrite(@CRLF & '> Name: ' & $name & ' (' & $folder & '/' & $file & ')')
	Next
EndFunc   ;==>insert_index

Func get_name($file_path)
	;=> Get title in HTML
	Local $fp = FileOpen($file_path)
	Local $source = FileRead($fp, 200) ; Read only 200 char (included <head>...</head>)
	FileClose($fp)

	Local $name = _StringBetween($source, '<title>', '</title>')
	Return $name[0]
EndFunc   ;==>get_name

Func clean_tasks()
	ConsoleWrite(@CRLF & '> Cleanning: Close Database and unload sqlite3.dll')
	_SQLite_Close() ;=> Close Database
	_SQLite_Shutdown() ;=> Unload DLL

	;=> Copy icons
	FileCopy(@ScriptDir & '\icon.png', $BASE_DIR & 'icon.png')
	FileCopy(@ScriptDir & '\icon@2x.png', $BASE_DIR & 'icon@2x.png')
	ConsoleWrite(@CRLF & '> Added icons')

	;=> Copy Info.plist
	FileCopy(@ScriptDir & '\Info.plist', $contents_dir & 'Info.plist')
	ConsoleWrite(@CRLF & '> Added Info.plist')

	ConsoleWrite(@CRLF & '+> Done! Total queries: ' & $debug_total_queries & @CRLF)
EndFunc   ;==>clean_tasks
