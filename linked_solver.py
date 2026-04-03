"""
LinkedIn Learning Solver  ·  v4.0
Cross-platform: Windows & Linux

Features
────────
• Incognito Chrome windows (no profile on disk, fresh every run)
• Multi-course solver — add N course URLs; each course runs in parallel
• Uses LinkedIn's built-in auto-advance — one tab per course,
  speed enforcer re-injected on each video transition
• Always starts from first video (no resume)
• Adaptive or flat 16x speed toggle

Requirements: pip install selenium webdriver-manager
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import threading
import time
import re
import os
import sys
import platform
import random
import tempfile

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.chrome.service import Service
except ImportError:
    print("selenium not found. Run: pip install selenium webdriver-manager")
    sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
#  JavaScript payloads
# ─────────────────────────────────────────────────────────────────────────────

JS_GET_DURATION = """
return (function() {
    var v = document.querySelector('video');
    return v ? v.duration : null;
})();
"""

JS_SPEED_ENFORCER = r"""
(function(SPEED) {
    if (window.__16xEnforcerActive) return;
    window.__16xEnforcerActive = true;
    'use strict';
    var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'playbackRate');
    if (desc && desc.set) {
        Object.defineProperty(HTMLMediaElement.prototype, 'playbackRate', {
            get: function()  { return SPEED; },
            set: function()  { desc.set.call(this, SPEED); },
            configurable: true
        });
    }
    setInterval(function() {
        document.querySelectorAll('video').forEach(function(v) {
            if (desc && desc.set && v.playbackRate !== SPEED) desc.set.call(v, SPEED);
            if (!v.muted) { v.muted = true; v.volume = 0; }
            if (v.paused && !v.ended) v.play().catch(function(){});
        });
    }, 500);
    try {
        document.hasFocus = function() { return true; };
        Object.defineProperty(document, 'visibilityState',
            { get: function(){ return 'visible'; }, configurable: true });
        Object.defineProperty(document, 'hidden',
            { get: function(){ return false; }, configurable: true });
    } catch(e) {}
    console.log('[' + SPEED + 'x] enforcer installed');
})(arguments[0]);
"""

JS_CHECK_OOPS = """
return (function() {
    if (!document.body) return false;
    var t = (document.body.innerText || '').substring(0, 500);
    return t.indexOf('Oops') !== -1 && t.indexOf('Try again') !== -1;
})();
"""

JS_VIDEO_ENDED = """
return (function() {
    var v = document.querySelector('video');
    if (!v) return false;
    return v.ended || (v.duration > 0 && Math.abs(v.currentTime - v.duration) < 1.5);
})();
"""

JS_READY_STATE = "return document.readyState;"

JS_EXTRACT_VIDEO_URLS = r"""
return (function() {
    var seen = {}, urls = [], titles = [];
    document.querySelectorAll('a.classroom-toc-item__link').forEach(function(a) {
        var href = a.getAttribute('href');
        if (!href) return;
        var clean = href.split('?')[0];
        if (seen[clean]) return;
        seen[clean] = true;
        urls.push('https://www.linkedin.com' + clean + '?autoplay=true');
        var el = a.querySelector('.classroom-toc-item__title');
        titles.push(el ? el.innerText.trim() : clean.split('/').pop());
    });
    if (urls.length === 0) {
        var base = window.location.pathname.split('/').slice(0, 3).join('/');
        document.querySelectorAll('a[href]').forEach(function(a) {
            var href = a.getAttribute('href') || '';
            if (!href.startsWith(base + '/')) return;
            var parts = href.split('?')[0].split('/');
            if (parts.length < 4) return;
            var clean = parts.slice(0, 4).join('/');
            if (seen[clean]) return;
            seen[clean] = true;
            urls.push('https://www.linkedin.com' + clean + '?autoplay=true');
            titles.push(parts[3]);
        });
    }
    return { urls: urls, titles: titles };
})();
"""


# ─────────────────────────────────────────────────────────────────────────────
#  Per-session driver wrapper  (incognito, no persistent profile)
# ─────────────────────────────────────────────────────────────────────────────

class SessionDriver:
    """One incognito Chrome window = one LinkedIn session."""

    def __init__(self, email, password, session_idx, course_label, log_cb):
        self.email        = email
        self.password     = password
        self.idx          = session_idx   # 1-based label
        self.course_label = course_label  # short identifier for logs
        self.log          = log_cb
        self.driver       = None
        self.lock         = threading.Lock()
        self.ready        = False

    def _pfx(self, msg):
        return f"[{self.course_label}|S{self.idx}] {msg}"

    def build_and_login(self):
        self.driver = self._build_driver()
        self._login()
        self.ready = True

    def quit(self):
        try:
            if self.driver:
                self.driver.quit()
        except Exception:
            pass

    # ── internal ──────────────────────────────────────────────────────────────

    def _build_driver(self):
        opts = Options()

        # ── Incognito ─────────────────────────────────────────────────────────
        opts.add_argument("--incognito")

        # ── Anti-detection ────────────────────────────────────────────────────
        opts.add_argument("--disable-blink-features=AutomationControlled")
        opts.add_experimental_option("excludeSwitches", ["enable-automation"])
        opts.add_experimental_option("useAutomationExtension", False)

        # ── Performance / stability ───────────────────────────────────────────
        opts.add_argument("--no-sandbox")
        opts.add_argument("--disable-dev-shm-usage")
        opts.add_argument("--disable-background-timer-throttling")
        opts.add_argument("--disable-backgrounding-occluded-windows")
        opts.add_argument("--disable-renderer-backgrounding")
        opts.add_argument("--disable-features=CalculateNativeWinOcclusion")
        opts.add_argument("--autoplay-policy=no-user-gesture-required")
        opts.add_argument("--disable-gpu")

        # Unique crash-dir per session so parallel instances don't collide
        crash_dir = os.path.join(
            tempfile.gettempdir(),
            f"li_crash_{self.course_label}_{self.idx}_{os.getpid()}")
        opts.add_argument(f"--crash-dumps-dir={crash_dir}")

        for p in ["/usr/bin/chromium", "/usr/bin/chromium-browser",
                  "/snap/bin/chromium", "/usr/bin/google-chrome"]:
            if os.path.exists(p):
                opts.binary_location = p
                break

        driver   = None
        last_err = None
        for fn in [
            lambda: webdriver.Chrome(options=opts),
            lambda: self._sys_cd(opts),
            lambda: self._wdm(opts),
        ]:
            try:
                d = fn()
                if d:
                    driver = d
                    break
            except Exception as e:
                last_err = e

        if driver is None:
            raise RuntimeError(
                self._pfx(
                    f"Cannot launch browser. "
                    f"Linux: sudo apt install chromium chromium-driver\n{last_err}"))

        driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {
            "source": "Object.defineProperty(navigator,'webdriver',{get:()=>undefined})"
        })
        return driver

    def _sys_cd(self, opts):
        import shutil
        candidates = ["/usr/bin/chromedriver", "/usr/local/bin/chromedriver",
                      shutil.which("chromedriver") or ""]
        cd = next((p for p in candidates if p and os.path.exists(p)), None)
        if cd:
            return webdriver.Chrome(service=Service(cd), options=opts)
        return None

    def _wdm(self, opts):
        from webdriver_manager.chrome import ChromeDriverManager
        return webdriver.Chrome(
            service=Service(ChromeDriverManager().install()), options=opts)

    def _login(self):
        self.log(self._pfx(f"Logging in as {self.email}..."))
        self.driver.get("https://www.linkedin.com/login")
        wait = WebDriverWait(self.driver, 25)
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(self.email)
        self.driver.find_element(By.ID, "password").send_keys(self.password)
        self.driver.find_element(By.XPATH, "//button[@type='submit']").click()
        wait.until(lambda d: "login" not in d.current_url)
        self.log(self._pfx("Logged in."))


# ─────────────────────────────────────────────────────────────────────────────
#  Engine  (one instance per course)
# ─────────────────────────────────────────────────────────────────────────────

class SixteenXEngine:
    def __init__(self, log_cb, course_label, app=None):
        self.log          = log_cb
        self.course_label = course_label
        self.app          = app
        self.sessions     = []
        self.running      = False

    def _pfx(self, msg):
        return f"[{self.course_label}] {msg}"

    # ── TOC extraction ────────────────────────────────────────────────────────

    def load_course_and_expand_toc(self, course_url):
        driver = self.sessions[0].driver
        m    = re.match(r'(https://www\.linkedin\.com/learning/[^/?#]+)', course_url)
        base = m.group(1) if m else course_url.split('?')[0]
        self.log(self._pfx(f"Loading course: {base}"))
        driver.get(base)
        try:
            WebDriverWait(driver, 20).until(
                EC.presence_of_element_located((By.CSS_SELECTOR,
                    ".classroom-nav,.course-detail,[class*='classroom'],"
                    "[class*='course-hero'],main")))
        except Exception:
            time.sleep(5)

        for xpath in [
            "//button[contains(.,'Contents')]",
            "//button[contains(.,'Chapters')]",
            "//button[contains(.,'Table of contents')]",
            "//*[@data-control-name='toc_toggle']",
            "//*[contains(@class,'classroom-nav__item') and contains(.,'Contents')]",
            "//*[contains(@aria-label,'course content')]",
        ]:
            try:
                driver.find_element(By.XPATH, xpath).click()
                self.log(self._pfx("Opened contents panel."))
                time.sleep(2)
                break
            except Exception:
                continue

        try:
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located(
                    (By.CSS_SELECTOR, "a.classroom-toc-item__link")))
        except Exception:
            self.log(self._pfx("TOC links slow to appear — scrolling anyway..."))

        self.log(self._pfx("Scanning TOC for videos..."))
        prev_count = 0
        for _ in range(10):
            driver.execute_script(
                "var t=document.querySelector"
                "('.classroom-toc-container,.classroom-toc,[class*=\"toc\"]');"
                "if(t)t.scrollTop+=600;"
                "window.scrollTo(0,document.body.scrollHeight);")
            links = driver.find_elements(By.CSS_SELECTOR, "a.classroom-toc-item__link")
            if len(links) > 0 and len(links) == prev_count:
                break
            prev_count = len(links)
            time.sleep(0.6)
        driver.execute_script("window.scrollTo(0,0);")
        return base

    def extract_video_urls(self):
        driver = self.sessions[0].driver
        self.log(self._pfx("Extracting video URLs..."))
        data   = driver.execute_script(JS_EXTRACT_VIDEO_URLS)
        urls   = data.get("urls")   or []
        titles = data.get("titles") or []
        self.log(self._pfx(f"Found {len(urls)} video(s)."))
        for i, t in enumerate(titles, 1):
            self.log(f"   {i:3}. {t}")
        return urls, titles

    def _adaptive_speed(self, sess, handle):
        """Pick speed based on video duration, or flat 16x if toggle off."""
        try:
            if self.app and not self.app.v_adaptive.get():
                return 16.0  # flat mode
            sess.driver.switch_to.window(handle)
            duration = sess.driver.execute_script(JS_GET_DURATION)
            if duration is None:
                return 4.0
            minutes = duration / 60.0
            if minutes < 2:
                return 2.0
            elif minutes < 5:
                return 4.0
            elif minutes < 10:
                return 8.0
            else:
                return 16.0
        except Exception:
            return 4.0

    # ── Auto-advance monitor ──────────────────────────────────────────────────

    def _play_and_monitor(self, sess, urls, titles):
        """
        Navigate to the FIRST video, inject speed enforcer, then let
        LinkedIn's built-in auto-advance play through all videos.
        Re-inject enforcer on each URL change (new video).
        """
        total = len(urls)
        if total == 0:
            return

        first_url = urls[0]
        driver    = sess.driver

        self.log(self._pfx(f"▶  Navigating to first video: {titles[0]}"))
        driver.get(first_url)

        # Wait for page load
        deadline = time.time() + 60
        while time.time() < deadline and self.running:
            try:
                state = driver.execute_script(JS_READY_STATE)
                if state in ("interactive", "complete"):
                    break
            except Exception:
                pass
            time.sleep(0.5)

        # Inject speed enforcer for first video
        time.sleep(2)
        try:
            speed = self._adaptive_speed(sess, driver.current_window_handle)
            driver.execute_script(JS_SPEED_ENFORCER, speed)
            self.log(self._pfx(
                f"  ▶  [1/{total}] {titles[0]}  [{speed}x muted]"))
        except Exception as e:
            self.log(self._pfx(f"   ⚠ Inject error: {e}"))

        # Build a set of expected video paths for tracking progress
        url_paths = [u.split('?')[0] for u in urls]
        current_idx   = 0
        last_path     = driver.current_url.split('?')[0]
        stable_count  = 0    # how many polls the URL has been stable

        while self.running:
            time.sleep(3)

            try:
                is_oops = driver.execute_script(JS_CHECK_OOPS)
            except Exception:
                is_oops = False

            if is_oops:
                self.log(self._pfx("   Oops detected — reloading..."))
                driver.get(urls[current_idx])
                time.sleep(3)
                try:
                    driver.execute_script("window.__16xEnforcerActive=false;")
                    speed = self._adaptive_speed(sess, driver.current_window_handle)
                    driver.execute_script(JS_SPEED_ENFORCER, speed)
                except Exception:
                    pass
                last_path = driver.current_url.split('?')[0]
                stable_count = 0
                continue

            try:
                current_path = driver.current_url.split('?')[0]
            except Exception:
                continue

            # Detect URL change → LinkedIn auto-advanced to next video
            if current_path != last_path:
                last_path    = current_path
                stable_count = 0

                # Figure out which video we're on now
                new_idx = None
                for i, p in enumerate(url_paths):
                    if p in current_path or current_path in p:
                        new_idx = i
                        break

                if new_idx is not None and new_idx != current_idx:
                    self.log(self._pfx(
                        f"  ✅ [{current_idx+1}/{total}] '{titles[current_idx]}' done."))
                    current_idx = new_idx

                # Re-inject speed enforcer for the new video
                time.sleep(2)
                try:
                    driver.execute_script("window.__16xEnforcerActive=false;")
                    speed = self._adaptive_speed(sess, driver.current_window_handle)
                    driver.execute_script(JS_SPEED_ENFORCER, speed)
                    self.log(self._pfx(
                        f"  ▶  [{current_idx+1}/{total}] {titles[current_idx] if current_idx < total else '?'}  [{speed}x muted]"))
                except Exception as e:
                    self.log(self._pfx(f"   ⚠ Re-inject error: {e}"))

                # If we've gone past the last known video, we're done
                if new_idx is not None and new_idx >= total - 1:
                    # Wait for the last video to finish
                    self._wait_last_video(sess, driver, titles[-1], total)
                    break
                elif new_idx is None:
                    # URL doesn't match any known video — might have left
                    # the course page entirely (course complete page)
                    if 'learning' not in current_path:
                        self.log(self._pfx(
                            f"  ✅ [{current_idx+1}/{total}] '{titles[current_idx]}' done."))
                        break
            else:
                stable_count += 1

            # Check if the current (possibly last) video ended
            try:
                video_ended = driver.execute_script(JS_VIDEO_ENDED)
            except Exception:
                video_ended = False

            if video_ended and current_idx >= total - 1:
                self.log(self._pfx(
                    f"  ✅ [{total}/{total}] '{titles[-1]}' done (last video ended)."))
                break

            # Safety: re-inject enforcer periodically (every ~30s of stable URL)
            if stable_count > 0 and stable_count % 10 == 0:
                try:
                    driver.execute_script("window.__16xEnforcerActive=false;")
                    speed = self._adaptive_speed(sess, driver.current_window_handle)
                    driver.execute_script(JS_SPEED_ENFORCER, speed)
                except Exception:
                    pass

        if not self.running:
            self.log(self._pfx("🛑 Stopped by user."))
        else:
            self.log(self._pfx("\n🎉 All videos done!"))

    def _wait_last_video(self, sess, driver, title, total):
        """Wait for the last video to finish playing."""
        self.log(self._pfx(f"  ⏳ Waiting for last video '{title}' to finish..."))
        while self.running:
            time.sleep(3)
            try:
                video_ended = driver.execute_script(JS_VIDEO_ENDED)
            except Exception:
                video_ended = False
            if video_ended:
                self.log(self._pfx(
                    f"  ✅ [{total}/{total}] '{title}' done (ended)."))
                break
            # Also re-inject periodically
            try:
                driver.execute_script("window.__16xEnforcerActive=false;")
                speed = self._adaptive_speed(sess, driver.current_window_handle)
                driver.execute_script(JS_SPEED_ENFORCER, speed)
            except Exception:
                pass

    # ── Top-level run ─────────────────────────────────────────────────────────

    def run(self, email, password, n_sessions, course_url,
            stagger_ms=500, batch_size=5,
            batch_gap_min=8, batch_gap_max=15):
        self.running = True
        n_sessions = 1   # auto-advance only needs 1 session
        try:
            self.log(self._pfx("=" * 50))
            self.log(self._pfx(f"  Course: {course_url}"))
            self.log(self._pfx("=" * 50))

            self.sessions = [
                SessionDriver(email, password, i+1, self.course_label, self.log)
                for i in range(n_sessions)
            ]

            self.log(self._pfx(
                f"🔑 Logging in with {n_sessions} incognito session..."))
            login_threads = [
                threading.Thread(target=s.build_and_login, daemon=True)
                for s in self.sessions
            ]
            for t in login_threads: t.start()
            for t in login_threads: t.join()

            failed = [s for s in self.sessions if not s.ready]
            if failed:
                self.log(self._pfx(
                    f"⚠  {len(failed)} session(s) failed — continuing with rest."))
                self.sessions = [s for s in self.sessions if s.ready]

            if not self.sessions:
                self.log(self._pfx("❌ No sessions logged in. Aborting."))
                return

            self.load_course_and_expand_toc(course_url)
            urls, titles = self.extract_video_urls()

            if not urls:
                self.log(self._pfx("\n❌ No videos found."))
                self.log(self._pfx(
                    "   Ensure you're on the course overview page "
                    "with Contents sidebar visible."))
                return

            self.log(self._pfx(
                f"\n🚀 {len(urls)} videos — using LinkedIn auto-advance "
                f"(always starting from video 1)\n"))

            # Use the first session, navigate to first video, let LinkedIn
            # auto-advance through the rest
            self._play_and_monitor(self.sessions[0], urls, titles)
            self.log(self._pfx("\n✅ Course complete."))

        except Exception as e:
            self.log(self._pfx(f"\n💥 Error: {e}"))
            import traceback
            self.log(traceback.format_exc())
        finally:
            self.running = False


# ─────────────────────────────────────────────────────────────────────────────
#  GUI
# ─────────────────────────────────────────────────────────────────────────────

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("LinkedIn Learning Solver")
        self.configure(bg="#0a0a0a")
        self.resizable(True, True)
        self.engines = []
        self.threads = []
        self._build_ui()
        self.after(300, self._show_beta_notice)

    def _show_beta_notice(self):
        messagebox.showinfo(
            "⚠ Beta Version",
            "This is a BETA version.\n\n"
            "For now, please use:\n"
            "  • 1 course URL only\n"
            "  • 1 session\n"
            "  • 1 video at a time (auto-advance)\n\n"
            "Multi-course support is still being tested."
        )

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        IS_WIN   = platform.system() == "Windows"
        BG       = "#0a0a0a"
        FG       = "#e0e0e0"
        ACCENT   = "#0073b1"
        RED      = "#c0392b"
        ENTRY_BG = "#141428"
        DIM      = "#2a2a2a"
        UI_FONT  = ("Segoe UI", 10)         if IS_WIN else ("Ubuntu", 10)
        HDR_FONT = ("Segoe UI", 13, "bold") if IS_WIN else ("Ubuntu", 13, "bold")
        SUB_FONT = ("Segoe UI", 9)          if IS_WIN else ("Ubuntu", 9)
        MONO     = ("Consolas", 9)          if IS_WIN else ("Monospace", 9)

        self._colors = dict(
            BG=BG, FG=FG, ACCENT=ACCENT, RED=RED,
            ENTRY_BG=ENTRY_BG, DIM=DIM,
            UI_FONT=UI_FONT, HDR_FONT=HDR_FONT,
            SUB_FONT=SUB_FONT, MONO=MONO)

        # ── Header ────────────────────────────────────────────────────────────
        hdr = tk.Frame(self, bg=ACCENT)
        hdr.pack(fill="x")
        tk.Label(hdr, text="  LinkedIn Learning Solver",
                 bg=ACCENT, fg="white", font=HDR_FONT,
                 pady=12, anchor="w").pack(fill="x", padx=16)
        tk.Label(hdr, text="~Naegleria  |  v3.2  |  Incognito + Multi-Course",
                 bg=ACCENT, fg="#b8d8f0", font=SUB_FONT,
                 anchor="w").pack(fill="x", padx=16)
        tk.Frame(hdr, bg=ACCENT, height=10).pack()

        # ── Credentials ───────────────────────────────────────────────────────
        cf = tk.Frame(self, bg=DIM, pady=8, padx=10)
        cf.pack(fill="x", padx=18, pady=(12, 0))
        cf.columnconfigure(1, weight=1)
        cf.columnconfigure(3, weight=1)

        tk.Label(cf, text="Email:", bg=DIM, fg=FG,
                 font=UI_FONT).grid(row=0, column=0, sticky="w", padx=(0,6))
        self.v_email = tk.StringVar()
        tk.Entry(cf, textvariable=self.v_email, bg=ENTRY_BG, fg=FG,
                 insertbackground=FG, font=UI_FONT, relief="flat",
                 bd=4).grid(row=0, column=1, sticky="ew", padx=(0,14))

        tk.Label(cf, text="Password:", bg=DIM, fg=FG,
                 font=UI_FONT).grid(row=0, column=2, sticky="w", padx=(0,6))
        self.v_pass = tk.StringVar()
        tk.Entry(cf, textvariable=self.v_pass, show="*", bg=ENTRY_BG, fg=FG,
                 insertbackground=FG, font=UI_FONT, relief="flat",
                 bd=4).grid(row=0, column=3, sticky="ew")

        # ── Multi-course URL section ───────────────────────────────────────────
        course_hdr = tk.Frame(self, bg=BG)
        course_hdr.pack(fill="x", padx=18, pady=(14, 2))
        tk.Label(course_hdr, text="Course URLs",
                 bg=BG, fg=FG, font=(UI_FONT[0], UI_FONT[1], "bold"),
                 anchor="w").pack(side="left")
        tk.Label(course_hdr,
                 text="  (all courses run in parallel, each with its own incognito sessions)",
                 bg=BG, fg="#444", font=SUB_FONT, anchor="w").pack(side="left")
        tk.Button(course_hdr, text="+ Add Course",
                  command=self._add_course_row,
                  bg="#1a3a1a", fg="#3fb950", font=SUB_FONT,
                  relief="flat", padx=10, pady=3, cursor="hand2",
                  activebackground="#0f2a0f").pack(side="right")

        # Scrollable container for course rows
        self._course_outer = tk.Frame(self, bg=BG)
        self._course_outer.pack(fill="x", padx=18)
        self._course_rows = []   # list of (frame, StringVar)
        self._add_course_row()   # start with one row

        # ── Settings ──────────────────────────────────────────────────────────
        self.v_adaptive  = tk.BooleanVar(value=True)

        # ── Speed mode toggle ─────────────────────────────────────────────────
        tf = tk.Frame(self, bg=BG)
        tf.pack(fill="x", padx=18, pady=(6, 0))
        tk.Checkbutton(
            tf,
            text="  Adaptive Speed  (short videos slower, long videos faster)",
            variable=self.v_adaptive,
            bg=BG, fg=FG,
            selectcolor="#1a1a1a",
            activebackground=BG,
            activeforeground=FG,
            font=UI_FONT
        ).pack(side="left")
        tk.Label(tf, text="  ← untick for flat 16x always",
                 bg=BG, fg="#444", font=SUB_FONT).pack(side="left")

        # ── Buttons ───────────────────────────────────────────────────────────
        bf = tk.Frame(self, bg=BG)
        bf.pack(fill="x", padx=18, pady=10)

        self.btn_run = tk.Button(
            bf, text="Start All Courses", command=self._start,
            bg=ACCENT, fg="white", font=(UI_FONT[0], 10, "bold"),
            relief="flat", padx=22, pady=8, cursor="hand2",
            activebackground="#005f93", activeforeground="white")
        self.btn_run.pack(side="left", padx=(0, 8))

        self.btn_stop = tk.Button(
            bf, text="Stop & Close All", command=self._stop,
            bg=RED, fg="white", font=UI_FONT,
            relief="flat", padx=18, pady=8, cursor="hand2",
            activebackground="#922b21", activeforeground="white",
            state="disabled")
        self.btn_stop.pack(side="left")

        self.btn_restart = tk.Button(
            bf, text="Restart", command=self._restart,
            bg="#7d4e00", fg="white", font=UI_FONT,
            relief="flat", padx=18, pady=8, cursor="hand2",
            activebackground="#5a3800", activeforeground="white",
            state="disabled")
        self.btn_restart.pack(side="left", padx=(8, 0))

        tk.Button(bf, text="Clear Log", command=self._clear,
                  bg="#1a1a1a", fg="#555", font=SUB_FONT,
                  relief="flat", padx=12, pady=8,
                  cursor="hand2").pack(side="right")

        # Progress bar
        style = ttk.Style()
        style.theme_use("default")
        style.configure("S.Horizontal.TProgressbar",
                        troughcolor="#1a1a1a", background=ACCENT, thickness=3)
        self.progress = ttk.Progressbar(
            self, mode="indeterminate", style="S.Horizontal.TProgressbar")
        self.progress.pack(fill="x", padx=18, pady=(0, 4))

        # Console
        tk.Label(self, text="  Output", bg=BG, fg="#333",
                 font=SUB_FONT, anchor="w").pack(fill="x", padx=18)
        self.console = scrolledtext.ScrolledText(
            self, bg="#0d1117", fg="#8b949e", font=MONO,
            relief="flat", bd=0, wrap="word", state="disabled", height=22)
        self.console.pack(fill="both", expand=True, padx=18, pady=(2, 18))
        self.console.tag_config("ok",  foreground="#3fb950")
        self.console.tag_config("err", foreground="#f85149")
        self.console.tag_config("inf", foreground="#58a6ff")
        self.console.tag_config("hdr", foreground="#e3b341",
                                font=(MONO[0], MONO[1], "bold"))
        self.minsize(920, 800)

    # ── Multi-course row management ───────────────────────────────────────────

    def _add_course_row(self):
        c   = self._colors
        idx = len(self._course_rows) + 1
        row = tk.Frame(self._course_outer, bg=c["BG"])
        row.pack(fill="x", pady=(2, 0))
        row.columnconfigure(1, weight=1)

        lbl = tk.Label(row, text=f"#{idx}", bg=c["BG"], fg=c["ACCENT"],
                       font=c["SUB_FONT"], width=3)
        lbl.grid(row=0, column=0, sticky="w")

        var   = tk.StringVar()
        entry = tk.Entry(row, textvariable=var, bg=c["ENTRY_BG"], fg=c["FG"],
                         insertbackground=c["FG"], font=c["UI_FONT"],
                         relief="flat", bd=4)
        entry.grid(row=0, column=1, sticky="ew", padx=(4, 4))

        def _remove(r=row, v=var):
            r.destroy()
            self._course_rows = [(fr, sv) for fr, sv in self._course_rows
                                 if fr is not r]
            self._renumber_courses()

        tk.Button(row, text="x", command=_remove,
                  bg=c["BG"], fg="#555", font=c["SUB_FONT"],
                  relief="flat", padx=6, cursor="hand2",
                  activeforeground=c["RED"]).grid(row=0, column=2, sticky="e")

        self._course_rows.append((row, var))

    def _renumber_courses(self):
        for i, (row, _) in enumerate(self._course_rows, 1):
            for w in row.winfo_children():
                if isinstance(w, tk.Label) and w.cget("width") == 3:
                    w.config(text=f"#{i}")
                    break

    # ── Logging ───────────────────────────────────────────────────────────────

    def _log(self, msg):
        def _w():
            self.console.configure(state="normal")
            tag = ("ok"  if any(c in msg for c in ["done","complete","Logged","All videos"]) else
                   "err" if any(c in msg for c in ["Error","failed","Aborting","Stopped"]) else
                   "hdr" if "===" in msg else "inf")
            self.console.insert("end", msg + "\n", tag)
            self.console.see("end")
            self.console.configure(state="disabled")
        self.after(0, _w)

    def _clear(self):
        self.console.configure(state="normal")
        self.console.delete("1.0", "end")
        self.console.configure(state="disabled")

    # ── Start / Stop ──────────────────────────────────────────────────────────

    def _start(self):
        email = self.v_email.get().strip()
        pwd   = self.v_pass.get().strip()
        course_urls = [sv.get().strip()
                       for _, sv in self._course_rows
                       if sv.get().strip()]

        if not email or not pwd:
            messagebox.showwarning("Missing Fields",
                                   "Fill in your email and password.")
            return
        if not course_urls:
            messagebox.showwarning("No Courses",
                                   "Add at least one Course URL.")
            return
        bad = [u for u in course_urls if "linkedin.com/learning" not in u]
        if bad:
            messagebox.showwarning("Invalid URL",
                                   f"Not a LinkedIn Learning URL:\n{bad[0]}")
            return

        self.btn_run.configure(state="disabled")
        self.btn_stop.configure(state="normal")
        self.btn_restart.configure(state="normal")
        self.progress.start(8)

        self.engines = []
        self.threads = []

        # Atomic counter — when all engines finish, call _done
        pending   = {"n": len(course_urls)}
        p_lock    = threading.Lock()

        def on_done():
            with p_lock:
                pending["n"] -= 1
                if pending["n"] == 0:
                    self.after(0, self._done)

        for i, url in enumerate(course_urls, 1):
            label  = f"C{i}"
            engine = SixteenXEngine(self._log, label, self)
            self.engines.append(engine)

            def _runner(eng=engine, u=url):
                try:
                    eng.run(email, pwd, 1, u)
                finally:
                    on_done()

            t = threading.Thread(target=_runner, daemon=True)
            t.start()
            self.threads.append(t)

        self._log(
            f"\n🚀 Launched {len(course_urls)} course(s) "
            f"— auto-advance from video 1, one session each\n")

    def _done(self):
        self.progress.stop()
        self.btn_run.configure(state="normal")
        self.btn_stop.configure(state="disabled")
        self.btn_restart.configure(state="disabled")

    def _kill_all(self):
        for eng in self.engines:
            eng.running = False
            for sess in (eng.sessions or []):
                sess.quit()
            eng.sessions = []

    def _stop(self):
        self._kill_all()
        self._log("Stopped — all browsers closed.")
        self._done()

    def _restart(self):
        self._log("Restarting — closing all browsers...")
        self._kill_all()
        self.after(1200, self._do_restart)

    def _do_restart(self):
        self._clear()
        self.progress.stop()
        self.btn_restart.configure(state="disabled")
        self.btn_stop.configure(state="disabled")
        self.btn_run.configure(state="normal")
        self._log("Restarted — launching fresh sessions...\n")
        self._start()


if __name__ == "__main__":
    App().mainloop()
