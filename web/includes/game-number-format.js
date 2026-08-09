(function(root, factory) {
    var api = factory(root);
    if (typeof module === 'object' && module.exports) {
        module.exports = api;
    }
    if (root) {
        root.GameNumberFormat = api;
    }
})(typeof window !== 'undefined' ? window : globalThis, function(root) {
    'use strict';

    var STORAGE_KEY = 'compact_game_numbers';
    var UNITS = [
        { value: 1e4, label: '万' },
        { value: 1e8, label: '亿' },
        { value: 1e12, label: '万亿' },
        { value: 1e16, label: '京' },
        { value: 1e20, label: '垓' },
        { value: 1e24, label: '秭' },
        { value: 1e28, label: '穰' }
    ];
    var SKIP_TAGS = {
        SCRIPT: true,
        STYLE: true,
        TEXTAREA: true,
        INPUT: true,
        SELECT: true,
        OPTION: true,
        CODE: true,
        PRE: true,
        NOSCRIPT: true
    };
    var observer = null;

    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function parseValue(value) {
        if (value === null || value === undefined || value === '') return null;
        var raw = String(value).trim();
        var normalized = raw.replace(/,/g, '');
        if (!/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?$/i.test(normalized)) {
            return null;
        }
        var number = Number(normalized);
        if (!Number.isFinite(number)) return null;
        return { raw: raw, normalized: normalized, number: number };
    }

    function groupPlainDecimal(normalized) {
        var sign = '';
        var source = normalized;
        if (source.charAt(0) === '-' || source.charAt(0) === '+') {
            sign = source.charAt(0) === '-' ? '-' : '';
            source = source.slice(1);
        }
        if (/[eE]/.test(source)) return null;
        var pieces = source.split('.');
        var integer = pieces[0] || '0';
        var decimal = pieces.length > 1 ? '.' + pieces[1] : '';
        integer = integer.replace(/^0+(?=\d)/, '');
        return sign + integer.replace(/\B(?=(\d{3})+(?!\d))/g, ',') + decimal;
    }

    function formatExactNumber(value) {
        var parsed = parseValue(value);
        if (!parsed) return value === null || value === undefined ? '0' : String(value);
        var grouped = groupPlainDecimal(parsed.normalized);
        if (grouped !== null) return grouped;
        return parsed.number.toLocaleString('en-US', {
            useGrouping: true,
            maximumFractionDigits: 20
        });
    }

    function preferredDigits(scaled, maxFractionDigits) {
        var absolute = Math.abs(scaled);
        var digits = absolute >= 100 ? 0 : (absolute >= 10 ? 1 : 2);
        if (Number.isFinite(maxFractionDigits)) {
            digits = Math.min(digits, Math.max(0, Math.floor(maxFractionDigits)));
        }
        return digits;
    }

    function formatNumberParts(value, options) {
        var settings = options || {};
        var parsed = parseValue(value);
        if (!parsed) {
            var fallback = value === null || value === undefined ? '0' : String(value);
            return { display: fallback, exact: fallback, compacted: false };
        }

        var exact = formatExactNumber(parsed.normalized);
        var threshold = Number.isFinite(settings.threshold)
            ? Math.max(1, settings.threshold)
            : 1e4;
        var compact = settings.compact !== false;
        var absolute = Math.abs(parsed.number);
        if (!compact || absolute < threshold) {
            return { display: exact, exact: exact, compacted: false };
        }

        var unitIndex = -1;
        for (var index = UNITS.length - 1; index >= 0; index -= 1) {
            if (absolute >= UNITS[index].value) {
                unitIndex = index;
                break;
            }
        }
        if (unitIndex < 0) {
            return { display: exact, exact: exact, compacted: false };
        }

        var scaled = parsed.number / UNITS[unitIndex].value;
        var digits = preferredDigits(scaled, settings.maxFractionDigits);
        var rounded = Number(scaled.toFixed(digits));
        while (Math.abs(rounded) >= 10000 && unitIndex < UNITS.length - 1) {
            unitIndex += 1;
            scaled = parsed.number / UNITS[unitIndex].value;
            digits = preferredDigits(scaled, settings.maxFractionDigits);
            rounded = Number(scaled.toFixed(digits));
        }
        var compactValue = rounded.toFixed(digits);
        if (compactValue.indexOf('.') !== -1) {
            compactValue = compactValue.replace(/0+$/, '').replace(/\.$/, '');
        }
        return {
            display: compactValue + UNITS[unitIndex].label,
            exact: exact,
            compacted: true
        };
    }

    function formatNumber(value, options) {
        return formatNumberParts(value, options).display;
    }

    function isCompactEnabled() {
        try {
            return !root || !root.localStorage || root.localStorage.getItem(STORAGE_KEY) !== '0';
        } catch (error) {
            return true;
        }
    }

    function setCompactEnabled(enabled) {
        try {
            if (root && root.localStorage) {
                root.localStorage.setItem(STORAGE_KEY, enabled ? '1' : '0');
            }
        } catch (error) {
            // Storage can be unavailable in private/locked-down browser contexts.
        }
        return Boolean(enabled);
    }

    function hasProtectedLabel(textBefore) {
        return /(?:账号|帐号|用户|角色|人物|订单|流水|序列|验证码|密码|邀请码|编号|群号|手机号|电话|端口|版本|日期|时间|坐标|等级|级别|QQ|UID|ID|TXD)[\s：:#=号_-]*[\d,./~～至到-]*$/i.test(textBefore);
    }

    function shouldProtectNumber(text, match, start, end) {
        var normalized = match.replace(/^[+-]/, '').replace(/,/g, '');
        var integerPart = normalized.split('.')[0];
        if (integerPart.length > 1 && integerPart.charAt(0) === '0') return true;
        if (/^(?:19|20)\d{6}$/.test(integerPart)) return true;

        var before = text.slice(Math.max(0, start - 24), start);
        var after = text.slice(end, Math.min(text.length, end + 12));
        var previous = start > 0 ? text.charAt(start - 1) : '';
        var next = end < text.length ? text.charAt(end) : '';
        var multiplierContext = (previous === 'x' || previous === 'X' || previous === '×') &&
            (start < 2 || !/[A-Za-z0-9_]/.test(text.charAt(start - 2)));

        if (/[A-Za-z0-9_]/.test(previous) && !multiplierContext) return true;
        if (/[A-Za-z0-9_]/.test(next)) return true;
        if (previous === '#' || previous === '@') return true;
        if (hasProtectedLabel(before)) return true;
        if (/(?:CMD|DYNAMIC_INVITE_LINK)[A-Z0-9_:=-]*$/i.test(before)) return true;
        if (/(?:第|Lv\.?|level\s*)$/i.test(before)) return true;
        if (/^(?:级|级别|层|页|章|年|月|日|号|%|％)/.test(after)) return true;
        if (/^(?:万亿|万|亿|京|垓|秭|穰)/.test(after)) return true;
        return false;
    }

    function formatPlainSegment(text, options) {
        var settings = options || {};
        var allowHtml = settings.allowHtml !== false;
        var compact = settings.compact !== false;
        var output = '';
        var lastIndex = 0;
        var numberPattern = /[+-]?\d+(?:,\d{3})*(?:\.\d+)?/g;
        var match;
        while ((match = numberPattern.exec(text)) !== null) {
            var raw = match[0];
            var start = match.index;
            var end = start + raw.length;
            var prefix = text.slice(lastIndex, start);
            output += allowHtml ? prefix : escapeHtml(prefix);

            var parsed = parseValue(raw);
            var protectedNumber = !parsed || Math.abs(parsed.number) < 1e4 ||
                shouldProtectNumber(text, raw, start, end);
            if (protectedNumber || !compact) {
                output += allowHtml ? raw : escapeHtml(raw);
            } else {
                var parts = formatNumberParts(raw, settings);
                if (!parts.compacted) {
                    output += allowHtml ? parts.display : escapeHtml(parts.display);
                } else {
                    output += '<span class="game-number-compact" title="精确值：' +
                        escapeHtml(parts.exact) + '" aria-label="精确值 ' +
                        escapeHtml(parts.exact) + '">' + escapeHtml(parts.display) + '</span>';
                }
            }
            lastIndex = end;
        }
        var suffix = text.slice(lastIndex);
        output += allowHtml ? suffix : escapeHtml(suffix);
        return output;
    }

    function formatText(value, options) {
        if (value === null || value === undefined || value === '') return value || '';
        var settings = Object.assign({}, options || {});
        if (settings.compact === undefined) settings.compact = isCompactEnabled();
        var text = String(value);
        var protectedPattern = /(<!--[\s\S]*?-->|<[^>]*>|&(?:#\d+|#x[0-9a-f]+|[a-z]+);|\[imgurl\s+picture:[^\]]+\]|(?:https?:\/\/|www\.)[^\s<]+|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|\b(?:\d{1,3}\.){3}\d{1,3}\b|\b(?:19|20)\d{2}[-\/.]\d{1,2}[-\/.]\d{1,2}\b|\b\d{1,2}:\d{2}(?::\d{2})?\b|\bv?\d+\.\d+(?:\.\d+)*(?:[-+][\w.-]+)?\b)/gi;
        var output = '';
        var lastIndex = 0;
        var match;
        while ((match = protectedPattern.exec(text)) !== null) {
            output += formatPlainSegment(text.slice(lastIndex, match.index), settings);
            output += settings.allowHtml === false ? escapeHtml(match[0]) : match[0];
            lastIndex = match.index + match[0].length;
        }
        output += formatPlainSegment(text.slice(lastIndex), settings);
        return output;
    }

    function shouldSkipElement(element) {
        if (!element || element.nodeType !== 1) return false;
        if (SKIP_TAGS[element.tagName]) return true;
        if (element.classList && element.classList.contains('game-number-compact')) return true;
        if (typeof element.closest === 'function' &&
            element.closest('[data-number-format="off"], .game-number-compact')) return true;
        return false;
    }

    function formatTextNode(node) {
        if (!node || node.nodeType !== 3 || !node.nodeValue || !node.parentElement) return;
        if (shouldSkipElement(node.parentElement)) return;
        var formatted = formatText(node.nodeValue, { allowHtml: false, compact: true });
        if (formatted === escapeHtml(node.nodeValue)) return;
        var template = node.ownerDocument.createElement('template');
        template.innerHTML = formatted;
        node.parentNode.replaceChild(template.content, node);
    }

    function formatDom(rootNode) {
        if (!rootNode || !isCompactEnabled() || !rootNode.ownerDocument && !rootNode.createTreeWalker) return;
        if (rootNode.nodeType === 3) {
            formatTextNode(rootNode);
            return;
        }
        if (rootNode.nodeType === 1 && shouldSkipElement(rootNode)) return;
        var documentRef = rootNode.ownerDocument || rootNode;
        var walker = documentRef.createTreeWalker(
            rootNode,
            root.NodeFilter ? root.NodeFilter.SHOW_TEXT : 4
        );
        var nodes = [];
        var current;
        while ((current = walker.nextNode())) nodes.push(current);
        nodes.forEach(formatTextNode);
    }

    function startAutoFormat(documentRef) {
        if (!documentRef || !documentRef.body || !isCompactEnabled()) return;
        formatDom(documentRef.body);
        if (!root.MutationObserver || observer) return;
        observer = new root.MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
                if (mutation.type === 'characterData') {
                    formatTextNode(mutation.target);
                } else {
                    Array.prototype.forEach.call(mutation.addedNodes || [], function(node) {
                        formatDom(node);
                    });
                }
            });
        });
        observer.observe(documentRef.body, {
            childList: true,
            characterData: true,
            subtree: true
        });
    }

    var api = {
        STORAGE_KEY: STORAGE_KEY,
        UNITS: UNITS.slice(),
        formatNumber: formatNumber,
        formatNumberParts: formatNumberParts,
        formatExactNumber: formatExactNumber,
        formatText: formatText,
        formatDom: formatDom,
        startAutoFormat: startAutoFormat,
        isCompactEnabled: isCompactEnabled,
        setCompactEnabled: setCompactEnabled
    };

    if (root && root.document) {
        var script = root.document.currentScript;
        var autoFormat = !script || script.getAttribute('data-auto-format') !== 'false';
        if (autoFormat) {
            if (root.document.readyState === 'loading') {
                root.document.addEventListener('DOMContentLoaded', function() {
                    startAutoFormat(root.document);
                }, { once: true });
            } else {
                startAutoFormat(root.document);
            }
        }
    }

    return api;
});
