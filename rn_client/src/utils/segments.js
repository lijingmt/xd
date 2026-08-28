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
      units.push({
        text: String(part.content || ''),
        color: currentColor ? colorHexForClass(currentColor) : '#F0E6D2',
        bold: currentBold,
      });
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
