const $ = (id) => document.getElementById(id);

const GIFT_NAMES = {
  demo_entry_gift: "入职礼物",
  gift_phone: "手机",
  gift_snack: "零食",
  gift_coffee: "咖啡",
  gift_alarm: "闹钟",
  gift_file: "文件",
};

const LIKE_THRESHOLD = 10;

// 用户端累计点赞（本地显示用，服务端才是真实权威）
let localUserLikes = {};

function identity() {
  return {
    user_id: ($("userId").value || "").trim() || "demo-user",
    nickname: ($("nickname").value || "").trim() || "模拟观众",
  };
}

async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json();
}

function setOnline(online, text) {
  const status = $("connStatus");
  status.classList.toggle("status--on", online);
  status.classList.toggle("status--off", !online);
  $("connText").textContent = text || (online ? "引擎已连接" : "引擎未连接");
}

function describeEvent(event) {
  if (!event) return "暂无";
  const name = event.nickname || "模拟观众";
  if (event.kind === "like") return `${name} 点赞 ×${event.repeat || 1}`;
  if (event.kind === "comment") return `${name} 评论「${event.text || ""}」`;
  if (event.kind === "gift") return `${name} 送出 ${GIFT_NAMES[event.gift_id] || event.gift_id || "礼物"}`;
  return `${name} 触发 ${event.kind}`;
}

function renderSeatGrid(seats) {
  const grid = $("seatGrid");
  if (!grid) return;
  if (grid.children.length !== seats.length) {
    grid.innerHTML = "";
    seats.forEach((seat) => {
      const chip = document.createElement("div");
      chip.className = "seat-chip";
      chip.dataset.seat = String(seat.index);
      grid.appendChild(chip);
    });
  }
  seats.forEach((seat, index) => {
    const chip = grid.children[index];
    const occupied = Boolean(seat.employee_id);
    chip.classList.toggle("seat-chip--occupied", occupied);
    chip.textContent = occupied
      ? `${String(seat.index).padStart(2, "0")} ${seat.nickname || "员工"}`
      : String(seat.index).padStart(2, "0");
  });
}

function renderEmployeeList(employees) {
  const list = $("employeeList");
  if (!list) return;
  if (!employees || employees.length === 0) {
    list.innerHTML = '<p class="hint">暂无员工</p>';
    return;
  }
  list.innerHTML = "";
  employees.forEach((emp) => {
    const row = document.createElement("div");
    row.className = "emp-row";
    row.innerHTML = `<strong>#${String(emp.seat_index).padStart(2, "0")}</strong> ${emp.nickname} <em style="color:#888">(${emp.entry_method})</em>`;
    list.appendChild(row);
  });
}

function renderQueue(queuePreview) {
  const list = $("queueList");
  if (!list) return;
  if (!queuePreview || queuePreview.length === 0) {
    list.innerHTML = '<p class="hint">队列为空</p>';
    return;
  }
  list.innerHTML = "";
  queuePreview.forEach((q, i) => {
    const row = document.createElement("div");
    row.className = "queue-row";
    row.innerHTML = `<em>${i + 1}.</em> ${q.nickname}`;
    list.appendChild(row);
  });
}

function renderUserLikeHint(snapshot) {
  const user = identity();
  const hint = $("userLikeHint");
  if (!hint) return;
  // 从本地累计 + 服务端是否已在职 判断
  if (snapshot && snapshot.employees) {
    const already = snapshot.employees.find((e) => e.nickname === user.nickname);
    if (already) {
      hint.textContent = `当前用户「${user.nickname}」已入职（工位 #${already.seat_index}）`;
      hint.style.color = "#2a8a2a";
      return;
    }
  }
  const total = localUserLikes[user.user_id] || 0;
  const remaining = Math.max(0, LIKE_THRESHOLD - total);
  hint.textContent = `当前累计点赞：${total} / ${LIKE_THRESHOLD}  ${remaining > 0 ? `（还差 ${remaining} 个入职）` : "（已可入职！）"}`;
  hint.style.color = remaining > 0 ? "" : "#2a8a2a";
}

function render(snapshot) {
  if (!snapshot || !snapshot.session) return;
  const session = snapshot.session;
  $("seatUsage").textContent = `${session.occupied_seats} / ${session.seat_count}`;
  $("freeSeats").textContent = String(session.free_seats ?? (session.seat_count - session.occupied_seats));
  $("queueCount").textContent = String(session.queue_count ?? 0);
  $("stateVersion").textContent = String(snapshot.version ?? 0);
  $("countLike").textContent = String(session.event_counts?.like ?? 0);
  $("countComment").textContent = String(session.event_counts?.comment ?? 0);
  $("countGift").textContent = String(session.event_counts?.gift ?? 0);
  $("lastEvent").textContent = describeEvent(session.last_event);

  renderSeatGrid(snapshot.seats || []);
  renderEmployeeList(snapshot.employees || []);
  renderQueue(session.queue_preview || []);
  renderUserLikeHint(snapshot);
}

