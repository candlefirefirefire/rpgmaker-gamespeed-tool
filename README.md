# RPG Maker 游戏加速工具

给 RPG Maker MV / MZ 游戏加一个倍速开关。扫描指定目录下的所有游戏，在对应 JS 文件里注入一段独立小代码块——不改引擎逻辑、不碰存档、随时一键还原。

## 为什么不用 Cheat Engine？

RPG Maker MV / MZ 跑在 NW.js（Chromium）里，游戏逻辑由 `requestAnimationFrame` + `SceneManager.update` 驱动。CE 的 Speedhack 改的是系统计时器，对这类帧驱动游戏效果有限（画面会动，事件逻辑不动）。真正有效的办法是在游戏自己的 update 循环里调时间步长，这个工具做的就是这件事。

## 支持情况

| 引擎 | 支持 | 说明 |
|---|---|---|
| RPG Maker MZ | ✅ | 注入 `rmmz_managers.js`，覆盖 `determineRepeatNumber` 的返回值 |
| RPG Maker MV | ✅ | 注入 `rpg_managers.js`，覆盖 `SceneManager._deltaTime` |
| RPG Maker XP / VX / Ace | ❌ | RGSS 引擎，请用 CE 的 Speedhack（对 RGSS 有效） |
| RPG Maker 2000 / 2003 | 不适用 | 通常可直接用 CE Speedhack |

## 快速开始

1. 双击 `启动工具.bat`
2. 工具默认扫描 `E:\game`，可在界面改路径后点「扫描游戏」
3. 勾选游戏（或点「安装全部」）→ 选默认倍速 → 点「安装选中 / 安装全部」
4. 启动游戏，右上角会显示当前倍速

> 双击 `.ps1` 会用记事本打开，不是运行。请双击 `.bat`。

## 游戏内热键

| 按键 | 功能 |
|---|---|
| `F7` | 加速（最高 8 倍） |
| `F6` | 减速（最低 1 倍） |
| `F9` | 显示/隐藏右上角倍速角标 |

## 原理

### MZ

`SceneManager.update` 每帧调用 `determineRepeatNumber(deltaTime)` 得到本帧要执行的 `updateMain()` 次数。工具覆盖该函数，返回 `base × 倍速`，即一帧内多跑几次逻辑，画面仍是 60fps。

### MV

MV 1.4+ 使用固定时间步长 `_deltaTime = 1/60` 配累加器跑逻辑。工具在每帧把 `SceneManager._deltaTime` 设为 `(1/60) / 倍速`，累加器自然多跑几次 `updateMain()`。

### 注入长什么样

每个被修改的文件里会多一段：

```js
// [GameSpeedTool] begin
(function(){ ... })();
// [GameSpeedTool] end
```

这段代码：

- 幂等：重复安装会替换而不是追加
- 与原文件其余内容完全独立
- 可一键还原：工具从 `.gstbak` 备份逐字节恢复

### 界面代码

- `GameSpeedTool.ps1`：WinForms 界面、按钮事件、日志
- `GameSpeedTool.Core.ps1`：扫描、引擎识别、注入块生成、安装 / 还原

## 还原

工具里勾选游戏 →「还原选中」，或点「全部还原」。还原会把文件恢复成安装前的字节级原样。

## 注意事项

- 加速会同时加速游戏内计时：限时事件、倒计时、日期系统等都会变快
- 战斗中的长按 / 连按判定可能变严格（判定按逻辑帧算，逻辑跑快了）
- 部分插件会自己缓存时间，倍速可能不如预期，属正常现象
- 工具只改你指定目录下的 JS 文件，不联网、不上传任何数据
- 杀软可能对「修改游戏目录里的 js」报误报，加白名单即可

## 常见问题

**双击没反应？**
确认双击的是 `启动工具.bat` 而不是 `.ps1`。

**提示执行策略禁止？**
bat 已带 `-ExecutionPolicy Bypass`。如果仍被拦，在 PowerShell 里执行：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Windows 提示「已保护你的电脑」？**
点「更多信息 → 仍要运行」。这是 SmartScreen 对未签名脚本的常规提示。

**游戏更新后加速失效？**
游戏更新会覆盖 `js` 目录。重新扫描、重新安装即可。

## 目录结构

```
GameSpeedTool.ps1       界面（WinForms）
GameSpeedTool.Core.ps1  扫描 / 注入 / 还原逻辑
启动工具.bat            启动入口
README.md
LICENSE
```

## License

MIT
