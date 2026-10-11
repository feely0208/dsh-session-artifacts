/**
 * dsh-session-artifacts — 会话产物归拢与命名
 *
 * 把「每个会话一个专属文件夹 + 收尾按实际内容改名 + 刷新索引」这套方法注册为 DSH skill。
 * 随包附带三个**纯 bash** 脚本（不依赖 DSH），Claude Code / Codex / Cursor 等任何 agent 都能直接用。
 *
 * ── 它解决什么（2026-10-11，真实后果）──────────────────────────────
 *  ① **乱**：多个会话共用一个工作目录，跑几天就成了
 *     「3.46 GB / 514 个顶层条目」，其中 305 张截图只占 59 MB。
 *     关键不是体积，是**颗粒度** —— 截图、源码、文档、构建工具平铺在同一层，
 *     于是「哪张还有用」谁也说不清，最后整个目录不敢动。
 *  ② **忘**：名字是在"开干前"起的，内容却是在"干完之后"才确定的；
 *     加上一个会话常有多个主题、人的记忆会淡 ——
 *     隔几周回来光看文件夹名，想不起来里面是什么。
 *
 * ── 两条刻意的设计 ────────────────────────────────────────────────
 *  1. **命名分两段**：开干时给临时名（粗糙没关系），收尾时由 agent 回顾整个会话的
 *     实际内容再改名。一次性命名注定对不上内容。
 *  2. **名字与 README 分工**：名字是索引键（要短、要好记），README 是内容清单（要全）。
 *     不要试图把所有主题塞进文件名 —— 那样名字会长到没法用。
 *     再加一层 `INDEX.md`（自动生成），解决"几个月后不知道这个文件夹是什么"。
 *
 * ── 与官方 API 的约定 ──────────────────────────────────────────────
 * 依赖 `ctx.skills`（由 @deepseek-ai/dsh-skill 提供）。缺失时插件不做任何事，
 * 不会影响 profile 启动。
 */

import { readFileSync, existsSync, statSync, chmodSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

/** 本包根目录（lib/ 的上一级） */
const packageRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
/** 随包分发的 skill 正文与脚本 */
const skillDir = join(packageRoot, 'skill');
const binDir = join(packageRoot, 'bin');

/** 技能正文里的占位符 —— 运行期替换成真实绝对路径，用户装到哪都能照文档直接跑 */
const PH_BIN = '<bin 目录>';
const PH_SESS = '<sess.sh 路径>';
const PH_RENAME = '<sess-rename.sh 路径>';
const PH_INDEX = '<sess-index.sh 路径>';

export const name = 'session-artifacts';
export const inject = ['skills'];

const SKILL_NAME = 'session-artifacts';

/** 三个脚本的绝对路径（随包分发；安装后位置由加载器决定） */
export const sessionScriptPath = () => join(binDir, 'sess.sh');
export const renameScriptPath = () => join(binDir, 'sess-rename.sh');
export const indexPath = () => join(binDir, 'sess-index.sh');

function skillBody() {
  const raw = readFileSync(join(skillDir, 'session-artifacts.md'), 'utf-8');
  return raw
    .split(PH_BIN).join(binDir)
    .split(PH_RENAME).join(renameScriptPath())
    .split(PH_INDEX).join(indexPath())
    .split(PH_SESS).join(sessionScriptPath());
}

export function apply(ctx) {
  // skills 服务缺失时静默跳过：可选能力，不应阻断 profile 启动
  if (!ctx.skills || typeof ctx.skills.register !== 'function') {
    ctx.logger?.warn?.('[session-artifacts] 未找到 skills 服务，跳过技能注册');
    return;
  }

  let content;
  try {
    content = skillBody();
  } catch (error) {
    ctx.logger?.error?.(`[session-artifacts] 读取技能正文失败: ${String(error)}`);
    return;
  }

  ctx.skills.register({
    name: SKILL_NAME,
    source: 'bundled',
    description:
      '会话产物归拢与命名：每个新会话在 ~/会话产物/ 下建专属文件夹（<日期>-<主题>），' +
      '截图、验证脚本、临时下载、中间产物一律进去，不往工作目录根扔；' +
      '收尾时按会话**实际内容**重命名，并刷新索引。',
    whenToUse:
      '会话中需要保存截图/脚本/临时文件时；整理、清理、重命名、回顾会话遗留文件时。' +
      '用户提到「截图」「临时文件」「产物」「清理」「整理」「归拢」「文件夹」「改名」' +
      '「索引」「太乱」「记不清」时同样适用。',
    content,
  });

  ctx.logger?.info?.(`[session-artifacts] 已注册技能 ${SKILL_NAME}`);

  // 脚本随包分发，但发布/安装可能丢掉可执行位；缺失时补上。
  // 失败不影响技能本身（用户可手动 chmod +x）。
  for (const p of [sessionScriptPath(), renameScriptPath(), indexPath()]) {
    if (!existsSync(p)) continue;
    try {
      const mode = statSync(p).mode;
      if ((mode & 0o111) === 0) chmodSync(p, mode | 0o755);
    } catch {
      // 只读文件系统或权限不足：忽略
    }
  }
}
