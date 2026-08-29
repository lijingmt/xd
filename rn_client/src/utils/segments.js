/**
 * MUD 行/段落渲染纯工具：与 /api/json 返回结构一一对应。
 * text segment: {type:'text', parts:[{type:'text'|'color-start'|'color-end',...}]}
 * button: {type:'button', label, cmd, class}
 * image: {type:'image', src, alt}
 * cmd-input / input: {type:'cmd-input', cmd, default,...}
 * 全部为纯函数，供前端 TestUnit 离线覆盖。
 */

export const COLOR_HEX = {
  'color-black': '#000000',
  'color-red-bold': '#FF0000',
  'color-green-bold': '#00AA00',
  'color-blue-bold': '#0066CC',
  'color-cyan-bold': '#FFD700',
  'color-purple-bold': '#8B00FF',
  'color-orange-bold': '#FF8C00',
  'color-gray': '#FFFFFF',
  'color-dark-gray': '#888888',
  'color-light-gray': '#003366',
  'color-red': '#90EE90',
  'color-green': '#ADD8E6',
  'color-cyan': '#FF6B6B',
  'color-purple': '#DDA0DD',
  'color-yellow': '#FFFF00',
  'color-white': '#333333',
  'color-gold': '#D4AF37',
  'color-bold': '#F0E6D2',
  'color-bright-green-bold': '#00FF00',
  'color-bright-blue-bold': '#0099FF',
  'color-hot-pink-bold': '#FF1493',
  'color-bright-gold-bold': '#FFD700',
  'color-bright-white-bold': '#FFFFFF',
  'color-bright-yellow-bold': '#FFFF00',
};

export function colorHexForClass(className) {
  return COLOR_HEX[String(className || '')] || '#F0E6D2';
}

export function isBoldClass(className) {
  const name = String(className || '');
  return name.indexOf('bold') !== -1;
}

/* ===== 遗留 HTML 兼容 =====
 * 大量旧公告/广播文本内嵌 <div style="color:X">、<font color>、<br>
 * 等标记。原生端不能把标签当字面文本渲染：这里解析常见结构——
 * 提取颜色、<br> 转换行、其余标签剥离；未识别颜色沿用上下文色。 */

const HTML_COLOR_NAMES = {
  red: '#FF0000', crimson: '#DC143C', firebrick: '#B22222',
  maroon: '#800000', orange: '#FFA500', darkorange: '#FF8C00',
  coral: '#FF7F50', gold: '#FFD700', yellow: '#FFFF00',
  olive: '#808000', lime: '#00FF00', green: '#008000',
  seagreen: '#2E8B57', teal: '#008080', cyan: '#00FFFF',
  aqua: '#00FFFF', skyblue: '#87CEEB', blue: '#0000FF',
  navy: '#000080', royalblue: '#4169E1', purple: '#800080',
  darkviolet: '#9400D3', magenta: '#FF00FF', fuchsia: '#FF00FF',
  pink: '#FFC0CB', hotpink: '#FF69B4', brown: '#A52A2A',
  white: '#FFFFFF', silver: '#C0C0C0', gray: '#808080',
  grey: '#808080', black: '#000000', indigo: '#4B0082',
};

const HTML_TAG_RE = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[^<>]*?)?)\/?>/g;

function htmlColorFromAttrs(attrs) {
  if (!attrs) return null;
  const style = attrs.match(/style\s*=\s*["']([^"']*)["']/i);
  if (style) {
    const color = style[1].match(/(?:^|;)\s*color\s*:\s*([^;]+)/i);
    if (color) return htmlColorValue(color[1].trim());
  }
  const font = attrs.match(/color\s*=\s*["']([^"']+)["']/i);
  if (font) return htmlColorValue(font[1].trim());
  return null;
}

