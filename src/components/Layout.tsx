import type { ReactNode } from "react";
import { Link } from "react-router-dom";

interface LayoutProps {
  children: ReactNode;
  center?: boolean;
  backTo?: string;
  backLabel?: string;
}

export function Layout({
  children,
  center = false,
  backTo,
  backLabel = "返回",
}: LayoutProps) {
  return (
    <div className={`app-shell${center ? " app-shell--center" : ""}`}>
      {backTo && (
        <Link to={backTo} className="back-link">
          ← {backLabel}
        </Link>
      )}
      {children}
    </div>
  );
}
