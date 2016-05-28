#include <GuiListView.au3>
#include <GuiIPAddress.au3>
#include <Array.au3>
#include <File.au3>
#include <GuiStatusBar.au3>
#include <EditConstants.au3>
#include <Constants.au3>
#include <Misc.au3>

Global Const $title = "Proxy Checker"
Global Const $installDir = @ScriptDir ;make reg entry or env var after install
Global $timeout = IniRead($installDir&"\options.ini", "OPT", "Timeout", 250)
Global $refreshEnable = IniRead($installDir&"\options.ini", "OPT", "enableRefresh", 1)
Global $refreshTimer = IniRead($installDir&"\options.ini", "OPT", "refreshTimer", 5000)
Global $fontName = IniRead($installDir&"\options.ini", "OPT", "fontName", "Arial")
Global $fontSize = IniRead($installDir&"\options.ini", "OPT", "fontSize", 10)
Global $fontWeight = IniRead($installDir&"\options.ini", "OPT", "fontWeight", 0)
Global $ipListFileHwnd = FileOpen($installDir&"\ipList.cfg", 1)
Local $aParts[2] = [75, -1]

Opt("TCPTimeout", $timeout)
TCPStartup()
OnAutoItExitRegister("_exit")
If $refreshEnable Then
	AdlibRegister("_checkList", $refreshTimer)
EndIf

$hGUI = GUICreate($title, 400, 342)
$fileMenu = GUICtrlCreateMenu("File")
$saveMenuItem = GUICtrlCreateMenuItem("Save", $fileMenu)
$findMenuItem = GUICtrlCreateMenuItem("Find", $fileMenu)
$refreshMenuItem = GUICtrlCreateMenuItem("Refresh", $fileMenu)
$optionsMenuItem = GUICtrlCreateMenuItem("Options", $fileMenu)
$aboutMenuItem = GUICtrlCreateMenuItem("About", $fileMenu)
$g_hStatus = _GUICtrlStatusBar_Create($hGUI)
_GUICtrlStatusBar_SetParts($g_hStatus, $aParts)
_GUICtrlStatusBar_SetText($g_hStatus, "Loading...")
$list = GUICtrlCreateListView("Status", 0, 0, 400, 275, -1, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_AddColumn($list, "Address")
_GUICtrlListView_AddColumn($list, "Port")
_GUICtrlListView_AddColumn($list, "Ping")
_GUICtrlListView_SetColumnWidth($list, 0, 42)
_GUICtrlListView_SetColumnWidth($list, 1, 226)
_GUICtrlListView_SetColumnWidth($list, 2, 66)
_GUICtrlListView_SetColumnWidth($list, 3, 66)
$contextMenu = GUICtrlCreateContextMenu($list)
$conCopyIPMenuItem = GUICtrlCreateMenuItem("Copy Address", $contextMenu)
$conPropertiesMenuItem = GUICtrlCreateMenuItem("Properties", $contextMenu)
$addAddress = GUICtrlCreateButton("Add Address", 0, 275, 133, 25)
$delAddress = GUICtrlCreateButton("Delete Address", 133, 275, 133, 25)
$refresh = GUICtrlCreateButton("Refresh", 266, 275, 133, 25)
GUISetState()

FileSetPos($ipListFileHwnd, 0, 0)
For $i = 1 To _FileCountLines($installDir&"\ipList.cfg")
	$raw = FileReadLine($ipListFileHwnd)
	$delPos = StringInStr($raw, "|")
	$startupIP = StringLeft($raw, $delPos-1)
	$startupPort = StringRight($raw, StringLen($raw)-($delPos))
	$ping = Ping($startupIP, $timeout)
	$mainSocketID = TCPConnect($startupIP, $startupPort)
	If @error <> 0 Then
		$status = 0
	Else
		$status = 1
	EndIf
	TCPCloseSocket($mainSocketID)
	_GUICtrlListView_AddItem($list, $status)
	$1 = _GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $startupIP, 1)
	$2 = _GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $startupPort, 2)
	$3 = _GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $ping, 3)