function htmlColorValue(value) {
  if (/^#[0-9a-fA-F]{3,8}$/.test(value)) return value;
  return HTML_COLOR_NAMES[String(value).toLowerCase()] || null;
}

/**
 * 解析一段含内嵌 HTML 的文本为着色片段。
 * baseColor: 外层上下文色（§ 色或默认色）；HTML 色优先于上下文色，
 * 闭合标签弹回到上一层（栈式），<br> 产出换行。
 */
export function parseHtmlishSpans(text, baseColor) {
  const spans = [];
  /* stack: [{tag, color}] —— color 是该标签打开前的上下文色；
   * 闭合标签按名字匹配回退，避免 </b> 误弹 <font> 的底色。 */
  const stack = [];
  let cursor = 0;
  let current = baseColor || null;
  const source = String(text == null ? '' : text);
  HTML_TAG_RE.lastIndex = 0;
  let match;
  const pushText = value => {
    if (value) spans.push({ text: value, color: current });
  };
  while ((match = HTML_TAG_RE.exec(source)) !== null) {
    pushText(source.slice(cursor, match.index));
    cursor = match.index + match[0].length;
    const closing = match[1] === '/';
    const tag = match[2].toLowerCase();
    if (tag === 'br' && !closing) {
      pushText('\n');
      continue;
    }
    if (closing) {
      for (let i = stack.length - 1; i >= 0; i -= 1) {
        if (stack[i].tag === tag) {
          current = stack[i].color;
          stack.length = i;
          break;
        }
      }
      continue;
    }
    const color = htmlColorFromAttrs(match[3]);
    if (color) {
      stack.push({ tag, color: current });
      current = color;
    }
  }
  pushText(source.slice(cursor));
  return spans;
}

/** 把 text segment 的 parts 压平为 [{text,color,bold}] 渲染单元。 */
export function flattenTextParts(parts) {
  const units = [];
  let currentColor = '';
  let currentBold = false;
  for (const part of parts || []) {
    if (!part || !part.type) continue;
    if (part.type === 'color-start') {
      currentColor = String(part.class || '');
      currentBold = isBoldClass(currentColor);
      continue;
    }
    if (part.type === 'color-end') {
      currentColor = '';
      currentBold = false;
      continue;
    }
    if (part.type === 'text') {
      const base = currentColor ? colorHexForClass(currentColor) : null;
      for (const span of
          parseHtmlishSpans(part.content, base)) {
        units.push({
          text: span.text,
          color: span.color || '#F0E6D2',
          bold: currentBold,
        });
      }
    }
  }
  return units;
}

/** 一行(line)的裸文本（无颜色），用于搜索/调试。 */
export function linePlainText(line) {
  let out = '';
  for (const segment of (line && line.segments) || []) {
    if (!segment) continue;
    if (segment.type === 'text') {
      for (const unit of flattenTextParts(segment.parts)) out += unit.text;
    } else if (segment.type === 'button') {
      out += `[${segment.label || ''}]`;
    }
  }
  return out;
}

/** 判断是否战斗中：沿用 Vue 端“察看战况”按钮契约。 */
export function lineHasBattleButton(line) {
  for (const segment of (line && line.segments) || []) {
    if (segment && segment.type === 'button' &&
        segment.label === '察看战况') return true;
  }
  return false;
}

export function responseHasBattleButton(lines) {
  return (lines || []).some(lineHasBattleButton);
}

/** 按钮样式归一化：服务端 class -> {bg,border,color}。 */
export function buttonStyleFor(segment) {
  const cls = String((segment && segment.class) || '');
  if (cls.indexOf('outline') !== -1) {
    return { bg: 'transparent', border: '#8a6d2f', color: '#d4af37' };
  }
  /* danger 必须先于 success 判断：'btn-danger' 内含字母g，
   * 不能用单字母启发式，否则红色按钮会被误染成绿色。 */
  if (cls.indexOf('danger') !== -1) {
    return { bg: '#5a1a2a', border: '#ff4d6d', color: '#ffe3e8' };
  }
  if (cls.indexOf('success') !== -1 || cls.indexOf('warning') !== -1) {
    return { bg: '#2d5243', border: '#2d5243', color: '#e8f2ec' };
  }
  return { bg: '#3a2f46', border: '#6a5a7a', color: '#f0e6d2' };
}

/** 从 url 推导完整图片地址（相对路径补 apiBase）。 */
export function resolveImageUrl(apiBase, src) {
  const value = String(src || '');
  if (!value) return '';
  if (/^https?:\/\//.test(value)) return value;
  return `${String(apiBase || '').replace(/\/+$/, '')}${value}`;
}

/**
 * input/cmd-input 提交时拼命令：
 * cmd-input 直接 “cmd 值”；普通 input 记入表单值，由后续命令引用。
 */
export function buildInputCommand(segment, value) {
  const cmd = String((segment && segment.cmd) || '').trim();
  const val = String(value || '').trim();
  if (!cmd) return '';
  return val ? `${cmd} ${val}` : cmd;
}
