# Codex 快速上手

菜鸟教程[网址](https://www.runoob.com/codex/codex-concepts.html)

## 命令速查

### 斜杠命令

| 命令               | 说明           |
| :----------------- | :------------- |
| `/model <name>`    | 切换模型       |
| `/fast`            | 切换 Fast 模式 |
| `/plan`            | 进入计划模式   |
| `/review`          | 审查代码变更   |
| `/new`             | 开始新会话     |
| `/resume`          | 恢复历史会话   |
| `/fork`            | 克隆当前会话   |
| `/compact`         | 压缩上下文     |
| `/status`          | 显示会话状态   |
| `/clear`           | 清除屏幕       |
| `/quit`            | 退出 Codex     |
| `/approval <mode>` | 切换审批模式   |

### CLI 基础指令

| 命令                | 说明               |
| :------------------ | :----------------- |
| `codex`             | 启动交互式 TUI     |
| `codex "任务"`      | 启动并执行指定任务 |
| `codex exec "任务"` | 非交互模式执行任务 |
| `codex --version`   | 显示版本信息       |
| `codex --help`      | 显示帮助信息       |

## 配置文件路径

### 配置文件位置

| 文件     | 路径                   | 作用         |
| :------- | :--------------------- | :----------- |
| 用户配置 | `~/.codex/config.toml` | 全局默认配置 |
| 项目配置 | `.codex/config.toml`   | 项目特定配置 |
| 项目指令 | `AGENTS.md`            | 项目行为规范 |
| 日志目录 | `~/.codex/log/`        | 运行日志     |
| 会话目录 | `~/.codex/sessions/`   | 会话记录     |

### 技能目录

| 位置   | 路径                 |
| :----- | :------------------- |
| 项目级 | `.agents/skills/`    |
| 用户级 | `~/.agents/skills/`  |
| 系统级 | `/etc/codex/skills/` |

## CLI 快捷键

| 快捷键          | 功能             |
| :-------------- | :--------------- |
| `Enter`         | 发送消息         |
| `Shift+Enter`   | 换行             |
| `Ctrl+C`        | 中断操作         |
| `Ctrl+C (两次)` | 退出 Codex       |
| `Ctrl+D`        | 退出（输入空时） |
| `Ctrl+R`        | 搜索历史         |
| `Up/Down`       | 浏览历史         |
| `Tab`           | 自动补全         |
| `Esc Esc`       | 编辑上一条消息   |
| `Ctrl+O`        | 复制最后回复     |

## 安装

### 初次安装 

使用 npm 进行安装

~~~ powershell
npm install -g @openai/codex
~~~

### 更新

~~~ powershell
npm install -g @openai/codex@latest
~~~

### DeepSeek API

查看DeepSeek[官网](https://api-docs.deepseek.com/zh-cn/quick_start/agent_integrations/codex/)即可

