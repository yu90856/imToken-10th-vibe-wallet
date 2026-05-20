import { chainLogoUrl } from "../../lib/chainLogo";
import { DEFI_BY_CHAIN } from "../../data/defi";

export function DefiPage() {
  return (
    <div className="tab-page tab-page--scroll">
      <header className="page-header">
        <h1>DeFi</h1>
        <p>各鏈主流 DeFi 協議：借貸、質押、收益與衍生品。</p>
      </header>

      {DEFI_BY_CHAIN.map((group) => (
        <section key={group.chainId} className="defi-chain-block">
          <h2 className="section-title defi-chain-title">
            <img src={chainLogoUrl(group.chainId)} alt="" width={20} height={20} />
            {group.chainName}
          </h2>
          <div className="defi-list">
            {group.protocols.map((p) => (
              <a
                key={p.id}
                href={p.url}
                target="_blank"
                rel="noopener noreferrer"
                className="defi-card card"
              >
                <div className="defi-card__head">
                  <strong>{p.name}</strong>
                  <span className="defi-tags">
                    {p.types.map((t) => (
                      <span key={t} className="defi-tag">
                        {t}
                      </span>
                    ))}
                  </span>
                </div>
                <p>{p.description}</p>
              </a>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
