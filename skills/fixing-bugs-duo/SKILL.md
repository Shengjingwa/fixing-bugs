---
name: fixing-bugs-duo
description: 两会话修 bug：A 诊断、写方案并监督，B 子 agent 在同一个 worktree 里先红后绿；简单问题直接单会话修完。
disable-model-invocation: true
license: MIT
---

# 两会话修 bug

调用本 skill 的会话是 **A**：诊断、写交接材料、监督、裁决、验收，并且是唯一和用户对话的会话。**B** 是 A 开的后台子 agent，只读 [b.md](b.md)，在任务 worktree 里按冻结的方案先红后绿。A 审查时读 [review.md](review.md)，建 flow 文件时读 [files.md](files.md)。

简单问题不开 B：快修档、以及诊断后估算不超过 2 步且没命中硬条件的问题，A 单会话修完。

## 依赖

- `fixing-bugs`：本 skill 目录的同级目录 `../fixing-bugs/`。A 用它的「开头」「快修」「停下与交付」和 `full.md` 第 1–4 段；B 用 `full.md` 第 5–6 段。读不到时按 `fixing-bugs` 的「依赖」一节处理：标 `blocked`，写明缺什么，继续不依赖它的部分。
- `diagnosing-bugs`、`tdd`：`fixing-bugs` 已声明，读取方式同上。

## 现场

| 位置 | 路径 | 写者 |
|---|---|---|
| 主仓库 | `<父目录>/<repo>` | 全程不写，只用来记基线和建 worktree |
| 任务 worktree | `<父目录>/<repo>-wt-<短名>`，分支 `fix/<短名>`（项目有分支规范时按规范） | 分时独占，见下 |
| flow 仓库 | `<父目录>/<repo>-flow/`，自带 git；本任务子目录 `<短名>/`，根目录有 `registry.md` | 只有 A |
| `progress.md` | 任务 worktree 根目录，不入仓 | 只有 B |

任务 worktree **分时独占**：
- A 诊断期间由 A 独占。A 的打点从不 commit，交给 B 前清理到 `git status --short` 为空。
- B 在跑时由 B 独占，A 只读。A 读 git 一律加 `--no-optional-locks`，审查钉在 commit sha 上，不读 B 的工作区。
- B 结束本轮、A 还没 resume 它时，A 可以在 worktree 里运行命令。A 不改跟踪文件，不 commit，不 checkout，跑完后 `git status --short` 和 B 交回时一致。
- B 在跑而 A 要亲手做实验时，A 用 `git worktree add --detach <临时路径> <sha>` 开临时 worktree，用完即删。

A 和 B 都不用 `git stash`：stash 栈由同一仓库的全部 worktree 共享。

flow 仓库里的每次写入，A 都立即 commit。**先落盘再回复**：裁决、审查结论和攒批意见，都要先写进文件、commit 之后，才算做完，才能通知 B 或回复用户。

**门槛硬条件**，碰到任一条就不能豁免：
- 需要外部裁决（别的团队、协议或接口的属主）
- 改动碰到关键路径（清单在 `registry.md`）
- 属于历史翻车域（`registry.md` 里该模块出过 P0 或 P1）

`registry.md` 里没有这个仓库的关键路径清单或该模块的记录时，问用户，时机见第 4 步。用户答不上，按「命中」处理。答复写回 `registry.md`。

## 1. 开头

1. 做 `fixing-bugs` 的「开头」：记主仓库基线，写一句现象和修好标准，定起始档位。
2. 给这个 bug 起一个短名 `<短名>`（小写短横线，例如 `csv-missing-row`）。
3. 起始档位是快修：在主仓库按 `fixing-bugs` 的「快修」修完，本 skill 到此结束。快修中碰到升档信号时，先把本轮在主仓库里的增量撤回（基线不动），已有的事实和复现命令带到第 2 步。

**完成：** 对话里有基线摘要、一句话现象和修好标准、起始档位、`<短名>`；快修档已修完，或已转到第 2 步且主仓库除基线外无本轮增量。

## 2. 建现场

1. 建任务 worktree：`git -C <主仓库> worktree add -b fix/<短名> <父目录>/<repo>-wt-<短名> HEAD`。
2. 在后台装依赖（项目需要时），不等它结束，直接往下做。
3. flow 仓库不存在时：建目录，`git init`，按 [files.md](files.md) 建 `registry.md`。建本任务子目录 `<短名>/`，commit。
4. 读 `registry.md`，逐条核对三条硬条件，记下哪些已有结论、哪些缺事实。缺的事实先不问，到第 4 步按需要再问。