Next
_GUICtrlStatusBar_SetText($g_hStatus, "Idle")
While 1
	Switch GUIGetMsg()
		Case -3
			_exit()
		Case $addAddress
			$aNewAddress = _newAddress()
			If $aNewAddress <> 0 Then
				$ping = Ping($aNewAddress[1], $timeout)
				$mainSocketID = TCPConnect($aNewAddress[1], $aNewAddress[0])
				If @error <> 0 Then
					$status = 0
				Else
					$status = 1
				EndIf
				TCPCloseSocket($mainSocketID)
				_GUICtrlListView_AddItem($list, $status)
				_GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $aNewAddress[1], 1)
				_GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $aNewAddress[0], 2)
				_GUICtrlListView_AddSubItem($list, _GUICtrlListView_GetItemCount($list)-1, $ping, 3)
			EndIf
		Case $delAddress
			_GUICtrlListView_DeleteItemsSelected($list)
		Case $refresh
			_checkList()
		Case $refreshMenuItem
			_checkList()
		Case $saveMenuItem
			_saveToList(1)
		Case $optionsMenuItem
			_optionsGUI()
		Case $findMenuItem
			_GUICtrlStatusBar_SetText($g_hStatus, "Searching...")
			$findString = InputBox($title, "Enter the Text you want to search for")
			_GUICtrlListView_SetItemSelected($list, _GUICtrlListView_FindInText($list, $findString), True, True)
			_GUICtrlStatusBar_SetText($g_hStatus, "Idle")
		Case $aboutMenuItem
			MsgBox(64, $title, "Author: Zay"&@CRLF&@CRLF&"And that's pretty much it")
		Case $conCopyIPMenuItem
			ClipPut(__getIP())
			MsgBox(64, $title, "Copied to clipboard")
		Case $conPropertiesMenuItem
			_propertiesGUI()
	EndSwitch
WEnd

Func _optionsGUI()
	Local $isSaved = False
	Local $aFont[8]
	$optGUI = GUICreate($title&"- Options", 285, 262, -1, -1, -1, -1, $hGUI)
	$timeoutDcLabel = GUICtrlCreateLabel("Timeout", 36, 16, 42, 17)
	$timeoutInput = GUICtrlCreateInput($timeout, 36, 40, 121, 21)
	$enableRefreshCheck = GUICtrlCreateCheckbox("automatic Refresh", 36, 80, 113, 17)
	$refreshTimerInput = GUICtrlCreateInput($refreshTimer, 52, 104, 121, 21)
	$chooseFontButton = GUICtrlCreateButton("Font", 33, 168, 75, 25)
	$optSaveButton = GUICtrlCreateButton("Save", 65, 208, 75, 25)
	$optCancelButton = GUICtrlCreateButton("Cancel", 145, 208, 75, 25)
	$testInetConnButton = GUICtrlCreateButton("Test Internet Connection", 121, 168, 131, 25)
	If $refreshEnable Then
		GUICtrlSetState($enableRefreshCheck, 1)
	Else
		GUICtrlSetState($enableRefreshCheck, 4)
	EndIf
	GUISetState()

	While 1
		Switch GUIGetMsg()
			Case -3
				ExitLoop
			Case $chooseFontButton
				$aFont = _ChooseFont($fontName, $fontSize, 0, $fontWeight, False, False, False, $optGUI)
			Case $testInetConnButton
				If _IsInternetConnected() Then
					MsgBox(0, $title, "Able to connect to the internet")
				Else
					MsgBox(0, $title, "Unable to connect to the internet")
				EndIf
			Case $optCancelButton
				GUIDelete($optGUI)
				GUISetState(@SW_ENABLE, $hGUI)
				Return 0
			Case $optSaveButton
				$timeout = IniWrite($installDir&"\options.ini", "OPT", "Timeout", GUICtrlRead($timeoutInput))
				$refreshTimer = IniWrite($installDir&"\options.ini", "OPT", "refreshTimer", GUICtrlRead($refreshTimerInput))
				If GUICtrlRead($enableRefreshCheck) Then
					$refreshEnable = IniWrite($installDir&"\options.ini", "OPT", "enableRefresh", 1)
				Else
					$refreshEnable = IniWrite($installDir&"\options.ini", "OPT", "enableRefresh", 0)
				EndIf
				$fontName = IniWrite($installDir&"\options.ini", "OPT", "fontName", $aFont[2])
				$fontSize = IniWrite($installDir&"\options.ini", "OPT", "fontSize", $aFont[3])
				$fontWeight = IniWrite($installDir&"\options.ini", "OPT", "fontWeight", $aFont[4])
				GUIDelete($optGUI)
				GUISetState(@SW_ENABLE, $hGUI)
				Return 0
		EndSwitch
	WEnd
	If $isSaved Then
		GUIDelete($optGUI)
		GUISetState(@SW_ENABLE, $hGUI)
		Return 0
	Else
		$yesno = MsgBox(4+32, $title, "Save changes?")
		If $yesno = 6 Then
			$timeout = IniWrite($installDir&"\options.ini", "OPT", "Timeout", GUICtrlRead($timeoutInput))
			$refreshTimer = IniWrite($installDir&"\options.ini", "OPT", "refreshTimer", GUICtrlRead($refreshTimerInput))
			If GUICtrlRead($enableRefreshCheck) Then
				$refreshEnable = IniWrite($installDir&"\options.ini", "OPT", "enableRefresh", 1)
			Else
				$refreshEnable = IniWrite($installDir&"\options.ini", "OPT", "enableRefresh", 0)
			EndIf
			$fontName = IniWrite($installDir&"\options.ini", "OPT", "fontName", $aFont[2])
			$fontSize = IniWrite($installDir&"\options.ini", "OPT", "fontSize", $aFont[3])
			$fontWeight = IniWrite($installDir&"\options.ini", "OPT", "fontWeight", $aFont[4])
			GUIDelete($optGUI)
			GUISetState(@SW_ENABLE, $hGUI)
			Return 0
		Else
			GUIDelete($optGUI)
			GUISetState(@SW_ENABLE, $hGUI)
			Return 0
		EndIf
	EndIf
