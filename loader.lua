getgenv().__brick_loader_cfg = {
    api_url = "http://2.59.58.83:25012",
    script_slug = "rod_and_reef",
    loader_url = "https://raw.githubusercontent.com/brick-hub-rblx/Rod_And_Reef/refs/heads/main/loader.lua",
}
local brick_key = (function()
local genv = getgenv and getgenv() or _G
local ref = cloneref or function(object)
    return object
end
local http = ref(game:GetService("HttpService"))
local run_service = ref(game:GetService("RunService"))
local players_service = ref(game:GetService("Players"))
local user_input = ref(game:GetService("UserInputService"))

local loader_cfg = type(genv.__brick_loader_cfg) == "table" and genv.__brick_loader_cfg or {}
local api_url = loader_cfg.api_url or "http://2.59.58.83:25012"
local script_slug = loader_cfg.script_slug or "aotr"
local discord_url = "https://discord.gg/mFKncuFBq2"
local save_file = "LazyHub/brick_login.json"
local settings_file = "LazyHub/lazy_ui.json"
local recheck_seconds = 600
local network_retries = 3

local request_fn = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
local can_files = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"

local texts = {
    fr = {
        title = "Connexion",
        username = "Pseudo",
        password = "Mot de passe",
        login = "Se connecter",
        checking = "Vérification...",
        hwid = "HWID",
        copy_hwid = "Copier le HWID",
        copy_discord = "Copier le Discord",
        copied = "Copié",
        show = "Voir",
        hide = "Cacher",
        no_account = "Pas de compte ? Écris au bot BrickHub en message privé : /register",
        welcome = "Connecté",
        invalid_credentials = "Pseudo ou mot de passe incorrect.",
        no_key = "Aucune clé sur ce compte. Active-en une avec /key activate.",
        expired = "Ta clé est expirée.",
        revoked = "Ta clé a été révoquée.",
        hwid_mismatch = "Ce compte est lié à une autre machine. Fais /hwid reset sur Discord.",
        script_denied = "Ta clé ne donne pas accès à ce script.",
        no_files = "Le script n'est pas encore publié sur le serveur.",
        unknown_script = "Ce script n'est pas encore enregistré sur le serveur de clés.",
        hwid_taken = "Cette machine est déjà liée à un autre compte.",
        locked = "Trop d'essais. Réessaie dans 15 minutes.",
        rate_limited = "Trop de requêtes. Patiente une minute.",
        bad_request = "Pseudo (3 à 20 caractères : lettres, chiffres, _) ou mot de passe (8 minimum) invalide.",
        server_error = "Erreur du serveur de clés. Réessaie plus tard.",
        network = "Serveur de clés injoignable.",
        no_request = "Cet executor ne permet pas les requêtes HTTP.",
        no_hwid = "HWID introuvable sur cet executor.",
        revoked_midway = "Accès retiré : le script s'arrête.",
    },
    en = {
        title = "Login",
        username = "Username",
        password = "Password",
        login = "Log in",
        checking = "Checking...",
        hwid = "HWID",
        copy_hwid = "Copy HWID",
        copy_discord = "Copy Discord",
        copied = "Copied",
        show = "Show",
        hide = "Hide",
        no_account = "No account? DM the BrickHub bot: /register",
        welcome = "Logged in",
        invalid_credentials = "Wrong username or password.",
        no_key = "No key on this account. Activate one with /key activate.",
        expired = "Your key has expired.",
        revoked = "Your key has been revoked.",
        hwid_mismatch = "This account is bound to another machine. Use /hwid reset on Discord.",
        script_denied = "Your key does not give access to this script.",
        no_files = "The script is not published on the server yet.",
        unknown_script = "This script is not registered on the key server yet.",
        hwid_taken = "This machine is already bound to another account.",
        locked = "Too many attempts. Try again in 15 minutes.",
        rate_limited = "Too many requests. Wait a minute.",
        bad_request = "Invalid username (3-20 chars: letters, digits, _) or password (8 minimum).",
        server_error = "Key server error. Try again later.",
        network = "Key server unreachable.",
        no_request = "This executor does not allow HTTP requests.",
        no_hwid = "HWID not available on this executor.",
        revoked_midway = "Access removed: the script is stopping.",
    },
}

local function read_json(path)
    if not can_files then
        return nil
    end
    local ok, decoded = pcall(function()
        if isfile(path) then
            return http:JSONDecode(readfile(path))
        end
        return nil
    end)
    if ok and type(decoded) == "table" then
        return decoded
    end
    return nil
end

local function current_texts()
    local settings = read_json(settings_file)
    if settings and settings.lang == "fr" then
        return texts.fr
    end
    return texts.en
end

local function get_hwid()
    if type(gethwid) == "function" then
        local ok, value = pcall(gethwid)
        if ok and type(value) == "string" and #value >= 8 then
            return value
        end
    end
    local ok, value = pcall(function()
        return ref(game:GetService("RbxAnalyticsService")):GetClientId()
    end)
    if ok and type(value) == "string" and #value >= 8 then
        return value
    end
    return nil
end

local function valid_username(value)
    return type(value) == "string" and #value >= 3 and #value <= 20 and value:match("^[%w_]+$") ~= nil
end

local function valid_password(value)
    return type(value) == "string" and #value >= 8 and #value <= 128
end

local function verify(username, password, hwid)
    if type(request_fn) ~= "function" then
        return { ok = false, reason = "no_request" }
    end
    local ok, response = pcall(request_fn, {
        Url = api_url .. "/v1/verify",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = http:JSONEncode({ username = username, password = password, hwid = hwid, script = script_slug }),
    })
    if not ok or type(response) ~= "table" or type(response.Body) ~= "string" then
        return { ok = false, reason = "network" }
    end
    local decoded_ok, body = pcall(function()
        return http:JSONDecode(response.Body)
    end)
    if not decoded_ok or type(body) ~= "table" then
        return { ok = false, reason = "network" }
    end
    if body.ok == true then
        return { ok = true, lifetime = body.lifetime == true, expires = body.expires }
    end
    return { ok = false, reason = type(body.reason) == "string" and body.reason or "server_error" }
end

local function verify_with_retry(username, password, hwid)
    local result = verify(username, password, hwid)
    local attempt = 1
    while not result.ok and result.reason == "network" and attempt < network_retries do
        task.wait(2)
        attempt += 1
        result = verify(username, password, hwid)
    end
    return result
end

local function save_credentials(username, password)
    if not can_files then
        return
    end
    pcall(function()
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("LazyHub") then
            makefolder("LazyHub")
        end
        writefile(save_file, http:JSONEncode({ username = username, password = password }))
    end)
end

local function clear_credentials()
    if not can_files then
        return
    end
    pcall(function()
        if not isfile(save_file) then
            return
        end
        if type(delfile) == "function" then
            delfile(save_file)
        else
            writefile(save_file, "{}")
        end
    end)
end

local function copy_text(value)
    local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if type(clip) ~= "function" then
        return false
    end
    return pcall(clip, value)
end

local palette = {
    background = Color3.fromRGB(30, 30, 30),
    panel = Color3.fromRGB(37, 37, 38),
    bar = Color3.fromRGB(50, 50, 51),
    border = Color3.fromRGB(60, 60, 60),
    field = Color3.fromRGB(60, 60, 60),
    accent = Color3.fromRGB(14, 99, 156),
    accent_hover = Color3.fromRGB(28, 151, 234),
    accent_text = Color3.new(1, 1, 1),
    text = Color3.fromRGB(204, 204, 204),
    muted = Color3.fromRGB(133, 133, 133),
    bad = Color3.fromRGB(244, 71, 71),
    good = Color3.fromRGB(78, 201, 176),
}

local theme_keys = {
    "bg", "side", "bar", "border", "text", "muted", "accent",
    "accent_text", "status", "status_text", "select", "input", "off",
}
local theme_rows = {
    ["Dark+"] =
        "1e1e1e 252526 323233 3c3c3c d4d4d4 858585 0e639c " ..
        "ffffff 007acc ffffff 37373d 3c3c3c 5a5a5a",
    ["Light+"] =
        "ffffff f3f3f3 dddddd cecece 333333 6e6e6e 007acc " ..
        "ffffff 007acc ffffff e4e6f1 ffffff b0b0b0",
    ["Monokai"] =
        "272822 1e1f1c 1e1f1c 3e3d32 f8f8f2 75715e a6e22e " ..
        "272822 75715e f8f8f2 414339 3e3d32 5b5a4d",
    ["Solarized Dark"] =
        "002b36 00212b 00212b 073642 93a1a1 586e75 268bd2 " ..
        "fdf6e3 268bd2 fdf6e3 073642 073642 586e75",
    ["One Dark Pro"] =
        "282c34 21252b 21252b 181a1f abb2bf 5c6370 61afef " ..
        "21252b 21252b 9da5b4 2c313a 1d1f23 4b5263",
    ["Dracula"] =
        "282a36 21222c 191a21 191a21 f8f8f2 6272a4 bd93f9 " ..
        "282a36 bd93f9 282a36 44475a 343746 4a4d5f",
    ["GitHub Dark"] =
        "0d1117 010409 161b22 30363d c9d1d9 8b949e 238636 " ..
        "ffffff 1f6feb ffffff 161b22 0d1117 484f58",
    ["Nord"] =
        "2e3440 3b4252 3b4252 2e3440 d8dee9 7b88a1 88c0d0 " ..
        "2e3440 5e81ac eceff4 434c5e 3b4252 566075",
    ["Tokyo Night"] =
        "1a1b26 16161e 16161e 101014 a9b1d6 565f89 7aa2f7 " ..
        "16161e 3d59a1 ffffff 292e42 24283b 414868",
    ["Night Owl"] =
        "011627 010e1a 010b14 122d42 d6deeb 5f7e97 82aaff " ..
        "011627 5f7e97 ffffff 0b2942 0b253a 3c556b",
    ["Brique"] =
        "1f1a1d 262023 2b2226 3a2f33 f0e8e6 9c8a8c d65638 " ..
        "ffffff d65638 ffffff 3a2d30 2c2427 5e5054",
}

local function parse_theme_row(row)
    if type(row) ~= "string" then
        return nil
    end
    local colors = {}
    local count = 0
    for code in string.gmatch(row, "%S+") do
        if not string.match(code, "^%x%x%x%x%x%x$") then
            return nil
        end
        count += 1
        colors[theme_keys[count]] = Color3.fromHex(code)
    end
    if count ~= #theme_keys then
        return nil
    end
    return colors
end

local function apply_gui_theme()
    local settings = read_json(settings_file)
    local colors = nil
    if settings then
        if settings.theme == "Custom" then
            colors = parse_theme_row(settings.custom)
        elseif type(settings.theme) == "string" then
            colors = parse_theme_row(theme_rows[settings.theme])
        end
    end
    colors = colors or parse_theme_row(theme_rows["Dark+"])
    local accent = colors.accent
    local brightness = accent.R * 0.299 + accent.G * 0.587 + accent.B * 0.114
    local toward = brightness > 0.6 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
    palette.background = colors.bg
    palette.panel = colors.side
    palette.bar = colors.bar
    palette.border = colors.border
    palette.field = colors.input
    palette.accent = accent
    palette.accent_hover = accent:Lerp(toward, 0.18)
    palette.accent_text = colors.accent_text
    palette.text = colors.text
    palette.muted = colors.muted
end

local function make(class_name, props, parent)
    local object = Instance.new(class_name)
    for key, value in props do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local tween_service = ref(game:GetService("TweenService"))
local hover_info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function hover_fill(button, normal, over)
    button.MouseEnter:Connect(function()
        tween_service:Create(button, hover_info, { BackgroundColor3 = over }):Play()
    end)
    button.MouseLeave:Connect(function()
        tween_service:Create(button, hover_info, { BackgroundColor3 = normal }):Play()
    end)
end

local function hover_text(button, normal, over)
    button.MouseEnter:Connect(function()
        tween_service:Create(button, hover_info, { TextColor3 = over }):Play()
    end)
    button.MouseLeave:Connect(function()
        tween_service:Create(button, hover_info, { TextColor3 = normal }):Play()
    end)
end

local transient_reasons = { network = true, server_error = true, rate_limited = true }

local function is_pointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local action_service = ref(game:GetService("ContextActionService"))
local sink_keys = nil

local function sink_action()
    return Enum.ContextActionResult.Sink
end

local function bind_key_sink(name)
    if not sink_keys then
        sink_keys = {}
        for _, key in Enum.KeyCode:GetEnumItems() do
            if key ~= Enum.KeyCode.Unknown and key ~= Enum.KeyCode.Escape then
                sink_keys[#sink_keys + 1] = key
            end
        end
    end
    pcall(action_service.BindActionAtPriority, action_service, name, sink_action, false, 9000, table.unpack(sink_keys))
end

local function unbind_key_sink(name)
    pcall(action_service.UnbindAction, action_service, name)
end

local function build_window(strings, hwid, prefill)
    pcall(apply_gui_theme)
    local host = (gethui and gethui()) or game:GetService("CoreGui")
    local container
    if host:IsA("LayerCollector") then
        container = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 100,
        }, nil)
    else
        container = make("ScreenGui", { ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 }, nil)
    end
    container.Name = http:GenerateGUID(false)

    local main = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(340, 330),
        BackgroundColor3 = palette.background,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 101,
    }, container)
    round(main, 8)
    make("UIStroke", { Color = palette.border, Thickness = 1 }, main)

    local bar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = palette.bar,
        BorderSizePixel = 0,
        ZIndex = 102,
    }, main)
    round(bar, 8)
    make("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "BRICKHUB  |  " .. strings.title,
        TextColor3 = palette.text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 103,
    }, bar)
    local close = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextColor3 = palette.muted,
        TextSize = 14,
        ZIndex = 103,
    }, bar)

    local function field(y, placeholder)
        local frame = make("Frame", {
            Position = UDim2.fromOffset(20, y),
            Size = UDim2.new(1, -40, 0, 36),
            BackgroundColor3 = palette.field,
            BorderSizePixel = 0,
            ZIndex = 102,
        }, main)
        round(frame, 6)
        make("UIStroke", { Color = palette.border, Thickness = 1 }, frame)
        local box = make("TextBox", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 1, 0),
            BackgroundTransparency = 1,
            ClearTextOnFocus = false,
            Font = Enum.Font.Gotham,
            PlaceholderText = placeholder,
            PlaceholderColor3 = palette.muted,
            Text = "",
            TextColor3 = palette.text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClipsDescendants = true,
            ZIndex = 103,
        }, frame)
        return frame, box
    end

    local _, user_box = field(54, strings.username)
    local pass_frame, pass_box = field(100, strings.password)
    pass_box.Size = UDim2.new(1, -70, 1, 0)
    pass_box.TextTransparency = 1
    local mask = make("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = palette.text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
        ZIndex = 104,
    }, pass_frame)
    local reveal = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(50, 26),
        BackgroundColor3 = palette.panel,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = strings.show,
        TextColor3 = palette.muted,
        TextSize = 12,
        ZIndex = 105,
    }, pass_frame)
    round(reveal, 5)
    local revealed = false
    local function refresh_mask()
        if revealed then
            mask.Text = pass_box.Text
        else
            mask.Text = string.rep("•", utf8.len(pass_box.Text) or #pass_box.Text)
        end
    end
    pass_box:GetPropertyChangedSignal("Text"):Connect(refresh_mask)
    for _, box in { user_box, pass_box } do
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if box.Text:find("\t", 1, true) then
                box.Text = box.Text:gsub("\t", "")
            end
        end)
    end
    reveal.MouseButton1Click:Connect(function()
        revealed = not revealed
        reveal.Text = revealed and strings.hide or strings.show
        refresh_mask()
    end)

    local status = make("TextLabel", {
        Position = UDim2.fromOffset(20, 146),
        Size = UDim2.new(1, -40, 0, 40),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = palette.muted,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 102,
    }, main)

    local login = make("TextButton", {
        Position = UDim2.fromOffset(20, 192),
        Size = UDim2.new(1, -40, 0, 38),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = strings.login,
        TextColor3 = palette.accent_text,
        TextSize = 14,
        ZIndex = 102,
    }, main)
    round(login, 6)

    make("TextLabel", {
        Position = UDim2.fromOffset(20, 240),
        Size = UDim2.new(1, -40, 0, 30),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = strings.no_account,
        TextColor3 = palette.muted,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 102,
    }, main)

    local function small_button(x, width, text)
        local button = make("TextButton", {
            Position = UDim2.fromOffset(x, 280),
            Size = UDim2.fromOffset(width, 30),
            BackgroundColor3 = palette.panel,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Text = text,
            TextColor3 = palette.text,
            TextSize = 12,
            ZIndex = 102,
        }, main)
        round(button, 6)
        make("UIStroke", { Color = palette.border, Thickness = 1 }, button)
        return button
    end
    local copy_hwid = small_button(20, 140, strings.copy_hwid)
    local copy_discord = small_button(170, 150, strings.copy_discord)

    local function flash(button, original)
        button.Text = strings.copied
        task.delay(1.2, function()
            if button.Parent then
                button.Text = original
            end
        end)
    end
    copy_hwid.MouseButton1Click:Connect(function()
        if copy_text(hwid) then
            flash(copy_hwid, strings.copy_hwid)
        end
    end)
    copy_discord.MouseButton1Click:Connect(function()
        if copy_text(discord_url) then
            flash(copy_discord, strings.copy_discord)
        end
    end)

    local dragging, drag_origin, frame_origin = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if is_pointer(input) then
            dragging = true
            drag_origin = input.Position
            frame_origin = main.Position
        end
    end)
    bar.InputEnded:Connect(function(input)
        if is_pointer(input) then
            dragging = false
        end
    end)
    local drag_conn = user_input.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag_origin
            main.Position = UDim2.new(
                frame_origin.X.Scale,
                frame_origin.X.Offset + delta.X,
                frame_origin.Y.Scale,
                frame_origin.Y.Offset + delta.Y
            )
        end
    end)

    local tab_conn = user_input.InputBegan:Connect(function(input)
        if input.KeyCode ~= Enum.KeyCode.Tab then
            return
        end
        local focused = user_input:GetFocusedTextBox()
        local target = nil
        if focused == user_box then
            target = pass_box
        elseif focused == pass_box then
            target = user_box
        end
        if target then
            target:CaptureFocus()
            task.defer(function()
                focused.Text = focused.Text:gsub("\t", "")
            end)
        end
    end)

    hover_fill(login, palette.accent, palette.accent_hover)
    hover_fill(reveal, palette.panel, palette.border)
    hover_fill(copy_hwid, palette.panel, palette.border)
    hover_fill(copy_discord, palette.panel, palette.border)
    hover_text(close, palette.muted, palette.bad)

    local sink_name = http:GenerateGUID(false)
    bind_key_sink(sink_name)

    local mouse_bind = http:GenerateGUID(false)
    local saved_icon = user_input.MouseIconEnabled
    run_service:BindToRenderStep(mouse_bind, Enum.RenderPriority.Last.Value + 1, function()
        if not user_input.MouseIconEnabled then
            user_input.MouseIconEnabled = true
        end
        if user_input.MouseBehavior ~= Enum.MouseBehavior.Default then
            user_input.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)

    if prefill then
        user_box.Text = prefill.username or ""
    end
    local pop_scale = make("UIScale", { Scale = 0.88 }, main)
    tween_service:Create(
        pop_scale,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
    container.Parent = host

    local window = {
        user_box = user_box,
        pass_box = pass_box,
        status = status,
        login = login,
        close = close,
    }
    function window.destroy()
        drag_conn:Disconnect()
        tab_conn:Disconnect()
        unbind_key_sink(sink_name)
        pcall(run_service.UnbindFromRenderStep, run_service, mouse_bind)
        user_input.MouseIconEnabled = saved_icon
        container:Destroy()
    end
    function window.set_status(text, color)
        status.Text = text
        status.TextColor3 = color
    end
    return window
end

local function start_watcher(username, password, hwid, strings)
    local token = {}
    genv.__brick_key_watch = token
    task.spawn(function()
        while genv.__brick_key_watch == token do
            task.wait(recheck_seconds)
            if genv.__brick_key_watch ~= token then
                return
            end
            local result = verify(username, password, hwid)
            if result.ok then
                genv.__brick_account.lifetime = result.lifetime
                genv.__brick_account.expires = result.expires
            elseif not transient_reasons[result.reason] then
                warn("[brick_key] " .. strings.revoked_midway .. " (" .. tostring(result.reason) .. ")")
                genv.__brick_key_watch = nil
                if type(genv.__titan_hub_unload) == "function" then
                    pcall(genv.__titan_hub_unload)
                end
                return
            end
        end
    end)
end

local session = nil

local function finish_success(username, password, hwid, result, strings)
    session = { username = username, password = password, hwid = hwid }
    genv.__brick_account = {
        username = username,
        hwid = hwid,
        lifetime = result.lifetime,
        expires = result.expires,
    }
    save_credentials(username, password)
    start_watcher(username, password, hwid, strings)
end

local guard_source = [==[
local genv = getgenv()
if genv.__brick_input_guard then
    pcall(genv.__brick_input_guard.stop)
    genv.__brick_input_guard = nil
end
local uis = game:GetService("UserInputService")
local run_service = game:GetService("RunService")
local player_gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local ok, input_module = pcall(require, game:GetService("ReplicatedStorage").Modules.Core.Input)
if not ok or type(input_module) ~= "table" or type(input_module.Actions) ~= "table" then
    return
end
local saved = {}
local active = false
local function block()
    if active then
        return
    end
    active = true
    for index, action in input_module.Actions do
        saved[index] = action.Key
        action.Key = "BrickGuard"
    end
end
local function release()
    if not active then
        return
    end
    active = false
    for index, action in input_module.Actions do
        if saved[index] ~= nil then
            action.Key = saved[index]
        end
    end
    table.clear(saved)
end
local focus_conn = uis.TextBoxFocused:Connect(function(box)
    if not (player_gui and box:IsDescendantOf(player_gui)) then
        block()
    end
end)
local release_conn = uis.TextBoxFocusReleased:Connect(release)
local beat_conn = run_service.Heartbeat:Connect(function()
    if active and not uis:GetFocusedTextBox() then
        release()
    end
end)
genv.__brick_input_guard = {
    stop = function()
        focus_conn:Disconnect()
        release_conn:Disconnect()
        beat_conn:Disconnect()
        release()
    end,
}
]==]

local function start_input_guard()
    local player = players_service.LocalPlayer
    local scripts = player and player:FindFirstChild("PlayerScripts")
    local actor = scripts and scripts:FindFirstChild("Actor")
    if actor and type(run_on_actor) == "function" then
        pcall(run_on_actor, actor, guard_source)
    end
end

local function run()
    local strings = current_texts()
    if genv.__brick_login_open then
        return false
    end
    start_input_guard()
    if type(request_fn) ~= "function" then
        warn("[brick_key] " .. strings.no_request)
        return false
    end
    local hwid = get_hwid()
    if not hwid then
        warn("[brick_key] " .. strings.no_hwid)
        return false
    end

    local saved = read_json(save_file)
    local last_reason = nil
    if saved and valid_username(saved.username) and valid_password(saved.password) then
        local result = verify_with_retry(saved.username, saved.password, hwid)
        if result.ok then
            finish_success(saved.username, saved.password, hwid, result, strings)
            return true
        end
        last_reason = result.reason
        if result.reason == "invalid_credentials" then
            clear_credentials()
        end
    end

    genv.__brick_login_open = true
    local window = build_window(strings, hwid, saved)
    if last_reason and strings[last_reason] then
        window.set_status(strings[last_reason], palette.bad)
    end

    local outcome = nil
    local busy = false
    local function submit()
        if busy or outcome ~= nil then
            return
        end
        local username = window.user_box.Text:gsub("%s+", "")
        local password = window.pass_box.Text:gsub("\t", "")
        if not valid_username(username) or not valid_password(password) then
            window.set_status(strings.bad_request, palette.bad)
            return
        end
        busy = true
        window.login.Text = strings.checking
        window.set_status(strings.checking, palette.muted)
        task.spawn(function()
            local result = verify_with_retry(username, password, hwid)
            if result.ok then
                finish_success(username, password, hwid, result, strings)
                window.set_status(strings.welcome, palette.good)
                task.wait(0.4)
                outcome = true
            else
                window.set_status(strings[result.reason] or strings.server_error, palette.bad)
                window.login.Text = strings.login
                busy = false
            end
        end)
    end
    window.login.MouseButton1Click:Connect(submit)
    window.user_box.FocusLost:Connect(function(enter_pressed)
        if enter_pressed then
            window.pass_box:CaptureFocus()
        end
    end)
    window.pass_box.FocusLost:Connect(function(enter_pressed)
        if enter_pressed then
            submit()
        end
    end)
    window.close.MouseButton1Click:Connect(function()
        if outcome == nil then
            outcome = false
        end
    end)

    while outcome == nil do
        task.wait(0.1)
    end
    window.destroy()
    genv.__brick_login_open = nil
    return outcome
end

local function launch()
    local strings = current_texts()
    if not session or type(request_fn) ~= "function" then
        return false
    end
    local ok, response = pcall(request_fn, {
        Url = api_url .. "/v1/bundle",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = http:JSONEncode({
            username = session.username,
            password = session.password,
            hwid = session.hwid,
            script = script_slug,
        }),
    })
    if not ok or type(response) ~= "table" or type(response.Body) ~= "string" then
        warn("[brick_key] " .. strings.network)
        return false
    end
    local decoded_ok, body = pcall(function()
        return http:JSONDecode(response.Body)
    end)
    if not decoded_ok or type(body) ~= "table" then
        warn("[brick_key] " .. strings.network)
        return false
    end
    if body.ok ~= true or type(body.files) ~= "table" or type(body.entry) ~= "string" then
        local reason = type(body.reason) == "string" and body.reason or "server_error"
        warn("[brick_key] " .. (strings[reason] or strings.server_error))
        return false
    end
    local entry_source = body.files[body.entry]
    if type(entry_source) ~= "string" then
        warn("[brick_key] " .. strings.no_files)
        return false
    end
    local entry_fn, load_error = loadstring(entry_source, "=" .. body.entry)
    if not entry_fn then
        warn("[brick_key] " .. tostring(load_error))
        return false
    end
    genv.__brick_files = body.files
    genv.__brick_loader_session = true
    genv.__brick_loader_url = loader_cfg.loader_url
    local run_ok, run_error = pcall(entry_fn)
    if not run_ok then
        warn("[brick_key] " .. tostring(run_error))
    end
    return true
end

local function logout()
    genv.__brick_key_watch = nil
    genv.__brick_account = nil
    genv.__brick_loader_session = nil
    genv.__brick_files = nil
    session = nil
    clear_credentials()
end

return { run = run, logout = logout, launch = launch }
end)()
getgenv().__brick_key_module = brick_key
if brick_key.run() then
    brick_key.launch()
end
