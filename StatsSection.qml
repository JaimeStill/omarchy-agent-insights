import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The detail the stock 4.5 panel folded into its rotating hero line:
// tokens by day for the last week, tokens by model, and all-time totals.
// One per subscription, under its limit rows. Everything it shows is already
// in the usage record; this file only draws it.
Column {
  id: stats

  // The panel root (for theme colors and the font) and the Main usage model
  // (for its token and model-name formatters).
  property var panel: null
  property var usageModel: null
  property var provider: null
  // Collapse state lives on the panel root (`insightsCollapsed`, keyed by
  // providerId), because these delegates are rebuilt on every record refresh.
  readonly property string providerId: provider ? String(provider.providerId || "") : ""
  readonly property bool expanded: !(panel && panel.insightsCollapsed && panel.insightsCollapsed[providerId])
  function toggleExpanded() {
    if (!panel || providerId === "") return
    var next = Object.assign({}, panel.insightsCollapsed || {})
    if (next[providerId]) delete next[providerId]
    else next[providerId] = true
    panel.insightsCollapsed = next
  }

  readonly property color foreground: panel ? panel.foreground : Commons.Color.foreground
  readonly property color dim: panel ? panel.dim : Qt.darker(foreground, 1.55)
  readonly property color track: panel ? panel.track : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  readonly property string fontFamily: panel ? panel.fontFamily : Style.font.family

  // Synced records union dates across devices, so keep the latest week only.
  readonly property var days: provider && provider.hasLocalStats !== false ? (provider.recentDays || []).slice(-7) : []
  readonly property bool hasDayData: days.some(function(d) { return Number(d.messageCount || 0) > 0 })
  readonly property real dayPeak: {
    var peak = 0
    for (var i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].messageCount || 0))
    return Math.max(1, peak)
  }
  readonly property var models: modelRows(provider)
  readonly property bool hasPromptStats: !!provider && provider.hasPromptStats !== false
  readonly property bool hasTotals: hasPromptStats && (Number(provider.totalPrompts || 0) > 0 || Number(provider.totalSessions || 0) > 0)
  readonly property bool hasAnything: hasDayData || models.length > 0 || hasTotals

  visible: hasAnything
  spacing: Style.space(12)

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function tokens(n) { return usageModel ? usageModel.formatTokenCount(Number(n || 0)) : String(n || 0) }
  function number(n) { return Commons.I18n.formatNumber(Number(n || 0)) }

  // Reads the panel's ticking clock so "Today" moves at midnight.
  readonly property string today: todayDate(panel ? panel.nowMs : Date.now())
  function todayDate(ms) {
    var d = new Date(ms)
    function pad(n) { return n < 10 ? "0" + n : String(n) }
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
  }

  function dayLabel(date, today) {
    if (today) return "Today"
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return Qt.locale(Commons.I18n.formatLocale).dayName([7, 1, 2, 3, 4, 5, 6][parsed.getDay()], Locale.ShortFormat)
  }

  function dayTooltip(day, today) {
    if (!day) return ""
    var parsed = new Date(String(day.date || "") + "T00:00:00")
    var when = isNaN(parsed.getTime()) ? String(day.date || "") : parsed.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale), Locale.LongFormat)
    var text = when + ": " + tokens(day.messageCount) + " tokens"
    if (today && hasPromptStats)
      text += "\n" + number(provider.todayPrompts) + " prompts · " + number(provider.todaySessions) + " sessions"
    return text
  }

  function modelRows(p) {
    var byModel = p ? (p.modelUsage || {}) : {}
    var today = p ? (p.todayTokensByModel || {}) : {}
    var rows = []
    for (var id in byModel) {
      var bucket = byModel[id] || {}
      var input = Number(bucket.inputTokens || 0)
      var output = Number(bucket.outputTokens || 0)
      var cacheRead = Number(bucket.cacheReadInputTokens || 0)
      var cacheWrite = Number(bucket.cacheCreationInputTokens || 0)
      var total = input + output + cacheRead + cacheWrite
      if (total <= 0) continue
      rows.push({
        name: usageModel ? usageModel.friendlyModelName(id) : id,
        total: total,
        input: input,
        output: output,
        cacheRead: cacheRead,
        cacheWrite: cacheWrite,
        today: Number(today[id] || 0)
      })
    }
    rows.sort(function(a, b) { return b.total - a.total })
    return rows
  }

  function modelTooltip(row) {
    if (!row) return ""
    var lines = [
      "In " + tokens(row.input) + " · out " + tokens(row.output),
      "Cache read " + tokens(row.cacheRead) + " · cache write " + tokens(row.cacheWrite)
    ]
    if (row.today > 0) lines.push("Today " + tokens(row.today))
    return lines.join("\n")
  }

  // ---------- Toggle ----------
  Item {
    width: parent.width
    implicitHeight: toggleText.implicitHeight

    Text {
      id: toggleText
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: (stats.expanded ? "▾ " : "▸ ") + "USAGE DETAIL"
      color: toggleMouse.containsMouse ? stats.foreground : stats.dim
      font.family: stats.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: toggleText
      anchors.margins: -Style.space(4)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: stats.toggleExpanded()
    }
  }

  // ---------- Tokens by day ----------
  Column {
    visible: stats.expanded && stats.hasDayData
    width: parent.width
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: "Tokens by day"
      color: stats.foreground
      font.family: stats.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: stats.days

      Item {
        id: dayRow
        required property var modelData
        // By date, not position: a fallback source can stop short of today.
        readonly property bool today: String(modelData.date || "") === stats.today
        readonly property real ratio: Number(modelData.messageCount || 0) / stats.dayPeak
        width: stats.width
        implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.space(2)

        Text {
          id: dayLabel
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(52)
          text: stats.dayLabel(dayRow.modelData.date, dayRow.today)
          color: dayRow.today ? stats.foreground : stats.dim
          font.family: stats.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: dayRow.today
        }

        Rectangle {
          id: dayTrack
          anchors.left: dayLabel.right
          anchors.right: dayValue.left
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
          radius: height / 2
          color: stats.track

          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: parent.radius
            width: parent.width * stats.clamp(dayRow.ratio, 0, 1)
            color: dayRow.today ? stats.foreground : stats.alpha(stats.foreground, 0.55)

            Behavior on width {
              NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
            }
          }
        }

        Text {
          id: dayValue
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(56)
          horizontalAlignment: Text.AlignRight
          text: stats.tokens(dayRow.modelData.messageCount)
          color: dayRow.today ? stats.foreground : stats.dim
          font.family: stats.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        HoverHandler { id: dayHover }

        PanelToolTip {
          visible: dayHover.hovered
          text: stats.dayTooltip(dayRow.modelData, dayRow.today)
          fontFamily: stats.fontFamily
        }
      }
    }
  }

  // ---------- Tokens by model ----------
  Column {
    visible: stats.expanded && stats.models.length > 0
    width: parent.width
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: "Tokens by model"
      color: stats.foreground
      font.family: stats.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: stats.models

      // The share bar fills the row behind the label, scaled to the heaviest
      // model so the top row is always full.
      Item {
        id: modelRow
        required property var modelData
        readonly property real share: modelData.total / Math.max(1, stats.models[0].total)
        width: stats.width
        implicitHeight: modelName.implicitHeight + Style.space(10)

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: stats.alpha(stats.foreground, 0.05)
        }

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: parent.width * stats.clamp(modelRow.share, 0, 1)
          radius: Style.cornerRadius
          color: stats.alpha(stats.foreground, 0.14)

          Behavior on width {
            NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
          }
        }

        Text {
          id: modelName
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.right: modelTokens.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: modelRow.modelData.name
          color: stats.foreground
          font.family: stats.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          id: modelTokens
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: stats.tokens(modelRow.modelData.total)
          color: stats.dim
          font.family: stats.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        HoverHandler { id: modelHover }

        PanelToolTip {
          visible: modelHover.hovered
          text: stats.modelTooltip(modelRow.modelData)
          fontFamily: stats.fontFamily
        }
      }
    }
  }

  // ---------- All-time totals ----------
  Row {
    visible: stats.expanded && stats.hasTotals
    width: parent.width
    spacing: Style.space(8)

    Repeater {
      model: stats.hasTotals ? [
        { label: "Prompts", value: stats.number(stats.provider.totalPrompts) },
        { label: "Sessions", value: stats.number(stats.provider.totalSessions) },
        { label: "Active days", value: stats.number(stats.provider.activeDays) }
      ] : []

      Rectangle {
        required property var modelData
        width: (stats.width - Style.space(8) * 2) / 3
        implicitHeight: totalBody.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: stats.alpha(stats.foreground, 0.05)

        Column {
          id: totalBody
          anchors.centerIn: parent
          spacing: Style.space(2)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: modelData.value
            color: stats.foreground
            font.family: stats.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: modelData.label
            color: stats.dim
            font.family: stats.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
