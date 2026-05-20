import { useState } from "react";
import { EXPLORE_CATEGORIES } from "../../data/explore";
import { DappConnectBar } from "../../components/explore/DappConnectBar";

type ViewMode = "grid" | "browser";

export function ExplorePage() {
  const [mode, setMode] = useState<ViewMode>("grid");
  const [url, setUrl] = useState("https://app.venus.io");
  const [frameUrl, setFrameUrl] = useState("");

  const openUrl = (target?: string) => {
    let next = (target ?? url).trim();
    if (!next) return;
    if (!/^https?:\/\//i.test(next)) next = `https://${next}`;
    setUrl(next);
    setFrameUrl(next);
    setMode("browser");
  };

  return (
    <div className={`tab-page explore-page${mode === "browser" ? " explore-page--browser" : ""}`}>
      <div className="explore-bar">
        <input
          type="url"
          placeholder="輸入 Dapp 網址"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && openUrl()}
        />
        <button type="button" className="btn btn--secondary explore-bar__go" onClick={() => openUrl()}>
          前往
        </button>
        <button
          type="button"
          className={`btn explore-bar__toggle${mode === "grid" ? " btn--primary" : " btn--secondary"}`}
          onClick={() => setMode(mode === "grid" ? "browser" : "grid")}
        >
          {mode === "grid" ? "瀏覽" : "目錄"}
        </button>
      </div>

      {mode === "grid" ? (
        <div className="explore-grid-scroll">
          <p className="field-hint" style={{ marginBottom: 12 }}>
            點選 Dapp 進入瀏覽，頂部按「連接網站」即可與 Venus 等協議連線。
          </p>
          {EXPLORE_CATEGORIES.map((cat) => (
            <section key={cat.id} className="explore-section">
              <h2 className="section-title">{cat.title}</h2>
              <div className="dapp-grid">
                {cat.items.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    className="dapp-card"
                    onClick={() => openUrl(item.url)}
                  >
                    <strong>{item.name}</strong>
                    <span>{item.description}</span>
                  </button>
                ))}
              </div>
            </section>
          ))}
        </div>
      ) : (
        <div className="explore-browser">
          {frameUrl ? <DappConnectBar dappUrl={frameUrl} /> : null}
          <div className="explore-frame-wrap">
            {frameUrl ? (
              <iframe
                title="Web3 瀏覽"
                src={frameUrl}
                className="explore-frame"
                allow="clipboard-write; fullscreen"
              />
            ) : (
              <p className="field-hint explore-frame-placeholder">
                輸入網址後點擊「前往」，或從目錄選擇 Dapp。
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
