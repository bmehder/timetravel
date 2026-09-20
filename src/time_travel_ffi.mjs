const minimumVisible = 64;

// Module state intentionally survives the inspector being closed and rendered
// again, restoring the user's most recent size and position.
let savedLayout = null;

export function attachDragging(root) {
  const panel = root.querySelector("[data-time-travel-panel]");
  const handle = root.querySelector("[data-time-travel-drag-handle]");

  if (!panel || !handle || handle.dataset.draggingReady === "true") return;
  handle.dataset.draggingReady = "true";

  if (savedLayout) {
    panel.style.width = `${savedLayout.width}px`;
    panel.style.height = `${savedLayout.height}px`;
    panel.style.left = `${savedLayout.left}px`;
    panel.style.top = `${savedLayout.top}px`;
    panel.style.right = "auto";
    panel.style.bottom = "auto";
  }

  const rememberLayout = () => {
    const rect = panel.getBoundingClientRect();
    savedLayout = {
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    };
  };

  const resizeObserver = new ResizeObserver(rememberLayout);
  resizeObserver.observe(panel);

  const removalObserver = new MutationObserver(() => {
    if (!panel.isConnected) {
      resizeObserver.disconnect();
      removalObserver.disconnect();
    }
  });
  removalObserver.observe(root, { childList: true, subtree: true });

  handle.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    if (event.target.closest?.("button")) return;

    const rect = panel.getBoundingClientRect();
    const offsetX = event.clientX - rect.left;
    const offsetY = event.clientY - rect.top;

    panel.style.left = `${rect.left}px`;
    panel.style.top = `${rect.top}px`;
    panel.style.right = "auto";
    panel.style.bottom = "auto";

    handle.setPointerCapture(event.pointerId);

    const move = (moveEvent) => {
      // Keep only a small portion visible rather than clamping the whole panel
      // inside the viewport. This lets the debugger be moved out of the app's
      // way without making it impossible to retrieve.
      const minX = minimumVisible - panel.offsetWidth;
      const maxX = window.innerWidth - minimumVisible;
      const maxY = window.innerHeight - minimumVisible;
      const left = Math.min(
        Math.max(minX, moveEvent.clientX - offsetX),
        maxX,
      );
      const top = Math.min(Math.max(0, moveEvent.clientY - offsetY), maxY);

      panel.style.left = `${left}px`;
      panel.style.top = `${top}px`;
      rememberLayout();
    };

    const stop = () => {
      rememberLayout();
      handle.removeEventListener("pointermove", move);
      handle.removeEventListener("pointerup", stop);
      handle.removeEventListener("pointercancel", stop);
    };

    handle.addEventListener("pointermove", move);
    handle.addEventListener("pointerup", stop);
    handle.addEventListener("pointercancel", stop);
  });
}
