# =============================================================================
#  GameSpeedTool.Core.ps1 - 核心逻辑 (被 GameSpeedTool.ps1 dot-source)
# =============================================================================
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Test-IsSpeedInstalled([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
    $txt = [System.IO.File]::ReadAllText($Path)
    return $txt.Contains('[GameSpeedTool] begin')
}

function Get-GameInfo([string]$ExePath) {
    $dir = Split-Path -Parent $ExePath
    $engine = 'Unknown'
    $target = ''

    $mzRel = @('js\rmmz_managers.js', 'www\js\rmmz_managers.js')
    foreach ($rel in $mzRel) {
        $c = Join-Path $dir $rel
        if (Test-Path -LiteralPath $c) { $engine = 'MZ'; $target = $c; break }
    }
    if ($engine -eq 'Unknown') {
        $mvRel = @('www\js\rpg_managers.js', 'js\rpg_managers.js')
        foreach ($rel in $mvRel) {
            $c = Join-Path $dir $rel
            if (Test-Path -LiteralPath $c) { $engine = 'MV'; $target = $c; break }
        }
    }
    if ($engine -eq 'Unknown') {
        $ini = Join-Path $dir 'Game.ini'
        $rv = @(Get-ChildItem -LiteralPath $dir -Filter '*.rvproj2' -File -ErrorAction SilentlyContinue)
        $rgss = @(Get-ChildItem -LiteralPath $dir -Filter '*.rgss*' -File -ErrorAction SilentlyContinue)
        if ($rv.Count -gt 0 -or $rgss.Count -gt 0) { $engine = 'RGSS' }
        elseif (Test-Path -LiteralPath $ini) { $engine = 'RGSS' }
    }

    [pscustomobject]@{
        Name     = Split-Path -Leaf $dir
        Engine   = $engine
        Target   = $target
        Launcher = $ExePath
        Dir      = $dir
    }
}

function Scan-Games([string]$Root) {
    $list = New-Object System.Collections.ArrayList
    $seen = @{}
    $exes = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter 'Game.exe' -File -ErrorAction SilentlyContinue)
    foreach ($exe in $exes) {
        # 跳过 Wolf 加载器等工具目录
        if ($exe.FullName -match '\\Tool\\loaders\\') { continue }
        $g = Get-GameInfo $exe.FullName
        $key = $g.Dir.ToLower()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        [void]$list.Add($g)
    }
    return $list
}

