(function () {
  "use strict";

  var CONFIG_PATH = "/etc/jaspermate/config";
  var SERVICE_NAME = "jaspermate-cellular";
  var STATUS_POLL_MS = 5000;

  // Known config keys and their defaults
  var CONFIG_KEYS = ["APN", "PIN", "ROUTE_METRIC"];

  // Parsed config state
  var configLines = [];   // Array of {type, key?, text?} for comment-preserving serialization
  var configValues = {};  // Current KEY=VALUE map
  var configLoaded = false;
  var svcPollTimer = null;
  var operationPending = false;

  // ── Config Parsing ──

  function parseConfig(text) {
    configLines = [];
    configValues = {};
    if (!text) return;

    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var kvMatch = line.match(/^([A-Za-z_][A-Za-z_0-9]*)=(.*)$/);
      if (kvMatch) {
        configLines.push({ type: "kv", key: kvMatch[1] });
        configValues[kvMatch[1]] = kvMatch[2];
      } else {
        configLines.push({ type: "other", text: line });
      }
    }
  }

  function serializeConfig(formValues) {
    var emitted = {};
    var parts = [];

    for (var i = 0; i < configLines.length; i++) {
      var entry = configLines[i];
      if (entry.type === "kv") {
        var val = formValues.hasOwnProperty(entry.key) ? formValues[entry.key] : configValues[entry.key];
        parts.push(entry.key + "=" + (val != null ? val : ""));
        emitted[entry.key] = true;
      } else {
        parts.push(entry.text);
      }
    }

    // Append any known keys that weren't in the file
    for (var k = 0; k < CONFIG_KEYS.length; k++) {
      var key = CONFIG_KEYS[k];
      if (!emitted[key] && formValues.hasOwnProperty(key)) {
        parts.push(key + "=" + formValues[key]);
      }
    }

    var result = parts.join("\n");
    // Ensure trailing newline
    if (result.length > 0 && result[result.length - 1] !== "\n") {
      result += "\n";
    }
    return result;
  }

  // ── Form ↔ Config ──

  function loadConfigToForm() {
    var apn = document.getElementById("jmc-apn");
    var pin = document.getElementById("jmc-pin");
    var metric = document.getElementById("jmc-metric");

    if (apn) apn.value = configValues.APN || "";
    if (pin) pin.value = configValues.PIN || "";
    if (metric) metric.value = configValues.ROUTE_METRIC || "100";
  }

  function readFormValues() {
    var apn = document.getElementById("jmc-apn");
    var pin = document.getElementById("jmc-pin");
    var metric = document.getElementById("jmc-metric");

    var metricVal = metric ? parseInt(metric.value, 10) : 100;
    if (isNaN(metricVal) || metricVal < 1) metricVal = 100;
    if (metricVal > 9999) metricVal = 9999;

    return {
      APN: apn ? apn.value.trim() : "",
      PIN: pin ? pin.value.trim() : "",
      ROUTE_METRIC: String(metricVal)
    };
  }

  // ── Config File I/O ──

  function loadConfig() {
    cockpit.file(CONFIG_PATH).read()
      .then(function (content) {
        if (content === null) {
          // File doesn't exist
          configLoaded = false;
          showConfigMissing();
          hideLoading();
          return;
        }
        parseConfig(content);
        loadConfigToForm();
        configLoaded = true;
        enableForm(true);
        hideLoading();
      })
      .catch(function (err) {
        configLoaded = false;
        hideLoading();
        if (err.problem === "not-found" || (err.message && err.message.indexOf("No such file") !== -1)) {
          showConfigMissing();
        } else {
          showFeedback("Failed to load config: " + (err.message || err), "error");
        }
      });
  }

  function saveConfig(andRestart) {
    if (!configLoaded || operationPending) return;
    operationPending = true;
    setButtonsDisabled(true);
    showFeedback("Saving...", "info");

    // Re-read the file first to preserve any external edits
    cockpit.file(CONFIG_PATH).read()
      .then(function (content) {
        if (content !== null) {
          parseConfig(content);
        }
        var formValues = readFormValues();
        var newText = serializeConfig(formValues);

        return cockpit.file(CONFIG_PATH, { superuser: "require" }).replace(newText);
      })
      .then(function () {
        // Update local state with saved values
        var formValues = readFormValues();
        for (var key in formValues) {
          configValues[key] = formValues[key];
        }

        if (andRestart) {
          showFeedback("Saved. Restarting service...", "info");
          return restartService(true);
        } else {
          showFeedback("Configuration saved.", "success");
          operationPending = false;
          setButtonsDisabled(false);
        }
      })
      .catch(function (err) {
        showFeedback("Failed to save: " + (err.message || err), "error");
        operationPending = false;
        setButtonsDisabled(false);
      });
  }

  // ── Service Control ──

  function pollServiceStatus() {
    cockpit.spawn(
      ["systemctl", "show", "-p", "LoadState,ActiveState,SubState,ActiveEnterTimestamp", "--value", SERVICE_NAME]
    )
      .then(function (output) {
        var lines = output.trim().split("\n");
        var loadState = lines[0] || "not-found";
        var activeState = lines[1] || "inactive";
        var subState = lines[2] || "";
        var since = lines[3] || "";

        updateServiceUI(loadState, activeState, subState, since);
      })
      .catch(function () {
        updateServiceUI("not-found", "unknown", "", "");
      });
  }

  function updateServiceUI(loadState, activeState, subState, since) {
    var indicator = document.getElementById("jmc-svc-indicator");
    var stateEl = document.getElementById("jmc-svc-state");
    var sinceEl = document.getElementById("jmc-svc-since");
    var restartBtn = document.getElementById("jmc-btn-restart");
    var stopBtn = document.getElementById("jmc-btn-stop");

    if (!indicator || !stateEl) return;

    // Remove all state classes
    indicator.className = "jmc-svc-indicator";
    stateEl.className = "jmc-svc-value";

    if (loadState === "not-found") {
      indicator.classList.add("jmc-svc-inactive");
      stateEl.textContent = "Not installed";
      stateEl.classList.add("jmc-svc-value-inactive");
      if (sinceEl) sinceEl.textContent = "--";
      if (restartBtn) restartBtn.disabled = true;
      if (stopBtn) stopBtn.disabled = true;
      return;
    }

    var displayState = activeState;
    if (subState && subState !== activeState) {
      displayState = activeState + " (" + subState + ")";
    }

    if (activeState === "active") {
      indicator.classList.add("jmc-svc-active");
      stateEl.textContent = displayState;
      stateEl.classList.add("jmc-svc-value-active");
      if (!operationPending) {
        if (restartBtn) restartBtn.disabled = false;
        if (stopBtn) stopBtn.disabled = false;
      }
    } else if (activeState === "failed") {
      indicator.classList.add("jmc-svc-failed");
      stateEl.textContent = displayState;
      stateEl.classList.add("jmc-svc-value-failed");
      if (!operationPending) {
        if (restartBtn) restartBtn.disabled = false;
        if (stopBtn) stopBtn.disabled = true;
      }
    } else {
      indicator.classList.add("jmc-svc-inactive");
      stateEl.textContent = displayState;
      stateEl.classList.add("jmc-svc-value-inactive");
      if (!operationPending) {
        if (restartBtn) restartBtn.disabled = false;
        if (stopBtn) stopBtn.disabled = true;
      }
    }

    if (sinceEl) {
      sinceEl.textContent = since || "--";
    }
  }

  function restartService(fromSave) {
    if (!fromSave) {
      operationPending = true;
      setButtonsDisabled(true);
      showFeedback("Restarting service...", "info");
    }

    return cockpit.spawn(["systemctl", "restart", SERVICE_NAME], { superuser: "require" })
      .then(function () {
        showFeedback(fromSave ? "Saved and service restarted." : "Service restarted.", "success");
        operationPending = false;
        setButtonsDisabled(false);
        // Poll status after a short delay to let systemd settle
        setTimeout(pollServiceStatus, 2000);
      })
      .catch(function (err) {
        showFeedback("Restart failed: " + (err.message || err), "error");
        operationPending = false;
        setButtonsDisabled(false);
        pollServiceStatus();
      });
  }

  function stopService() {
    operationPending = true;
    setButtonsDisabled(true);
    showFeedback("Stopping service...", "info");

    cockpit.spawn(["systemctl", "stop", SERVICE_NAME], { superuser: "require" })
      .then(function () {
        showFeedback("Service stopped.", "success");
        operationPending = false;
        setButtonsDisabled(false);
        setTimeout(pollServiceStatus, 2000);
      })
      .catch(function (err) {
        showFeedback("Stop failed: " + (err.message || err), "error");
        operationPending = false;
        setButtonsDisabled(false);
        pollServiceStatus();
      });
  }

  // ── UI Helpers ──

  function showFeedback(message, type) {
    var el = document.getElementById("jmc-feedback");
    if (!el) return;
    el.textContent = message;
    el.className = "jmc-feedback jmc-feedback-" + type;

    if (type === "success") {
      setTimeout(function () {
        if (el.textContent === message) {
          el.className = "jmc-feedback jmc-feedback-hidden";
        }
      }, 5000);
    }
  }

  function showConfigMissing() {
    var form = document.getElementById("jmc-config-form");
    if (form) {
      form.innerHTML = '<div class="jmc-not-installed">Configuration file not found. Install the jaspermate-cellular service first.</div>';
    }
  }

  function enableForm(enabled) {
    var inputs = ["jmc-apn", "jmc-pin", "jmc-metric"];
    for (var i = 0; i < inputs.length; i++) {
      var el = document.getElementById(inputs[i]);
      if (el) el.disabled = !enabled;
    }
    var saveBtn = document.getElementById("jmc-btn-save");
    var saveOnlyBtn = document.getElementById("jmc-btn-save-only");
    if (saveBtn) saveBtn.disabled = !enabled;
    if (saveOnlyBtn) saveOnlyBtn.disabled = !enabled;
  }

  function setButtonsDisabled(disabled) {
    var ids = ["jmc-btn-save", "jmc-btn-save-only", "jmc-btn-restart", "jmc-btn-stop"];
    for (var i = 0; i < ids.length; i++) {
      var el = document.getElementById(ids[i]);
      if (el) el.disabled = disabled;
    }
  }

  function showLoading() {
    var el = document.getElementById("jmc-loading");
    if (el) el.classList.remove("jmc-loading-hidden");
  }

  function hideLoading() {
    var el = document.getElementById("jmc-loading");
    if (el) el.classList.add("jmc-loading-hidden");
  }

  // ── Init ──

  function init() {
    // Form submit = Save & Restart
    var form = document.getElementById("jmc-config-form");
    if (form) {
      form.addEventListener("submit", function (e) {
        e.preventDefault();
        saveConfig(true);
      });
    }

    // Save Only button
    var saveOnlyBtn = document.getElementById("jmc-btn-save-only");
    if (saveOnlyBtn) {
      saveOnlyBtn.addEventListener("click", function () {
        saveConfig(false);
      });
    }

    // Service control buttons
    var restartBtn = document.getElementById("jmc-btn-restart");
    if (restartBtn) {
      restartBtn.addEventListener("click", function () {
        restartService(false);
      });
    }

    var stopBtn = document.getElementById("jmc-btn-stop");
    if (stopBtn) {
      stopBtn.addEventListener("click", function () {
        stopService();
      });
    }

    // Disable form until config loads
    enableForm(false);

    // Load config and poll service status
    loadConfig();
    pollServiceStatus();
    svcPollTimer = setInterval(pollServiceStatus, STATUS_POLL_MS);

    // Clean up polling on page unload
    window.addEventListener("beforeunload", function () {
      if (svcPollTimer) {
        clearInterval(svcPollTimer);
        svcPollTimer = null;
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
