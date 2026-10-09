# flow 文件格式

flow 仓库只有 A 写，B 只读。每次写入后立即 commit。

```text
<父目录>/<repo>-flow/
  registry.md              跨任务登记表
  <短名>/
    handover.md            现状快照
    steps.md               执行顺序与 DoD
    rulings.md             裁决账本（追加式）
    batch.md               攒批、跳过、驳回（追加式）
    review-state.md        审查游标
    problem-and-solutions.md
    test-plan.md
    anchored/A-1.<扩展名>   锚定断言原文
    repro/                 原始复现命令与一次性 harness
    b-prompt.md            只在退回两个独立聊天时用
  archive/<短名>/          收尾后移入
```

**状态权威**：B 的实时状态以 `progress.md` 为准；裁决和勿翻案项以 `rulings.md` 为准。A 不在自己的文件里再维护一份实时进度。

## registry.md

```markdown
# registry

## 关键路径
- <路径或模块>：<为什么关键>

## 历史翻车域
| 日期 | 模块 | 任务 | 等级 | 一句话 |

## 勿翻案项（跨任务）
- <规则>（来源：<任务短名>）

## 门槛判例
| 任务 | 估算步数 | 实际步数 | 档位 | 备注 |
```

## handover.md

```markdown
# handover <短名>

- 档位：轻量版 | 全流程 | 豁免
- 方案版本：<短名>-v<k>（未冻结时写「未冻结」）
- B：<agent ID>；监视脚本 PID：<pid>
- 待用户：<无 | 事项>
- 原始复现：repro/<文件>，预期失败样子：<一句>

## 里程碑
| 步骤 | 状态 | commit |

## 执行口径
- 勿翻案项见 rulings.md 预埋区
```

## steps.md

```markdown
# steps <短名>

- S0 准备：建 progress.md；跑 repro/<文件>（预期失败）；跑相关测试 `<命令>`，记基线失败
- S1 [M]? <内容> | 用例：<编号> | 完成：<可观察的判据>
- ...

DoD：steps 全部完成；test-plan 本轮必做全部 green；无 P0；P1 遗留均经用户批准并写入 MR/PR 描述
```

`[M]` 规则：
- 轻量版：只有最后一步是 `[M]`。
- 全流程：碰关键路径的步骤和最后一步必须标 `[M]`；相邻两个 `[M]` 之间不超过 3 步。

一步对应一个 `Flow: step S<n>` commit。估算步数和定稿后的实际步数差出档位（≤2、3–8、>8）时，重新报给用户。

## rulings.md

```markdown
# rulings <短名>

## 预埋区
### 勿翻案
- P-1 <已裁决事项>（依据：<文档小节或用户原话>）
### 预设答案
- Q-1 <预见的歧义> → <答案>

## 锚定登记
### A-1
- 文件：anchored/A-1.<扩展名>
- 方向：<一句话，例如「被拒绝的是 X，不是 Y」>
- 核心行：
  - `<核心行原文>`

## 裁决
### R-1 → <裁决>（<时间>）
- 理由：
- 影响：<受影响的步骤，没有就写「无」>

## 方案版本
- v1 <时间> 初版
```

## anchored/A-1.<扩展名>

用目标语言写成可以直接拷进测试文件的一段代码：

1. 开头用注释写它依赖的夹具、接口和导入假设，方便 B 做机械适配。
2. 期望值加比较表达式的行，以及被测对象所在的行，用行尾注释 `CORE` 标出。注释语法按语言，例如 `# CORE`、`// CORE`。
3. 在 `rulings.md` 的锚定登记里写下方向和核心行原文。

全流程里，其他历史翻车型判据各写一条 `A-<n>`，规则相同。

## batch.md

```markdown
# batch <短名>

## 攒批
### F-1 P1|P2 <标题>（sha <sha>，<路径:行号>）
- 证据：
- 要求：<修复要求，或「进 MR/PR 描述」>
- 状态：open | fixed <sha> | 遗留（用户批准：<出处>）

## 跳过记录
- <sha> Flow: docs，跳过理由：

## 驳回候选
### X-1 <候选标题>（来源：<维度>）
- 驳回理由：
```

P0 也写进「攒批」区，编号同样用 `F-<n>`，等级写 P0。

## review-state.md

```markdown
# review-state <短名>

- last_reviewed_sha：<sha>
- 当前周期：<上一个 [M] 的 sha>..（进行中）
- 维度：1 方案符合性；2 断言方向抽样；3 关键路径与相邻功能；4 清洁与攒批
- 在途：<无 | F-n 等待 B 修复 | 审查进行中>
```

## 方案升版

方案冻结后只能升版本：
1. 用户拍板改方案。
2. A 同步修订 `problem-and-solutions.md`、`test-plan.md`、`steps.md`、`anchored/` 和 `rulings.md` 预埋区。
3. 在 `rulings.md` 的「方案版本」记下这次变更，以及对已完成步骤的影响（哪些步骤要返工）。
4. commit 并打 tag `<短名>-v<k+1>`，更新 `handover.md`。
5. 用流程指令 resume B。升版期间，B 只做不受影响的步骤。
