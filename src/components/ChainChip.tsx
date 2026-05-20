import { useState } from "react";
import type { Chain } from "../data/chains";

interface ChainChipProps {
  chain: Chain;
  selected: boolean;
  onClick: () => void;
}

export function ChainChip({ chain, selected, onClick }: ChainChipProps) {
  const [imgFailed, setImgFailed] = useState(false);

  return (
    <button
      type="button"
      className={`chain-chip${selected ? " chain-chip--selected" : ""}`}
      onClick={onClick}
      aria-pressed={selected}
    >
      <div className="chain-icon" style={{ background: chain.color }}>
        {!imgFailed ? (
          <img
            src={chain.logoUrl}
            alt=""
            width={40}
            height={40}
            onError={() => setImgFailed(true)}
          />
        ) : (
          chain.symbol.slice(0, 2)
        )}
      </div>
      <span>{chain.name}</span>
    </button>
  );
}