**完成：** worktree 和 flow 子目录都在，flow 仓库已 commit；对话里有三条硬条件的现状（已命中、未命中或缺事实）。

## 3. 诊断

在任务 worktree 里做 `fixing-bugs` 的 `full.md` 第 1–2 段。

- 原始复现命令和一次性 harness 放进 flow 的 `<短名>/repro/`，不放进 worktree。这样清理打点后它们还在，B 也能直接运行。
- A 自己搭复现、打点。同时派只读子 agent 并行侦察：代码路径、git 历史（`log -S`、`blame`、bisect 候选）、日志。每个子 agent 只拿一句现象、复现命令和它负责的那个问题，交回带证据（路径加行号，或 commit sha）的结论。
- 干净的 worktree 复现不出、而主仓库能复现时，说明 bug 依赖基线里的未提交改动。停下问用户：先把这些改动提交到一个分支、再从那个分支重建 worktree，还是只带哪几个文件。A 不擅自搬运改动。

**完成：** `full.md` 第 2 段的完成条件全部满足；复现命令和 harness 在 flow 的 `repro/` 里，并已 commit。

## 4. 分流

按根因估算执行顺序，不含 S0 准备步骤：

| 情况 | 做法 |
|---|---|
| ≤2 步，且没命中硬条件 | **豁免**：A 不开 B，自己在任务 worktree 里按 `fixing-bugs` 修完。没有风险信号时接排查档第 3 步；有风险信号时接 `full.md` 第 3 段，文档放 flow 的 `<短名>/`。按「停下与交付」收尾后，A 自己 commit、push、建 Draft MR/PR，按第 8 步第 5 条报告，写明为什么没开 B，再做第 9 步。 |
| 3–8 步，且没命中硬条件 | **轻量版**：只在最后一步标 `[M]`，只在最后一步的完成 commit 上做一次全量审查 |
| >8 步，或命中硬条件 | **全流程**：`[M]` 按 [files.md](files.md) 的规则标，每个 `[M]` 做一次全量审查；历史翻车型判据各写一条锚定断言 |

轻量版和全流程都锚定第一条正式回归测试（锚定断言 A-1）。

硬条件缺事实时：
- ≤2 步：豁免与否取决于答案，现在就问，等回答再分流。
- 3–8 步：先按轻量版往下做，问题并进第 6 步的确认提问；答案命中硬条件就改成全流程。
- >8 步：直接走全流程。缺的关键路径清单并进第 6 步的确认提问，审查要用。

**完成：** 对话里有估算步数、硬条件结论、分流结果和理由；豁免时已转去单会话修复。

## 5. 先开 B 做准备

1. 按 `fixing-bugs`「停下与交付」第 1 步，清掉 worktree 里的打点，直到 `git status --short` 为空。
2. 在 worktree 根目录运行 `git rev-parse --git-path info/exclude`，把 `progress.md` 追加进它输出的文件。worktree 里的 `.git` 是文件，不能直接写 `.git/info/exclude`；输出可能是相对路径，所以要在 worktree 根目录运行和追加。
3. 按 [files.md](files.md) 写 `handover.md` 和只有 S0 的 `steps.md`，再把 `rulings.md`、`batch.md`、`review-state.md` 建成只有标题的骨架（`last_reviewed_sha` 填 worktree 当前 HEAD），commit。B 启动时就要读这些文件。
4. 用后台子 agent 开 B（Cursor：`Task`，`run_in_background: true`），提示词：

```text
你是 fixing-bugs-duo 的执行会话 B。先读 <本 skill 目录>/b.md，按它执行。
- 任务 worktree：<路径>（分支 fix/<短名>）
- flow 目录（只读）：<父目录>/<repo>-flow/<短名>/
- fixing-bugs 目录：<本 skill 目录>/../fixing-bugs/
- 本轮：只做 S0，方案还没冻结
```

