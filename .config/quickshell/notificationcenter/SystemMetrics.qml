import QtQuick
import Quickshell.Io

// SystemMetrics – polls CPU, RAM, and Disk usage
QtObject {
    id: metrics

    // ── Exposed state ───────────────────────────────────────────────────
    property bool active: false
    property real cpuPercent:  0.0   // 0–100
    property real ramPercent:  0.0   // 0–100
    property real ramUsedGb:   0.0
    property real ramTotalGb:  0.0
    property real diskPercent: 0.0   // 0–100
    property real diskUsedGb:  0.0
    property real diskTotalGb: 0.0

    // ── CPU tracking internals ──────────────────────────────────────────
    property var _prevCpu: null

    // ── Timer to trigger poll ───────────────────────────────────────────
    property var _timer: Timer {
        interval: 2000
        running: metrics.active
        repeat: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true;
            if (!ramProc.running) ramProc.running = true;
        }
    }

    // ── CPU – read /proc/stat ──────────────────────────────────────────
    property var cpuProc: Process {
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/);
                if (parts.length < 5 || parts[0] !== "cpu") return;
                var user    = parseInt(parts[1]);
                var nice    = parseInt(parts[2]);
                var system  = parseInt(parts[3]);
                var idle    = parseInt(parts[4]);
                var iowait  = parseInt(parts[5]) || 0;
                var irq     = parseInt(parts[6]) || 0;
                var softirq = parseInt(parts[7]) || 0;
                var total = user + nice + system + idle + iowait + irq + softirq;

                if (metrics._prevCpu !== null) {
                    var dtotal = total - metrics._prevCpu.total;
                    var didle  = idle  - metrics._prevCpu.idle;
                    if (dtotal > 0)
                        metrics.cpuPercent = Math.round((1 - didle / dtotal) * 100);
                }
                metrics._prevCpu = { total: total, idle: idle };
            }
        }
    }

    // ── RAM – read /proc/meminfo ───────────────────────────────────────
    property var ramProc: Process {
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        property var _vals: ({})
        stdout: SplitParser {
            onRead: function(line) {
                var m = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/);
                if (m) ramProc._vals[m[1]] = parseInt(m[2]);
                var t = ramProc._vals["MemTotal"];
                var a = ramProc._vals["MemAvailable"];
                if (t && a) {
                    var used = t - a;
                    metrics.ramTotalGb  = Math.round(t    / 1024 / 1024 * 10) / 10;
                    metrics.ramUsedGb   = Math.round(used / 1024 / 1024 * 10) / 10;
                    metrics.ramPercent  = Math.round(used / t * 100);
                }
            }
        }
    }

    // ── Disk – shell poll (infrequent) ─────────────────────────────────
    property var diskTimer: Timer {
        interval: 10000 // Every 10 seconds
        running: metrics.active
        repeat: true
        onTriggered: diskProc.running = true
    }

    property var diskProc: Process {
        command: ["sh", "-c", "df -BG / | tail -1"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/);
                if (parts.length < 5) return;
                var total = parseInt(parts[1]);
                var used  = parseInt(parts[2]);
                var pct   = parseInt(parts[4]);
                if (!isNaN(total)) metrics.diskTotalGb = total;
                if (!isNaN(used))  metrics.diskUsedGb  = used;
                if (!isNaN(pct))   metrics.diskPercent = pct;
            }
        }
    }

    // Initial fetch when opened
    onActiveChanged: {
        if (active) {
            cpuProc.running = true;
            ramProc.running = true;
            diskProc.running = true;
        }
    }
}
