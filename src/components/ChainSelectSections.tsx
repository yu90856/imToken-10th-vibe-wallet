import type { Chain } from "../data/chains";
import {
  EVM_CHAINS,
  LAYER1_CHAINS,
  LAYER2_CHAINS,
  POPULAR_CHAINS,
} from "../data/chains";
import type { ChainSectionId } from "../store/onboarding";
import { isChainSelected } from "../store/onboarding";
import { ChainChip } from "./ChainChip";

function ChainSection({
  sectionId,
  title,
  chains,
  selectionAnchor,
  onSelect,
}: {
  sectionId: ChainSectionId;
  title: string;
  chains: Chain[];
  selectionAnchor: string;
  onSelect: (section: ChainSectionId, chainId: string) => void;
}) {
  if (chains.length === 0) return null;
  return (
    <>
      <h2 className="section-title">{title}</h2>
      <div className="chain-scroll" role="list">
        {chains.map((chain) => (
          <ChainChip
            key={`${sectionId}-${chain.id}`}
            chain={chain}
            selected={isChainSelected(selectionAnchor, sectionId, chain.id)}
            onClick={() => onSelect(sectionId, chain.id)}
          />
        ))}
      </div>
    </>
  );
}

interface ChainSelectSectionsProps {
  selectionAnchor: string;
  onSelect: (section: ChainSectionId, chainId: string) => void;
}

export function ChainSelectSections({
  selectionAnchor,
  onSelect,
}: ChainSelectSectionsProps) {
  return (
    <>
      <ChainSection
        sectionId="popular"
        title="最多人使用"
        chains={POPULAR_CHAINS}
        selectionAnchor={selectionAnchor}
        onSelect={onSelect}
      />
      <ChainSection
        sectionId="layer1"
        title="Layer 1"
        chains={LAYER1_CHAINS}
        selectionAnchor={selectionAnchor}
        onSelect={onSelect}
      />
      <ChainSection
        sectionId="layer2"
        title="Layer 2"
        chains={LAYER2_CHAINS}
        selectionAnchor={selectionAnchor}
        onSelect={onSelect}
      />
      <ChainSection
        sectionId="evm"
        title="EVM 兼容鏈"
        chains={EVM_CHAINS}
        selectionAnchor={selectionAnchor}
        onSelect={onSelect}
      />
    </>
  );
}