function Get-InstallBlock([string]$Engine, [int]$Speed) {
    $hud = @'
    var __gstHud = (function () {
        var el = null, timer = null;
        function ensure() {
            if (el) { return el; }
            el = document.createElement("div");
            el.id = "__gamesspeed_hud__";
            el.style.cssText = "position:fixed;top:10px;right:10px;z-index:2147483647;padding:5px 12px;border-radius:8px;background:rgba(0,0,0,0.62);color:#7CFC8A;font:bold 17px/1 Consolas,monospace;pointer-events:none;user-select:none;text-shadow:0 0 5px #000;opacity:0.9;transition:background .2s;display:block;";
            document.body.appendChild(el);
            return el;
        }
        return function (flash) {
            var box = ensure();
            box.style.display = "block";
            box.textContent = "倍速 " + (window.__GAME_SPEED__ || 1) + "x";
            if (flash) {
                box.style.background = "rgba(180,30,30,0.9)";
                clearTimeout(timer);
                timer = setTimeout(function () { box.style.background = "rgba(0,0,0,0.62)"; }, 260);
            }
        };
    })();
'@
    $hotkey = @'
    window.addEventListener("keydown", function (e) {
        if (e.repeat) { return; }
        if (e.key === "F7") { window.__GAME_SPEED__ = Math.min(8, (window.__GAME_SPEED__ || 1) + 1); __gstHud(true); }
        else if (e.key === "F6") { window.__GAME_SPEED__ = Math.max(1, (window.__GAME_SPEED__ || 1) - 1); __gstHud(true); }
        else if (e.key === "F9") { var h = document.getElementById("__gamesspeed_hud__"); if (h) { h.style.display = (h.style.display === "none") ? "block" : "none"; } }
    });
'@
    if ($Engine -eq 'MZ') {
        $body = @'
    if (typeof SceneManager.determineRepeatNumber === "function") {
        var _base = SceneManager.determineRepeatNumber;
        SceneManager.determineRepeatNumber = function (dt) {
            var s = window.__GAME_SPEED__ || 1;
            return Math.max(1, Math.round(_base.call(this, dt) * s));
        };
    } else {
        var _main = SceneManager.updateMain;
        SceneManager.updateMain = function () {
            var s = window.__GAME_SPEED__ || 1;
            for (var i = 0; i < s; i++) { _main.call(this); }
        };
    }
'@
    } else {
        $body = @'
    var _updateMain = SceneManager.updateMain;
    SceneManager.updateMain = function () {
        var s = window.__GAME_SPEED__ || 1;
        if (typeof SceneManager._deltaTime === "number") {
            SceneManager._deltaTime = (1 / 60) / s;
            _updateMain.call(this);
        } else {
            this.changeScene();
            for (var i = 0; i < s; i++) { this.updateScene(); }
            this.renderScene();
            this.requestUpdate();
        }
    };
'@
    }
    $block = "// [GameSpeedTool] begin`r`nwindow.__GAME_SPEED__ = $Speed;`r`n(function () {`r`n    if (window.__SPEEDTOOL__) { return; }`r`n    window.__SPEEDTOOL__ = true;`r`n$hud$body`r`n    __gstHud(false);`r`n$hotkey})();`r`n// [GameSpeedTool] end"
    return $block
}

function Install-Speed($Game, [int]$Speed) {
    if (-not $Game.Target -or -not (Test-Path -LiteralPath $Game.Target)) { return $false }
    $p = $Game.Target
    $bak = $p + '.gstbak'

    $txt = [System.IO.File]::ReadAllText($p)
    $hasBlock = $txt.Contains('[GameSpeedTool] begin')

    # 去掉旧块, 得到干净内容
    $clean = [regex]::Replace($txt, '(?s)\r?\n?// \[GameSpeedTool\] begin.*?// \[GameSpeedTool\] end\s*', '')

    if (-not $hasBlock) {
        # 当前是原版(或游戏更新后的新版本), 保存原始字节作为备份(保留 BOM)
        [System.IO.File]::WriteAllBytes($bak, [System.IO.File]::ReadAllBytes($p))
    } elseif (-not (Test-Path -LiteralPath $bak)) {
        # 已安装但备份丢失: 用去块后的文本重建备份
        [System.IO.File]::WriteAllText($bak, $clean, $script:Utf8NoBom)
    }

    $block = Get-InstallBlock $Game.Engine $Speed
    [System.IO.File]::WriteAllText($p, $clean.TrimEnd() + "`r`n`r`n" + $block + "`r`n", $script:Utf8NoBom)
    return $true
}

function Restore-Speed($Game) {
    if (-not $Game.Target -or -not (Test-Path -LiteralPath $Game.Target)) { return $false }
    $p = $Game.Target
    $bak = $p + '.gstbak'
    if (Test-Path -LiteralPath $bak) {
        Copy-Item -LiteralPath $bak -Destination $p -Force
        Remove-Item -LiteralPath $bak -Force
    } else {
        $txt = [System.IO.File]::ReadAllText($p)
        $clean = [regex]::Replace($txt, '(?s)\r?\n?// \[GameSpeedTool\] begin.*?// \[GameSpeedTool\] end\s*', '')
        [System.IO.File]::WriteAllText($p, $clean.TrimEnd() + "`r`n", $script:Utf8NoBom)
    }
    return $true
}
