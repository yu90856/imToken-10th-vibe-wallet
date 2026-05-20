import { NavLink } from "react-router-dom";

const TABS = [
  { to: "/app/home", label: "首頁", icon: "⌂" },
  { to: "/app/market", label: "市場", icon: "◫" },
  { to: "/app/swap", label: "SWAP", icon: "⇄" },
  { to: "/app/explore", label: "探索", icon: "◎" },
  { to: "/app/assets", label: "資產", icon: "◉" },
] as const;

export function BottomNav() {
  return (
    <nav className="bottom-nav" aria-label="主選單">
      {TABS.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) =>
            `bottom-nav__item${isActive ? " bottom-nav__item--active" : ""}`
          }
        >
          <span className="bottom-nav__icon" aria-hidden>
            {tab.icon}
          </span>
          <span className="bottom-nav__label">{tab.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
