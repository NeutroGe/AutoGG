#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=yuumi.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         N3utro-

 Script Function:
	Get ranked players stats in league of legends solo/duo queue games

#ce ----------------------------------------------------------------------------

;including libraries used in the code

#NoTrayIcon
#include <Array.au3>
#include <Inet.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <TrayConstants.au3>
#include <File.au3>
#include <GuiRichEdit.au3>
#include <WinAPIProc.au3>
#include <WinHttp.au3>
#include <IE.au3>
;#include <MCFinclude.au3>

;setting up the tray icon menu

Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)
Opt("GUIOnEventMode", 1)

global $option_tray = TrayCreateItem("Disable summary page auto opening")
TrayItemSetOnEvent(-1, "switch_auto_open")
TraySetToolTip ("autogg")
TraySetState($TRAY_ICONSTATE_SHOW)
TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitApp")

AutoItSetOption("WinTitleMatchMode", 3)


;app options are below

$debug = 0 ;generates debug files if set to 1
$skip_local_player = 0 ;this should be always set to 1. Set only to 0 for debugging purposes (testing with custom games for example)
global $disable_auto_page_opening = 0 ; if set to 1 then doesn't open op.gg stat page automatically (useful for getting premade infos only)
$tempfile_location = @TempDir & "\sstats_temp.txt"
$gui_img_location = @TempDir & "\sstats_gui.jpg"
$error_log = @Scriptdir & "\error.log"

;initializing variables. the variables below are not options, dont change their values or the app will stop working

$gui_enabled = 0
$stats_done = 0
$enemy_stats_done = 0
$LCUsource = ""
$champ_select_start = 0
$champ_select_reset = 0
$posx = 0
$client_launched = 0

;checking if the app is already launched

if ProcessExists("autogg") Then

	msgbox("","Error", "Another instance of summoners stats is already running.")

	Exit

EndIf

AutoItSetOption("WinTitleMatchMode", 1)


;checking if the file gui.txt is in the app folder

if fileexists(@scriptdir & "/gui.jpg") = 0 Then

	msgbox("","Error", "The file gui.jpg is missing from the app folder.")

	Exit

EndIf

;closing Internet explorer windows if they alreay exists

if ProcessExists("iexplore.exe") then ProcessClose("iexplore.exe")

;finding out the server (EUW1, NA1, ...) on which the player is connected
;for that we check a configuration file in the installation folder of the game where it is indicated

;getting the lol client installation path from the executable process informations

$lol_process_id = ProcessExists('LeagueClient.exe')

if $lol_process_id = 0 Then

	msgbox("","Error", 'Please launch the League of Legends client before launching this app.')

	Exit

Else

	$lol_client_exe_file_path = _WinAPI_GetProcessFileName($lol_process_id)

	if $lol_client_exe_file_path = "" then

		msgbox("","Error", 'The game is beeing run with administrators rights and should not be. Please disable admin rights for the lol client and try again.')

		Exit

	EndIf

EndIf

$lol_client_install_path = StringReplace($lol_client_exe_file_path,"LeagueClient.exe", "")


;ok we found out where the client is installed, now we open the config file which contains the server region informations

$settings_file = FileReadToArray($lol_client_install_path & "Config\LeagueClientSettings.yaml")

if IsArray($settings_file) = 0 Then

	msgbox("","Error", "Cannot read the content of " & $lol_client_install_path & "Config\LeagueClientSettings.yaml")
	Exit

EndIf

$region_line = _ArraySearch($settings_file, "region:", 0, 0, 0, 1)

if $region_line = -1 Then

	msgbox("","Error", "Cannot find the region setting in " & $lol_client_install_path & "Config\LeagueClientSettings.yaml")
	Exit

EndIf

$region_line_delimiter_start = stringinstr($settings_file[$region_line], '"', 0, 1)

$region_line_delimiter_end = stringinstr($settings_file[$region_line], '"', 0, 2)

$region_letters_count = $region_line_delimiter_end - 1 - $region_line_delimiter_start

$region = stringmid($settings_file[$region_line], $region_line_delimiter_start + 1, $region_letters_count)

if $region <> "NA" AND $region <> "EUW" AND $region <> "EUNE" AND $region <> "LAN" AND $region <> "LAS" AND $region <> "BR" AND $region <> "JP" AND $region <> "RU" AND $region <> "TR" and $region <> "OCE" & $region <> "KR" Then

	msgbox("","Error", "Impossible to get the server region.")
	Exit

EndIf

