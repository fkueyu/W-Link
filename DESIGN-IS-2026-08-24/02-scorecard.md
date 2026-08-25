# Dieter Rams 十项评分

1. **创新 — 2/3**
   证据：设备当前颜色驱动控制页光场（`device_ambient_background.dart:56-120`），但模式仍是玻璃态智能灯控制器的演进。
   理由：对既有模式有明确改善，但未达到五个以上同类产品中罕见的新范式。

2. **有用 — 2/3**
   证据：首页与详情均可直接控制开关/亮度（`device_card.dart:332-475`、`device_control_screen.dart:547-729`），但控制页必须等待 `/json` 且存在重复入口。
   理由：核心任务可完成且较直接，但网络状态和相邻功能增加摩擦。

3. **美观 — 1/3**
   证据：20 档 spacing、13 档 type、67 个基础颜色引用，次要文本多处 WCAG 失败（见 `01-evidence.md#视觉-token`）。
   理由：有清晰品牌方向，但超过 3–5 处系统性不一致，不能评 2。

4. **易理解 — 1/3**
   证据：测试模式无行为、Schedule 实际仅 Nightlight、在线/局域网标签与行为不完全一致（`settings_screen.dart:106-123`、`schedule_screen.dart:64-243`）。
   理由：至少 2–3 个主要标签需要解释或修正。

5. **不打扰 — 1/3**
   证据：46 处动画相关声明、宽屏重复背景、16 层设备卡树与多层玻璃/光晕（`adaptive_shell.dart:46-80`、`device_card.dart:58-163`）。
   理由：装饰在多个表面与内容竞争，而不是始终退居背景。

6. **诚实 — 1/3**
   证据：毫秒级/零延迟、纯黑、后台几乎不耗电等无测量或与 token/生命周期冲突（`README.md:14-18`、`docs/帮助与支持.md:17-18`）。
   理由：存在两项以上夸大和多个标签错配，虽无 dark pattern，仍只能评 1。

7. **持久 — 1/3**
   证据：大面积玻璃拟态、霓虹渐变、强光晕与高圆角同时使用（`theme.dart:59-96,234-276`、`animated_background.dart:76-175`）。
   理由：包含多个明显时代风格标记，未来维护容易显旧。

8. **细致 — 1/3**
   证据：focus 缺失、失败不回滚、在线状态不离线、英文硬编码混入中文（`bouncy_button.dart:53-80`、`device_providers.dart:290-365`）。
   理由：empty/loading/error 等表面存在，但至少三类关键边缘状态不完整。

9. **环保 — 1/3**
   证据：reduce-motion 已支持，但同一设备可维持两套 WS/轮询，会运行不可见 ticker，release 体积与功耗未测（`device_providers.dart:121-175`、`animated_background.dart:57-100`）。
   理由：有暗色与动效降级基础，但资源策略尚未达到克制标准。

10. **尽可能少 — 1/3**
    证据：103 个静态交互声明、8 个同目的额外 affordance、Nightlight 双实现和大量重复 page/dialog chrome（见 Pathfinder duplication report）。
    理由：可移除或合并的元素明显超过五个。

**总分：13/30**
