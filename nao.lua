
local ccStringsUrl = "https://raw.githubusercontent.com/SquidDev-CC/CC-Tweaked/f7e3e72a6e8653f192b7dfad6cf4d072232e7259/src/main/resources/data/computercraft/lua/rom/modules/main/cc/strings.lua"

package.path =  "/modules/main/?;/modules/main/?.lua;/modules/main/?/init.lua;"..package.path

if not pcall(require, "cc.strings") then
    print("Attempting to download required module (cc.strings) from CC-Tweaked GitHub.")
    print("This should only happen once per computer.")

    local httpHandle, err = http.get(ccStringsUrl)
    if not httpHandle then
        printError("Error downloading file.")
        error(err, 0)
    end

    local file, err = fs.open("modules/main/cc/strings.lua", "w")
    if not file then
        httpHandle.close()
        printError("Error saving downloaded file.")
        error(err, 0)
    end
    file.write(httpHandle.readAll())
    httpHandle.close()
    file.close()

    print("Downloaded to /modules/main/cc/strings.lua")
    print("Press any key to continue")
    os.pullEvent("key")
end

local strings = require("cc.strings")

settings.load()

if not settings.get("nao.refreshInterval") then
    settings.define("nao.keys.refresh", { default = "r", type = "string", description = "The key to press to force refresh to the file list.", })
    settings.define("nao.keys.up", { default = "w", type = "string", description = "The key to press to move the selector up.", })
    settings.define("nao.keys.down", { default = "s", type = "string", description = "The key to press to move the selector down.", })
    settings.define("nao.keys.activate", { default = "space", type = "string", description = "The key to press to run files and enter directories.", })
    settings.define("nao.keys.altActivate", { default = "leftAlt", type = "string", description = "The key to press to open the interaction menu.", })
    settings.define("nao.refreshInterval", { default = 5, type = "number", description = "How long to wait before automatically refreshing the file list. Set to 0 to disable", })
    settings.save()
end

local key = {
    refresh = settings.get("nao.keys.refresh"),
    up = settings.get("nao.keys.up"),
    down = settings.get("nao.keys.down"),
    activate = settings.get("nao.keys.activate"),
    altActivate = settings.get("nao.keys.altActivate"),
}
local refreshInterval = settings.get("nao.refreshInterval")

local programName = "NAO"

local w, h = term.getSize()
local masterWindow = window.create(term.current(), 1, 1, w, h)

local fileSelectorPosition = 0
local refreshTimer
local dirList
local popupOpen = false

-- TODO: handle term resize

local fileWindow = window.create(masterWindow, 1, 2, w, h-1, false)
local launchWindow = window.create(masterWindow, 1, 1, w, h, false)
local launchArgsWindow = window.create(launchWindow, 1, 1, w, 1, false)

local function clearTerm(t)
    t = t or term
    t.setCursorPos(1,1)
    t.clear()
    t.setCursorPos(1,1)
end

local function drawFileMenu()
    if popupOpen then
        return
    end

    -- TODO: scroll for long lists


    masterWindow.setVisible(false)
    clearTerm()
    print("/"..shell.dir())

    if fileSelectorPosition == 0 then
        print(strings.ensure_width("> .. Up One Level")) -- TODO: react to being at root
    else
        print(strings.ensure_width("  .. Up One Level"))
    end

    for pos, fileName in ipairs(dirList) do
        local fileType
        if fs.isDir(fileName) then
            fileType = "D"
        else
            fileType = "F"
        end

        if fileSelectorPosition == pos then
            print(strings.ensure_width("> "..fileType.."  "..fileName))
        else
            print(strings.ensure_width("  "..fileType.."  "..fileName))
        end
    end
    masterWindow.setVisible(true)
end

local function refresh()
    dirList = fs.list(shell.dir())
    dirList.n = dirList.n or #dirList
    drawFileMenu()
    if refreshInterval > 0 then
        refreshTimer = os.startTimer(refreshInterval)
    end
end

local function launchMenu(fileOrDir)
    popupOpen = true
    term.redirect(launchWindow)
    clearTerm()
    write(fileOrDir.." ")
    local x, y = term.getCursorPos()
    launchArgsWindow.reposition(x, y)
    term.redirect(launchArgsWindow)
    clearTerm()



    launchWindow.setVisible(true)
    launchArgsWindow.setVisible(true)


    local function autoComplete(line)
        line = line or ""
        return shell.complete(fileOrDir.." "..line)
    end 

    local args = read(nil, nil, autoComplete)


    -- TODO: allow aborting launch




    launchArgsWindow.setVisible(false)
    launchWindow.setVisible(false)
    term.redirect(masterWindow)
    local w, h = term.getSize()
    local clientWindow = window.create(masterWindow, 1, 1, w, h)
    term.redirect(clientWindow)
    clearTerm()

    -- TODO: take mbs private mode code

    shell.run(fileOrDir, args)

    write("Press any key to return to "..programName)

    os.pullEvent("key")

    term.redirect(masterWindow)
    popupOpen = false
end

local function activate()
    if fileSelectorPosition == 0 then
        local currentDir = shell.dir()
        if currentDir ~= "" then
            local parentDir = fs.combine(currentDir, "..")
            shell.setDir(parentDir)
        end
        return
    end

    local fileOrDir = dirList[fileSelectorPosition]
    local fullPath = fs.combine(shell.dir(), fileOrDir)

    if fs.isDir(fullPath) then
        shell.setDir(fullPath)
        fileSelectorPosition = 0
        return
    else
        launchMenu(fileOrDir)
    end
end

local function altMenu()
    if fileSelectorPosition == 0 then
        return
    end

    local fileOrDir = dirList[fileSelectorPosition]
    local fullPath = fs.combine(shell.dir(), fileOrDir)

    popupOpen = true

    popupOpen = false
end


local function main()
    refresh()
    while true do
        local event, eventInfo = os.pullEvent()
        -- TODO: click events
        if event == "key" then
            local keyCode = eventInfo
            if keyCode == keys[key.activate] then
                activate()
                refresh()
            elseif keyCode == keys[key.altActivate] then
                altMenu()
                refresh()
            elseif keyCode == keys[key.down] then
                fileSelectorPosition = math.min(fileSelectorPosition+1, dirList.n)
                drawFileMenu()
            elseif keyCode == keys[key.up] then
                fileSelectorPosition = math.max(fileSelectorPosition-1, 0)
                drawFileMenu()
            elseif keyCode == keys[key.refresh] then
                refresh()
            end
        elseif event == "timer" then
            local timerId = eventInfo
            if timerId == refreshTimer then
                refresh()
            end
        end
    end
end

local oldDir = shell.dir()
local oldTerm = term.redirect(masterWindow)

local ok, err = pcall(main)

shell.setDir(oldDir)
term.redirect(oldTerm)

if not ok then
    error(err, 0)
end