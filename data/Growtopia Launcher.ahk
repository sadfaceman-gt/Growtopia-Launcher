; ---------------------------------------------------------------- ;
;    ________                       __                .__          ;
;   /  _____/______  ______  _  ___/  |_  ____ ______ |__|____     ;
;  /   \  __\_  __ \/  _ \ \/ \/ /\   __\/  _ \\____ \|  \__  \    ;
;  \    \_\  \  | \(  <_> )     /  |  | (  <_> )  |_> >  |/ __ \_  ;
;   \______  /__|   \____/ \/\_/   |__|  \____/|   __/|__(____  /  ;
;          \/                                  |__|           \/   ;
;    .____                               .__                       ;
;    |    |   _____   __ __  ____   ____ |  |__   ___________      ;
;    |    |   \__  \ |  |  \/    \_/ ___\|  |  \_/ __ \_  __ \     ;
;    |    |___ / __ \|  |  /   |  \  \___|   Y  \  ___/|  | \/     ;
;    |_______ (____  /____/|___|  /\___  >___|  /\___  >__|        ;
;            \/    \/           \/     \/     \/     \/            ;
;                                                                  ;
Global                     Version := 1.5                          ;
; ---------------------------------------------------------------- ;

; -------------------- Initialization -------------------- ;
SendMode "Input"
SetWorkingDir A_ScriptDir
#SingleInstance Force
DetectHiddenWindows True
OnError LogError

Global EmbedURL := ["file://" . StrReplace(StrReplace(A_WorkingDir, " ", "%20"), "\", "/") . "/Launcher/Page/twitter.html",
					"https://www.growtopiagame.com/forums/forum/general/announcements",
					"https://www.instagram.com/growtopia?theme=dark",
					"https://www.youtube.com/c/growtopiaofficial",
					"file://" . StrReplace(StrReplace(A_WorkingDir, " ", "%20"), "\", "/") . "/Launcher/Page/default.html"]
Global LauncherVersion := Format("{:0.1f}", Version)
Global GTVersion := Format("{:0.2f}", 0.00)
Global SettingsCount := 5
Global SettingsList := Array()
Global GameButtonMode := "Launch"
Global GameButtonState := "Off"
Global SelFile := "0_default"
SettingsList.Length := SettingsCount
Global DLInterrupt := False
Global DLProgress := False
Global COLLAPSE_THIS := True
Global OnlineUser := -2
Global OnlineUserOutdated := False
Global LauncherWorking := False

; -------------------- Pre-loaded libraries -------------------- ;
If COLLAPSE_THIS Or True {
	; -------------------- WebView2 version 1.0.1072.54 -------------------- ;
	; 							thqby - 2022/11/26							 ;
	class WebView2 extends WebView2.Base {
		static create(hwnd, callback := unset, createdEnvironment := 0, datadir := '', edgeruntime := '', options := 0, dllPath := 'WebView2Loader.dll') {
			Controller := WebView2.Controller()
			ControllerCompletedHandler := WebView2.Handler(ControllerCompleted_Invoke)
			if (createdEnvironment)
				ComCall(3, createdEnvironment, 'ptr', hwnd, 'ptr', ControllerCompletedHandler)	; ICoreWebView2Environment::CreateCoreWebView2Controller Method.
			else {
				dllPath := A_WorkingDir . "\Launcher\Bin\" . (A_PtrSize * 8) . "bit\WebView2Loader.dll"
				if (!edgeruntime) {
					ver := '0.0.0.0'
					loop files 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application\*', 'D'
						if RegExMatch(A_LoopFilePath, '\\([\d.]+)$', &m) && VerCompare(m[1], ver) > 0
							edgeruntime := A_LoopFileFullPath, ver := m[1]
				}
				EnvironmentCompletedHandler := WebView2.Handler(EnvironmentCompleted_Invoke)
				if options {
					if !options.HasProp('TargetCompatibleBrowserVersion')
						options.TargetCompatibleBrowserVersion := ver
					options := WebView2.EnvironmentOptions(options)
				}
				if (R := DllCall(dllPath '\CreateCoreWebView2EnvironmentWithOptions', 'str', edgeruntime,
					'str', datadir || RegExReplace(A_AppData, 'Roaming$', 'Local\Microsoft\Edge\User Data'), 'ptr', options,
					'ptr', EnvironmentCompletedHandler, 'uint')) {
					ControllerCompletedHandler := EnvironmentCompletedHandler := 0
					throw OSError(R)
				}
			}
			if (!IsSet(callback))
				while (!Controller.ptr)
					Sleep(-1)
			return Controller

			EnvironmentCompleted_Invoke(com_this, hresult, createdEnvironment) {
				ComCall(3, createdEnvironment, 'ptr', hwnd, 'ptr', ControllerCompletedHandler)
				EnvironmentCompletedHandler := 0
				return 0
			}
			ControllerCompleted_Invoke(com_this, hresult, createdController) {
				DllCall('user32\GetClientRect', 'ptr', hwnd, 'ptr', RECT := Buffer(16)), ObjAddRef(createdController)
				Controller.ptr := createdController, Controller.Bounds := RECT
				if (IsSet(callback))
					try callback(Controller)
				ControllerCompletedHandler := 0
				return 0
			}
		}

		static AHKObjHelper() {
			return { get: get, set: set, call: call }

			get(this, prop, params := unset) {
				if !IsSet(params) {
					if (this is Array && prop is Integer) || (this is Map)
						return this[prop]
					params := []
				}
				return this.%prop%[params*]
			}
			set(this, prop, value, params := unset) {
				if !IsSet(params) {
					if (this is Array && prop is Integer) || (this is Map)
						return this[prop] := value
					params := []
				}
				return this.%prop%[params*] := value
			}
			call(this, method, params*) => this.%method%(params*)
		}

		; Interfaces Base class
		class Base {
			ptr := 0
			__New(ptr := unset, addref := true) {
				if IsSet(ptr) {
					this.ptr := ptr
					if (addref)
						ObjAddRef(ptr)
				}
			}
			__Delete() {
				if (this.ptr)
					this.Release()
			}
			__Call(Name, Params) {
				if (HasMethod(this, 'add_' Name)) {
					if (!IsInteger(handler := Params[1]) && !(handler is WebView2.Handler))
						handler := WebView2.Handler(Params*)
					token := this.add_%Name%(handler)
					return { ptr: this.ptr, handler: handler, __Delete: this.remove_%Name%.Bind(, token) }
				} else
					throw Error('This value of type "' this.__Class '" has no method named "' Name '".', -1)
			}
			AddRef() => ObjAddRef(this.ptr)
			Release() => ObjRelease(this.ptr)
		}

		;#region WebView2 Interfaces
		class AcceleratorKeyPressedEventArgs extends WebView2.Base {
			static IID := '{9f760f8a-fb79-42be-9990-7b56900fa9c7}'
			KeyEventKind => (ComCall(3, this, 'int*', &keyEventKind := 0), keyEventKind)	; COREWEBVIEW2_KEY_EVENT_KIND
			VirtualKey => (ComCall(4, this, 'uint*', &virtualKey := 0), virtualKey)
			KeyEventLParam => (ComCall(5, this, 'int*', &lParam := 0), lParam)
			PhysicalKeyStatus => (ComCall(6, this, 'int*', &physicalKeyStatus := 0), physicalKeyStatus)	; COREWEBVIEW2_PHYSICAL_KEY_STATUS
			Handled {
				get => (ComCall(7, this, 'int*', &handled := 0), handled)
				set => ComCall(8, this, 'int', Value)
			}
		}
		class BrowserProcessExitedEventArgs extends WebView2.Base {
			static IID := '{1f00663f-af8c-4782-9cdd-dd01c52e34cb}'
			BrowserProcessExitKind => (ComCall(3, this, 'int*', &browserProcessExitKind := 0), browserProcessExitKind)	; COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND
			BrowserProcessId => (ComCall(4, this, 'uint*', &value := 0), value)
		}
		class CompositionController extends WebView2.Base {
			static IID := '{3df9b733-b9ae-4a15-86b4-eb9ee9826469}'
			RootVisualTarget {
				get => (ComCall(3, this, 'ptr*', &target := 0), ComValue(0xd, target))
				set => ComCall(4, this, 'ptr', Value)
			}
			SendMouseInput(eventKind, virtualKeys, mouseData, point) => ComCall(5, this, 'int', eventKind, 'int', virtualKeys, 'uint', mouseData, 'int64', point)
			SendPointerInput(eventKind, pointerInfo) => ComCall(6, this, 'int', eventKind, 'ptr', pointerInfo)	; ICoreWebView2PointerInfo
			Cursor => (ComCall(7, this, 'ptr*', &cursor := 0), cursor)
			SystemCursorId => (ComCall(8, this, 'uint*', &systemCursorId := 0), systemCursorId)
			add_CursorChanged(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2CursorChangedEventHandler
			remove_CursorChanged(token) => ComCall(10, this, 'int64', token)

			static IID_2 := '{0b6a3d24-49cb-4806-ba20-b5e0734a7b26}'
			UIAProvider => (ComCall(11, this, 'ptr*', &provider := 0), ComValue(0xd, provider))
		}
		class Controller extends WebView2.Base {
			static IID := '{4d00c0d1-9434-4eb6-8078-8697a560334f}'
			__Delete() {
				if (this.ptr)
					this.Close(), super.__Delete()
			}
			Fill() {
				if !this.ptr
					return
				DllCall('user32\GetClientRect', 'ptr', this.ParentWindow, 'ptr', RECT := Buffer(16))
				this.Bounds := RECT
			}
			IsVisible {
				get => (ComCall(3, this, 'int*', &isVisible := 0), isVisible)
				set => ComCall(4, this, 'int', Value)
			}
			Bounds {
				get => (ComCall(5, this, 'ptr', bounds := Buffer(16)), bounds)
				set => A_PtrSize = 8 ? ComCall(6, this, 'ptr', Value) : ComCall(6, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64'))
			}
			ZoomFactor {
				get => (ComCall(7, this, 'double*', &zoomFactor := 0), zoomFactor)
				set => ComCall(8, this, 'double', Value)
			}
			add_ZoomFactorChanged(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ZoomFactorChangedEventHandler
			remove_ZoomFactorChanged(token) => ComCall(10, this, 'int64', token)
			SetBoundsAndZoomFactor(bounds, zoomFactor) => (A_PtrSize = 8 ? ComCall(11, this, 'ptr', bounds, 'double', zoomFactor) : ComCall(11, this, 'int64', NumGet(bounds, 'int64'), 'int64', NumGet(bounds, 8, 'int64'), 'double', zoomFactor))
			MoveFocus(reason) => ComCall(12, this, 'int', reason)
			add_MoveFocusRequested(eventHandler) => (ComCall(13, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2MoveFocusRequestedEventHandler
			remove_MoveFocusRequested(token) => ComCall(14, this, 'int64', token)
			add_GotFocus(eventHandler) => (ComCall(15, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2FocusChangedEventHandler
			remove_GotFocus(token) => ComCall(16, this, 'int64', token)
			add_LostFocus(eventHandler) => (ComCall(17, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2FocusChangedEventHandler
			remove_LostFocus(token) => ComCall(18, this, 'int64', token)
			add_AcceleratorKeyPressed(eventHandler) => (ComCall(19, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2AcceleratorKeyPressedEventHandler
			remove_AcceleratorKeyPressed(token) => ComCall(20, this, 'int64', token)
			ParentWindow {
				get => (ComCall(21, this, 'ptr*', &parentWindow := 0), parentWindow)
				set => ComCall(22, this, 'ptr', Value)
			}
			NotifyParentWindowPositionChanged() => ComCall(23, this)
			Close() => ComCall(24, this)
			CoreWebView2 => (ComCall(25, this, 'ptr*', coreWebView2 := WebView2.Core()), coreWebView2)

			static IID_2 := '{c979903e-d4ca-4228-92eb-47ee3fa96eab}'
			DefaultBackgroundColor {
				get => (ComCall(26, this, 'int*', &backgroundColor := 0), backgroundColor)	; COREWEBVIEW2_COLOR
				set => ComCall(27, this, 'int', Value)
			}

			static IID_3 := '{f9614724-5d2b-41dc-aef7-73d62b51543b}'
			RasterizationScale {
				get => (ComCall(28, this, 'double*', &scale := 0), scale)
				set => ComCall(29, this, 'double', Value)
			}
			ShouldDetectMonitorScaleChanges {
				get => (ComCall(30, this, 'int*', &value := 0), value)
				set => ComCall(31, this, 'int', Value)
			}
			add_RasterizationScaleChanged(eventHandler) => (ComCall(32, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2RasterizationScaleChangedEventHandler
			remove_RasterizationScaleChanged(token) => ComCall(33, this, 'int64', token)
			BoundsMode {
				get => (ComCall(34, this, 'int*', &boundsMode := 0), boundsMode)	; COREWEBVIEW2_BOUNDS_MODE
				set => ComCall(35, this, 'int', Value)
			}
		}
		class ContentLoadingEventArgs extends WebView2.Base {
			static IID := '{0c8a1275-9b6b-4901-87ad-70df25bafa6e}'
			IsErrorPage => (ComCall(3, this, 'int*', &isErrorPage := 0), isErrorPage)
			NavigationId => (ComCall(4, this, 'int64*', &navigationId := 0), navigationId)
		}
		class Cookie extends WebView2.Base {
			static IID := '{AD26D6BE-1486-43E6-BF87-A2034006CA21}'
			Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
			Value {
				get => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
				set => ComCall(5, this, 'wstr', Value)
			}
			Domain => (ComCall(6, this, 'ptr*', &domain := 0), CoTaskMem_String(domain))
			Path => (ComCall(7, this, 'ptr*', &path := 0), CoTaskMem_String(path))
			Expires {
				get => (ComCall(8, this, 'double*', &expires := 0), expires)
				set => ComCall(9, this, 'double', Value)
			}
			IsHttpOnly {
				get => (ComCall(10, this, 'int*', &isHttpOnly := 0), isHttpOnly)
				set => ComCall(11, this, 'int', Value)
			}
			SameSite {
				get => (ComCall(12, this, 'int*', &sameSite := 0), sameSite)	; COREWEBVIEW2_COOKIE_SAME_SITE_KIND
				set => ComCall(13, this, 'int', Value)
			}
			IsSecure {
				get => (ComCall(14, this, 'int*', &isSecure := 0), isSecure)
				set => ComCall(15, this, 'int', Value)
			}
			IsSession => (ComCall(16, this, 'int*', &isSession := 0), isSession)
		}
		class CookieList extends WebView2.Base {
			static IID := '{F7F6F714-5D2A-43C6-9503-346ECE02D186}'
			Count => (ComCall(3, this, 'uint*', &count := 0), count)
			GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', cookie := WebView2.Cookie()), cookie)
		}
		class CookieManager extends WebView2.Base {
			static IID := '{177CD9E7-B6F5-451A-94A0-5D7A3A4C4141}'
			CreateCookie(name, value, domain, path) => (ComCall(3, this, 'wstr', name, 'wstr', value, 'wstr', domain, 'wstr', path, 'ptr*', cookie := WebView2.Cookie()), cookie)
			CopyCookie(cookieParam) => (ComCall(4, this, 'ptr', cookieParam, 'ptr*', cookie := WebView2.Cookie()), cookie)	; ICoreWebView2Cookie
			GetCookies(uri, handler) => ComCall(5, this, 'wstr', uri, 'ptr', handler)	; ICoreWebView2GetCookiesCompletedHandler
			AddOrUpdateCookie(cookie) => ComCall(6, this, 'ptr', cookie)	; ICoreWebView2Cookie
			DeleteCookie(cookie) => ComCall(7, this, 'ptr', cookie)	; ICoreWebView2Cookie
			DeleteCookies(name, uri) => ComCall(8, this, 'wstr', name, 'wstr', uri)
			DeleteCookiesWithDomainAndPath(name, domain, path) => ComCall(9, this, 'wstr', name, 'wstr', domain, 'wstr', path)
			DeleteAllCookies() => ComCall(10, this)
		}
		class Core extends WebView2.Base {
			static IID := '{76eceacb-0462-4d94-ac83-423a6793775e}'
			AddAHKObjHelper() => this.AddHostObjectToScript('AHKObjHelper', WebView2.AHKObjHelper())
			Settings => (ComCall(3, this, 'ptr*', settings := WebView2.Settings()), settings)
			Source => (ComCall(4, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			Navigate(uri) => ComCall(5, this, 'wstr', uri)
			NavigateToString(htmlContent) => ComCall(6, this, 'wstr', htmlContent)
			add_NavigationStarting(eventHandler) => (ComCall(7, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NavigationStartingEventHandler
			remove_NavigationStarting(token) => ComCall(8, this, 'int64', token)
			add_ContentLoading(eventHandler) => (ComCall(9, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ContentLoadingEventHandler
			remove_ContentLoading(token) => ComCall(10, this, 'int64', token)
			add_SourceChanged(eventHandler) => (ComCall(11, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2SourceChangedEventHandler
			remove_SourceChanged(token) => ComCall(12, this, 'int64', token)
			add_HistoryChanged(eventHandler) => (ComCall(13, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2HistoryChangedEventHandler
			remove_HistoryChanged(token) => ComCall(14, this, 'int64', token)
			add_NavigationCompleted(eventHandler) => (ComCall(15, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NavigationCompletedEventHandler
			remove_NavigationCompleted(token) => ComCall(16, this, 'int64', token)
			add_FrameNavigationStarting(eventHandler) => (ComCall(17, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NavigationStartingEventHandler
			remove_FrameNavigationStarting(token) => ComCall(18, this, 'int64', token)
			add_FrameNavigationCompleted(eventHandler) => (ComCall(19, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NavigationCompletedEventHandler
			remove_FrameNavigationCompleted(token) => ComCall(20, this, 'int64', token)
			add_ScriptDialogOpening(eventHandler) => (ComCall(21, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ScriptDialogOpeningEventHandler
			remove_ScriptDialogOpening(token) => ComCall(22, this, 'int64', token)
			add_PermissionRequested(eventHandler) => (ComCall(23, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2PermissionRequestedEventHandler
			remove_PermissionRequested(token) => ComCall(24, this, 'int64', token)
			add_ProcessFailed(eventHandler) => (ComCall(25, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ProcessFailedEventHandler
			remove_ProcessFailed(token) => ComCall(26, this, 'int64', token)
			AddScriptToExecuteOnDocumentCreated(javaScript, handler) => ComCall(27, this, 'wstr', javaScript, 'ptr', handler)	; ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler
			RemoveScriptToExecuteOnDocumentCreated(id) => ComCall(28, this, 'wstr', id)
			ExecuteScript(javaScript, handler) => ComCall(29, this, 'wstr', javaScript, 'ptr', handler)	; ICoreWebView2ExecuteScriptCompletedHandler
			CapturePreview(imageFormat, imageStream, handler) => ComCall(30, this, 'int', imageFormat, 'ptr', imageStream, 'ptr', handler)	; ICoreWebView2CapturePreviewCompletedHandler
			Reload() => ComCall(31, this)
			PostWebMessageAsJson(webMessageAsJson) => ComCall(32, this, 'wstr', webMessageAsJson)
			PostWebMessageAsString(webMessageAsString) => ComCall(33, this, 'wstr', webMessageAsString)
			add_WebMessageReceived(handler) => (ComCall(34, this, 'ptr', handler, 'int64*', &token := 0), token)	; ICoreWebView2WebMessageReceivedEventHandler
			remove_WebMessageReceived(token) => ComCall(35, this, 'int64', token)
			CallDevToolsProtocolMethod(methodName, parametersAsJson, handler) => ComCall(36, this, 'wstr', methodName, 'wstr', parametersAsJson, 'ptr', handler)	; ICoreWebView2CallDevToolsProtocolMethodCompletedHandler
			BrowserProcessId => (ComCall(37, this, 'uint*', &value := 0), value)
			CanGoBack => (ComCall(38, this, 'int*', &canGoBack := 0), canGoBack)
			CanGoForward => (ComCall(39, this, 'int*', &canGoForward := 0), canGoForward)
			GoBack() => ComCall(40, this)
			GoForward() => ComCall(41, this)
			GetDevToolsProtocolEventReceiver(eventName) => (ComCall(42, this, 'wstr', eventName, 'ptr*', receiver := WebView2.DevToolsProtocolEventReceiver()), receiver)
			Stop() => ComCall(43, this)
			add_NewWindowRequested(eventHandler) => (ComCall(44, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NewWindowRequestedEventHandler
			remove_NewWindowRequested(token) => ComCall(45, this, 'int64', token)
			add_DocumentTitleChanged(eventHandler) => (ComCall(46, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2DocumentTitleChangedEventHandler
			remove_DocumentTitleChanged(token) => ComCall(47, this, 'int64', token)
			DocumentTitle => (ComCall(48, this, 'ptr*', &title := 0), CoTaskMem_String(title))
			AddHostObjectToScript(name, object) => ComCall(49, this, 'wstr', name, 'ptr', ComVar(object))
			RemoveHostObjectFromScript(name) => ComCall(50, this, 'wstr', name)
			OpenDevToolsWindow() => ComCall(51, this)
			add_ContainsFullScreenElementChanged(eventHandler) => (ComCall(52, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ContainsFullScreenElementChangedEventHandler
			remove_ContainsFullScreenElementChanged(token) => ComCall(53, this, 'int64', token)
			ContainsFullScreenElement => (ComCall(54, this, 'int*', &containsFullScreenElement := 0), containsFullScreenElement)
			add_WebResourceRequested(eventHandler) => (ComCall(55, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2WebResourceRequestedEventHandler
			remove_WebResourceRequested(token) => ComCall(56, this, 'int64', token)
			AddWebResourceRequestedFilter(uri, resourceContext) => ComCall(57, this, 'wstr', uri, 'int', resourceContext)
			RemoveWebResourceRequestedFilter(uri, resourceContext) => ComCall(58, this, 'wstr', uri, 'int', resourceContext)
			add_WindowCloseRequested(eventHandler) => (ComCall(59, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2WindowCloseRequestedEventHandler
			remove_WindowCloseRequested(token) => ComCall(60, this, 'int64', token)

			static IID_2 := '{9E8F0CF8-E670-4B5E-B2BC-73E061E3184C}'
			add_WebResourceResponseReceived(eventHandler) => (ComCall(61, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2WebResourceResponseReceivedEventHandler
			remove_WebResourceResponseReceived(token) => ComCall(62, this, 'int64', token)
			NavigateWithWebResourceRequest(request) => ComCall(63, this, 'ptr', request)	; ICoreWebView2WebResourceRequest
			add_DOMContentLoaded(eventHandler) => (ComCall(64, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2DOMContentLoadedEventHandler
			remove_DOMContentLoaded(token) => ComCall(65, this, 'int64', token)
			CookieManager => (ComCall(66, this, 'ptr*', cookieManager := WebView2.CookieManager()), cookieManager)
			Environment => (ComCall(67, this, 'ptr*', environment := WebView2.Environment()), environment)

			static IID_3 := '{A0D6DF20-3B92-416D-AA0C-437A9C727857}'
			TrySuspend(handler) => ComCall(68, this, 'ptr', handler)	; ICoreWebView2TrySuspendCompletedHandler
			Resume() => ComCall(69, this)
			IsSuspended => (ComCall(70, this, 'int*', &isSuspended := 0), isSuspended)
			SetVirtualHostNameToFolderMapping(hostName, folderPath, accessKind) => ComCall(71, this, 'wstr', hostName, 'wstr', folderPath, 'int', accessKind)
			ClearVirtualHostNameToFolderMapping(hostName) => ComCall(72, this, 'wstr', hostName)

			static IID_4 := '{20d02d59-6df2-42dc-bd06-f98a694b1302}'
			add_FrameCreated(eventHandler) => (ComCall(73, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2FrameCreatedEventHandler
			remove_FrameCreated(token) => ComCall(74, this, 'int64', token)
			add_DownloadStarting(eventHandler) => (ComCall(75, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2DownloadStartingEventHandler
			remove_DownloadStarting(token) => ComCall(76, this, 'int64', token)

			static IID_5 := '{bedb11b8-d63c-11eb-b8bc-0242ac130003}'
			add_ClientCertificateRequested(eventHandler) => (ComCall(77, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2ClientCertificateRequestedEventHandler
			remove_ClientCertificateRequested(token) => ComCall(78, this, 'int64', token)

			static IID_6 := '{499aadac-d92c-4589-8a75-111bfc167795}'
			OpenTaskManagerWindow() => ComCall(79, this)

			static IID_7 := '{79c24d83-09a3-45ae-9418-487f32a58740}'
			PrintToPdf(resultFilePath, printSettings, handler) => ComCall(80, this, 'wstr', resultFilePath, 'ptr', printSettings, 'ptr', handler)

			static IID_8 := '{E9632730-6E1E-43AB-B7B8-7B2C9E62E094}'
			add_IsMutedChanged(eventHandler) => (ComCall(81, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2IsMutedChangedEventHandler
			remove_IsMutedChanged(token) => ComCall(82, this, 'int64', token)
			IsMuted {
				get => (ComCall(83, this, 'int*', &value := 0), value)
				set => ComCall(84, this, 'int', Value)
			}
			add_IsDocumentPlayingAudioChanged(eventHandler) => (ComCall(85, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2IsDocumentPlayingAudioChangedEventHandler
			remove_IsDocumentPlayingAudioChanged(token) => ComCall(86, this, 'int64', token)
			IsDocumentPlayingAudio => (ComCall(87, this, 'int*', &value := 0), value)
		}
		class ClientCertificate extends WebView2.Base {
			static IID := '{e7188076-bcc3-11eb-8529-0242ac130003}'
			Subject => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
			Issuer => (ComCall(4, this, 'ptr*', &value := 0), CoTaskMem_String(value))
			ValidFrom => (ComCall(5, this, 'double*', &value := 0), value)
			ValidTo => (ComCall(6, this, 'double*', &value := 0), value)
			DerEncodedSerialNumber => (ComCall(7, this, 'ptr*', &value := 0), CoTaskMem_String(value))
			DisplayName => (ComCall(8, this, 'ptr*', &value := 0), CoTaskMem_String(value))
			ToPemEncoding() => (ComCall(9, this, 'ptr*', &pemEncodedData := 0), CoTaskMem_String(pemEncodedData))
			PemEncodedIssuerCertificateChain => (ComCall(10, this, 'ptr*', value := WebView2.StringCollection()), value)
			Kind => (ComCall(11, this, 'int*', &value := 0), value)	; COREWEBVIEW2_CLIENT_CERTIFICATE_KIND
		}
		class StringCollection extends WebView2.Base {
			static IID := '{f41f3f8a-bcc3-11eb-8529-0242ac130003}'
			Count => (ComCall(3, this, 'uint*', &value := 0), value)
			GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', &value := 0), CoTaskMem_String(value))
		}
		class ClientCertificateCollection extends WebView2.Base {
			static IID := '{ef5674d2-bcc3-11eb-8529-0242ac130003}'
			Count => (ComCall(3, this, 'uint*', &value := 0), value)
			GetValueAtIndex(index) => (ComCall(4, this, 'uint', index, 'ptr*', certificate := WebView2.ClientCertificate()), certificate)
		}
		class ClientCertificateRequestedEventArgs extends WebView2.Base {
			static IID := '{bc59db28-bcc3-11eb-8529-0242ac130003}'
			Host => (ComCall(3, this, 'ptr*', &value := 0), CoTaskMem_String(value))
			Port => (ComCall(4, this, 'int*', &value := 0), value)
			IsProxy => (ComCall(5, this, 'int*', &value := 0), value)
			AllowedCertificateAuthorities => (ComCall(6, this, 'ptr*', value := WebView2.StringCollection()), value)
			MutuallyTrustedCertificates => (ComCall(7, this, 'ptr*', value := WebView2.ClientCertificateCollection()), value)
			SelectedCertificate {
				get => (ComCall(8, this, 'ptr*', value := WebView2.ClientCertificate()), value)
				set => ComCall(9, this, 'ptr', value)
			}
			Cancel {
				get => (ComCall(10, this, 'int*', &value := 0), value)
				set => ComCall(11, this, 'int', Value)
			}
			Handled {
				get => (ComCall(12, this, 'int*', &value := 0), value)
				set => ComCall(13, this, 'int', Value)
			}
			GetDeferral() => (ComCall(14, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
		}
		class DOMContentLoadedEventArgs extends WebView2.Base {
			static IID := '{16B1E21A-C503-44F2-84C9-70ABA5031283}'
			NavigationId => (ComCall(3, this, 'int64*', &navigationId := 0), navigationId)
		}
		class Deferral extends WebView2.Base {
			static IID := '{c10e7f7b-b585-46f0-a623-8befbf3e4ee0}'
			Complete() => ComCall(3, this)
		}
		class DevToolsProtocolEventReceivedEventArgs extends WebView2.Base {
			static IID := '{653c2959-bb3a-4377-8632-b58ada4e66c4}'
			ParameterObjectAsJson => (ComCall(3, this, 'ptr*', &parameterObjectAsJson := 0), CoTaskMem_String(parameterObjectAsJson))
		}
		class DevToolsProtocolEventReceiver extends WebView2.Base {
			static IID := '{b32ca51a-8371-45e9-9317-af021d080367}'
			add_DevToolsProtocolEventReceived(handler) => (ComCall(3, this, 'ptr', handler, 'int64*', &token := 0), token)	; ICoreWebView2DevToolsProtocolEventReceivedEventHandler
			remove_DevToolsProtocolEventReceived(token) => ComCall(4, this, 'int64', token)
		}
		class DownloadOperation extends WebView2.Base {
			static IID := '{3d6b6cf2-afe1-44c7-a995-c65117714336}'
			add_BytesReceivedChanged(eventHandler) => (ComCall(3, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2BytesReceivedChangedEventHandler
			remove_BytesReceivedChanged(token) => ComCall(4, this, 'int64', token)
			add_EstimatedEndTimeChanged(eventHandler) => (ComCall(5, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2EstimatedEndTimeChangedEventHandler
			remove_EstimatedEndTimeChanged(token) => ComCall(6, this, 'int64', token)
			add_StateChanged(eventHandler) => (ComCall(7, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2StateChangedEventHandler
			remove_StateChanged(token) => ComCall(8, this, 'int64', token)
			Uri => (ComCall(9, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			ContentDisposition => (ComCall(10, this, 'ptr*', &contentDisposition := 0), CoTaskMem_String(contentDisposition))
			MimeType => (ComCall(11, this, 'ptr*', &mimeType := 0), CoTaskMem_String(mimeType))
			TotalBytesToReceive => (ComCall(12, this, 'int64*', &totalBytesToReceive := 0), totalBytesToReceive)
			BytesReceived => (ComCall(13, this, 'int64*', &bytesReceived := 0), bytesReceived)
			EstimatedEndTime => (ComCall(14, this, 'ptr*', &estimatedEndTime := 0), CoTaskMem_String(estimatedEndTime))
			ResultFilePath => (ComCall(15, this, 'ptr*', &resultFilePath := 0), CoTaskMem_String(resultFilePath))
			State => (ComCall(16, this, 'int*', &downloadState := 0), downloadState)	; COREWEBVIEW2_DOWNLOAD_STATE
			InterruptReason => (ComCall(17, this, 'int*', &interruptReason := 0), interruptReason)	; COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON
			Cancel() => ComCall(18, this)
			Pause() => ComCall(19, this)
			Resume() => ComCall(20, this)
			CanResume => (ComCall(21, this, 'int*', &canResume := 0), canResume)
		}
		class DownloadStartingEventArgs extends WebView2.Base {
			static IID := '{e99bbe21-43e9-4544-a732-282764eafa60}'
			DownloadOperation => (ComCall(3, this, 'ptr*', downloadOperation := WebView2.DownloadOperation()), downloadOperation)
			Cancel {
				get => (ComCall(4, this, 'int*', &cancel := 0), cancel)
				set => ComCall(5, this, 'int', Value)
			}
			ResultFilePath {
				get => (ComCall(6, this, 'ptr*', &resultFilePath := 0), CoTaskMem_String(resultFilePath))
				set => ComCall(7, this, 'wstr', Value)
			}
			Handled {
				get => (ComCall(8, this, 'int*', &handled := 0), handled)
				set => ComCall(9, this, 'int', Value)
			}
			GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
		}
		class Environment extends WebView2.Base {
			static IID := '{b96d755e-0319-4e92-a296-23436f46a1fc}'
			CreateCoreWebView2Controller(parentWindow, handler) => ComCall(3, this, 'ptr', parentWindow, 'ptr', handler)	; ICoreWebView2CreateCoreWebView2ControllerCompletedHandler
			CreateWebResourceResponse(content, statusCode, reasonPhrase, headers) => (ComCall(4, this, 'ptr', content, 'int', statusCode, 'wstr', reasonPhrase, 'wstr', headers, 'ptr*', response := WebView2.WebResourceResponse()), response)
			BrowserVersionString => (ComCall(5, this, 'ptr*', &versionInfo := 0), CoTaskMem_String(versionInfo))
			add_NewBrowserVersionAvailable(eventHandler) => (ComCall(6, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2NewBrowserVersionAvailableEventHandler
			remove_NewBrowserVersionAvailable(token) => ComCall(7, this, 'int64', token)

			static IID_2 := '{41F3632B-5EF4-404F-AD82-2D606C5A9A21}'
			CreateWebResourceRequest(uri, method, postData, headers) => (ComCall(8, this, 'wstr', uri, 'wstr', method, 'ptr', postData, 'wstr', headers, 'ptr*', request := WebView2.WebResourceRequest()), request)

			static IID_3 := '{80a22ae3-be7c-4ce2-afe1-5a50056cdeeb}'
			CreateCoreWebView2CompositionController(parentWindow, handler) => ComCall(9, this, 'ptr', parentWindow, 'ptr', handler)	; ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler
			CreateCoreWebView2PointerInfo() => (ComCall(10, this, 'ptr*', pointerInfo := WebView2.PointerInfo()), pointerInfo)

			static IID_4 := '{20944379-6dcf-41d6-a0a0-abc0fc50de0d}'
			GetProviderForHwnd(hwnd) => (ComCall(11, this, 'ptr', hwnd, 'ptr*', &provider := 0), ComValue(0xd, provider))

			static IID_5 := '{319e423d-e0d7-4b8d-9254-ae9475de9b17}'
			add_BrowserProcessExited(eventHandler) => (ComCall(12, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2BrowserProcessExitedEventHandler
			remove_BrowserProcessExited(token) => ComCall(13, this, 'int64', token)

			static IID_6 := '{e59ee362-acbd-4857-9a8e-d3644d9459a9}'
			CreatePrintSettings() => (ComCall(14, this, 'ptr*', printSettings := WebView2.PrintSettings()), printSettings)

			static IID_7 := '{43C22296-3BBD-43A4-9C00-5C0DF6DD29A2}'
			UserDataFolder => (ComCall(15, this, 'ptr*', &value := 0), CoTaskMem_String(value))
		}
		class EnvironmentOptions extends Buffer {
			__New(opts) {
				super.__New(15 * A_PtrSize, 0)
				p := NumPut('ptr', this.Ptr + 2 * A_PtrSize, 'ptr', p := ObjPtr(this), this)
				for cb in [
					QueryInterface, AddRef, Release,
					get_AdditionalBrowserArguments, set_AdditionalBrowserArguments,
					get_Language, set_Language,
					get_TargetCompatibleBrowserVersion, set_TargetCompatibleBrowserVersion,
					get_AllowSingleSignOnUsingOSPrimaryAccount, set_AllowSingleSignOnUsingOSPrimaryAccount,
					get_ExclusiveUserDataFolderAccess, set_ExclusiveUserDataFolderAccess
				]
					p := NumPut('ptr', CallbackCreate(cb), p)
				for n in opts.OwnProps()
					this.%n% := opts.%n%
				QueryInterface(this, riid, ppvObject) {
					static IID_ICoreWebView2EnvironmentOptions := '{2FDE08A8-1E9A-4766-8C05-95A9CEB9D1C5}'
					static IID_ICoreWebView2EnvironmentOptions2 := '{1821A568-A141-4D77-B3D8-2878E383D8DD}'
					DllCall("ole32.dll\StringFromGUID2", "ptr", riid, "ptr", buf := Buffer(78), "int", 39)
					iid := StrGet(buf)
					if iid = IID_ICoreWebView2EnvironmentOptions || iid = IID_ICoreWebView2EnvironmentOptions2 {
						ObjAddRef(this)
						NumPut('ptr', this, ppvObject)
						return 0
					}
					NumPut('ptr', 0, ppvObject)
					return 0x80004002
				}
				AddRef(this) => ObjAddRef(NumGet(this, A_PtrSize, 'ptr'))
				Release(this) => ObjRelease(NumGet(this, A_PtrSize, 'ptr'))
				set_AdditionalBrowserArguments(*) => 0
				set_AllowSingleSignOnUsingOSPrimaryAccount(*) => 0
				set_Language(*) => 0
				set_TargetCompatibleBrowserVersion(*) => 0
				set_ExclusiveUserDataFolderAccess(*) => 0
				get_AdditionalBrowserArguments(this, pvalue) {
					this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
					if this.HasOwnProp('AdditionalBrowserArguments') {
						p := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(v := this.AdditionalBrowserArguments) * 2 + 2, 'ptr')
						DllCall('RtlMoveMemory', 'ptr', p, 'ptr', StrPtr(v), 'uptr', s)
						NumPut('ptr', p, pvalue)
					} else NumPut('ptr', 0, pvalue)
					return 0
				}
				get_AllowSingleSignOnUsingOSPrimaryAccount(this, pvalue) {
					this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
					if this.HasOwnProp('AllowSingleSignOnUsingOSPrimaryAccount')
						NumPut('int', !!this.AllowSingleSignOnUsingOSPrimaryAccount, pvalue)
					else NumPut('int', 0, pvalue)
					return 0
				}
				get_ExclusiveUserDataFolderAccess(this, pvalue) {
					this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
					if this.HasOwnProp('ExclusiveUserDataFolderAccess')
						NumPut('int', !!this.ExclusiveUserDataFolderAccess, pvalue)
					else NumPut('int', 0, pvalue)
					return 0
				}
				get_Language(this, pvalue) {
					this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
					if this.HasOwnProp('Language') {
						p := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(v := this.Language) * 2 + 2, 'ptr')
						DllCall('RtlMoveMemory', 'ptr', p, 'ptr', StrPtr(v), 'uptr', s)
						NumPut('ptr', p, pvalue)
					} else NumPut('ptr', 0, pvalue)
					return 0
				}
				get_TargetCompatibleBrowserVersion(this, pvalue) {
					this := ObjFromPtrAddRef(NumGet(this, A_PtrSize, 'ptr'))
					if this.HasOwnProp('TargetCompatibleBrowserVersion') {
						p := DllCall('ole32\CoTaskMemAlloc', 'uptr', s := StrLen(v := this.TargetCompatibleBrowserVersion) * 2 + 2, 'ptr')
						DllCall('RtlMoveMemory', 'ptr', p, 'ptr', StrPtr(v), 'uptr', s)
						NumPut('ptr', p, pvalue)
					} else NumPut('ptr', 0, pvalue)
					return 0
				}
			}
			__Delete() {
				loop 13
					CallbackFree(NumGet(this, (A_Index + 1) * A_PtrSize, 'ptr'))
			}
		}
		class Frame extends WebView2.Base {
			static IID := '{f1131a5e-9ba9-11eb-a8b3-0242ac130003}'
			AddAHKObjHelper() => this.AddHostObjectToScriptWithOrigins('AHKObjHelper', WebView2.AHKObjHelper())
			Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
			add_NameChanged(eventHandler) => (ComCall(4, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2FrameNameChangedEventHandler
			remove_NameChanged(token) => ComCall(5, this, 'int64', token)
			AddHostObjectToScriptWithOrigins(name, object, originsArr*) {
				if originsCount := originsArr.Length {
					p := (origins := Buffer(originsCount * A_PtrSize)).Ptr
					loop originsCount
						p := NumPut('ptr', StrPtr(originsArr[A_Index]), p)
				}
				ComCall(6, this, 'wstr', name, 'ptr', ComVar(object), 'uint', originsCount, 'ptr', origins)	; LPCWSTR*
			}
			RemoveHostObjectFromScript(name) => ComCall(7, this, 'wstr', name)
			add_Destroyed(eventHandler) => (ComCall(8, this, 'ptr', eventHandler, 'int64*', &token := 0), token)	; ICoreWebView2FrameDestroyedEventHandler
			remove_Destroyed(token) => ComCall(9, this, 'int64', token)
			IsDestroyed() => (ComCall(10, this, 'int*', &destroyed := 0), destroyed)
		}
		class FrameCreatedEventArgs extends WebView2.Base {
			static IID := '{4d6e7b5e-9baa-11eb-a8b3-0242ac130003}'
			Frame => (ComCall(3, this, 'ptr*', frame := WebView2.Frame()), frame)
		}
		class FrameInfo extends WebView2.Base {
			static IID := '{da86b8a1-bdf3-4f11-9955-528cefa59727}'
			Name => (ComCall(3, this, 'ptr*', &name := 0), CoTaskMem_String(name))
			Source => (ComCall(4, this, 'ptr*', &source := 0), CoTaskMem_String(source))
		}
		class FrameInfoCollection extends WebView2.Base {
			static IID := '{8f834154-d38e-4d90-affb-6800a7272839}'
			GetIterator() => (ComCall(3, this, 'ptr*', iterator := WebView2.FrameInfoCollectionIterator()), iterator)
		}
		class FrameInfoCollectionIterator extends WebView2.Base {
			static IID := '{1bf89e2d-1b2b-4629-b28f-05099b41bb03}'
			HasCurrent => (ComCall(3, this, 'int*', &hasCurrent := 0), hasCurrent)
			GetCurrent() => (ComCall(4, this, 'ptr*', frameInfo := WebView2.FrameInfo()), frameInfo)
			MoveNext() => (ComCall(5, this, 'int*', &hasNext := 0), hasNext)
		}
		class Handler extends Buffer {
			/**
			* Construct ICoreWebView2 Event or Completed Handler.
			* @param invoke_cb Invoke function of handler.
			* The first parameter of the callback function is the event interface pointer, and other parameters are as follows.
			* #### Handlers:
			* - BrowserProcessExitedEventHandler::Invoke(Environment*, BrowserProcessExitedEventArgs*);
			* - BytesReceivedChangedEventHandler::Invoke(DownloadOperation*, IUnknown*);
			* - ContentLoadingEventHandler::Invoke(ICoreWebView2*, ContentLoadingEventArgs*);
			* - ClientCertificateRequestedEventHandler::Invoke(ICoreWebView2*, ClientCertificateRequestedEventArgs*);
			* - ContainsFullScreenElementChangedEventHandler::Invoke(ICoreWebView2*, IUnknown*);
			* - CursorChangedEventHandler::Invoke(CompositionController*, IUnknown*);
			* - DocumentTitleChangedEventHandler::Invoke(ICoreWebView2*, IUnknown*);
			* - DOMContentLoadedEventHandler::Invoke(ICoreWebView2*, DOMContentLoadedEventArgs*);
			* - DevToolsProtocolEventReceivedEventHandler::Invoke(ICoreWebView2*, DevToolsProtocolEventReceivedEventArgs*);
			* - DownloadStartingEventHandler::Invoke(ICoreWebView2*, DownloadStartingEventArgs*);
			* - EstimatedEndTimeChangedEventHandler::Invoke(DownloadOperation*, IUnknown*);
			* - FrameCreatedEventHandler::Invoke(ICoreWebView2*, FrameCreatedEventArgs*);
			* - FrameDestroyedEventHandler::Invoke(Frame*, IUnknown*);
			* - FrameNameChangedEventHandler::Invoke(Frame*, IUnknown*);
			* - FocusChangedEventHandler::Invoke(Controller*, IUnknown*);
			* - HistoryChangedEventHandler::Invoke(ICoreWebView2*, IUnknown*);
			* - MoveFocusRequestedEventHandler::Invoke(Controller*, MoveFocusRequestedEventArgs*);
			* - NavigationCompletedEventHandler::Invoke(ICoreWebView2*, NavigationCompletedEventArgs*);
			* - NavigationStartingEventHandler::Invoke(ICoreWebView2*, NavigationStartingEventArgs*);
			* - NewBrowserVersionAvailableEventHandler::Invoke(Environment*, IUnknown*);
			* - NewWindowRequestedEventHandler::Invoke(ICoreWebView2*, NewWindowRequestedEventArgs*);
			* - PermissionRequestedEventHandler::Invoke(ICoreWebView2*, PermissionRequestedEventArgs*);
			* - ProcessFailedEventHandler::Invoke(ICoreWebView2*, ProcessFailedEventArgs*);
			* - RasterizationScaleChangedEventHandler::Invoke(Controller*, IUnknown*);
			* - ScriptDialogOpeningEventHandler::Invoke(ICoreWebView2*, ScriptDialogOpeningEventArgs*);
			* - SourceChangedEventHandler::Invoke(ICoreWebView2*, SourceChangedEventArgs*);
			* - StateChangedEventHandler::Invoke(DownloadOperation*, IUnknown*);
			* - WebMessageReceivedEventHandler::Invoke(ICoreWebView2*, WebMessageReceivedEventArgs*);
			* - WebResourceRequestedEventHandler::Invoke(ICoreWebView2*, WebResourceRequestedEventArgs*);
			* - WebResourceResponseReceivedEventHandler::Invoke(ICoreWebView2*, WebResourceResponseReceivedEventArgs*);
			* - WindowCloseRequestedEventHandler::Invoke(ICoreWebView2*, IUnknown*);
			* - ZoomFactorChangedEventHandler::Invoke(Controller*, IUnknown*);
			* - IWebView2CreateWebView2EnvironmentCompletedHandler::Invoke(Controller *sender, AcceleratorKeyPressedEventArgs *args);
			* - AddScriptToExecuteOnDocumentCreatedCompletedHandler::Invoke(HRESULT errorCode, LPCWSTR id);
			* - CallDevToolsProtocolMethodCompletedHandler::Invoke(HRESULT errorCode, LPCWSTR returnObjectAsJson);
			* - CapturePreviewCompletedHandler::Invoke(HRESULT errorCode);
			* - CreateCoreWebView2CompositionControllerCompletedHandler::Invoke(HRESULT errorCode, CompositionController *webView);
			* - CreateCoreWebView2ControllerCompletedHandler::Invoke(HRESULT errorCode, Controller *createdController);
			* - CreateCoreWebView2EnvironmentCompletedHandler::Invoke(HRESULT errorCode, Environment *createdEnvironment);
			* - ExecuteScriptCompletedHandler::Invoke(HRESULT errorCode, LPCWSTR resultObjectAsJson);
			* - GetCookiesCompletedHandler::Invoke(HRESULT result, CookieList *cookieList);
			* - PrintToPdfCompletedHandler::Invoke(HRESULT result, BOOL isSuccessful);
			* - TrySuspendCompletedHandler::Invoke(HRESULT errorCode, BOOL isSuccessful);
			* - WebResourceResponseViewGetContentCompletedHandler::Invoke(HRESULT errorCode, IStream *content);
			* - CoreWebView2IsDefaultDownloadDialogOpenChangedEventHandler::Invoke(ICoreWebView2 *sender, IUnknown *args);
			* - CoreWebView2IsMutedChangedEventHandler::Invoke(ICoreWebView2 *sender, IUnknown *args);
			*/
			__New(invoke_cb, paramcount := 0) {
				super.__New(6 * A_PtrSize)
				NumPut('ptr', this.Ptr + 2 * A_PtrSize, 'ptr', p := ObjPtr(this), this)
				for cb in [QueryInterface, AddRef, Release]
					NumPut('ptr', CallbackCreate(cb), this, (A_Index + 1) * A_PtrSize)
				NumPut('ptr', paramcount ? CallbackCreate(invoke_cb, , paramcount) : CallbackCreate(invoke_cb), this, 5 * A_PtrSize)

				QueryInterface(interface, riid, ppvObject) {

				}
				AddRef(this) => ObjAddRef(NumGet(this, A_PtrSize, 'ptr'))
				Release(this) => ObjRelease(NumGet(this, A_PtrSize, 'ptr'))
			}
			__Delete() {
				loop 4
					CallbackFree(NumGet(this, (A_Index + 1) * A_PtrSize, 'ptr'))
			}
		}
		class HttpHeadersCollectionIterator extends WebView2.Base {
			static IID := '{0702fc30-f43b-47bb-ab52-a42cb552ad9f}'
			GetCurrentHeader(&name, &value) {
				ComCall(3, this, 'ptr*', &name := 0, 'ptr*', &value := 0)
				name := CoTaskMem_String(name), value := CoTaskMem_String(value)
			}
			HasCurrentHeader => (ComCall(4, this, 'int*', &hasCurrent := 0), hasCurrent)
			MoveNext() => (ComCall(5, this, 'int*', &hasNext := 0), hasNext)
		}
		class HttpRequestHeaders extends WebView2.Base {
			static IID := '{e86cac0e-5523-465c-b536-8fb9fc8c8c60}'
			GetHeader(name) => (ComCall(3, this, 'wstr', name, 'ptr*', &value := 0), CoTaskMem_String(value))
			GetHeaders(name) => (ComCall(4, this, 'wstr', name, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
			RetVal(name) => (ComCall(5, this, 'wstr', name, 'int*', &RetVal := 0), RetVal)
			SetHeader(name, value) => ComCall(6, this, 'wstr', name, 'wstr', value)
			RemoveHeader(name) => ComCall(7, this, 'wstr', name)
			GetIterator() => (ComCall(8, this, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
		}
		class HttpResponseHeaders extends WebView2.Base {
			static IID := '{03c5ff5a-9b45-4a88-881c-89a9f328619c}'
			AppendHeader(name, value) => ComCall(3, this, 'wstr', name, 'wstr', value)
			RetVal(name) => (ComCall(4, this, 'wstr', name, 'int*', &RetVal := 0), RetVal)
			GetHeader(name) => (ComCall(5, this, 'wstr', name, 'ptr*', &value := 0), CoTaskMem_String(value))
			GetHeaders(name) => (ComCall(6, this, 'wstr', name, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
			GetIterator() => (ComCall(7, this, 'ptr*', iterator := WebView2.HttpHeadersCollectionIterator()), iterator)
		}
		class MoveFocusRequestedEventArgs extends WebView2.Base {
			static IID := '{2d6aa13b-3839-4a15-92fc-d88b3c0d9c9d}'
			Reason => (ComCall(3, this, 'int*', &reason := 0), reason)	; COREWEBVIEW2_MOVE_FOCUS_REASON
			Handled {
				get => (ComCall(4, this, 'int*', &value := 0), value)
				set => ComCall(5, this, 'int', Value)
			}
		}
		class NavigationCompletedEventArgs extends WebView2.Base {
			static IID := '{30d68b7d-20d9-4752-a9ca-ec8448fbb5c1}'
			IsSuccess => (ComCall(3, this, 'int*', &isSuccess := 0), isSuccess)
			WebErrorStatus => (ComCall(4, this, 'int*', &webErrorStatus := 0), webErrorStatus)	; COREWEBVIEW2_WEB_ERROR_STATUS
			NavigationId => (ComCall(5, this, 'int64*', &navigationId := 0), navigationId)
		}
		class NavigationStartingEventArgs extends WebView2.Base {
			static IID := '{5b495469-e119-438a-9b18-7604f25f2e49}'
			Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			IsUserInitiated => (ComCall(4, this, 'int*', &isUserInitiated := 0), isUserInitiated)
			IsRedirected => (ComCall(5, this, 'int*', &isRedirected := 0), isRedirected)
			RequestHeaders => (ComCall(6, this, 'ptr*', requestHeaders := WebView2.HttpRequestHeaders()), requestHeaders)
			Cancel {
				get => (ComCall(7, this, 'int*', &cancel := 0), cancel)
				set => ComCall(8, this, 'int', Value)
			}
			NavigationId => (ComCall(9, this, 'int64*', &navigationId := 0), navigationId)
		}
		class NewWindowRequestedEventArgs extends WebView2.Base {
			static IID := '{34acb11c-fc37-4418-9132-f9c21d1eafb9}'
			Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			NewWindow {
				set => ComCall(4, this, 'ptr', Value)
				get => (ComCall(5, this, 'ptr*', newWindow := WebView2.Core()), newWindow)
			}
			Handled {
				set => ComCall(6, this, 'int', Value)
				get => (ComCall(7, this, 'int*', &handled := 0), handled)
			}
			IsUserInitiated => (ComCall(8, this, 'int*', &isUserInitiated := 0), isUserInitiated)
			GetDeferral() => (ComCall(9, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
			WindowFeatures => (ComCall(10, this, 'ptr*', value := WebView2.WindowFeatures()), value)

			static IID_2 := '{bbc7baed-74c6-4c92-b63a-7f5aeae03de3}'
			Name => (ComCall(11, this, 'ptr*', &value := 0), CoTaskMem_String(value))
		}
		class PermissionRequestedEventArgs extends WebView2.Base {
			static IID := '{973ae2ef-ff18-4894-8fb2-3c758f046810}'
			Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			PermissionKind => (ComCall(4, this, 'int*', &permissionKind := 0), permissionKind)	; COREWEBVIEW2_PERMISSION_KIND
			IsUserInitiated => (ComCall(5, this, 'int*', &isUserInitiated := 0), isUserInitiated)
			State {
				get => (ComCall(6, this, 'int*', &state := 0), state)	; COREWEBVIEW2_PERMISSION_STATE
				set => ComCall(7, this, 'int', Value)
			}
			GetDeferral() => (ComCall(8, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
		}
		class PointerInfo extends WebView2.Base {
			static IID := '{e6995887-d10d-4f5d-9359-4ce46e4f96b9}'
			PointerKind {
				get => (ComCall(3, this, 'uint*', &pointerKind := 0), pointerKind)
				set => ComCall(4, this, 'uint', Value)
			}
			PointerId {
				get => (ComCall(5, this, 'uint*', &pointerId := 0), pointerId)
				set => ComCall(6, this, 'uint', Value)
			}
			FrameId {
				get => (ComCall(7, this, 'uint*', &frameId := 0), frameId)
				set => ComCall(8, this, 'uint', Value)
			}
			PointerFlags {
				get => (ComCall(9, this, 'uint*', &pointerFlags := 0), pointerFlags)
				set => ComCall(10, this, 'uint', Value)
			}
			PointerDeviceRect {
				get => (ComCall(11, this, 'ptr', pointerDeviceRect := Buffer(16)), pointerDeviceRect)
				set => (A_PtrSize = 8 ? ComCall(12, this, 'ptr', Value) : ComCall(12, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
			}
			DisplayRect {
				get => (ComCall(13, this, 'ptr', displayRect := Buffer(16)), displayRect)
				set => (A_PtrSize = 8 ? ComCall(14, this, 'ptr', Value) : ComCall(14, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
			}
			PixelLocation {
				get => (ComCall(15, this, 'int64*', &pixelLocation := 0), pixelLocation)
				set => ComCall(16, this, 'int64', Value)
			}
			HimetricLocation {
				get => (ComCall(17, this, 'int64*', &himetricLocation := 0), himetricLocation)
				set => ComCall(18, this, 'int64', Value)
			}
			PixelLocationRaw {
				get => (ComCall(19, this, 'int64*', &pixelLocationRaw := 0), pixelLocationRaw)
				set => ComCall(20, this, 'int64', Value)
			}
			HimetricLocationRaw {
				get => (ComCall(21, this, 'int64*', &himetricLocationRaw := 0), himetricLocationRaw)
				set => ComCall(22, this, 'int64', Value)
			}
			Time {
				get => (ComCall(23, this, 'uint*', &time := 0), time)
				set => ComCall(24, this, 'uint', Value)
			}
			HistoryCount {
				get => (ComCall(25, this, 'uint*', &historyCount := 0), historyCount)
				set => ComCall(26, this, 'uint', Value)
			}
			InputData {
				get => (ComCall(27, this, 'int*', &inputData := 0), inputData)
				set => ComCall(28, this, 'int', Value)
			}
			KeyStates {
				get => (ComCall(29, this, 'uint*', &keyStates := 0), keyStates)
				set => ComCall(30, this, 'uint', Value)
			}
			PerformanceCount {
				get => (ComCall(31, this, 'uint64*', &performanceCount := 0), performanceCount)
				set => ComCall(32, this, 'uint64', Value)
			}
			ButtonChangeKind {
				get => (ComCall(33, this, 'int*', &buttonChangeKind := 0), buttonChangeKind)
				set => ComCall(34, this, 'int', Value)
			}
			PenFlags {
				get => (ComCall(35, this, 'uint*', &penFLags := 0), penFLags)
				set => ComCall(36, this, 'uint', Value)
			}
			PenMask {
				get => (ComCall(37, this, 'uint*', &penMask := 0), penMask)
				set => ComCall(38, this, 'uint', Value)
			}
			PenPressure {
				get => (ComCall(39, this, 'uint*', &penPressure := 0), penPressure)
				set => ComCall(40, this, 'uint', Value)
			}
			PenRotation {
				get => (ComCall(41, this, 'uint*', &penRotation := 0), penRotation)
				set => ComCall(42, this, 'uint', Value)
			}
			PenTiltX {
				get => (ComCall(43, this, 'int*', &penTiltX := 0), penTiltX)
				set => ComCall(44, this, 'int', Value)
			}
			PenTiltY {
				get => (ComCall(45, this, 'int*', &penTiltY := 0), penTiltY)
				set => ComCall(46, this, 'int', Value)
			}
			TouchFlags {
				get => (ComCall(47, this, 'uint*', &touchFlags := 0), touchFlags)
				set => ComCall(48, this, 'uint', Value)
			}
			TouchMask {
				get => (ComCall(49, this, 'uint*', &touchMask := 0), touchMask)
				set => ComCall(50, this, 'uint', Value)
			}
			TouchContact {
				get => (ComCall(51, this, 'ptr', touchContact := Buffer(16)), touchContact)
				set => (A_PtrSize = 8 ? ComCall(52, this, 'ptr', Value) : ComCall(52, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
			}
			TouchContactRaw {
				get => (ComCall(53, this, 'ptr', touchContactRaw := Buffer(16)), touchContactRaw)
				set => (A_PtrSize = 8 ? ComCall(54, this, 'ptr', Value) : ComCall(54, this, 'int64', NumGet(Value, 'int64'), 'int64', NumGet(Value, 8, 'int64')))
			}
			TouchOrientation {
				get => (ComCall(55, this, 'uint*', &touchOrientation := 0), touchOrientation)
				set => ComCall(56, this, 'uint', Value)
			}
			TouchPressure {
				get => (ComCall(57, this, 'uint*', &touchPressure := 0), touchPressure)
				set => ComCall(58, this, 'uint', Value)
			}
		}
		class PrintSettings extends WebView2.Base {
			static IID := '{377f3721-c74e-48ca-8db1-df68e51d60e2}'
			Orientation {
				get => (ComCall(3, this, 'int*', &orientation := 0), orientation)
				set => ComCall(4, this, 'int', Value)
			}
			ScaleFactor {
				get => (ComCall(5, this, 'double*', &scaleFactor := 0), scaleFactor)
				set => ComCall(6, this, 'double', Value)
			}
			PageWidth {
				get => (ComCall(7, this, 'double*', &pageWidth := 0), pageWidth)
				set => ComCall(8, this, 'double', Value)
			}
			PageHeight {
				get => (ComCall(9, this, 'double*', &pageHeight := 0), pageHeight)
				set => ComCall(10, this, 'double', Value)
			}
			MarginTop {
				get => (ComCall(11, this, 'double*', &marginTop := 0), marginTop)
				set => ComCall(12, this, 'double', Value)
			}
			MarginBottom {
				get => (ComCall(13, this, 'double*', &marginBottom := 0), marginBottom)
				set => ComCall(14, this, 'double', Value)
			}
			MarginLeft {
				get => (ComCall(15, this, 'double*', &marginLeft := 0), marginLeft)
				set => ComCall(16, this, 'double', Value)
			}
			MarginRight {
				get => (ComCall(17, this, 'double*', &marginRight := 0), marginRight)
				set => ComCall(18, this, 'double', Value)
			}
			ShouldPrintBackgrounds {
				get => (ComCall(19, this, 'int*', &shouldPrintBackgrounds := 0), shouldPrintBackgrounds)
				set => ComCall(20, this, 'int', Value)
			}
			ShouldPrintSelectionOnly {
				get => (ComCall(21, this, 'int*', &shouldPrintSelectionOnly := 0), shouldPrintSelectionOnly)
				set => ComCall(22, this, 'int', Value)
			}
			ShouldPrintHeaderAndFooter {
				get => (ComCall(23, this, 'int*', &shouldPrintHeaderAndFooter := 0), shouldPrintHeaderAndFooter)
				set => ComCall(24, this, 'int', Value)
			}
			HeaderTitle {
				get => (ComCall(25, this, 'ptr*', &headerTitle := 0), CoTaskMem_String(headerTitle))
				set => ComCall(26, this, 'wstr', Value)
			}
			FooterUri {
				get => (ComCall(27, this, 'ptr*', &footerUri := 0), CoTaskMem_String(footerUri))
				set => ComCall(28, this, 'wstr', Value)
			}
		}
		class ProcessFailedEventArgs extends WebView2.Base {
			static IID := '{8155a9a4-1474-4a86-8cae-151b0fa6b8ca}'
			ProcessFailedKind => (ComCall(3, this, 'int*', &processFailedKind := 0), processFailedKind)	; COREWEBVIEW2_PROCESS_FAILED_KIND

			static IID_2 := '{4dab9422-46fa-4c3e-a5d2-41d2071d3680}'
			Reason => (ComCall(4, this, 'int*', &reason := 0), reason)	; COREWEBVIEW2_PROCESS_FAILED_REASON
			ExitCode => (ComCall(5, this, 'int*', &exitCode := 0), exitCode)
			ProcessDescription => (ComCall(6, this, 'ptr*', &processDescription := 0), CoTaskMem_String(processDescription))
			FrameInfosForFailedProcess => (ComCall(7, this, 'ptr*', frames := WebView2.FrameInfoCollection()), frames)
		}
		class ScriptDialogOpeningEventArgs extends WebView2.Base {
			static IID := '{7390bb70-abe0-4843-9529-f143b31b03d6}'
			Uri => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
			Kind => (ComCall(4, this, 'int*', &kind := 0), kind)	; COREWEBVIEW2_SCRIPT_DIALOG_KIND
			Message => (ComCall(5, this, 'ptr*', &message := 0), CoTaskMem_String(message))
			Accept() => ComCall(6, this)
			DefaultText => (ComCall(7, this, 'ptr*', &defaultText := 0), CoTaskMem_String(defaultText))
			ResultText {
				get => (ComCall(8, this, 'ptr*', &resultText := 0), CoTaskMem_String(resultText))
				set => ComCall(9, this, 'wstr', Value)
			}
			GetDeferral() => (ComCall(10, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
		}
		class Settings extends WebView2.Base {
			static IID := '{e562e4f0-d7fa-43ac-8d71-c05150499f00}'
			IsScriptEnabled {
				get => (ComCall(3, this, 'int*', &isScriptEnabled := 0), isScriptEnabled)
				set => ComCall(4, this, 'int', Value)
			}
			IsWebMessageEnabled {
				get => (ComCall(5, this, 'int*', &isWebMessageEnabled := 0), isWebMessageEnabled)
				set => ComCall(6, this, 'int', Value)
			}
			AreDefaultScriptDialogsEnabled {
				get => (ComCall(7, this, 'int*', &areDefaultScriptDialogsEnabled := 0), areDefaultScriptDialogsEnabled)
				set => ComCall(8, this, 'int', Value)
			}
			IsStatusBarEnabled {
				get => (ComCall(9, this, 'int*', &isStatusBarEnabled := 0), isStatusBarEnabled)
				set => ComCall(10, this, 'int', Value)
			}
			AreDevToolsEnabled {
				get => (ComCall(11, this, 'int*', &areDevToolsEnabled := 0), areDevToolsEnabled)
				set => ComCall(12, this, 'int', Value)
			}
			AreDefaultContextMenusEnabled {
				get => (ComCall(13, this, 'int*', &enabled := 0), enabled)
				set => ComCall(14, this, 'int', Value)
			}
			AreHostObjectsAllowed {
				get => (ComCall(15, this, 'int*', &allowed := 0), allowed)
				set => ComCall(16, this, 'int', Value)
			}
			IsZoomControlEnabled {
				get => (ComCall(17, this, 'int*', &enabled := 0), enabled)
				set => ComCall(18, this, 'int', Value)
			}
			IsBuiltInErrorPageEnabled {
				get => (ComCall(19, this, 'int*', &enabled := 0), enabled)
				set => ComCall(20, this, 'int', Value)
			}

			static IID_2 := '{ee9a0f68-f46c-4e32-ac23-ef8cac224d2a}'
			UserAgent {
				get => (ComCall(21, this, 'ptr*', &userAgent := 0), CoTaskMem_String(userAgent))
				set => ComCall(22, this, 'wstr', Value)
			}

			static IID_3 := '{fdb5ab74-af33-4854-84f0-0a631deb5eba}'
			AreBrowserAcceleratorKeysEnabled {
				get => (ComCall(23, this, 'int*', &areBrowserAcceleratorKeysEnabled := 0), areBrowserAcceleratorKeysEnabled)
				set => ComCall(24, this, 'int', Value)
			}

			static IID_4 := '{cb56846c-4168-4d53-b04f-03b6d6796ff2}'
			IsPasswordAutosaveEnabled {
				get => (ComCall(25, this, 'int*', &value := 0), value)
				set => ComCall(26, this, 'int', Value)
			}
			IsGeneralAutofillEnabled {
				get => (ComCall(27, this, 'int*', &value := 0), value)
				set => ComCall(28, this, 'int', Value)
			}

			static IID_5 := '{183e7052-1d03-43a0-ab99-98e043b66b39}'
			IsPinchZoomEnabled {
				get => (ComCall(29, this, 'int*', &enabled := 0), enabled)
				set => ComCall(30, this, 'int', Value)
			}

			static IID_6 := '{11cb3acd-9bc8-43b8-83bf-f40753714f87}'
			IsSwipeNavigationEnabled {
				get => (ComCall(31, this, 'int*', &enabled := 0), enabled)
				set => ComCall(32, this, 'int', Value)
			}
		}
		class SourceChangedEventArgs extends WebView2.Base {
			static IID := '{31e0e545-1dba-4266-8914-f63848a1f7d7}'
			IsNewDocument => (ComCall(3, this, 'int*', &isNewDocument := 0), isNewDocument)
		}
		class WebMessageReceivedEventArgs extends WebView2.Base {
			static IID := '{0f99a40c-e962-4207-9e92-e3d542eff849}'
			Source => (ComCall(3, this, 'ptr*', &source := 0), CoTaskMem_String(source))
			WebMessageAsJson => (ComCall(4, this, 'ptr*', &webMessageAsJson := 0), CoTaskMem_String(webMessageAsJson))
			TryGetWebMessageAsString() => (ComCall(5, this, 'ptr*', &webMessageAsString := 0), CoTaskMem_String(webMessageAsString))
		}
		class WebResourceRequest extends WebView2.Base {
			static IID := '{97055cd4-512c-4264-8b5f-e3f446cea6a5}'
			Uri {
				get => (ComCall(3, this, 'ptr*', &uri := 0), CoTaskMem_String(uri))
				set => ComCall(4, this, 'wstr', Value)
			}
			Method {
				get => (ComCall(5, this, 'ptr*', &method := 0), CoTaskMem_String(method))
				set => ComCall(6, this, 'wstr', Value)
			}
			Content {
				get => (ComCall(7, this, 'ptr*', &content := 0), content)	; IStream*
				set => ComCall(8, this, 'ptr', Value)
			}
			Headers => (ComCall(9, this, 'ptr*', headers := WebView2.HttpRequestHeaders()), headers)
		}
		class WebResourceRequestedEventArgs extends WebView2.Base {
			static IID := '{453e667f-12c7-49d4-be6d-ddbe7956f57a}'
			Request => (ComCall(3, this, 'ptr*', request := WebView2.WebResourceRequest()), request)
			Response {
				get => (ComCall(4, this, 'ptr*', response := WebView2.WebResourceResponse()), response)
				set => ComCall(5, this, 'ptr', Value)
			}
			GetDeferral() => (ComCall(6, this, 'ptr*', deferral := WebView2.Deferral()), deferral)
			ResourceContext => (ComCall(7, this, 'int*', &context := 0), context)	; COREWEBVIEW2_WEB_RESOURCE_CONTEXT
		}
		class WebResourceResponse extends WebView2.Base {
			static IID := '{aafcc94f-fa27-48fd-97df-830ef75aaec9}'
			Content {
				get => (ComCall(3, this, 'ptr*', &content := 0), content)	; IStream*
				set => ComCall(4, this, 'ptr', Value)
			}
			Headers => (ComCall(5, this, 'ptr*', headers := WebView2.HttpResponseHeaders()), headers)
			StatusCode {
				get => (ComCall(6, this, 'int*', &statusCode := 0), statusCode)
				set => ComCall(7, this, 'int', Value)
			}
			ReasonPhrase {
				get => (ComCall(8, this, 'ptr*', &reasonPhrase := 0), CoTaskMem_String(reasonPhrase))
				set => ComCall(9, this, 'wstr', Value)
			}
		}
		class WebResourceResponseReceivedEventArgs extends WebView2.Base {
			static IID := '{D1DB483D-6796-4B8B-80FC-13712BB716F4}'
			Request => (ComCall(3, this, 'ptr*', request := WebView2.WebResourceRequest()), request)
			Response => (ComCall(4, this, 'ptr*', response := WebView2.WebResourceResponseView()), response)
		}
		class WebResourceResponseView extends WebView2.Base {
			static IID := '{79701053-7759-4162-8F7D-F1B3F084928D}'
			Headers => (ComCall(3, this, 'ptr*', headers := WebView2.HttpResponseHeaders()), headers)
			StatusCode => (ComCall(4, this, 'int*', &statusCode := 0), statusCode)
			ReasonPhrase => (ComCall(5, this, 'ptr*', &reasonPhrase := 0), CoTaskMem_String(reasonPhrase))
			GetContent(handler) => ComCall(6, this, 'ptr', handler)	; ICoreWebView2WebResourceResponseViewGetContentCompletedHandler
		}
		class WindowFeatures extends WebView2.Base {
			static IID := '{5eaf559f-b46e-4397-8860-e422f287ff1e}'
			HasPosition => (ComCall(3, this, 'int*', &value := 0), value)
			HasSize => (ComCall(4, this, 'int*', &value := 0), value)
			Left => (ComCall(5, this, 'uint*', &value := 0), value)
			Top => (ComCall(6, this, 'uint*', &value := 0), value)
			Height => (ComCall(7, this, 'uint*', &value := 0), value)
			Width => (ComCall(8, this, 'uint*', &value := 0), value)
			ShouldDisplayMenuBar => (ComCall(9, this, 'int*', &value := 0), value)
			ShouldDisplayStatus => (ComCall(10, this, 'int*', &value := 0), value)
			ShouldDisplayToolbar => (ComCall(11, this, 'int*', &value := 0), value)
			ShouldDisplayScrollBars => (ComCall(12, this, 'int*', &value := 0), value)
		}
		;#endregion

		;#region structs
		class PHYSICAL_KEY_STATUS extends Buffer {
			__New() {
				super.__New(24, 0)
			}
			RepeatCount {
				get => NumGet(this, 'uint')
				set => NumPut('uint', Value, this)
			}
			ScanCode {
				get => NumGet(this, 4, 'uint')
				set => NumPut('uint', Value, this, 4)
			}
			IsExtendedKey {
				get => NumGet(this, 8, 'int')
				set => NumPut('int', Value, this, 8)
			}
			IsMenuKeyDown {
				get => NumGet(this, 12, 'int')
				set => NumPut('int', Value, this, 12)
			}
			WasKeyDown {
				get => NumGet(this, 16, 'int')
				set => NumPut('int', Value, this, 16)
			}
			IsKeyReleased {
				get => NumGet(this, 20, 'int')
				set => NumPut('int', Value, this, 20)
			}
		}
		;#endregion

		;#region constants
		static CAPTURE_PREVIEW_IMAGE_FORMAT := { PNG: 0, JPEG: 1 }
		static COOKIE_SAME_SITE_KIND := { NONE: 0, LAX: 1, STRICT: 2 }
		static HOST_RESOURCE_ACCESS_KIND := { DENY: 0, ALLOW: 1, DENY_CORS: 2 }
		static SCRIPT_DIALOG_KIND := { ALERT: 0, CONFIRM: 1, PROMPT: 2, BEFOREUNLOAD: 3 }
		static PROCESS_FAILED_KIND := {
			BROWSER_PROCESS_EXITED: 0,
			RENDER_PROCESS_EXITED: 1,
			RENDER_PROCESS_UNRESPONSIVE: 2,
			FRAME_RENDER_PROCESS_EXITED: 3,
			UTILITY_PROCESS_EXITED: 4,
			SANDBOX_HELPER_PROCESS_EXITED: 5,
			GPU_PROCESS_EXITED: 6,
			PPAPI_PLUGIN_PROCESS_EXITED: 7,
			PPAPI_BROKER_PROCESS_EXITED: 8,
			UNKNOWN_PROCESS_EXITED: 9
		}
		static PROCESS_FAILED_REASON := { UNEXPECTED: 0, UNRESPONSIVE: 1, TERMINATED: 2, CRASHED: 3, LAUNCH_FAILED: 4, OUT_OF_MEMORY: 5 }
		static PERMISSION_KIND := {
			UNKNOWN_PERMISSION: 0,
			MICROPHONE: 1,
			CAMERA: 2,
			GEOLOCATION: 3,
			NOTIFICATIONS: 4,
			OTHER_SENSORS: 5,
			CLIPBOARD_READ: 6
		}
		static PERMISSION_STATE := { DEFAULT: 0, ALLOW: 1, DENY: 2 }
		static WEB_ERROR_STATUS := {
			UNKNOWN: 0,
			CERTIFICATE_COMMON_NAME_IS_INCORRECT: 1,
			CERTIFICATE_EXPIRED: 2,
			CLIENT_CERTIFICATE_CONTAINS_ERRORS: 3,
			CERTIFICATE_REVOKED: 4,
			CERTIFICATE_IS_INVALID: 5,
			SERVER_UNREACHABLE: 6,
			TIMEOUT: 7,
			ERROR_HTTP_INVALID_SERVER_RESPONSE: 8,
			CONNECTION_ABORTED: 9,
			CONNECTION_RESET: 10,
			DISCONNECTED: 11,
			CANNOT_CONNECT: 12,
			HOST_NAME_NOT_RESOLVED: 13,
			OPERATION_CANCELED: 14,
			REDIRECT_FAILED: 15,
			UNEXPECTED_ERROR: 16
		}
		static WEB_RESOURCE_CONTEXT := {
			ALL: 0,
			DOCUMENT: 1,
			STYLESHEET: 2,
			IMAGE: 3,
			MEDIA: 4,
			FONT: 5,
			SCRIPT: 6,
			XML_HTTP_REQUEST: 7,
			FETCH: 8,
			TEXT_TRACK: 9,
			EVENT_SOURCE: 10,
			WEBSOCKET: 11,
			MANIFEST: 12,
			SIGNED_EXCHANGE: 13,
			PING: 14,
			CSP_VIOLATION_REPORT: 15,
			OTHER: 16
		}
		static MOVE_FOCUS_REASON := { PROGRAMMATIC: 0, NEXT: 1, PREVIOUS: 2 }
		static KEY_EVENT_KIND := { KEY_DOWN: 0, KEY_UP: 1, SYSTEM_KEY_DOWN: 2, SYSTEM_KEY_UP: 3 }
		static BROWSER_PROCESS_EXIT_KIND := { NORMAL: 0, FAILED: 1 }
		static MOUSE_EVENT_KIND := {
			HORIZONTAL_WHEEL: 0x20e,
			LEFT_BUTTON_DOUBLE_CLICK: 0x203,
			LEFT_BUTTON_DOWN: 0x201,
			LEFT_BUTTON_UP: 0x202,
			LEAVE: 0x2a3,
			MIDDLE_BUTTON_DOUBLE_CLICK: 0x209,
			MIDDLE_BUTTON_DOWN: 0x207,
			MIDDLE_BUTTON_UP: 0x208,
			MOVE: 0x200,
			RIGHT_BUTTON_DOUBLE_CLICK: 0x206,
			RIGHT_BUTTON_DOWN: 0x204,
			RIGHT_BUTTON_UP: 0x205,
			WHEEL: 0x20a,
			X_BUTTON_DOUBLE_CLICK: 0x20d,
			X_BUTTON_DOWN: 0x20b,
			X_BUTTON_UP: 0x20c
		}
		static MOUSE_EVENT_VIRTUAL_KEYS := {
			NONE: 0,
			LEFT_BUTTON: 0x1,
			RIGHT_BUTTON: 0x2,
			SHIFT: 0x4,
			CONTROL: 0x8,
			MIDDLE_BUTTON: 0x10,
			X_BUTTON1: 0x20,
			X_BUTTON2: 0x40
		}
		static POINTER_EVENT_KIND := {
			ACTIVATE: 0x24b,
			DOWN: 0x246,
			ENTER: 0x249,
			LEAVE: 0x24a,
			UP: 0x247,
			UPDATE: 0x245
		}
		static BOUNDS_MODE := { USE_RAW_PIXELS: 0, USE_RASTERIZATION_SCALE: 1 }
		static CLIENT_CERTIFICATE_KIND := { SMART_CARD: 0, PIN: 1, OTHER: 2 }
		static DOWNLOAD_STATE := { IN_PROGRESS: 0, INTERRUPTED: 1, COMPLETED: 2 }
		static DOWNLOAD_INTERRUPT_REASON := {
			NONE: 0,
			FILE_FAILED: 1,
			FILE_ACCESS_DENIED: 2,
			FILE_NO_SPACE: 3,
			FILE_NAME_TOO_LONG: 4,
			FILE_TOO_LARGE: 5,
			FILE_MALICIOUS: 6,
			FILE_TRANSIENT_ERROR: 7,
			FILE_BLOCKED_BY_POLICY: 8,
			FILE_SECURITY_CHECK_FAILED: 9,
			FILE_TOO_SHORT: 10,
			FILE_HASH_MISMATCH: 11,
			NETWORK_FAILED: 12,
			NETWORK_TIMEOUT: 13,
			NETWORK_DISCONNECTED: 14,
			NETWORK_SERVER_DOWN: 15,
			NETWORK_INVALID_REQUEST: 16,
			SERVER_FAILED: 17,
			SERVER_NO_RANGE: 18,
			SERVER_BAD_CONTENT: 19,
			SERVER_UNAUTHORIZED: 20,
			SERVER_CERTIFICATE_PROBLEM: 21,
			SERVER_FORBIDDEN: 22,
			SERVER_UNEXPECTED_RESPONSE: 23,
			SERVER_CONTENT_LENGTH_MISMATCH: 24,
			SERVER_CROSS_ORIGIN_REDIRECT: 25,
			USER_CANCELED: 26,
			USER_SHUTDOWN: 27,
			USER_PAUSED: 28,
			DOWNLOAD_PROCESS_CRASHED: 29
		}
		static PRINT_ORIENTATION := { PORTRAIT: 0, LANDSCAPE: 1 }
		static DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT := { TOP_LEFT: 0, TOP_RIGHT: 1, BOTTOM_LEFT: 2, BOTTOM_RIGHT: 3 }
		;#endregion
	}
	CoTaskMem_String(ptr) {
		s := StrGet(ptr), DllCall('ole32\CoTaskMemFree', 'ptr', ptr)
		return s
	}

	; -------------------- Construction and deconstruction VARIANT struct -------------------- ;
	class ComVar {
		__New(vVal := unset, vType := 0xC, convert := false) {
			static size := 8 + 2 * A_PtrSize
			this.var := Buffer(size, 0), this.owner := true
			this.ref := ComValue(0x4000 | vType, this.var.Ptr + (vType = 0xC ? 0 : 8))
			if IsSet(vVal) {
				if (Type(vVal) == "ComVar") {
					this.var := vVal.var, this.ref := vVal.ref, this.obj := vVal, this.owner := false
				} else {
					if (IsObject(vVal)) {
						if (vType != 0xC)
							this.ref := ComValue(0x400C, this.var.ptr)
						if convert && (vVal is Array) {
							switch Type(vVal[1]) {
								case "Integer": vType := 3
								case "String": vType := 8
								case "Float": vType := 5
								case "ComValue", "ComObject": vType := ComObjType(vVal[1])
								default: vType := 0xC
							}
							ComObjFlags(obj := ComObjArray(vType, vVal.Length), -1), i := 0, this.ref[] := obj
							for v in vVal
								obj[i++] := v
						} else
							this.ref[] := vVal
					} else
						this.ref[] := vVal
				}
			}
		}
		__Delete() => (this.owner ? DllCall("oleaut32\VariantClear", "ptr", this.var) : 0)
		__Item {
			get => this.ref[]
			set => this.ref[] := value
		}
		Ptr => this.var.Ptr
		Size => this.var.Size
		Type {
			get => NumGet(this.var, "ushort")
			set {
				if (!this.IsVariant)
					throw PropertyError("VarType is not VT_VARIANT, Type is read-only.", -2)
				NumPut("ushort", Value, this.var)
			}
		}
		IsVariant => ComObjType(this.ref) & 0xC
	}
}

; -------------------- Gui initialization and installation check -------------------- ;
If !A_IsAdmin {
	If FileExist(A_WorkingDir . "\Launcher\autostart"){
		MsgBox "Failed to launch Growtopia Launcher as administrator. Please manually launch Growtopia Launcher as administrator", "Growtopia Launcher", "OK T10"
		FileDelete A_WorkingDir . "\Launcher\autostart"
		ExitApp
	}
	FileAppend "", A_WorkingDir "\Launcher\autostart"
	If A_IsCompiled
		Run '*RunAs "' A_ScriptFullPath '" /restart'
	Else
		Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
	ExitApp
}
If FileExist(A_WorkingDir . "\Launcher\autostart")
	FileDelete A_WorkingDir . "\Launcher\autostart"
If FileExist(A_WorkingDir . "\Launcher\Bin\g"){
	RegWrite FileRead(A_WorkingDir . "\Launcher\Bin\g"), "REG_DWORD", "HKCU\Software\Growtopia Launcher", "GTSize"
	FileDelete A_WorkingDir . "\Launcher\Bin\g"
}
If FileExist(A_WorkingDir . "\Launcher\Settings")
	SettingsFileToReg()
Else
	ReadSetReg()
GuiMain()
GetPlayerCount()
Return

; -------------------- Gui Functions -------------------- ;

GuiMain(){
	Global
	Main := Gui("", "Growtopia Launcher")
	EmbedSite_TL := Main.Add("Text", "x30 y260 w400 h478 Background000000")
	SelImg := Main.Add("Picture", "x0 y0", A_WorkingDir . "\Launcher\Images\menu_" . SelFile . ".png")
	Main.Add("Picture", "x30 y20 w400 h200 BackgroundTrans", A_WorkingDir . "\Launcher\Images\logo_1.png")
	Main.SetFont("cFFFFFF s16", "Century Gothic")
	VerText := Main.Add("Text", "x30 y200 w400 BackgroundTrans Center", "`n")
	ServerText := Main.Add("Text", "x401 y602 w590 BackgroundTrans Center", "Loading...")
	GameButton := Main.Add("Picture", "x501 y642 BackgroundTrans", A_WorkingDir . "\Launcher\Images\button_launch_off.png")
	Main.Add("Picture", "x940 y0 BackgroundTrans",  A_WorkingDir . "\Launcher\Images\sidebar.png")
	Main.Add("Picture", "x958 y26 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_close.png").OnEvent("Click", MCloseMain)
	Main.Add("Picture", "x958 y108 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_forums.png").OnEvent("Click", FrLink)
	Main.Add("Picture", "x958 y190 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_instagram.png").OnEvent("Click", IgLink)
	Main.Add("Picture", "x958 y272 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_youtube.png").OnEvent("Click", YtLink)
	Main.Add("Picture", "x958 y354 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_discord.png").OnEvent("Click", DcLink)
	Main.Add("Picture", "x958 y436 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_github.png").OnEvent("Click", GhLink)
	Main.Add("Picture", "x958 y518 BackgroundTrans", A_WorkingDir . "\Launcher\Images\icon_settings.png").OnEvent("Click", GuiSet)
	GetSelFile()
	SelImg.Value := A_WorkingDir . "\Launcher\Images\menu_" . SelFile . ".png"
	MainDisable()
	Main.Show("w1024 h768 Center")
	Global EmbedView_TL := WebView2.create(EmbedSite_TL.Hwnd)
	EmbedView_TL.CoreWebView2.Navigate(EmbedURL[SettingsList[3]])
	GameButton.OnEvent("Click", GameButtonClick)
	Main.OnEvent("Close", MainClose)
	GetGTVer_Main()
	MainEnable()
	Return
}
MainClose(*){
	Global
	FileDelete A_WorkingDir . "\Launcher\Bin\player"
	FileDelete A_WorkingDir . "\Launcher\Bin\s"
	FileDelete A_WorkingDir . "\Launcher\Bin\ver"
	If SettingsList[1] {
		If LauncherWorking {
			If MsgBox("Launcher is still running. Are you sure you want to close now?", "Growtopia Launcher", "YesNo Default2 T5") = "Yes" {
				RunWait A_ComSpec . " /c taskkill /pid " . WinGetPid("ahk_exe msedgewebview2.exe"), , "Hide"
				ExitApp 0
			}
			Return 1
		}
		ExitApp 0
	}
	Main.Minimize()
	Return 1
}
MCloseMain(*){
	Global
	FileDelete A_WorkingDir . "\Launcher\Bin\player"
	FileDelete A_WorkingDir . "\Launcher\Bin\s"
	FileDelete A_WorkingDir . "\Launcher\Bin\ver"
	If LauncherWorking {
		If MsgBox("Launcher is still running. Are you sure you want to close now?", "Growtopia Launcher", "YesNo Default2 T5") = "Yes" {
			RunWait A_ComSpec . " /c taskkill /pid " . WinGetPid("ahk_exe msedgewebview2.exe"), , "Hide"
			ExitApp 0
		}
		Return 1
	}
	If MsgBox("Close Growtopia Launcher?", "Growtopia Launcher", "YesNo Default1 T5") = "No"
		Return 1
	RunWait A_ComSpec . " /c taskkill /pid " . WinGetPid("ahk_exe msedgewebview2.exe"), , "Hide"
	ExitApp 0
}
GameButtonClick(*){
	Global
	MainDisable()
	If(StrLower(GameButtonMode) = "install")
		InstallGT()
	Else If(StrLower(GameButtonMode) = "update")
		UpdateGT()
	Else If(StrLower(GameButtonMode) = "launch")
		LaunchGT()
	Else If(StrLower(GameButtonMode) = "check")
		GetGTVer_Main()
	MainEnable()
	Return
}
FrLink(*){
	If GetKeyState("Ctrl")
		EmbedView_TL.CoreWebView2.Navigate("https://www.growtopiagame.com/forums/forum/general/announcements")
	Else
		Run "https://www.growtopiagame.com/forums/forum/general/announcements"
	Return
}
IgLink(*){
	If GetKeyState("Ctrl")
		EmbedView_TL.CoreWebView2.Navigate("https://www.instagram.com/growtopia?theme=dark")
	Else
		Run "https://www.instagram.com/growtopia?theme=dark"
	Return
}
YtLink(*){
	If GetKeyState("Ctrl")
		EmbedView_TL.CoreWebView2.Navigate("https://www.youtube.com/c/growtopiaofficial")
	Else
		Run "https://www.youtube.com/c/growtopiaofficial"
	Return
}
DcLink(*){
	Run "https://discord.com/invite/growtopia"
	Return
}
GhLink(*){
	Run "https://github.com/sadfaceman-gt/Growtopia-Launcher"
	Return
}

GuiSet(*){
	Global
	MainDisable()
	Set := Gui("", "Growtopia Launcher")
	Set.SetFont("c00FF00 s12", "Century Gothic")
	Set.BackColor := "000000"
	GSet1 := Set.Add("Checkbox", "x10 y10 w500", "Quit launcher when closed")
	GSet1.Value := SettingsList[1]
	GSet2 := Set.Add("Checkbox", "x10 y40 w500", "Hide launcher when launching")
	GSet2.Value := SettingsList[2]
	Set.Add("Text", "x10 y70", "Timeline destination")
	GSet3 := Set.Add("DropDownList", "x10 y90 Choose" . SettingsList[3], ["", "Forums", "Instagram", "YouTube", "None"])
	Set.Add("Text", "x10 y130", "Player counter update interval (in seconds)")
	GSet4 := Set.Add("Slider", "x10 y150 Range15-120 Tooltip", SettingsList[4])
	Set.Add("Text", "x10 y180", "Version check interval (in hours)")
	GSet5 := Set.Add("Slider", "x10 y200 Range1-24 Tooltip", SettingsList[5])
	Set.Add("Button", "c000000 x160 y240 h32 w200", "Save and Exit").OnEvent("Click", GuiSetSubmit)
	Set.OnEvent("Close", GuiSetSubmit)
	Set.Show("Center")
	Return
}
GuiSetSubmit(*){
	Global
	SettingsList[1] := GSet1.Value
	SettingsList[2] := GSet2.Value
	SettingsList[3] := GSet3.Value
	SettingsList[4] := GSet4.Value
	SettingsList[5] := GSet5.Value
	SettingsListCheck()
	WriteSetReg()
	Set.Destroy()
	EmbedView_TL.CoreWebView2.Navigate(EmbedURL[SettingsList[3]])
	MainEnable()
	Return
}

; -------------------- Runtime functions -------------------- ;

LogError(exp, mode){
	Global
	If exp.Extra
		exp.Extra := "Specifically : " exp.Extra "`n`t"
	FileAppend FormatTime(, "d MMMM yyyy HH:mm:ss") " - Error on line " exp.Line " :`n`t" exp.What " : " exp.Message "`n`t" exp.Extra "Stack :`n" exp.Stack "`n`n", A_WorkingDir "\Launcher\log.txt"
	Return -1
}

GetPlayerCount(){
	Global
	If FileExist(A_WorkingDir . "\Launcher\Bin\player")
		FileDelete A_WorkingDir . "\Launcher\Bin\player"
	Try
		Download "https://growtopiagame.com/detail", A_WorkingDir . "\Launcher\Bin\player"
	Catch {
		ServerText.Opt("cFF8F1F")
		If OnlineUser < -1
			ServerText.Text := "Failed to get player count"
		Else If not OnlineUserOutdated 
			ServerText.Text := ServerText.Text . FormatTime(, " (HH:mm)")
		OnlineUserOutdated := True
		Return
	}
	GPCFrom := StrSplit(FileRead(A_WorkingDir . "\Launcher\Bin\player"), ",")
	Loop GPCFrom.Length {
		If !InStr(GPCFrom[A_Index], '"online_user"')
			Continue
		OnlineUser := Format("{:d}", RegExReplace(StrReplace(GPCFrom[A_Index], '"online_user"'), '[\{:",]'))
		If OnlineUser < 1 {
			ServerText.Opt("cFF1F1F")
			ServerText.Text := "Server is down"
		} Else If OnlineUser < 100 {
			ServerText.Opt("cFF1F1F")
			ServerText.Text := "Server is down (" . OnlineUser . " online)"
		} Else {
			ServerText.Opt("c1FFF1F")
			ServerText.Text := "Server is up! • " . OnlineUser . " online"
		}
		OnlineUserOutdated := False
		Break
	}
}

InstallGT(){
	Global
	DLPath := A_Temp . "\Growtopia Launcher"
	DLReturn := DownloadFile("https://growtopiagame.com/Growtopia-Installer.exe", DLPath . "\Growtopia-Installer.exe")
	If DLReturn = 1 {
		MsgBox "Download failed. Please try again at another time", "Growtopia Launcher", "OK T5"
		Return
	}
	If DLReturn = 2
		Return
	Install := Gui("", "Growtopia Launcher")
	Install.SetFont("c00FF00 s12", "Century Gothic")
	Install.BackColor := "000000"
	Install.Add("Text", "x10 y10 w300 Center", "Installing Growtopia...")
	Install.Show("Center")
	If FileExist(DLPath . "\Growtopia-Installer")
		DirDelete DLPath . "\Growtopia-Installer", 1
	RunWait A_ComSpec . ' /c 7z x -aos -o"' . DLPath . '\Growtopia-Installer\" "' . DLPath . '\Growtopia-Installer.exe"', A_WorkingDir . "\Launcher\Bin\", "Hide"
	DLPath := A_Temp . "\Growtopia Launcher\Growtopia-Installer"
	If !FileExist(DLPath . "\Growtopia.exe"){
		MsgBox "Couldn't install Growtopia. Please try again at another time", "Growtopia Launcher", "OK T5"
		Install.Destroy()
		If FileExist(DLPath)
			DirDelete DLPath, 1
		Return
	}
	DirDelete DLPath . "\$PLUGINSDIR", 1
	FName := ""
	FExt := ""
	Loop Files DLPath . "\*.*" {
		SplitPath A_LoopFilePath, &FName, , &FExt
		If InStr(StrLower(FName), "vc_redist.x64")
			RunWait A_LoopFilePath
		If ((StrLower(FExt) = "exe") or (StrLower(FExt) = "dll")) and !InStr(StrLower(FName), "vc_redist")
			Continue
		FileDelete A_LoopFilePath
	}
	DirCopy DLPath, A_WorkingDir, 1
	RegWrite FileGetSize(A_Temp . "\Growtopia Launcher\Growtopia-Installer.exe"), "REG_DWORD", "HKCU\Software\Growtopia Launcher", "GTSize"
	DirDelete DLPath, 1
	FileDelete A_Temp . "\Growtopia Launcher\Growtopia-Installer.exe"
	Install.Destroy()
	MsgBox "Growtopia has successfully been installed. Growtopia Launcher will now restart", "Growtopia Launcher", "OK T5"
	RunWait A_ComSpec . " /c taskkill /pid " . WinGetPid("ahk_exe msedgewebview2.exe"), , "Hide"
	Reload
	Return
}

UpdateGT(){
	Global
	DLPath := A_Temp . "\Growtopia Launcher"
	DLReturn := DownloadFile("https://growtopiagame.com/Growtopia-Installer.exe", DLPath . "\Growtopia-Installer.exe")
	If DLReturn = 1 {
		MsgBox "Download failed. Please try again at another time", "Growtopia Launcher", "OK T5"
		Return
	}
	If DLReturn = 2
		Return
	Update := Gui("", "Growtopia Launcher")
	Update.SetFont("c00FF00 s12", "Century Gothic")
	Update.BackColor := "000000"
	Update.Add("Text", "x10 y10 w300 Center", "Updating Growtopia...")
	Update.Show("Center")
	If FileExist(DLPath . "\Growtopia-Installer")
		DirDelete DLPath . "\Growtopia-Installer", 1
	RunWait A_ComSpec . ' /c 7z x -aos -o"' . DLPath . '\Growtopia-Installer\" "' . DLPath . '\Growtopia-Installer.exe"', A_WorkingDir . "\Launcher\Bin\", "Hide"
	DLPath := A_Temp . "\Growtopia Launcher\Growtopia-Installer"
	If !FileExist(DLPath . "\Growtopia.exe"){
		MsgBox "Couldn't update Growtopia. Please try again at another time", "Growtopia Launcher", "OK T5"
		Update.Destroy()
		If FileExist(DLPath)
			DirDelete DLPath, 1
		Return
	}
	DirDelete DLPath . "\$PLUGINSDIR", 1
	FName := ""
	FExt := ""
	Loop Files DLPath . "\*.*" {
		SplitPath A_LoopFilePath, &FName, , &FExt
		If ((StrLower(FExt) = "exe") or (StrLower(FExt) = "dll")) and !InStr(StrLower(FName), "vc_redist")
			Continue
		FileDelete A_LoopFilePath
	}
	DirCopy DLPath, A_WorkingDir, 1
	RegWrite FileGetSize(A_Temp . "\Growtopia Launcher\Growtopia-Installer.exe"), "REG_DWORD", "HKCU\Software\Growtopia Launcher", "GTSize"
	DirDelete DLPath, 1
	FileDelete A_Temp . "\Growtopia Launcher\Growtopia-Installer.exe"
	Update.Destroy()
	MsgBox "Growtopia has successfully been updated. Growtopia Launcher will now restart", "Growtopia Launcher", "OK T5"
	RunWait A_ComSpec . " /c taskkill /pid " . WinGetPid("ahk_exe msedgewebview2.exe"), , "Hide"
	Reload
	Return
}

LaunchGT(){
	Global
	If WinExist("ahk_exe growtopia.exe ahk_class AppClass")
		Return
	If !FileExist(A_WorkingDir . "\Growtopia.exe"){
		GameButtonMode := "Install"
		MsgBox "Something is wrong with your Growtopia installation, please reinstall", "Growtopia Launcher", "OK T5"
		Return
	}
	Run "Growtopia.exe", A_WorkingDir
	If !WinWait("ahk_exe growtopia.exe ahk_class AppClass", , 10){
		MsgBox "Failed to launch Growtopia, try reinstalling or reopening the launcher", "Growtopia Launcher", "OK T5"
		Return
	}
	If SettingsList[2]
		Main.Hide()
	Loop {
		WinWaitClose("ahk_exe growtopia.exe ahk_class AppClass")
		Sleep 3000
		If !WinExist("ahk_exe growtopia.exe ahk_class AppClass")
			Break
	}
	If SettingsList[2]
		Main.Show()
	Else
		Main.Restore()
	Return
}

SetGameButton(){
	Global
	GameButton.Value := A_WorkingDir . "\Launcher\Images\button_" . StrLower(GameButtonMode) . "_" . StrLower(GameButtonState) . ".png"
	If (StrLower(GameButtonMode) = "launch")
		VerText.Text := Format("Launcher v{}`nGrowtopia v{}", LauncherVersion, GTVersion)
	Else If (StrLower(GameButtonMode) = "update")
		VerText.Text := Format("Launcher v{}`nA new update is available! ({})", LauncherVersion, GTVersion)
	Else
		VerText.Text := Format("Launcher v{}`n", LauncherVersion)
	Return
}

SettingsFileToReg(){
	Global
	SettingsFile := FileOpen(A_WorkingDir . "\Launcher\Settings", "r")
	Try {
		Loop SettingsCount {
			SettingsFile.ReadLine()
			SettingsList[A_Index] := Format("{:d}", SettingsFile.ReadLine())
		}
	} Catch {
		SettingsList[1] := 0
		SettingsList[2] := 1
		SettingsList[3] := 3
		SettingsList[4] := 30
		SettingsList[5] := 4
	}
	SettingsFile.Close()
	SettingsListCheck()
	RegDeleteKey "HKCU\Software\Growtopia Launcher"
	RegCreateKey "HKCU\Software\Growtopia Launcher"
	WriteSetReg()
	FileDelete A_WorkingDir . "\Launcher\Settings"
	Return
}

WriteSetReg(){
	Global
	RegCreateKey "HKCU\Software\Growtopia Launcher"
	RegWrite SettingsList[1], "REG_DWORD", "HKCU\Software\Growtopia Launcher", "Set01QuitLauncher"
	RegWrite SettingsList[2], "REG_DWORD", "HKCU\Software\Growtopia Launcher", "Set02HideLauncher"
	RegWrite SettingsList[3], "REG_DWORD", "HKCU\Software\Growtopia Launcher", "Set03TimelineDestination"
	RegWrite SettingsList[4], "REG_DWORD", "HKCU\Software\Growtopia Launcher", "Set04PlayerCounterUpdateInterval"
	RegWrite SettingsList[5], "REG_DWORD", "HKCU\Software\Growtopia Launcher", "Set05VersionCheckInterval"
	Return
}

ReadSetReg(){
	Global
	RegCreateKey "HKCU\Software\Growtopia Launcher"
	SettingsList[1] := RegRead("HKCU\Software\Growtopia Launcher", "Set01QuitLauncher", 0)
	SettingsList[2] := RegRead("HKCU\Software\Growtopia Launcher", "Set02HideLauncher", 1)
	SettingsList[3] := RegRead("HKCU\Software\Growtopia Launcher", "Set03TimelineDestination", 3)
	SettingsList[4] := RegRead("HKCU\Software\Growtopia Launcher", "Set04PlayerCounterUpdateInterval", 30)
	SettingsList[5] := RegRead("HKCU\Software\Growtopia Launcher", "Set05VersionCheckInterval", 4)
	SettingsListCheck()
	Return
}

SettingsListCheck(){
	Global
	If (SettingsList[3] < 1) or (SettingsList[3] > EmbedURL.Length)
		SettingsList[3] := 3
	If (SettingsList[4] < 15) or (SettingsList[4] > 120)
		SettingsList[4] := 30
	If (SettingsList[5] < 1) or (SettingsList[4] > 24)
		SettingsList[5] := 4
	Return
}

GetSelFile(){
	Global
	SelTime := Format("{:d}", FormatTime("", "d") + FormatTime("", "M") * 100)
	SelFile := "0_default"
	If !FileExist(A_WorkingDir "\Launcher\bin\eventbg") {
		FileAppend("-------------------- DO NOT DELETE --------------------`nWelcome to the event background setting file. Here, you set the time as to when to display certain custom backgrounds for the launcher. Here is how the file works.`n-------------------- DO NOT DELETE --------------------`nEach line corresponds to one background, and is formatted as such : StartDate EndDate FileName`n- StartDate refers to the start of when the background image should be shown. The date is formatted as 'MMDD', 'MM' refers to the month number (1-12), and 'DD' refers to the date (1-31). For example, a StartDate of '621' refers to June 21st, and '1130' refers to November 30th.`n- EndDate refers to the end of when the background image should be shown. The date is formatted as 'MMDD', 'MM' refers to the month number (1-12), and 'DD' refers to the date (1-31). For example, a StartDate of '621' refers to June 21st, and '1130' refers to November 30th.`n- FileName refers to the background image file that should be shown. The image file itself must have 'menu_' at the start and '.png' as its extension. The image should be 1028x768 pixels in size. The file must be placed under the 'Launcher\Images' folder. For example, a FileName of 'MyBackground' would select the image file named 'menu_MyBackground.png' inside the 'Launcher\Images' folder.`n-------------------- DO NOT DELETE --------------------`nFor example, the line '601 620 7_pineapple' means that the image file 'menu_7_pineapple.png' should be used between June 1st and June 20th. Note that these numbers are arbitrary (For example, an EndDate of '0231' or February 31st will be accepted, even though it's not a valid date) and can overlap (For example, an end date of '0520' and another start date of '0515' will be accepted). Lines further down will overwrite the ones further up.`n-------------------- DO NOT DELETE --------------------`nDO NOT MODIFY THE CONTENTS OF THIS FILE ABOVE THE LINE THAT SAYS 'DATA STARTS HERE'. If custom backgrounds stops working, reset this file by deleting it.`n-------------------- DATA STARTS HERE --------------------`n105 118 1_anniversary`n128 210 2_newyear`n210 220 3_valentine`n315 325 4_stpatrick`n400 430 5_easter`n501 513 6_cinco`n601 620 7_pineapple`n627 731 8_summer`n810 824 9_paw`n908 930 10_harvest`n1020 1105 11_halloween`n1118 1200 12_thanksgiving`n1210 1231 13_winter", A_WorkingDir "\Launcher\bin\eventbg")
	}
	ebgfile := FileOpen(A_WorkingDir "\Launcher\bin\eventbg", "r")
	Loop 12
		ebgfile.ReadLine()
	While !ebgfile.AtEOF {
		ebgs := StrSplit(ebgfile.ReadLine(), A_Space)
		Try {
			If (Format("{:d}", ebgs[1]) <= SelTime) and (SelTime <= Format("{:d}", ebgs[2]))
				If FileExist(A_WorkingDir "\Launcher\Images\menu_" ebgs[3] ".png")
					SelFile := ebgs[3]
		} Catch
			Continue
	}
	ebgfile.Close()
	Return
}

GetGTVer_Main(){
	Global
	VerText.Text := Format("Launcher v{}`nGetting version info...", LauncherVersion)
	If !FileExist(A_WorkingDir . "\Growtopia.exe"){
		GameButtonMode := "Install"
		Return
	}
	If !RegRead("HKCU\Software\Growtopia Launcher", "GTSize", 0){
		MsgBox "A new version of Growtopia must be installed", "Growtopia Launcher", "OK T5"
		GameButtonMode := "Install"
		Return
	}
	If FileExist(A_WorkingDir . "\Launcher\Bin\ver")
		FileDelete A_WorkingDir . "\Launcher\Bin\ver"
	RunWait A_ComSpec " /c versionscrape.exe", A_WorkingDir . "\Launcher\Bin", "Hide"
	If !FileExist(A_WorkingDir . "\Launcher\Bin\ver"){
		MsgBox "Failed to check for an update, please try again", "Growtopia Launcher", "OK T5"
		GameButtonMode := "Check"
		Return
	}
	If !FileRead(A_WorkingDir . "\Launcher\Bin\ver"){
		MsgBox "Failed to check for an update, please try again", "Growtopia Launcher", "OK T5"
		GameButtonMode := "Check"
		Return
	}
	FVer := StrSplit(FileRead(A_WorkingDir . "\Launcher\Bin\ver"), ",")
	Loop FVer.Length {
		If InStr(FVer[A_Index], "'version':"){
			GTVersion := Format("{:0.2f}", SubStr(FVer[A_Index], 14, 4))
			Break
		}
	}
	If FileExist(A_WorkingDir . "\Launcher\Bin\s")
		FileDelete A_WorkingDir . "\Launcher\Bin\s"
	RunWait A_ComSpec " /c sizequery.exe", A_WorkingDir . "\Launcher\Bin", "Hide"
	If !FileExist(A_WorkingDir . "\Launcher\Bin\s"){
		MsgBox "Failed to check for an update. Please try again", "Growtopia Launcher", "OK T5"
		GameButtonMode := "Check"
		Return
	}
	Try {
		Format("{:d}", RegRead("HKCU\Software\Growtopia Launcher", "GTSize", 0))
		Format("{:d}", FileRead(A_WorkingDir . "\Launcher\Bin\s"))
	} Catch {
		MsgBox "Failed to check for an update. Please try again", "Growtopia Launcher", "OK T5"
		GameButtonMode := "Check"
		Return
	}
	If Format("{:d}", RegRead("HKCU\Software\Growtopia Launcher", "GTSize", 0)) != Format("{:d}", FileRead(A_WorkingDir . "\Launcher\Bin\s")){
		GameButtonMode := "Update"
		Return
	}
	GameButtonMode := "Launch"
	Return
}
GetGTVer(){
	GetGTVer_Main()
	SetGameButton()
}

DownloadFile(URL, FTarget){
	Global
	Target := FTarget
	FName := ""
	FDir := ""
	SplitPath Target, &FName, &FDir
	If !FileExist(FDir)
		DirCreate FDir
	If FileExist(FDir . "\Downloader.ahk")
		FileDelete FDir . "\Downloader.ahk"
	If FileExist(FDir . "\Downloader.exe")
		FileDelete FDir . "\Downloader.exe"
	DProg := Gui("-Sysmenu", "Growtopia Launcher")
	DProg.SetFont("c00FF00 s12", "Century Gothic")
	DProg.BackColor := "000000"
	ProgText := DProg.Add("Text", "w500 Center", "Downloading : 000.00 MB of 000.00 MB (100.0%)")
	DProg.SetFont("c00FF00 s10", "Century Gothic")
	DProg.Add("Text", "y40 x10 w500 Center", "Press (Ctrl + Shift + X) to cancel download")
	ProgText.Text := "Calculating progress..."
	DProg.Title := "Growtopia Launcher : Downloading " . FName
	DProg.Show("Center")
	If FileExist(A_WorkingDir . "\Launcher\Bin\s")
		FileDelete A_WorkingDir . "\Launcher\Bin\s"
	RunWait A_ComSpec " /c sizequery.exe", A_WorkingDir . "\Launcher\Bin", "Hide"
	If !FileExist(A_WorkingDir . "\Launcher\Bin\s"){
		DProg.Destroy()
		Return 1
	}
	Try
		SizeNow := Format("{:d}", FileRead(A_WorkingDir . "\Launcher\Bin\s"))
	Catch {
		Dprog.Destroy()
		Return 1
	}
	If FileExist(Target){
		If SizeNow = FileGetSize(Target){
			DProg.Destroy()
			Return 0
		}
		FileDelete Target
	}
	DvsorArray := [1, 1000, 1000000, 1000000000]
	DenomArray := ["B", "KB", "MB", "GB"]
	If Format("{:d}", (Log(SizeNow) / Log(1000))) + 1 > DvsorArray.Length {
		Dvsor := DvsorArray[DvsorArray.Length]
		Denom := DenomArray[DvsorArray.Length]
	} Else {
		Dvsor := DvsorArray[Format("{:d}", (Log(SizeNow) / Log(1000))) + 1]
		Denom := DenomArray[Format("{:d}", (Log(SizeNow) / Log(1000))) + 1]
	}
	SizeNow := Format("{:0.2f}", SizeNow / Dvsor)
	SetTimer DLProgQuery, 100
	FileAppend 'Try`n`tDownload "' . URL . '", "' . Target . '"`nCatch`n`tFileDelete "' . Target . '"`nExitApp', FDir . "\Downloader.ahk"
	RunWait A_ComSpec . ' /c ahk2exe /in "' . FDir . '\Downloader.ahk" /out "' . FDir . '\Downloader.exe" /base "AutoHotkeyUX.exe"', A_WorkingDir . "\Launcher\Bin\", "Hide"
	FileDelete FDir . "\Downloader.ahk"
	If !FileExist(FDir . "\Downloader.exe"){
		DProg.Destroy()
		SetTimer DLProgQuery, 0
		Return 1
	}
	DLPID := 0
	Run FDir . "\Downloader.exe", , , &DLPID
	If !WinWait("ahk_pid " . DLPID, , 10){
		RunWait A_ComSpec . " /c taskkill /pid " . DLPID, , "Hide"
		DProg.Destroy()
		SetTimer DLProgQuery, 0
		FileDelete FDir . "\Downloader.exe"
		Return 1
	}
	DLInterrupt := False
	DLProgress := True
	WinWaitClose "ahk_pid " . DLPID
	DLProgress := False
	SetTimer DLProgQuery, 0
	FileDelete FDir . "\Downloader.exe"
	DProg.Destroy()
	If !FileExist(Target)
		Return 1
	If DLInterrupt {
		DLInterrupt := False
		FileDelete Target
		Return 2
	}
	Return 0
}
; Return 0 - OK
; Return 1 - Failed to download
; Return 2 - Canceled
DLProgQuery(){
	Global
	If !FileExist(Target)
		SizeDL := Format("{:0.2f}", 0.00)
	Else
		SizeDL := Format("{:0.2f}", FileGetSize(Target) / Dvsor)
	ProgText.Text := "Downloading : " . SizeDL . " " . Denom . " of " . SizeNow . " " . Denom . " (" . Format("{:0.1f}", 100 * SizeDL / SizeNow) . "%)"
	Return
}
^+x:: {
	Global
	If !DLProgress
		Return
	Critical "On"
	If(MsgBox("Are you sure you want to cancel download?", "Growtopia Launcher", "YesNo Default2 T15") = "Yes"){
		DLInterrupt := True
		RunWait A_ComSpec . " /c taskkill /pid " . DLPID, , "Hide"
		Return
	}
}

MainDisable(){
	Global
	LauncherWorking := True
	GameButton.Enabled := False
	GameButtonState := "Off"
	SetGameButton()
	SetTimer GetPlayerCount, 0
	SetTimer GetGTVer, 0
	Return
}

MainEnable(){
	Global
	GameButton.Enabled := True
	GameButtonState := "On"
	GetPlayerCount()
	SetGameButton()
	SetTimer GetPlayerCount, SettingsList[4] * 1000
	SetTimer GetGTVer, SettingsList[5] * 3600 * 1000
	LauncherWorking := False
	Return
}