switch $region

	case "NA"
		$opgg_page_url = "https://na.op.gg/summoners/na/"
		$opgg_summoners_ahref = "na"
		$opgg_summoners_ahref_offset = 0 ;number of characters in the region text after the 2 first ones. Used to search in the page code later
		$opgg_multisearch_url = "https://na.op.gg/multisearch/na?summoners="

	case "EUW"
		$opgg_page_url = "https://euw.op.gg/summoners/euw/"
		$opgg_summoners_ahref = "euw"
		$opgg_summoners_ahref_offset = 1
		$opgg_multisearch_url = "https://euw.op.gg/multisearch/euw?summoners="

	case "EUNE"
		$opgg_page_url = "https://eune.op.gg/summoners/eune/"
		$opgg_summoners_ahref = "eune"
		$opgg_summoners_ahref_offset = 2
		$opgg_multisearch_url = "https://eune.op.gg/multisearch/eune?summoners="

	case "LAN"
		$opgg_page_url = "https://lan.op.gg/summoners/lan/"
		$opgg_summoners_ahref = "lan"
		$opgg_summoners_ahref_offset = 1
		$opgg_multisearch_url = "https://lan.op.gg/multisearch/lan?summoners="

	case "LAS"
		$opgg_page_url = "https://las.op.gg/summoners/las/"
		$opgg_summoners_ahref = "las"
		$opgg_summoners_ahref_offset = 1
		$opgg_multisearch_url = "https://las.op.gg/multisearch/las?summoners="

	case "BR"
		$opgg_page_url = "https://br.op.gg/summoners/br/"
		$opgg_summoners_ahref = "br"
		$opgg_summoners_ahref_offset = 0
		$opgg_multisearch_url = "https://br.op.gg/multisearch/br?summoners="

	case "JP"
		$opgg_page_url = "https://jp.op.gg/summoners/jp/"
		$opgg_summoners_ahref = "jp"
		$opgg_summoners_ahref_offset = 0
		$opgg_multisearch_url = "https://jp.op.gg/multisearch/jp?summoners="

	case "RU"
		$opgg_page_url = "https://na.op.gg/summoners/na/"
		$opgg_summoners_ahref = "na"
		$opgg_summoners_ahref_offset = 0
		$opgg_multisearch_url = "https://na.op.gg/multisearch/na?summoners="

	case "TR"
		$opgg_page_url = "https://ru.op.gg/summoners/ru/"
		$opgg_summoners_ahref = "ru"
		$opgg_summoners_ahref_offset = 0
		$opgg_multisearch_url = "https://ru.op.gg/multisearch/ru?summoners="

	case "OCE"
		$opgg_page_url = "https://oce.op.gg/summoners/oce/"
		$opgg_summoners_ahref = "oce"
		$opgg_summoners_ahref_offset = 1
		$opgg_multisearch_url = "https://oce.op.gg/multisearch/oce?summoners="

	case "KR"
		$opgg_page_url = "https://www.op.gg/summoners/kr/"
		$opgg_summoners_ahref = "kr"
		$opgg_summoners_ahref_offset = 0
		$opgg_multisearch_url = "https://www.op.gg/multisearch/kr?summoners="

EndSwitch

;ok we're done with getting the server region.

;drawing the app gui

;reading reg values if they exists

$posx = RegRead("HKEY_CURRENT_USER\Software\sstats", "posx")
if $posx <> 0 Then

	$posy = RegRead("HKEY_CURRENT_USER\Software\sstats", "posy")
	$eposx = RegRead("HKEY_CURRENT_USER\Software\sstats", "enemyposx")
	$eposy = RegRead("HKEY_CURRENT_USER\Software\sstats", "enemyposy")

Else

	$posx = 0
	$posy = 0
	$eposx = 319
	$eposy = 0

EndIf