function addLog(text) {
  const log = $("eventLog");
  const empty = log.querySelector(".hint");
  if (empty) empty.remove();
  const item = document.createElement("div");
  item.className = "log-item";
  const time = document.createElement("time");
  time.textContent = new Date().toLocaleTimeString("zh-CN", { hour12: false });
  const message = document.createElement("span");
  message.textContent = text;
  item.appendChild(time);
  item.appendChild(message);
  log.prepend(item);
  while (log.children.length > 12) log.removeChild(log.lastChild);
}

async function refresh() {
  try {
    const snapshot = await request("/api/state");
    render(snapshot);
    setOnline(true, "引擎已连接");
  } catch (error) {
    setOnline(false, "引擎未连接");
  }
}

async function sendMock(body, label) {
  const user = identity();
  try {
    const data = await request("/api/mock/event", {
      method: "POST",
      body: JSON.stringify({ ...user, ...body }),
    });
    render(data.snapshot);
    setOnline(true, "引擎已连接");

    // 更新本地累计点赞
    if (body.kind === "like") {
      localUserLikes[user.user_id] = (localUserLikes[user.user_id] || 0) + (body.repeat || 1);
    }

    const enterResults = data.entry_results || [];
    let extraMsg = "";
    if (enterResults.length > 0) {
      const r = enterResults[0];
      if (r.action === "joined") extraMsg = `→ 入职成功（工位 #${r.seat_index}）`;
      else if (r.action === "queued") extraMsg = `→ 已满员，进入排队（第 ${r.queue_index + 1} 位）`;
      else if (r.action === "already_in_office") extraMsg = "→ 已在职";
      else if (r.action === "already_in_queue") extraMsg = "→ 已在队列中";
    }
    addLog(`${label}${body.repeat && body.repeat > 1 ? ` ×${body.repeat}` : ""}${extraMsg}`);
  } catch (error) {
    setOnline(false, "引擎未连接");
    addLog(`${label} 失败：${error.message}`);
  }
}

async function leaveEmployee() {
  const seatIndex = parseInt($("leaveSeat").value, 10);
  if (isNaN(seatIndex) || seatIndex < 1 || seatIndex > 25) {
    addLog("离场失败：请输入 1-25 的工位编号");
    return;
  }
  try {
    const data = await request("/api/mock/leave", {
      method: "POST",
      body: JSON.stringify({ seat_index: seatIndex }),
    });
    render(data.snapshot);
    if (data.ok) {
      let msg = `工位 #${seatIndex} 员工离场`;
      if (data.promoted) msg += `；队列「${data.promoted.nickname}」自动补位`;
      addLog(msg);
    } else {
      addLog(`离场失败：${data.detail || data.error || "工位当前空闲"}`);
    }
  } catch (error) {
    addLog(`离场请求失败：${error.message}`);
  }
}

async function resetSession() {
  try {
    const snapshot = await request("/api/session/reset", { method: "POST" });
    localUserLikes = {};
    render(snapshot);
    addLog("已重置场次（清空员工、队列、计数）");
  } catch (error) {
    addLog(`重置失败：${error.message}`);
  }
}

// ---------- 事件绑定 ----------

$("btnLike1").addEventListener("click", () =>
  sendMock({ kind: "like", repeat: 1 }, "点赞 +1")
);
$("btnLike5").addEventListener("click", () =>
  sendMock({ kind: "like", repeat: 5 }, "点赞 +5")
);
$("btnLike10").addEventListener("click", () =>
  sendMock({ kind: "like", repeat: 10 }, "点赞 +10")
);
$("btnComment").addEventListener("click", () =>
  sendMock({ kind: "comment", text: $("commentText").value || "入职" }, "发送评论")
);
$("btnGift").addEventListener("click", () =>
  sendMock({ kind: "gift", gift_id: $("giftSelect").value }, "送出礼物")
);
$("btnLeave").addEventListener("click", leaveEmployee);
$("btnReset").addEventListener("click", resetSession);

// 用户身份变化时更新提示
$("userId").addEventListener("input", () => {
  localUserLikes = {};
  refresh();
});
$("nickname").addEventListener("input", () => refresh());

// 启动
refresh();
setInterval(refresh, 2000);
