import type { SortKey } from "../data/tokens";

const LABELS: { key: SortKey; label: string }[] = [
  { key: "name", label: "名稱" },
  { key: "volume", label: "交易量" },
  { key: "change", label: "24h 漲跌" },
];

interface SortBarProps {
  value: SortKey;
  onChange: (key: SortKey) => void;
}

export function SortBar({ value, onChange }: SortBarProps) {
  return (
    <div className="sort-bar">
      {LABELS.map(({ key, label }) => (
        <button
          key={key}
          type="button"
          className={`sort-bar__btn${value === key ? " sort-bar__btn--active" : ""}`}
          onClick={() => onChange(key)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
