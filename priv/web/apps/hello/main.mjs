const main = (target, { props = {}, context = {}, bus } = {}) => {
  const root = document.createElement("div");
  root.style.cssText = "font-family:system-ui,-apple-system,'Segoe UI',sans-serif;display:inline-flex;align-items:center;gap:10px;border:1px solid #cbd5e1;background:#f8fafc;border-radius:10px;padding:8px 14px;color:#334155;cursor:pointer;";
  let ticks = 0;
  const render = () => {
    root.innerHTML = `<span style="width:8px;height:8px;border-radius:50%;background:#22c55e;box-shadow:0 0 0 3px rgba(34,197,94,.2)"></span><span>Plain JS island — ${ticks} tick${ticks === 1 ? "" : "s"}. Click to cheer.</span>`;
  };
  render();
  const timer = setInterval(() => {
    ticks += 1;
    render();
  }, 1e3);
  const onClick = () => bus && bus.emit("activity", {
    title: "Vanilla JS",
    text: "No framework, still on the bus 🎉",
    icon: "🟢",
    color: "#22c55e"
  });
  root.addEventListener("click", onClick);
  target.appendChild(root);
  return {
    setProps: () => render(),
    destroy: () => {
      clearInterval(timer);
      root.removeEventListener("click", onClick);
      root.remove();
    }
  };
};
export {
  main as default
};
//# sourceMappingURL=main.mjs.map