$gui = GUICreate("autogg", 319, 496, $posx, $posy, $WS_POPUP)
;GUISetState(@SW_HIDE)
$Pic1 = GUICtrlCreatePic("gui.jpg", 0, 0, 319, 496)
GUICtrlSetState(-1, $GUI_DISABLE)
$Dragarea = GUICtrlCreateLabel("", 0, 0, 319, 33, -1, $GUI_WS_EX_PARENTDRAG)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
$title = GUICtrlCreateLabel("Your Team", 105, 32, 193, 33, -1, $GUI_WS_EX_PARENTDRAG)
GUICtrlSetFont(-1, 15, 400)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetFont(-1, 15, 400)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
$summoner1_gui = _GUICtrlRichEdit_Create($gui, "",5, 96, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
settext($summoner1_gui,"Waiting for the game client to be launched...")
$summoner2_gui = _GUICtrlRichEdit_Create($gui, "",5, 176, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner3_gui = _GUICtrlRichEdit_Create($gui, "",5, 256, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner4_gui = _GUICtrlRichEdit_Create($gui, "",5, 336, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner5_gui = _GUICtrlRichEdit_Create($gui, "",5, 416, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
GUISetOnEvent($GUI_EVENT_CLOSE, "guiclose")

GUISetState(@SW_SHOW)


$gui2 = GUICreate("enemyteam", 319, 496, $eposx, $eposy, $WS_POPUP)
;GUISetState(@SW_HIDE)
$Pic2 = GUICtrlCreatePic("gui.jpg", 0, 0, 319, 496)
GUICtrlSetState(-1, $GUI_DISABLE)
$Dragarea2 = GUICtrlCreateLabel("", 0, 0, 319, 33, -1, $GUI_WS_EX_PARENTDRAG)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetFont(-1, 15, 400)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
$Enemy = GUICtrlCreateLabel("Enemy Team", 105, 32, 146, 33)
GUICtrlSetFont(-1, 15, 400)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
;enemy team
$summoner6_gui = _GUICtrlRichEdit_Create($gui2, "",5, 96, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner7_gui = _GUICtrlRichEdit_Create($gui2, "",5, 176, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner8_gui = _GUICtrlRichEdit_Create($gui2, "",5, 256, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner9_gui = _GUICtrlRichEdit_Create($gui2, "",5, 336, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
$summoner10_gui = _GUICtrlRichEdit_Create($gui2, "",5, 416, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
settext($summoner6_gui,"Waiting for the game client to be launched...")
GUISetOnEvent($GUI_EVENT_CLOSE, "guiclose")

GUISetState(@SW_SHOW)

DllCall("user32.dll","int","HideCaret","int",0) ;this is to disable the cursor when the user select the text of the GUI to copy it

WinSetOnTop("autogg", "", 1)
WinSetOnTop("enemyteam", "", 1)



;----------------------------------------------------------------

;starting to check in a loop the content of the LCU local http server to see if a champion selection screen is displayed or not

;When a game is started and the champion selection screen is displayed, the page /lol-champ-select/v1/session becomes available and contains players names, positions and their selected champions.
;So we wait for this page to become available, and when it does we retrieve and use the players names to download their matches history through riot API, generate their stats from them and display these stats.
;Once a player has locked a champion, we also get the champion name and display the players stats with this champion.

While 1 ;until the software is closed, we start watching for games

	;checking if the league client is running or not, if not we wait

	;getting the lol client installation path from the executable process informations

	while ProcessExists('LeagueClient.exe') = 0

		sleep(1500)


	WEnd

	;closing Internet explorer windows if they alreay exists

	if ProcessExists("iexplore.exe") then ProcessClose("iexplore.exe")

	sleep(10000)

	if $client_launched = 0 Then

		$lol_process_id = ProcessExists('LeagueClient.exe')

		$lol_client_exe_file_path = _WinAPI_GetProcessFileName($lol_process_id)

		if $lol_client_exe_file_path = "" then

			msgbox("","Error", 'The game is beeing run with administrators rights and should not be. Please disable admin rights for the lol client and try again.')

			Exit

		EndIf

		$lol_client_install_path = StringReplace($lol_client_exe_file_path,"LeagueClient.exe", "")


		;getting local client (riot calls it "LCU") http server port and password (it changes everytime the league client is restarted)

		$lockfile = fileopen($lol_client_install_path & "lockfile")

		if $lockfile = -1 then

			msgbox("","Error", 'Cannot open ' & $lol_client_install_path & 'lockfile (is the game client started?')
			Exit

		EndIf

		$lockfile_content = FileReadLine($lockfile)

		$lockfile_split_content=""

		$lockfile_split_content = StringSplit($lockfile_content, ":")

		if IsArray($lockfile_split_content) <> 1 Then

			msgbox("","Error", "Cannot read the content of " & $lol_client_install_path & "lockfile")
			Exit

		EndIf

		;_arraydisplay($lockfile_split_content)

		$port = $lockfile_split_content[3]
		$pass = $lockfile_split_content[4]


		;connecting to the LCU local web server and checking if it works by accessing the local game settings informations

		$hOpen = _WinHttpOpen()
		$hConnect = _WinHttpConnect($hOpen, "127.0.0.1", $port)
		$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-game-settings/v1/game-settings", Default, Default, Default, True , 1, "riot", $pass, 1)

		if IsArray($hRequest) = 0 Then

			msgbox("","Error", "Impossible to connect to the local client web server")

			Exit

		EndIf

		;the source we get this way should contain the word "MasterVolume". We check if it is the case, which means the connection is successful

		if StringInStr($hRequest[1], "MasterVolume") = 0 Then

			msgbox("","Error", "Impossible to find MasterVolume reference in the http server query reply.")
			Exit

		EndIf

		_WinHttpCloseHandle($hRequest)

		settext($summoner1_gui,"Waiting for a new champion select to start...")

		$client_launched = 1

	EndIf

	;----------------------------------------------------------------

	$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-champ-select/v1/session", Default, Default, Default, True , 1, "riot", $pass, 1)

	if IsArray($hRequest) = 0 Then ;client is closed

		_WinHttpCloseHandle($hRequest)
        _WinHttpCloseHandle($hConnect)
        _WinHttpCloseHandle($hOpen)

		$client_launched = 0

		settext($summoner1_gui,"Waiting for the game client to be launched...")
		settext($summoner2_gui, "")
		settext($summoner3_gui, "")
		settext($summoner4_gui, "")
		settext($summoner5_gui, "")
		settext($summoner6_gui, "Waiting for a new game to start...")
		settext($summoner7_gui, "")
		settext($summoner8_gui, "")
		settext($summoner9_gui, "")
		settext($summoner10_gui, "")

		sleep(5000)

		ContinueLoop

	EndIf

	$LCUsource = $hRequest[1]

	_WinHttpCloseHandle($hRequest)

	if $debug = 1 then FileDelete(@scriptdir & "\data\lcu.txt")

	if $debug = 1 then FileWrite(@scriptdir & "\data\lcu.txt", $LCUsource)


	DllCall("user32.dll","int","HideCaret","int",0) ;this is to disable the cursor when the user select the text of the GUI to copy it

	$test = StringInStr($LCUsource, '"httpStatus":404') ; when no champion select page is displayed, querying the champ select page returns a 404 error

	if $test <> 0 then  ; no champion select screen is displayed so we reset the app gui and wait for a game to start

			$stats_done = 0

			$champ_select_start = 0

			if $champ_select_reset = 0 Then

				settext($summoner1_gui, "Waiting for a new champion select to start...")
				settext($summoner2_gui, "")
				settext($summoner3_gui, "")
				settext($summoner4_gui, "")
				settext($summoner5_gui, "")
				settext($summoner6_gui, "Waiting for a new game to start...")
				settext($summoner7_gui, "")
				settext($summoner8_gui, "")
				settext($summoner9_gui, "")
				settext($summoner10_gui, "")

				$champ_select_reset = 1

				if ProcessExists("iexplore.exe") then ProcessClose("iexplore.exe")

			EndIf

			sleep(1000)

	Else ; champion select has started

			if $champ_select_start = 0 Then

				settext($summoner1_gui, "Refreshing OP.GG pages in progress...")

				$champ_select_start = 1

				$champ_select_reset = 0

			EndIf

			if $stats_done = 0 Then  ;this is used so that when stats are done, the app doesn't do them over and over again, just once.

				;creating a folder for debugging files if enabled

				if $debug = 1 AND FileExists(@scriptdir & "\data") = 0 then DirCreate(@scriptdir & "\data")


				local $summoners_names_list[6] ;array that contains the names of all players of the team of the local player that is later used for the "recently played with" system detection

				;getting summoners names by finding their LCU summoner ID and converting it to their real names
				;we're not getting the local player stats because of the request limit of riot API

				;$LCUsource = _INetGetSource("https://riot:" & $pass & "@127.0.0.1:" & $port & "/lol-champ-select/v1/session")

				;ConsoleWrite($LCUsource)

				;identifying the id of the local player

				$local_player_index = stringinstr($LCUsource, "localPlayerCellId")
				$local_player_cell_ID = stringmid($LCUsource, $local_player_index + 19, 1)
				$local_player_cell_ID = number($local_player_cell_ID) + 1 ;cellID go from 0 to 9 so we add one to go from 1 to 10
				if $local_player_cell_ID > 5 then $local_player_cell_ID = $local_player_cell_ID - 5 ;if the local player cell id is for the second team, we remove 5 to transpose it so it's in the 1-5 range

				$index = stringinstr($LCUsource, '"myTeam":[{', 1)

				for $i = 1 to 5 step 1

					;if it's the local player we skip it

					if $i = $local_player_cell_ID AND $skip_local_player = 1 Then

						$gui_temp = eval("summoner" & $i & "_gui")

						settext($gui_temp, "Local player - skipping")

						ContinueLoop

					EndIf

					$index2 = stringinstr($LCUsource, "summonerId", 1, $i, $index)

					$index3 = stringinstr($LCUsource, ",", 1, 1, $index2)

					$id = stringmid($LCUsource, $index2 + 12, $index3 - ($index2 + 12))

					if StringIsDigit($id) = 0 Then continueloop ;the id wont be a number if there are less than 5 players so we skip them

					if $debug = 1 then filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $id & ",")

					;translating summoner ID into their summoner's name

					$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-summoner/v1/summoners/" & $id, Default, Default, Default, True , 1, "riot", $pass, 1)

					if IsArray($hRequest) = 0 Then

						msgbox("","Error", "Impossible to retreive the summoners informations from the local web server")

						Exit

					EndIf

					$summonerinfosource = $hRequest[1]

					_WinHttpCloseHandle($hRequest)

					$summoner_name_index_start = stringinstr($summonerinfosource, '"', 1, 5)

					$summoner_name_index_end = stringinstr($summonerinfosource, '"', 1, 6)

					$summoner_name = stringmid($summonerinfosource, $summoner_name_index_start +1, $summoner_name_index_end - $summoner_name_index_start - 1)

					if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $summoner_name & ",")

					$summoners_names_list[$i] = $summoner_name

				Next

;                  USED FOR DEBUGGING ONLY
; 				$summoners_names_list[1] = "obitosana"
; 				$summoners_names_list[2] = "Gh0stSn1per"
; 				$summoners_names_list[3] = "KC N3utro"
;~ 				$summoners_names_list[4] = "VroumBatum"
;~ 				$summoners_names_list[5] = "ChaselEmily"

				Local $oIE[6];

				$opggfullnamelist = ""

				$premade_players_list = "Recently played with:" & @CRLF & @CRLF

				for $i = 1 to 5 step 1 ;this is the core of the app, where we start getting the matches history of each players and parse them to generate stats

						settext($summoner2_gui, "Opening OP.GG profiles of each players...")


						if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop


						$summoner_name = $summoners_names_list[$i]

						if $summoner_name = "" then ContinueLoop ;this means the team of the localplayer has less than 5 members. Shouldn't happen but used for debugging in custom games

						$opggfullnamelist = $opggfullnamelist & $summoner_name & ","

						;convert summoner name for use in op.gg url (convert spaces to %20)

						$encoded_summoner_name = StringReplace($summoner_name, " ", "%20")

						if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $encoded_summoner_name & ",")

						;GUICtrlSetData(eval("summoner" & $i & "_gui") , $summoner_name)

						$oIE[$i] = _IECreate($opgg_page_url & $encoded_summoner_name, 0, 0, 0)

						if @error <> 0 Then

							filewrite($error_log, "Impossible to open an IE page for " & $summoner_name & " (line 440)" & @CRLF)

						EndIf

				Next

				settext($summoner3_gui, "Waiting for the pages to load...")

				for $i = 1 to 5 step 1

						$summoner_name = $summoners_names_list[$i]

						if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

						if $summoner_name = "" then ContinueLoop

					    _IELoadWait($oIE[$i])

				Next

				sleep(1000)

			    settext($summoner3_gui, "Updating the player's datas...")


				for $i = 1 to 5 step 1

						;clicking on the "update" button of the player's op.gg page. It's required to do it with powershell because autoit wont work with it strangely (perhaps because the page is too heavy?)

						$summoner_name = $summoners_names_list[$i]

						if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

						if $summoner_name = "" then ContinueLoop

						$sPSCmd = """$oIE = (New-Object -ComObject 'Shell.Application').Windows() | Where-Object { $_.LocationName -like '*" & $summoner_name & "*' }; $control = $oIE.document.IHTMLDocument3_getElementsByTagName('button') | where-object { $_.className -eq 'css-4e9tnt eapd0am1' };$control.click()"""

						RunWait(@comspec & ' /c powershell.exe -executionpolicy bypass -NoProfile -WindowStyle hidden -command ' & $sPSCmd, "", @SW_HIDE)

						sleep(100)

						if Winexists("[CLASS:#32770]","") Then

							WinClose("[CLASS:#32770]","")

							$sPSCmd = """$oIE = (New-Object -ComObject 'Shell.Application').Windows() | Where-Object { $_.LocationName -like '*" & $summoner_name & "*' }; $oIE.visible = $false"""

							RunWait(@comspec & ' /c powershell.exe -executionpolicy bypass -NoProfile -WindowStyle hidden -command ' & $sPSCmd, "", @SW_HIDE)

						EndIf

				Next

				sleep(500)

				settext($summoner3_gui, "Reloading pages after data update...")

				processclose("iexplore.exe")

				sleep(1000)

				for $i = 1 to 5 step 1

					$summoner_name = $summoners_names_list[$i]

					if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

					if $summoner_name = "" then ContinueLoop

					$encoded_summoner_name = StringReplace($summoner_name, " ", "%20")

					$oIE[$i] = _IECreate($opgg_page_url & $encoded_summoner_name, 0, 0, 0)

				Next

				settext($summoner3_gui, "Waiting for the pages to reload...")

				for $i = 1 to 5 step 1

						$summoner_name = $summoners_names_list[$i]

						if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

						if $summoner_name = "" then ContinueLoop

					    _IELoadWait($oIE[$i])

				Next

				sleep(200)

				;gathering premade informations

				settext($summoner3_gui, 'Gathering "recently played with" players informations...')

				for $i = 1 to 5 step 1

					$summoner_name = $summoners_names_list[$i]

					if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

					if $summoner_name = "" then ContinueLoop

					$body = _IEDocReadHTML($oIE[$i]) ;reading the content of the page

					;FileWrite(@scriptdir & "\source.txt", $body)

					if @error <> 0 Then

						filewrite($error_log, "Impossible to read the source for " & $summoner_name & " (line 537)" & @CRLF)

					EndIf

					$string_search_start_position = Stringinstr($body, "css-ut2tyh e1rsywk30")

					$string_search_end_position = Stringinstr($body, "</table>", 0, 1, $string_search_start_position)

					$premade_data = stringmid($body, $string_search_start_position, $string_search_end_position - $string_search_start_position)

					;ConsoleWrite(@CRLF & $premade_data & @CRLF)

					;checking how many premade players there are in the player's page

					$premade_players_count = 0

					StringReplace($premade_data, "a href", "a href") ; little dev trick to count the number of players

					$premade_players_count = @extended

					;for each premade player in the player's page we get their name and check if it's a player in the current game

					if $premade_players_count <> 0 then

						for $j = 1 to $premade_players_count step 1


							$premade_name_position_start = StringInStr($premade_data, 'a href="/summoners/' & $opgg_summoners_ahref & '/', 0, $j) + 22 + $opgg_summoners_ahref_offset

							$premade_name_position_start = StringInStr($premade_data, ">", 0, 2, $premade_name_position_start) + 1

							$premade_name_position_end = StringInStr($premade_data, "<", 0, 1, $premade_name_position_start)

							$premade_player_name = StringMid($premade_data, $premade_name_position_start, $premade_name_position_end - $premade_name_position_start)

							;ConsoleWrite($premade_player_name & @CRLF)

							;searching if the premade player name is one of the current player in the team

							for $k = 1 to 5 step 1

								if $premade_player_name = $summoners_names_list[$k] AND $premade_player_name <> $summoner_name AND stringinstr($premade_players_list, $premade_player_name) = 0 Then

									;getting the number of games played with and the winrate

									$premade_times_played_start = StringInStr($premade_data, "played", 0, 1, $premade_name_position_end) + 8

									$premade_times_played_end = StringInStr($premade_data, "<", 0, 1, $premade_times_played_start)

									$premade_times_played = StringMid($premade_data, $premade_times_played_start, $premade_times_played_end - $premade_times_played_start)

									;----------------------------

									$premade_winrate_percentage_start = StringInStr($premade_data, "winratio", 0, 1, $premade_times_played_end) + 10

									$premade_winrate_percentage_end = StringInStr($premade_data, "<", 0, 1, $premade_winrate_percentage_start)

									$premade_winrate_percentage = StringMid($premade_data, $premade_winrate_percentage_start, $premade_winrate_percentage_end - $premade_winrate_percentage_start)

									;ConsoleWrite($premade_winrate_percentage_start & @CRLF)

									;ConsoleWrite($premade_winrate_percentage_end & @CRLF)

								;	ConsoleWrite($premade_winrate_percentage & @CRLF)


									$premade_players_list = $premade_players_list & $premade_player_name & " & " & $summoner_name & " (" & $premade_times_played & " - " & $premade_winrate_percentage & ") " & @CRLF

									settext($summoner4_gui, $premade_players_list)

								EndIf


							Next

						Next

					EndIf

					sleep(100)

				Next

				settext($summoner3_gui, "Closing the pages...")

				for $i = 1 to 5 step 1

					$summoner_name = $summoners_names_list[$i]

					if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

					if $summoner_name = "" then ContinueLoop

					_IEQuit($oIE[$i])

					sleep(100)

				Next

				settext($summoner1_gui, "Update done!" & @CRLF & @CRLF & "Check OP.GG summary page below for results")
				settext($summoner2_gui, $opgg_multisearch_url & $opggfullnamelist)

				;ConsoleWrite($premade_players_list & @CRLF)

				if $premade_players_list = "Recently played with:" & @CRLF & @CRLF then settext($summoner4_gui, "No players recently played with others")

				settext($summoner3_gui, "Waiting for the game to start...")


				if $disable_auto_page_opening = 0 then ShellExecute($opgg_multisearch_url & $opggfullnamelist)

				sleep(100)

				WinActivate("sstats")


				$stats_done = 1

			EndIf ;end of stats making

			sleep(10) ;used so that the numbers of queries to the local web server is not too high

			;we wait to see if the game starts or if someone dodges

			$test = 0

			while $test = 0

				sleep(2500)

				;consolewrite("sleep" & @CRLF)

				$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-champ-select/v1/session", Default, Default, Default, True , 1, "riot", $pass, 1)

				$LCUsource = $hRequest[1]

				_WinHttpCloseHandle($hRequest)

				$test = StringInStr($LCUsource, 'GAME_STARTING') + StringInStr($LCUsource, 'httpStatus":404')

				;ConsoleWrite($LCUsource & @CRLF)

				;filewrite(@ScriptDir & "\test" & @min & @sec & ".txt", $LCUsource)

			WEnd

			sleep(2500)

			;we check if a game is currently running

			$enemy_stats_done = 0

				if ProcessExists("League of Legends.exe") <> 0 then

					settext($summoner3_gui, "Game is running, GLHF! :)")

					settext($summoner6_gui,"Getting the enemy team players name from" & @CRLF & "the livegame page...")

					while ProcessExists("League of Legends.exe") <> 0

						sleep(5000)

						if $enemy_stats_done = 0 then

							;getting enemy team players data

							;finding enemy team players name

							;opening local player op.gg "live game" page

							$encoded_summoner_name = StringReplace($summoners_names_list[1], " ", "%20")

							$oIE_livegame = _IECreate($opgg_page_url & $encoded_summoner_name & "/ingame", 0, 0, 0)

							if @error <> 0 Then

								filewrite($error_log, "Impossible to open the livegame page for " & $encoded_summoner_name & " (line 668)" & @CRLF)

							EndIf

							 _IELoadWait($oIE_livegame)

							sleep(5000)

							 $body_livegame = _IEDocReadHTML($oIE_livegame) ;reading the content of the page

							 if @error <> 0 then

								 filewrite($error_log, "Impossible to read the source of the livepage for " & $encoded_summoner_name & " (line 681)" & @CRLF)

							 EndIf

							; FileWrite(@scriptdir & "\livegame" & @MIN & @SEC & ".txt", $body_livegame)

							 $retry_count = 0

							 While StringInStr($body_livegame, $summoners_names_list[2]) = 0

								; FileWrite(@scriptdir & "\livegame" & @MIN & @SEC & ".txt", $body_livegame)

								 _IEQuit($oIE_livegame)

								 sleep(1000)

								 $oIE_livegame = _IECreate($opgg_page_url & $encoded_summoner_name & "/ingame", 0, 0, 0)

								 sleep(5000)

								 $body_livegame = _IEDocReadHTML($oIE_livegame) ;reading the content of the page

								 $retry_count = $retry_count + 1

								 if $retry_count > 5 then

									 msgbox("","Error", "Impossible to get the live game data. This usually happens when op.gg is bugging.)")

									 _IEQuit($oIE_livegame)

									 Exit

								EndIf

							WEnd

							 ;to check if the player team is the blue or red one, we search for "red team" in the page, then for one of our team player name. If it's found after the text "red team"
							 ;it means our team is the red team, otherwise it's the blue team (it's because in op.gg "live game" page the red team is always displayed after the blue team, at the end.

							 $livegame_red_team_name_position = StringInStr($body_livegame, "Red Team")

							 $check_livegame_player_team = StringInStr($body_livegame, $summoners_names_list[1], 0, 1, $livegame_red_team_name_position, 12800) ;12800 = approx max nb of text characters of team comp

							 if $check_livegame_player_team <> 0 Then ; our team is the red team => the enemy team is the blue team

									 ;looking for "blue team" text position in the page

									 $livegame_blue_team_start_position = StringInStr($body_livegame, "Blue Team")

									 ;getting the enemy team player's name

									 local $enemy_players_name[6]

									 for $j = 1 to 5 step 1


									$enemy_player_name_position_start = StringInStr($body_livegame, '<td class="summoner-name"><a href="/summoners/' & $opgg_summoners_ahref & '/', 0, $j, $livegame_blue_team_start_position) + 49 + $opgg_summoners_ahref_offset

									$enemy_player_name_position_start = StringInStr($body_livegame, ">", 0, 1, $enemy_player_name_position_start) + 1

									$enemy_player_name_position_end = StringInStr($body_livegame, "<", 0, 1, $enemy_player_name_position_start)

									$enemy_player_name_name = StringMid($body_livegame, $enemy_player_name_position_start, $enemy_player_name_position_end - $enemy_player_name_position_start)

									$enemy_players_name[$j] = $enemy_player_name_name

									 Next

							 Else   ; our team is the blue team => the enemy team is the red team

									 ;looking for "red team" text position in the page

									 $livegame_red_team_start_position = StringInStr($body_livegame, "Red Team")

									 ;getting the enemy team player's name

									 local $enemy_players_name[6]

									 for $j = 1 to 5 step 1


									$enemy_player_name_position_start = StringInStr($body_livegame, '<td class="summoner-name"><a href="/summoners/' & $opgg_summoners_ahref & '/', 0, $j, $livegame_red_team_start_position) + 49 + $opgg_summoners_ahref_offset

									$enemy_player_name_position_start = StringInStr($body_livegame, ">", 0, 1, $enemy_player_name_position_start) + 1

									$enemy_player_name_position_end = StringInStr($body_livegame, "<", 0, 1, $enemy_player_name_position_start)

									$enemy_player_name_name = StringMid($body_livegame, $enemy_player_name_position_start, $enemy_player_name_position_end - $enemy_player_name_position_start)

									$enemy_players_name[$j] = $enemy_player_name_name

									 Next

									EndIf

								 _IEQuit($oIE_livegame)

								 $enemy_stats_done = 1

								 ;_ArrayDisplay($enemy_players_name)

								 ;we got the names of enemy players team, now we refresh their data and check if they have premades or not like for our team before

								 settext($summoner6_gui,"Refreshing enemy team players data...")

								Local $enemy_oIE[6];

								$enemy_opggfullnamelist = ""

								$enemy_premade_players_list = "Recently played with:" & @CRLF & @CRLF

								for $i = 1 to 5 step 1 ;this is the core of the app, where we start getting the matches history of each players and parse them to generate stats

										settext($summoner7_gui, "Opening OP.GG profiles of each players...")

										$summoner_name = $enemy_players_name[$i]

										if $summoner_name = "" then ContinueLoop ;this means the team of the localplayer has less than 5 members. Shouldn't happen but used for debugging in custom games

										$enemy_opggfullnamelist = $enemy_opggfullnamelist & $summoner_name & ","

										;convert summoner name for use in op.gg url (convert spaces to %20)

										$encoded_summoner_name = StringReplace($summoner_name, " ", "%20")

										if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $encoded_summoner_name & ",")

										;GUICtrlSetData(eval("summoner" & $i & "_gui") , $summoner_name)

										$enemy_oIE[$i] = _IECreate($opgg_page_url & $encoded_summoner_name, 0, 0, 0)

										if @error <> 0 Then

											filewrite($error_log, "Impossible to open an IE page for" & $summoner_name & " (line 780)" & @CRLF)

										EndIf

								Next

								settext($summoner8_gui, "Waiting for the pages to load...")

								for $i = 1 to 5 step 1

										$summoner_name = $enemy_players_name[$i]

										if $summoner_name = "" then ContinueLoop

										_IELoadWait($enemy_oIE[$i])

								Next

								sleep(1000)

								settext($summoner8_gui, "Updating the enemies player's datas...")

								for $i = 1 to 5 step 1

										$summoner_name = $enemy_players_name[$i]

										if $summoner_name = "" then ContinueLoop

										;clicking on the "update" button of the player's op.gg page. It's required to do it with powershell because autoit wont work with it strangely (perhaps because the page is too heavy?)

										if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop

										if $summoner_name = "" then ContinueLoop

										$sPSCmd = """$oIE = (New-Object -ComObject 'Shell.Application').Windows() | Where-Object { $_.LocationName -like '*" & $summoner_name & "*' }; $control = $oIE.document.IHTMLDocument3_getElementsByTagName('button') | where-object { $_.className -eq 'css-4e9tnt eapd0am1' };$control.click()"""

										;Consolewrite("""$oIE = (New-Object -ComObject 'Shell.Application').Windows() | Where-Object { $_.LocationName -like '*" & $summoner_name & "*' }; $control = $oIE.document.IHTMLDocument3_getElementsByTagName('button') | where-object { $_.className -eq 'css-1wyd9qh ejbh9aw1' };$control.click()""" & @CRLF)

										RunWait(@comspec & ' /c powershell.exe -executionpolicy bypass -NoProfile -WindowStyle hidden -command ' & $sPSCmd, "", @SW_HIDE)

										sleep(100)

										if Winexists("[CLASS:#32770]","") Then

											WinClose("[CLASS:#32770]","")

											$sPSCmd = """$oIE = (New-Object -ComObject 'Shell.Application').Windows() | Where-Object { $_.LocationName -like '*" & $summoner_name & "*' }; $oIE.visible = $false"""

											RunWait(@comspec & ' /c powershell.exe -executionpolicy bypass -NoProfile -WindowStyle hidden -command ' & $sPSCmd, "", @SW_HIDE)

										EndIf

								Next

								settext($summoner8_gui, "Reloading pages after data update...")

								sleep(500)

								processclose("iexplore.exe")

								sleep(1000)

								for $i = 1 to 5 step 1

									$summoner_name = $enemy_players_name[$i]

									if $summoner_name = "" then ContinueLoop

									$encoded_summoner_name = StringReplace($summoner_name, " ", "%20")

									$enemy_oIE[$i] = _IECreate($opgg_page_url & $encoded_summoner_name, 0, 0, 0)

								Next

								settext($summoner8_gui, "Waiting for the pages to reload...")

								for $i = 1 to 5 step 1

										$summoner_name = $enemy_players_name[$i]

										if $summoner_name = "" then ContinueLoop

										_IELoadWait($enemy_oIE[$i])

								Next

								sleep(200)

								;gathering premade informations

								settext($summoner8_gui, 'Gathering enemies "recently played with" informations...')

								for $i = 1 to 5 step 1

									$summoner_name = $enemy_players_name[$i]

									if $summoner_name = "" then ContinueLoop

									$body = _IEDocReadHTML($enemy_oIE[$i]) ;reading the content of the page

									if @error <> 0 Then

										filewrite($error_log, "Impossible to read the source for " & $summoner_name & " (line 871)" & @CRLF)

									EndIf

									$string_search_start_position = Stringinstr($body, "css-ut2tyh e1rsywk30")

									$string_search_end_position = Stringinstr($body, "</table>", 0, 1, $string_search_start_position)

									$premade_data = stringmid($body, $string_search_start_position, $string_search_end_position - $string_search_start_position)

									;ConsoleWrite(@CRLF & $premade_data & @CRLF)

									;checking how many premade players there are in the player's page

									$premade_players_count = 0

									StringReplace($premade_data, "a href", "a href") ; little dev trick to count the number of players

									$premade_players_count = @extended

									;for each premade player in the player's page we get their name and check if it's a player in the current game

									if $premade_players_count <> 0 then

										for $j = 1 to $premade_players_count step 1


											$premade_name_position_start = StringInStr($premade_data, 'a href="/summoners/' & $opgg_summoners_ahref & '/', 0, $j) + 22 + $opgg_summoners_ahref_offset

											$premade_name_position_start = StringInStr($premade_data, ">", 0, 2, $premade_name_position_start) + 1

											$premade_name_position_end = StringInStr($premade_data, "<", 0, 1, $premade_name_position_start)

											$premade_player_name = StringMid($premade_data, $premade_name_position_start, $premade_name_position_end - $premade_name_position_start)

											;searching if the premade player name is one of the current player in the team

											for $k = 1 to 5 step 1

												if $premade_player_name = $enemy_players_name[$k] AND $premade_player_name <> $summoner_name AND stringinstr($enemy_premade_players_list, $premade_player_name) = 0 Then

												$premade_times_played_start = StringInStr($premade_data, "played", 0, 1, $premade_name_position_end) + 8

												$premade_times_played_end = StringInStr($premade_data, "<", 0, 1, $premade_times_played_start)

												$premade_times_played = StringMid($premade_data, $premade_times_played_start, $premade_times_played_end - $premade_times_played_start)

												;----------------------------

												$premade_winrate_percentage_start = StringInStr($premade_data, "winratio", 0, 1, $premade_times_played_end) + 10

												$premade_winrate_percentage_end = StringInStr($premade_data, "<", 0, 1, $premade_winrate_percentage_start)

												$premade_winrate_percentage = StringMid($premade_data, $premade_winrate_percentage_start, $premade_winrate_percentage_end - $premade_winrate_percentage_start)

												;ConsoleWrite($premade_winrate_percentage_start & @CRLF)

												;ConsoleWrite($premade_winrate_percentage_end & @CRLF)

											    ;ConsoleWrite($premade_winrate_percentage & @CRLF)

												$enemy_premade_players_list = $enemy_premade_players_list & $premade_player_name & " & " & $summoner_name & " (" & $premade_times_played & " - " & $premade_winrate_percentage & ") " & @CRLF

												settext($summoner9_gui, $enemy_premade_players_list)

												EndIf


											Next

										Next

									EndIf

									sleep(100)

								Next

								settext($summoner8_gui, "Closing the pages...")

								for $i = 1 to 5 step 1

									$summoner_name = $enemy_players_name[$i]

									if $summoner_name = "" then ContinueLoop

									_IEQuit($enemy_oIE[$i])

									sleep(100)

								Next

								settext($summoner6_gui, "Update done!" & @CRLF & @CRLF & "Check OP.GG summary page below for results")
								settext($summoner7_gui, $opgg_multisearch_url & $enemy_opggfullnamelist)

								if $enemy_premade_players_list = "Recently played with:" & @CRLF & @CRLF then settext($summoner9_gui, "No players recently played with others")

								settext($summoner8_gui, "Game has started, GL HF :)")


								if $disable_auto_page_opening = 0 then ShellExecute($opgg_multisearch_url & $enemy_opggfullnamelist)

								sleep(100)

								WinActivate("sstats")


								$enemy_stats_done = 1

							EndIf

					wend

				endif

	Endif ;fin

WEnd ;end of the app

;----------------------------------------------------------------------;

;below are custom functions called in the app source code

;--------------------------------------------------------------------------------------

func settext($gui, $text) ;used to format text properly in the app GUI

	_GUICtrlRichEdit_SetText($gui, $text)
	_GUICtrlRichEdit_SetSel($gui, 0, -1)
	_GUICtrlRichEdit_SetFont($gui, 10)
	_GUICtrlRichEdit_SetCharColor($gui, dec("FFFFFF"))
	_GUICtrlRichEdit_SetSel($gui, 0, 0)
	DllCall("user32.dll","int","HideCaret","int",0)

EndFunc


Func ExitApp() ;used by the GUI to close the app
	$sstats = WinGetPos("sstats")
	$enemyteam = Wingetpos("enemyteam")
	RegWrite("HKEY_CURRENT_USER\Software\sstats", "posx", "REG_DWORD", $sstats[0])
	RegWrite("HKEY_CURRENT_USER\Software\sstats", "posy", "REG_DWORD", $sstats[1])
	RegWrite("HKEY_CURRENT_USER\Software\sstats", "enemyposx", "REG_DWORD", $enemyteam[0])
	RegWrite("HKEY_CURRENT_USER\Software\sstats", "enemyposy", "REG_DWORD", $enemyteam[1])
    Exit
EndFunc   ;==>ExitScript

Func switch_auto_open()

if $disable_auto_page_opening = 0 then

	$disable_auto_page_opening = 1
	TrayItemSetText($option_tray, "Enable summary page auto opening")

Else

	$disable_auto_page_opening = 0
	TrayItemSetText($option_tray, "Disable summary page auto opening")

EndIf



EndFunc

;----------------------------------------------------------------------------------------

func guiclose() ;used by the GUI to close the app
	Exit
EndFunc
