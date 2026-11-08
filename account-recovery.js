/* BioLab 账号登录增强：通过 Supabase Auth 发送密码重置邮件。 */
(function () {
  "use strict";

  var cfg = window.SUPABASE_CONFIG || {};
  if (!cfg.url || !cfg.anonKey) return;

  function install(modal) {
    if (!modal || modal.getAttribute("data-recovery-ready") === "1") return;
    var actions = modal.querySelector(".modal-actions");
    var email = modal.querySelector("#authEmail");
    var title = modal.querySelector("#authTitle");
    var note = modal.querySelector("#authNote");
    if (!actions || !email || !title || !note) return;

    modal.setAttribute("data-recovery-ready", "1");
    var button = document.createElement("button");
    button.type = "button";
    button.id = "authForgot";
    button.className = "btn";
    button.textContent = "忘记密码？";
    actions.insertBefore(button, actions.firstChild);

    function updateVisibility() {
      button.hidden = title.textContent !== "登录";
    }
    updateVisibility();
    var titleObserver = new MutationObserver(updateVisibility);
    titleObserver.observe(title, { childList: true, characterData: true, subtree: true });

    button.addEventListener("click", function () {
      var address = email.value.trim();
      if (!address || !email.checkValidity()) {
        note.textContent = "请先输入有效的注册邮箱。";
        note.style.color = "var(--rose)";
        email.focus();
        return;
      }

      button.disabled = true;
      note.textContent = "正在发送重置邮件…";
      note.style.color = "var(--text-faint)";

      var url = String(cfg.url).replace(/\\/+$/, "") + "/auth/v1/recover?redirect_to=" +
        encodeURIComponent(window.location.href.split("#")[0]);
      fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: cfg.anonKey
        },
        body: JSON.stringify({ email: address })
      }).then(function (response) {
        if (!response.ok) {
          return response.text().then(function (text) {
            var message = "HTTP " + response.status;
            try {
              var data = JSON.parse(text);
              message = data.msg || data.message || data.error_description || data.error || message;
            } catch (e) {}
            throw new Error(message);
          });
        }
        // 不区分邮箱是否注册，避免泄露账号是否存在。
        note.textContent = "如果该邮箱已注册，你会收到密码重置邮件；请检查收件箱和垃圾邮件。";
        note.style.color = "var(--mint)";
      }).catch(function (error) {
        var message = String(error && error.message || error);
        if (/Failed to fetch|NetworkError|Load failed/i.test(message)) {
          message = "连不上服务器，请检查网络和 Supabase 配置。";
        }
        note.textContent = "发送失败：" + message.slice(0, 100);
        note.style.color = "var(--rose)";
      }).then(function () {
        button.disabled = false;
      });
    });
  }

  function watch() {
    var modal = document.getElementById("authModal");
    if (modal) install(modal);
    var observer = new MutationObserver(function () {
      var current = document.getElementById("authModal");
      if (current) install(current);
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", watch);
  } else {
    watch();
  }
})();
