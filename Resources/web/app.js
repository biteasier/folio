// Folio page script. The native side calls folio.render(html, baseURL, opts);
// everything here only enhances that HTML (anchors, alerts, code, math, diagrams).
(() => {
  'use strict';
  const ROOT = new URL('.', location.href).href;
  const content = document.getElementById('content');
  const toc = document.getElementById('toc');
  const darkQuery = matchMedia('(prefers-color-scheme: dark)');
  let base = location.href;
  let seq = 0;

  const post = (type, extra = {}) => {
    try { webkit.messageHandlers.folio.postMessage({ type, ...extra }); } catch (_) {}
  };
  window.addEventListener('error', e => post('log', { message: `${e.message} (${e.filename}:${e.lineno})` }));
  window.addEventListener('unhandledrejection', e => post('log', { message: String(e.reason) }));

  // Load libraries only when a document actually needs them.
  const loading = {};
  const loadScript = path => loading[path] ||= new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = ROOT + path;
    s.onload = resolve;
    s.onerror = () => reject(new Error('could not load ' + path));
    document.head.appendChild(s);
  });
  const loadCSS = path => {
    if (loading[path]) return;
    loading[path] = true;
    const l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = ROOT + path;
    document.head.appendChild(l);
  };
  const esc = s => s.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // Relative links and images are relative to the Markdown file, not to this page.
  function resolveURLs(root) {
    for (const el of root.querySelectorAll('[src], [href], [poster]')) {
      for (const attr of ['src', 'href', 'poster']) {
        const v = el.getAttribute(attr);
        if (v == null) continue;
        if (/^\s*javascript:/i.test(v)) { el.removeAttribute(attr); continue; }
        if (attr === 'href' && v.startsWith('#')) continue;
        if (/^[a-z][a-z0-9+.-]*:/i.test(v) || v.startsWith('//')) continue;
        try { el.setAttribute(attr, new URL(v, base).href); } catch (_) {}
      }
    }
  }

  // GitHub-style heading ids, so #links and the table of contents work.
  function headingIDs(root) {
    const seen = new Map();
    for (const h of root.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
      let id = h.id;
      if (!id) {
        const slug = h.textContent.trim().toLowerCase()
          .replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, '').replace(/\s/g, '-');
        const n = seen.get(slug) || 0;
        seen.set(slug, n + 1);
        id = n ? `${slug}-${n}` : slug;
        h.id = id;
      }
      const a = document.createElement('a');
      a.className = 'anchor'; a.href = '#' + id; a.setAttribute('aria-hidden', 'true'); a.textContent = '#';
      h.prepend(a);
    }
  }

  const ALERT_ICONS = {
    note: 'M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Zm8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z',
    tip: 'M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253c.223.264.47.556.673.848.284.411.537.896.621 1.49a.75.75 0 0 1-1.484.211c-.04-.282-.163-.547-.37-.847a8.456 8.456 0 0 0-.542-.68c-.084-.1-.173-.205-.268-.32C3.201 7.75 2.5 6.766 2.5 5.25 2.5 2.31 4.863 0 8 0s5.5 2.31 5.5 5.25c0 1.516-.701 2.5-1.328 3.259-.095.115-.184.22-.268.319-.207.245-.383.453-.541.681-.208.3-.33.565-.37.847a.751.751 0 0 1-1.485-.212c.084-.593.337-1.078.621-1.489.203-.292.45-.584.673-.848.075-.088.147-.173.213-.253.561-.679.985-1.32.985-2.304 0-2.06-1.637-3.75-4-3.75ZM5.75 12h4.5a.75.75 0 0 1 0 1.5h-4.5a.75.75 0 0 1 0-1.5ZM6 15.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5a.75.75 0 0 1-.75-.75Z',
    important: 'M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13H1.75A1.75 1.75 0 0 1 0 11.25Zm1.75-.25a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5a.25.25 0 0 0-.25-.25Zm7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z',
    warning: 'M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z',
    caution: 'M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Zm.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5ZM8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z',
  };

  // > [!NOTE] … blocks, as on GitHub.
  function alerts(root) {
    for (const bq of root.querySelectorAll('blockquote')) {
      const p = bq.firstElementChild;
      if (!p || p.tagName !== 'P' || !p.firstChild || p.firstChild.nodeType !== 3) continue;
      const m = p.firstChild.data.match(/^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/i);
      if (!m) continue;
      const kind = m[1].toLowerCase();
      p.firstChild.data = p.firstChild.data.slice(m[0].length);
      if (p.firstChild.data === '' && p.childNodes[1]?.nodeName === 'BR') p.childNodes[1].remove();
      if (!p.textContent.trim() && !p.querySelector('img')) p.remove();
      bq.classList.add('alert', 'alert-' + kind);
      const title = document.createElement('p');
      title.className = 'alert-title';
      title.innerHTML = `<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true"><path d="${ALERT_ICONS[kind]}"/></svg>${kind[0].toUpperCase() + kind.slice(1)}`;
      bq.prepend(title);
    }
  }

  function wrapTables(root) {
    for (const t of root.querySelectorAll('table')) {
      if (t.parentElement?.classList.contains('table-wrap')) continue;
      const w = document.createElement('div');
      w.className = 'table-wrap';
      t.replaceWith(w);
      w.appendChild(t);
    }
  }

  function buildTOC() {
    const hs = content.querySelectorAll('h1, h2, h3, h4');
    const top = Math.min(...[...hs].map(h => +h.tagName[1]), 9);
    let html = '<div class="title">Contents</div>';
    for (const h of hs) {
      const level = Math.min(+h.tagName[1] - top + 1, 4);
      const text = esc(h.textContent.replace(/^#/, '').trim());
      html += `<a href="#${esc(h.id)}" class="l${level}" title="${text}">${text}</a>`;
    }
    if (!hs.length) html += '<div class="empty">No headings</div>';
    toc.innerHTML = html;
    if (document.body.classList.contains('toc-open')) markActive();   // avoids a forced layout
  }

  let ticking = false;
  function markActive() {
    const hs = content.querySelectorAll('h1, h2, h3, h4');
    let current = null;
    for (const h of hs) { if (h.getBoundingClientRect().top < 80) current = h; else break; }
    if (!current) current = hs[0];
    for (const a of toc.querySelectorAll('a')) a.classList.toggle('active', !!current && a.getAttribute('href') === '#' + current.id);
  }
  window.addEventListener('scroll', () => {
    if (ticking || !document.body.classList.contains('toc-open')) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; markActive(); });
  }, { passive: true });

  function scrollToId(id) {
    const el = document.getElementById(id) || document.getElementsByName(id)[0];
    if (el) el.scrollIntoView({ block: 'start' });
    return !!el;
  }

  // In-page links scroll instead of navigating.
  document.addEventListener('click', e => {
    const a = e.target.closest('a[href^="#"]');
    if (a) { e.preventDefault(); scrollToId(decodeURIComponent(a.getAttribute('href').slice(1))); return; }
    const btn = e.target.closest('.copy');
    if (btn) {
      const code = btn.closest('.code-block').querySelector('code');
      post('copy', { text: code ? code.textContent : '' });
      btn.classList.add('done');
      btn.innerHTML = ICON_CHECK;
      clearTimeout(btn._t);
      btn._t = setTimeout(() => { btn.classList.remove('done'); btn.innerHTML = ICON_COPY; }, 1400);
    }
  });

  async function renderMath(spans, blocks) {
    loadCSS('vendor/katex/katex.min.css');
    await loadScript('vendor/katex/katex.min.js');
    const opts = d => ({ displayMode: d, throwOnError: false, output: 'htmlAndMathml', strict: 'ignore', trust: false });
    for (const el of spans) {
      try { katex.render(el.textContent, el, opts(el.classList.contains('display'))); }
      catch (e) { el.classList.add('math-error'); }
    }
    for (const code of blocks) {
      const div = document.createElement('div');
      div.className = 'math display';
      try { katex.render(code.textContent, div, opts(true)); } catch (e) { div.textContent = code.textContent; div.classList.add('math-error'); }
      code.parentElement.replaceWith(div);
    }
    await document.fonts.ready;   // KaTeX hides glyphs until its fonts load
  }

  let mermaidTheme = null;
  async function renderMermaid(nodes, mySeq) {
    await loadScript('vendor/mermaid.min.js');
    const theme = darkQuery.matches ? 'dark' : 'default';
    if (theme !== mermaidTheme) {
      mermaid.initialize({
        startOnLoad: false, securityLevel: 'strict', theme: theme === 'dark' ? 'dark' : 'neutral',
        fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
        themeVariables: theme === 'dark' ? { background: 'transparent' } : {},
      });
      mermaidTheme = theme;
    }
    let i = 0;
    for (const node of nodes) {
      if (mySeq !== seq) return;
      const src = node.dataset.source ?? node.textContent;
      const div = document.createElement('div');
      div.className = 'mermaid-diagram';
      div.dataset.source = src;
      try {
        const { svg } = await mermaid.render(`mmd-${mySeq}-${i++}`, src);
        div.innerHTML = svg;
      } catch (e) {
        div.innerHTML = `<pre class="mermaid-error">Mermaid: ${esc(String(e.message || e))}</pre>`;
        document.querySelectorAll('body > [id^="dmmd-"]').forEach(n => n.remove());
      }
      (node.tagName === 'CODE' ? node.parentElement : node).replaceWith(div);
    }
  }
  darkQuery.addEventListener('change', () => {
    const diagrams = content.querySelectorAll('.mermaid-diagram');
    if (diagrams.length) renderMermaid(diagrams, seq);
  });

  const ICON_COPY = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25Z"/><path d="M5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z"/></svg>';
  const ICON_CHECK = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.75.75 0 0 1 1.06-1.06L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"/></svg>';

  // Syntax highlighting runs only for code that is on (or near) screen, so a
  // long document appears immediately. Highlighting never changes layout.
  let hlReady = null;
  const highlightOne = code => {
    if (code.dataset.hl) return;
    code.dataset.hl = '1';
    if (hljs.getLanguage(code.dataset.lang)) hljs.highlightElement(code);
  };
  const hlObserver = new IntersectionObserver(entries => {
    for (const e of entries) if (e.isIntersecting) { hlObserver.unobserve(e.target); highlightOne(e.target); }
  }, { rootMargin: '1200px 0px' });

  async function highlightAll() {
    if (!hlReady) return;
    await hlReady;
    for (const code of content.querySelectorAll('code[data-lang]:not([data-hl])')) highlightOne(code);
  }

  async function enhance(mySeq) {
    const highlight = [], mermaidBlocks = [], mathBlocks = [];
    hlObserver.disconnect();
    for (const code of content.querySelectorAll('pre > code')) {
      const lang = (code.className.match(/language-([^\s]+)/) || [])[1]?.toLowerCase();
      if (lang === 'mermaid') { mermaidBlocks.push(code); continue; }
      if (lang === 'math') { mathBlocks.push(code); continue; }
      const pre = code.parentElement;
      const wrap = document.createElement('div');
      wrap.className = 'code-block';
      const tools = document.createElement('div');
      tools.className = 'code-tools';
      if (lang) {
        wrap.dataset.lang = lang;
        code.dataset.lang = lang;
        highlight.push(code);
        const label = document.createElement('span');
        label.className = 'code-lang';
        label.textContent = lang;
        tools.appendChild(label);
      }
      const btn = document.createElement('button');
      btn.className = 'copy'; btn.type = 'button'; btn.title = 'Copy'; btn.innerHTML = ICON_COPY;
      tools.appendChild(btn);
      pre.replaceWith(wrap);
      wrap.append(pre, tools);
    }
    const mathSpans = content.querySelectorAll('.math');
    const jobs = [];
    if (highlight.length) {
      hlReady = loadScript('vendor/highlight.min.js').then(() => hljs.configure({ ignoreUnescapedHTML: true }));
      jobs.push(hlReady.then(() => {
        if (mySeq !== seq) return;
        if (highlight.length <= 40) highlight.forEach(highlightOne);   // small docs: all at once
        else highlight.forEach(c => hlObserver.observe(c));
      }));
    }
    if (mathSpans.length || mathBlocks.length) jobs.push(renderMath(mathSpans, mathBlocks));
    if (mermaidBlocks.length) jobs.push(renderMermaid(mermaidBlocks, mySeq));
    const results = await Promise.allSettled(jobs);
    for (const r of results) if (r.status === 'rejected') post('log', { message: String(r.reason) });
  }

  window.folio = {
    async render(html, baseURL, opts = {}) {
      const mySeq = ++seq;
      if (baseURL) base = baseURL;
      const y = window.scrollY;
      const t = document.createElement('template');   // inert: nothing loads until it's in the page
      t.innerHTML = html;
      resolveURLs(t.content);
      headingIDs(t.content);
      alerts(t.content);
      wrapTables(t.content);
      content.classList.remove('source-view');
      content.replaceChildren(t.content);
      buildTOC();
      folio.setTOC(!!opts.toc);
      if (opts.keepScroll) window.scrollTo(0, y); else if (window.scrollY) window.scrollTo(0, 0);
      await enhance(mySeq);
      if (opts.keepScroll) window.scrollTo(0, y);
      if (mySeq === seq) post('rendered');
    },

    async showSource(text, keep) {
      const mySeq = ++seq;
      const y = window.scrollY;
      content.classList.add('source-view');
      content.innerHTML = `<pre><code class="language-markdown">${esc(text)}</code></pre>`;
      toc.innerHTML = '<div class="title">Contents</div><div class="empty">Not available in source view</div>';
      if (text.length < 400000) {
        await loadScript('vendor/highlight.min.js');
        hljs.highlightElement(content.querySelector('code'));
      }
      window.scrollTo(0, keep ? y : 0);
      if (mySeq === seq) post('rendered');
    },

    highlightAll,   // before printing, so every code block is coloured
    setTOC(on) { document.body.classList.toggle('toc-open', on); if (on) markActive(); },
    scrollToId,
  };

  post('ready');
})();