5. 把 B 的 agent ID 写进 `handover.md`，并在对话里告诉用户（带链接）。
6. 在 flow 目录里起监视脚本，不要在 worktree 里起，否则会干扰下文「卡住」的判断。脚本在后台运行，用宿主的输出通知唤醒 A；Cursor 用 Shell 的 `notify_on_output`，匹配 `^DUO_WAKE_<短名>`。宿主给了 B 的转录路径时（Cursor 开子 agent 时会返回），一并传进去：
   - Windows：`powershell -File <本 skill 目录>/scripts/watch.ps1 -Worktree <路径> -Tag <短名> -Transcript <B 的转录>`
   - 其他：`bash <本 skill 目录>/scripts/watch.sh <路径> <短名> <B 的转录>`

   脚本打出的每一行是 `DUO_WAKE_<短名> <事件>`，事件有四种：
   - `commit`：B 有带 `Flow: step`、`Flow: fix` 或没有 trailer 的新 commit。`wip` 和 `docs` 不唤醒 A，留到下次醒来一起处理。
   - `request`：`progress.md` 出现新的 `### R-` 标题。
   - `stall`：B 本该在干活，转录却 10 分钟没有新内容。
   - `heartbeat`：20 分钟没有任何事件。

   把 PID 写进 `handover.md`。换 B 时要用新的转录路径重启脚本。

宿主没有后台子 agent，或不能给运行中的子 agent 发消息时，退回两个独立聊天：A 把上面的提示词写进 flow 的 `<短名>/b-prompt.md`，请用户新开一个聊天粘贴。这时 P0 写进 `batch.md`，靠 B 在每步 commit 前读到；急的请用户转达。B 的 BLOCKING 请求等 30 分钟没有答复时，B 直接问用户。

**完成：** worktree 干净，B 在跑 S0，用户已拿到 B 的 ID，监视脚本在跑，`handover.md` 已 commit。

## 6. 写交接材料并冻结

B 跑 S0 期间，A 在 flow 的 `<短名>/` 里写交接材料：
1. `problem-and-solutions.md` 和 `test-plan.md`：按 `full.md` 第 3–4 段写，路径换成 flow 子目录。
2. `steps.md`：执行顺序，每步附完成判据和对应的用例编号，标 `[M]`，末尾写 DoD。
3. `rulings.md`：预埋区（勿翻案项，以及预见到的歧义和预设答案），锚定登记。
4. `anchored/A-1.*`：第一条正式回归测试的断言文本。

格式见 [files.md](files.md)。

然后用一次提问请用户确认：推荐方案、测试 seam、分流结果（轻量版或全流程），以及第 4 步并进来的硬条件问题。用户已授权 A 在范围内自选时，记下授权来源，不再问。等待期间可以继续完善文档。

确认后冻结：commit flow 仓库，打 tag `<短名>-v1`，在 `handover.md` 写方案版本。然后 resume B：「方案 v1 已冻结，读 steps.md，从 S1 开始」。

**完成：** 文件齐全；用户确认或授权有记录；tag 已打；B 已收到开始指令。

## 7. 监督

每次被唤醒，先看唤醒来源，再按下表处理：

| 来源 | 做法 |
|---|---|
| `commit` | 对 `review-state.md` 里 `last_reviewed_sha` 之后的每个 commit，按 [review.md](review.md) 的触发分级处理 |
| `request` | 读 `progress.md` 新增的 R-n，在 `rulings.md` 追加答复。B 结束本轮在等时，resume B；B 在跑时不打扰，B 会在下一个定点读到 |
| `stall` | 按下文「卡住」处理 |
| `heartbeat` | 快照：`git --no-optional-locks log`、`progress.md`、B 的转录（可得时）。没有转录可看时，连续两次心跳都没有新 commit 也没有 R-n，按卡住处理 |
| B 本轮结束 | 读 B 回复的第一行 `STATUS:`，按 [b.md](b.md) 的约定处理。没有 `STATUS:` 行时，先拍一次快照，再 resume B，要它按现状补一行 `STATUS:` |

- **P0**：先落盘，再 resume B 并设 `interrupt: true`，消息写发现编号和证据。A→B 的消息只有三种：P0、用户确认的流程指令、BLOCKING 答复通知。其余一律写进 `batch.md`，靠 B 的定点读送达。
- **要用户拍板的事**：推翻勿翻案项、改变方案行为、P1 遗留放行、同一问题 3 轮修不好、B 对裁决有异议且 A 复核后仍分歧。A 去问用户，B 先做不受影响的步骤。用户拍板改方案时，按 [files.md](files.md) 的升版规程走。用户没回应时，在 `handover.md` 标「待用户」；全部步骤被阻塞时暂停任务，A 和 B 都不得自行裁决。
- **换 B**：`progress.md` 的压缩日志显示连续 3 个压缩间隔都短于 30 分钟，且剩余步骤 ≥ 3 时，A 建议用户换 B。用户同意后，A 用第 5 步的提示词新开一个 B（「本轮」写成「接着 progress.md 的当前步骤继续」），再把新 ID 写进 `handover.md`。B 出错退出时，同样新开一个 B 接上。
- **A 自己压缩或恢复后**：读 `handover.md`、`review-state.md`、`progress.md`，以及 `git log <last_reviewed_sha>..HEAD`。确认监视脚本还在跑，不在就重启。

