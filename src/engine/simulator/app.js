const $ = (id) => document.getElementById(id);

const GIFT_NAMES = {
  gift_join: "入职礼物",
  gift_phone: "手机",
  gift_snack: "零食",
  gift_coffee: "咖啡",
  gift_alarm: "闹钟",
  gift_file: "文件",
};

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
  if (!event) {
    return "暂无";
  }
  const name = event.nickname || "模拟观众";
  if (event.kind === "like") {
    return `${name} 点赞`;
  }
  if (event.kind === "comment") {
    return `${name} 评论「${event.text || ""}」`;
  }
  if (event.kind === "gift") {
    return `${name} 送出 ${GIFT_NAMES[event.gift_id] || event.gift_id || "礼物"}`;
  }
  return `${name} 触发 ${event.kind}`;
}

function renderSeatGrid(seats) {
  const grid = $("seatGrid");
  if (!grid) {
    return;
  }
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

function render(snapshot) {
  if (!snapshot || !snapshot.session) {
    return;
  }
  const session = snapshot.session;
  $("seatUsage").textContent = `${session.occupied_seats} / ${session.seat_count}`;
  $("stateVersion").textContent = String(snapshot.version ?? 0);
  $("countLike").textContent = String(session.event_counts?.like ?? 0);
  $("countComment").textContent = String(session.event_counts?.comment ?? 0);
  $("countGift").textContent = String(session.event_counts?.gift ?? 0);
  $("lastEvent").textContent = describeEvent(session.last_event);
  renderSeatGrid(snapshot.seats || []);
}

function addLog(text) {
  const log = $("eventLog");
  const empty = log.querySelector(".hint");
  if (empty) {
    empty.remove();
  }
  const item = document.createElement("div");
  item.className = "log-item";
  const time = document.createElement("time");
  time.textContent = new Date().toLocaleTimeString("zh-CN", { hour12: false });
  const message = document.createElement("span");
  message.textContent = text;
  item.appendChild(time);
  item.appendChild(message);
  log.prepend(item);
  while (log.children.length > 8) {
    log.removeChild(log.lastChild);
  }
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
    addLog(`${label}（${data.applied_count} 次）`);
  } catch (error) {
    setOnline(false, "引擎未连接");
    addLog(`${label}失败：${error.message}`);
  }
}

async function resetSession() {
  try {
    const snapshot = await request("/api/session/reset", { method: "POST" });
    render(snapshot);
    addLog("已重置场次");
  } catch (error) {
    addLog(`重置失败：${error.message}`);
  }
}

$("btnLike1").addEventListener("click", () =>
  sendMock({ kind: "like", repeat: 1 }, "点赞 +1")
);
$("btnLike10").addEventListener("click", () =>
  sendMock({ kind: "like", repeat: 10 }, "点赞 +10")
);
$("btnComment").addEventListener("click", () =>
  sendMock({ kind: "comment", text: "入职" }, "评论入职")
);
$("btnGift").addEventListener("click", () =>
  sendMock({ kind: "gift", gift_id: $("giftSelect").value }, "送出礼物")
);
$("btnReset").addEventListener("click", resetSession);

refresh();
setInterval(refresh, 2000);