EndFunc

Func _propertiesGUI()
	Local $ipv6, $traceroute, $geoData
	Local $ipv4 = __getIP()
	Local $port = __getPort()
	$ipv6 = __toIPv6($ipv4)
	$propertiesGUI = GUICreate("title Properties", 385, 280, -1, -1, -1, -1, $hGUI)
	$ipv4DcLabel = GUICtrlCreateLabel("IPv4 Address", 37, 16, 67, 17)
	$ipv4Label = GUICtrlCreateLabel($ipv4, 269, 16, 73, 17)
	$portDcLabel = GUICtrlCreateLabel("Port", 37, 80, 23, 17)
	$portLabel = GUICtrlCreateLabel($port, 309, 80, 34, 17)
	$ipv6DcLabel = GUICtrlCreateLabel("IPv6 Address", 37, 48, 67, 17)
	$ipv6Label = GUICtrlCreateLabel($ipv6, 229, 48, 115, 17)
	$tracerouteLabel = GUICtrlCreateLabel("Traceroute", 164, 112, 56, 17)
	$tracerouteEdit = GUICtrlCreateEdit("loading...", 37, 144, 313, 105, $ES_READONLY);auto scroll
	GUISetState()
	$DOS = Run(@ComSpec & " /c tracert "&$ipv4, "", @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD)
	$traceroute = StdoutRead($DOS)
	GUICtrlSetData($tracerouteEdit, $traceroute)
	While 1
		Switch GUIGetMsg()
			Case -3
				ExitLoop
		EndSwitch
	WEnd
	GUIDelete($propertiesGUI)
	GUISetState(@SW_ENABLE, $hGUI)
	Return 0
EndFunc

Func _newAddress()
	Local $return[2]
	GUISetState(@SW_DISABLE, $hGUI)
	$newAddressGUI = GUICreate("New Address", 265, 170, -1, -1, -1, -1, $hGUI)
	$ipAddressInput = _GUICtrlIpAddress_Create($newAddressGUI, 36, 40, 130, 21)
	$portInput = GUICtrlCreateInput("", 36, 96, 41, 21)
	$ipAddressLabel = GUICtrlCreateLabel("IP Address", 36, 16, 55, 17)
	$portLabel = GUICtrlCreateLabel("Port", 36, 72, 23, 17)
	$saveButton = GUICtrlCreateButton("Save", 144, 128, 75, 25, 0x0300)
	$testButton = GUICtrlCreateButton("Test", 65, 128, 75, 25)
	GUISetState()

	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case -3
				GUISetState(@SW_ENABLE, $hGUI)
				GUIDelete($newAddressGUI)
				Return 0
			Case $testButton
				GUICtrlSetState($testButton, 128)
				GUICtrlSetState($saveButton, 128)
				If _GUICtrlIpAddress_IsBlank($ipAddressInput) Or GUICtrlRead($portInput) = "" Then
					MsgBox(16, $title, "You need to fill in every field")
				Else
					$port = GUICtrlRead($portInput)
					$ipAddress = _toIntIp(_GUICtrlIpAddress_GetEx($ipAddressInput))
				EndIf
				$testPing = Ping($ipAddress, $timeout)
				If Not $testPing = 0 Then
					MsgBox(64, $title, "Status ok")
				Else
					If @error = 1 Then
						MsgBox(16, $title, "Host is offline")
					ElseIf @error = 2 Then
						MsgBox(16, $title, "Can't reach Host")
					ElseIf @error = 3 Then
						MsgBox(16, $title, "Bad destination")
					Else
						MsgBox(16, $title, "Unknown Error"&@CRLF&"Error Code: "&@error)
					EndIf
				EndIf
				GUICtrlSetState($testButton, 64)
				GUICtrlSetState($saveButton, 64)
			Case $saveButton
				GUICtrlSetState($testButton, 128)
				GUICtrlSetState($saveButton, 128)
				If _GUICtrlIpAddress_IsBlank($ipAddressInput) Or GUICtrlRead($portInput) = "" Then
					MsgBox(16, $title, "You need to fill in every field")
				Else
					$return[0] = GUICtrlRead($portInput)
					$return[1] = _toIntIp(_GUICtrlIpAddress_GetEx($ipAddressInput));Status|Address|Port|Ping
					GUISetState(@SW_ENABLE, $hGUI)
					GUIDelete($newAddressGUI)
					Return $return
				EndIf
		EndSwitch
	WEnd