**卡住**：下面三条同时成立，才算 B 卡住。
1. B 本该在干活：A 给 B 发了指令，还没收到 B 本轮结束的通知。在 Cursor 里，B 的转录最后一行不是 `"type":"turn_ended"`。
2. B 的转录 10 分钟没有新内容。
3. B 不是在跑长命令：宿主的终端列表里，没有工作目录在任务 worktree、状态为运行中的命令。

确认卡住后：
1. A 用最后一条指令 interrupt B 一次，并汇报。调用本 skill 即授权 A 这样做，不用再问用户。
2. interrupt 后 5 分钟，转录仍没有新内容，就报给用户。用户同意后新开一个 B。新开之前，宿主若仍显示旧 B 在跑，先 interrupt 旧 B，要它停手并回复 `STATUS: STOPPED`；收不到这条回复，就报给用户，不开新 B，免得两个 B 同时写 worktree。

**汇报**：A 在自己的对话里汇报，每次一行，格式固定：

```text
[duo <短名>] <进度，如 S2/3 完成> · <sha> · <审查或验收结论> · 待你拍板：<无 | 事项>
```

下面的事件各汇报一次：
1. B 已开，附 B 的 ID 链接。
2. 步骤完成（`Flow: step`），附轻检或全量审查的结论。
3. 发现 P0，以及 P0 修好。
4. 需要用户拍板。这一行放在消息最前面，同时用问答工具发问。
5. B 卡住、被 interrupt、换 B，或出错。
6. 最终交付，即第 8 步的报告。

没有变化的心跳不汇报，`wip` 和 `docs` commit 也不汇报。每次汇报前先更新 `handover.md` 的里程碑表，用户随时可以打开看。用户随时问进度时，A 先拍一次快照再回答。

**完成：** B 交回 `STATUS: DOD`；`last_reviewed_sha` 等于 B 的最终 sha；没有在途审查项，也没有未答复的 R-n。

## 8. 终审、验收与交付

1. 按 [review.md](review.md) 终审：最后一个 `[M]` 的全量审查要审整个任务区间，它兼作终审，不再另做一轮。终审时还要复读 `batch.md` 里的全部驳回项。
2. **独立验收**：B 停着时，A 在任务 worktree 的最终 sha 上亲手重跑两类命令：未缩小的原始复现命令，以及 `test-plan.md` 里全部本轮必做用例。输出写回 `test-plan.md`，commit。B 的回报不能代替这一步。
3. 核对 DoD：
   - 规格表全部通过
   - 全部步骤完成
   - 没有 P0
   - P1 遗留都经用户批准
   - 生产路径上没有诊断前缀

   终审或验收发现 P0 时，DoD 撤销，回到第 7 步。
4. 通过后 resume B：「交付」，附终审意见和 `batch.md` 路径。B push 分支，按项目规范建 Draft MR/PR。描述里写根因、改法、验证、P1/P2 攒批、待拍板项和方案版本。
5. 向用户报告：
   - 最终档位，以及是否豁免、豁免理由
   - 根因
   - 改动
   - 验证证据
   - MR/PR 链接
   - 两份文档的路径
   - 待用户拍板的事项

合入必须由人确认。A 和 B 都不合入，也不做等同于批准合入的动作，例如标记 ready、指派会自动合入的审查者。

MR/PR 评审意见由 A 转给 B，B 按 `Flow: fix` 修，A 亲验。意见触及方案行为时，问用户。A 保持低频在线，只在 B 推新 commit 时复核，直到用户确认合入或宣布放弃。

**完成：** 终审和独立验收的证据都在 flow 仓库里；Draft MR/PR 已建，或已写明缺什么；用户已收到报告。

## 9. 收尾

用户确认合入或放弃之后（豁免任务同样做）：
1. 在 `registry.md` 回写：
   - 本任务发现的 P0/P1 和所在模块
   - 新的历史翻车域
   - 跨任务有效的勿翻案项
   - 门槛判例：估算步数、实际步数、档位
2. 在 flow 仓库执行 `git mv <短名> archive/<短名>`，然后 commit。
3. 停掉监视脚本。已合入时，执行 `git worktree remove` 删除任务 worktree；分支按项目规范处理。

**完成：** `registry.md` 和归档已 commit；监视脚本已停；worktree 已删或写明保留原因。