EndFunc

Func __realoadOptions()
	$timeout = IniRead($installDir&"\options.ini", "OPT", "Timeout", 250)
	$refreshEnable = IniRead($installDir&"\options.ini", "OPT", "enableRefresh", 1)
	$refreshTimer = IniRead($installDir&"\options.ini", "OPT", "refreshTimer", 5000)
	$trayTipEnable = IniRead($installDir&"\options.ini", "OPT", "enableTrayTips", 1)
	$fontName = IniRead($installDir&"\options.ini", "OPT", "fontName", "Arial")
	$fontSize = IniRead($installDir&"\options.ini", "OPT", "fontSize", 10)
	$fontWeight = IniRead($installDir&"\options.ini", "OPT", "fontWeight", 0)
EndFunc

Func __getIP()
	$everything = StringTrimLeft(_GUICtrlListView_GetItemTextString($list), 2)
	$pingDelPos = StringInStr($everything, "|", 0, -1)
	$portAndIp = StringTrimRight($everything, StringLen($everything)-$pingDelPos+1)
	$ip = StringTrimRight($portAndIp, StringLen($portAndIp)-StringInStr($portAndIp, "|", 0, -1)+1)
	Return $ip
EndFunc

Func __getPort()
	$everything = StringTrimLeft(_GUICtrlListView_GetItemTextString($list), 2)
	$pingDelPos = StringInStr($everything, "|", 0, -1)
	$portAndIp = StringTrimRight($everything, StringLen($everything)-$pingDelPos+1)
	$port = StringTrimLeft($portAndIp, StringInStr($portAndIp, "|"))
	Return $port
EndFunc

Func __toIPv6($ipParam)
	Local $aSplit[4]
	$aSplit = StringSplit($ipParam, ".", 2)
	$v6 = ""
	For $i = 0 To UBound($aSplit)-1
		If $i = 2 Then
			$v6 &= ":"
		EndIf
		$v6 &= Hex($aSplit[$i], 2)
	Next
	Return "0:0:0:0:0:ffff:"&$v6
EndFunc

Func _toIntIp($tagIP)
	Local $1, $2, $3, $4
	$1 = DllStructGetData($tagIP, 1)
	$2 = DllStructGetData($tagIP, 2)
	$3 = DllStructGetData($tagIP, 3)
	$4 = DllStructGetData($tagIP, 4)
	Return $4&"."&$3&"."&$2&"."&$1
EndFunc

Func _checkList()
	_GUICtrlStatusBar_SetText($g_hStatus, "Refreshing...")
	Local $ip, $port, $i, $mainSID, $clStatus, $clPing
	For $i = 0 To _GUICtrlListView_GetItemCount($list)-1
		$ip = _GUICtrlListView_GetItemText($list, $i, 1)
		$port = _GUICtrlListView_GetItemText($list, $i, 2)
		$clPing = Ping($ip, $timeout)
		$mainSID = TCPConnect($ip, $port)
		If @error <> 0 Then
			$clStatus = 0
		Else
			$clStatus = 1
		EndIf
		TCPCloseSocket($mainSID)
		_GUICtrlListView_SetItem($list, $clStatus, $i)
		_GUICtrlListView_SetItem($list, $clPing, $i, 3)
		_GUICtrlStatusBar_SetText($g_hStatus, "Idle")
	Next
	Return 0
EndFunc

Func _saveToList($showMsg = 0)
	_GUICtrlStatusBar_SetText($g_hStatus, "Saving...")
	$itemCount = _GUICtrlListView_GetItemCount($list)-1
	If $itemCount <> -1 Then
		FileClose($ipListFileHwnd)
		$ipListFileHwnd = FileOpen($installDir&"\ipList.cfg", 2)
		For $i = 0 To $itemCount
			$ip = _GUICtrlListView_GetItemText($list, $i, 1)
			$port = _GUICtrlListView_GetItemText($list, $i, 2)
			FileWriteLine($ipListFileHwnd, $ip&"|"&$port)
		Next
	EndIf
	If $showMsg = 1 Then
		MsgBox(64, $title, "List has been saved.")
	EndIf
	_GUICtrlStatusBar_SetText($g_hStatus, "Idle")
	Return 0
EndFunc

;by Chimaera
Func _IsInternetConnected()
    Local $aReturn = DllCall('connect.dll', 'long', 'IsInternetConnected')
    If @error Then
        Return SetError(1, 0, False)
    EndIf
    Return $aReturn[0] = 0
EndFunc ;==>_IsInternetConnected

Func _exit()
	TCPShutdown()
	_saveToList()
	FileClose($ipListFileHwnd)
	Exit
EndFunc















